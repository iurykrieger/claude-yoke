---
name: ack-sensors
description: >
  Acknowledges every sensor available for the host project (catalog mode),
  verifies that every sensor referenced by an Acceptance Contract has a
  well-formed `.yoke/sensors/<id>.md` file (readiness mode), or creates /
  updates those sensor files from the contract's `## Sensors registry`
  block (upsert mode). Deterministic node — no agentic spawning. Output
  is structured YAML on stdout; diagnostics go to stderr. Sorted output
  is byte-identical across consecutive invocations on the same project.
argument-hint: "[--mode catalog | readiness | upsert] [<acceptance-contract-path>]"
allowed-tools: Bash, Read
---

# /yoke:ack-sensors — sensor catalog + readiness + upsert

Single source of truth for sensor discovery (catalog), pre-runtime
sensor-file readiness (readiness), and per-sensor file
materialization from the contract (upsert). Used by humans during
Trigger 3, by the Validator subagent at the start of every Phase-4
cycle, and by the human between cycles when a contract gains a new
sensor reference.

Per-sensor files live in `.yoke/sensors/<id>.md` (working memory,
project-scoped, **not** slug-keyed). They are the source of truth for
the sensor's command, class, tier (with class-based default), criterion
mapping, accumulated caveats, and run history. The Acceptance Contract
references sensors **by id only**.

Source PRD: `.yoke/prds/2026-04-27-sensor-cost-tiering.md`.

## How to run this skill

This skill is a thin wrapper: it forwards every argument to the
deterministic helper `lib/sensors/ack-sensors.sh`, which contains all
the parsing, sorting, materialization, and validation logic.

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
| `--mode readiness <contract>` | Verify every sensor referenced by the contract has a well-formed `.yoke/sensors/<id>.md` file | Before Phase 4; first thing the Validator does each cycle |
| `--mode upsert <contract>` | Create or update `.yoke/sensors/<id>.md` files from the contract's `## Sensors registry` block; field-level merge preserves author edits | After editing the contract; before the next `/yoke:implement` |

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
  - id: "<sensor-id>"
    path: ".yoke/sensors/<id>.md"
    exists: true | false
    parses: true | false
failures:
  - sensor: "<id>"
    expected: "<what should be there>"
    actual: "<what is there>"
    reason: "<short failure description>"
    correction: "<suggested next command>"
```

`failures:` is empty when `status: ready`. Every failure carries
`sensor`, `expected`, `actual`, `reason`, `correction` — the
structured-output rule from `patterns/sensors.md`.

Readiness checks **file existence + frontmatter shape**: the per-sensor
file must exist at `.yoke/sensors/<id>.md` and contain the required
frontmatter keys (`id`, `command`, `class`, `applies_to`, `runs`).
The standard correction when a check fails is to run
`/yoke:ack-sensors --mode upsert <contract>` to materialize / refresh
the missing file.

### Upsert mode

Reads the contract's `## Sensors registry` YAML block and the
`Sensors: [...]` references in BDD scenarios, then for each registered
sensor id:

- **Create path** (file absent at `.yoke/sensors/<id>.md`): renders
  the per-sensor file from `templates/sensor.md`, populating `id`,
  `command`, `class`, `applies_to` (the union of task ids referencing
  this sensor in the contract's scenarios), and `tier` (class-based
  default — `computational` → `cheap`, `inferential` → `expensive`).
  Body sections (`## Caveats`, `## Calibration notes`) are seeded
  empty for the author to fill in.
- **Update path** (file present): **field-level merge**. Only
  `applies_to` is refreshed from the contract. Author edits to
  `command`, `class`, explicit `tier:` overrides, the body (caveats,
  calibration notes), and `runs:` history are preserved verbatim.
  Atomic write via temp file + `mv`.
- **Idempotent**: when the desired `applies_to` matches the on-disk
  value, no file is rewritten — `mtime` stays put. Running upsert
  twice on a stable contract is a no-op.

Validation (fail-fast, structured violations on stderr):

- Every `Sensors: [<id>]` reference in a scenario must appear in the
  `## Sensors registry`. Unregistered references → exit 4.
- Every registry entry must have non-empty `command` and `class`. The
  `class` must be `computational` or `inferential`. Malformed entries
  → exit 4.
- Sensor `id` must satisfy `[a-z0-9][a-z0-9_.-]{0,63}` (path-traversal
  guard); enforced by `wm_sensor_path` in `lib/working-memory/paths.sh`.

#### Upsert output schema

```yaml
status: ok | error
upserted:
  - id: "<sensor-id>"
    path: ".yoke/sensors/<id>.md"
    action: created | updated | unchanged
failures: []
```

The `failures:` block is non-empty (and emitted on stderr) only when
the contract's registry / references fail validation; in that case
`status: error` and exit code is `4`.

### Exit codes

| Code | Meaning |
| :---: | :--- |
| `0` | Operation succeeded (catalog, readiness ready, upsert ok) |
| `2` | Usage error (bad flag, missing required argument) |
| `3` | Acceptance Contract file not found (readiness / upsert only) |
| `4` | Readiness: at least one sensor file is missing or malformed. Upsert: registry / reference validation failed. |

Codes match the family used by `lib/sensors/discover-from-claude-md.sh`
and `hooks/verify-acceptance.sh`.

## Pattern compliance

- **`patterns/sensors.md`** — every readiness / upsert failure
  includes `sensor`, `expected`, `actual`, `reason`, `correction`.
  No prose-only failures. Catalog output preserves the structured
  `category / command / source` shape. Per-sensor files are now the
  source of truth for command + class + tier; the contract carries
  only ids + a registry block.
- **`patterns/plugin-structure.md`** — skill lives at
  `skills/ack-sensors/SKILL.md`; logic delegates to
  `lib/sensors/ack-sensors.sh`, which calls the existing
  `lib/sensors/discover-from-claude-md.sh` (catalog) and writes to
  the project's `.yoke/sensors/` (upsert).
- **Conventions: "Blueprints wrapping agentic nodes"** — this skill
  is purely deterministic. `allowed-tools: Bash, Read` only — no
  `Task`, no `Agent`. Upsert is idempotent, atomic, and
  non-destructive (never deletes a sensor file even when the
  contract drops a reference — orphan handling is drift-sense's
  job).

## Anti-scope reminders

- This skill **does not** parse `package.json`, `Makefile`, or
  `pyproject.toml` for catalog mode beyond what
  `discover-from-*.sh` already does.
- This skill **does not** spawn sensors. The Validator orchestrates
  spawning.
- This skill **does not** read or write canonical memory.
- Upsert **does not** delete sensor files when the contract drops
  a reference — leftovers are drift-sense's responsibility.
- Upsert **does not** prompt interactively; missing registry
  metadata fails fast with a structured violation telling the user
  exactly which field to fill.

## Lineage

The CLAUDE.md parser (`lib/sensors/discover-from-claude-md.sh`)
predates this skill (introduced in Sprint 3). This skill exposes it
under a single user-facing surface, adds the readiness-mode
file-existence check, and adds the upsert mode that materializes
per-sensor files from the contract registry.
