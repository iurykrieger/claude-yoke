---
name: ack-sensors
description: >
  Acknowledges every sensor available for the host project (catalog mode)
  or verifies that every sensor declared in an Acceptance Contract is
  reachable on the local machine (readiness mode). Deterministic node —
  no agentic spawning. Output is structured YAML on stdout; diagnostics
  go to stderr. Sorted output is byte-identical across consecutive
  invocations on the same project.
argument-hint: "[--mode catalog | readiness] [<acceptance-contract-path>]"
allowed-tools: Bash, Read
---

# /yoke:ack-sensors — sensor catalog + readiness check

Single source of truth for sensor discovery (catalog) and pre-runtime
reachability (readiness). Used by humans during Trigger 3 and by the
Validator subagent at the start of every Phase-4 cycle.

## How to run this skill

This skill is a thin wrapper: it forwards every argument to the
deterministic helper `lib/sensors/ack-sensors.sh`, which contains all
the parsing, sorting, and reachability logic.

Run the helper from the plugin root, forwarding `$@`:

```bash
bash lib/sensors/ack-sensors.sh "$@"
```

Surface the helper's stdout to the user verbatim. Surface its stderr
verbatim. Propagate its exit code.

Do **not** add narration around the YAML output — the output is
machine-consumable (the Validator parses it programmatically) and any
prose between fields will break that contract.

## Modes

The helper supports one optional `--mode` flag. Default is `catalog`.

| Flag | What it does | When to call it |
| :--- | :--- | :--- |
| `--mode catalog` *(default)* | Enumerate every sensor that *could* run for the host project | Before drafting an Acceptance Contract; on demand from a human |
| `--mode readiness <contract>` | Verify every sensor declared under `## Sensors > ### Computational` in the given Acceptance Contract is reachable | Before Phase 4; first thing the Validator does each cycle |

### Catalog output schema

```yaml
sensors:
  - category: <testing|linting|build>
    command: "<shell command>"
    source: claude-md
  # ... entries sorted by (category, source, command) under LC_ALL=C
notes:
  - "<human-readable note about discovery state, when applicable>"
```

The `sensors:` and `notes:` keys are always present. Either may be
empty (`sensors: []` / `notes: []`). Empty discovery is a valid result,
not an error — the `notes:` block explains the reason (missing
CLAUDE.md, no parseable bullets, etc.).

### Readiness output schema

```yaml
status: ready | not-ready
sensors:
  - sensor: "<name from contract>"
    command: "<command from contract>"
    binary: "<leading token>"
    reachable: true | false
failures:
  - sensor: "<name>"
    command: "<command>"
    expected: "on-PATH"
    actual: "missing"
    reason: "binary not found: <leading token>"
```

`failures:` is empty when `status: ready`. Every failure carries
`sensor`, `command`, `expected`, `actual`, `reason` — the
structured-output rule from `patterns/sensors.md`.

### Exit codes

| Code | Meaning |
| :---: | :--- |
| `0` | Catalog or readiness ran successfully (regardless of whether sensors were found / reachable in catalog mode) |
| `2` | Usage error (bad flag, missing required argument in readiness mode) |
| `3` | Acceptance Contract file not found (readiness mode only) |
| `4` | At least one declared sensor's binary is missing (readiness mode only) |

Codes match the family used by `lib/sensors/discover-from-claude-md.sh`
and `hooks/verify-acceptance.sh`.

## Pattern compliance

- **`patterns/sensors.md`** — every readiness failure includes
  `sensor`, `command`, `expected`, `actual`, `reason`. No prose-only
  failures. Catalog output preserves the structured `category /
  command / source` shape.
- **`patterns/plugin-structure.md`** — skill lives at
  `skills/ack-sensors/SKILL.md`; logic delegates to
  `lib/sensors/ack-sensors.sh`, which calls the existing
  `lib/sensors/discover-from-claude-md.sh`.
- **Conventions: "Blueprints wrapping agentic nodes"** — this skill
  is purely deterministic. `allowed-tools: Bash, Read` only — no
  `Task`, no `Agent`.

## Anti-scope reminders

- This skill **does not** parse `package.json`, `Makefile`, or
  `pyproject.toml`. Those discoverers ship in Part 4.
- This skill **does not** spawn sensors. The Validator orchestrates
  spawning (Part 2).
- This skill **does not** read or write canonical memory.

## Lineage

The CLAUDE.md parser (`lib/sensors/discover-from-claude-md.sh`)
predates this skill (introduced in Sprint 3). This skill exposes it
under a single user-facing surface and adds the readiness-mode
reachability check.
