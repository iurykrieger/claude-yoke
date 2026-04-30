# Sprint 01 of 04: `/yoke:ack-sensors` skill — catalog + readiness modes

> Migrated from: # Spec: `/yoke:ack-sensors` skill — catalog + readiness modes (Part 1 of 4)


> Generated via /vibeflow:gen-spec on 2026-04-25 from `.vibeflow/prds/ack-sensors-skill.md`

## Objective

Ship a deterministic `/yoke:ack-sensors` skill with two modes — **catalog**
(enumerate every sensor available for the host project) and **readiness**
(verify every sensor declared in an Acceptance Contract is reachable) — so
both humans authoring the Contract and the Validator at runtime have a
single source of truth for sensor discovery.

## Context

Today the only sensor-discovery surface is `lib/sensors/discover-from-claude-md.sh`,
called ad-hoc at spec time. There is no skill that aggregates discovery
results, no readiness check before Phase 4, and no diff-stable catalog
that PR reviewers can compare across changes. This part lays the
deterministic foundation that Parts 2–4 build on.

## Definition of Done

1. `/yoke:ack-sensors` (no args, default mode `catalog`) emits a YAML
   document with `sensors: []` (possibly empty) and `notes: []`,
   sorted by `(category, source, command)` — byte-identical across two
   consecutive invocations on the same project (deterministic).
2. `/yoke:ack-sensors --mode readiness <acceptance-contract-path>`
   exits `0` when every sensor declared under
   `## Sensors > ### Computational` has its leading binary on `$PATH`;
   exits `4` and emits a structured YAML failure block (with one entry
   per missing binary: `sensor`, `command`, `expected: on-PATH`,
   `actual: missing`, `reason`) otherwise.
3. When `CLAUDE.md` is missing or has no parseable bullets, the
   catalog still returns a valid YAML envelope (`sensors: []` plus
   `notes:` explaining why) — never a non-zero exit, never silent
   output.
4. `tests/smoke/ack-sensors-catalog.test.sh` exercises (a) catalog
   over a fixture host project with one `## Testing` and one
   `## Linting` bullet, asserting sorted YAML against a golden file;
   (b) readiness against a fixture Acceptance Contract with one
   reachable + one missing binary, asserting exit code and structured
   failure block.
5. **Quality gate (sensors pattern compliance):** every readiness
   failure includes `sensor`, `reason`, `expected`, `actual`. No
   prose-only failures. Verified by smoke test golden-diff.
6. **Quality gate (deterministic skill):** `skills/ack-sensors/SKILL.md`
   frontmatter `allowed-tools` includes only `Bash`, `Read` — no
   `Task`, no `Agent`. The skill is a deterministic node; agentic
   spawning belongs to Parts 2–3.

## Scope

- New `skills/ack-sensors/SKILL.md` implementing catalog + readiness
  modes. Catalog mode shells out to existing
  `lib/sensors/discover-from-claude-md.sh` (no reimplementation).
  Readiness mode parses the Acceptance Contract's
  `## Sensors > ### Computational` block (same shape that
  `hooks/verify-acceptance.sh` consumes today) and runs `command -v`
  per sensor.
- New `tests/smoke/ack-sensors-catalog.test.sh` covering both modes
  with golden-output assertions; uses a fixture host project under
  `tests/fixtures/ack-sensors/`.
- Skill output schema documented inline in `SKILL.md` (YAML envelope,
  field-by-field).

## Anti-scope

- **No** new discoverers (package.json, Makefile, pyproject.toml) —
  deferred to Part 4 to keep this part within budget. Catalog v0
  surfaces only `CLAUDE.md`-derived sensors.
- **No** Validator changes — Part 2 wires the Validator to call this
  skill; Part 1 ships the skill itself.
- **No** inferential-sensor enumeration — there is no inferential
  template registry yet. Part 3 introduces `lib/sensors/templates/`
  and the catalog will gain inferential entries then.
- **No** changes to `hooks/verify-acceptance.sh` — Part 2 owns the
  hook's delegation to readiness mode.
- **No** caching of catalog output across invocations.

## Technical Decisions

### Skill, not bash script
`/yoke:ack-sensors` is a skill (`skills/ack-sensors/SKILL.md`), not
a bare bash script under `lib/`. Reason: it must be invocable as a
slash command by humans during Trigger 3, and skills are the
plugin's user-facing surface. The skill body is bash-driven —
deterministic node per the manifesto's blueprint principle.

**Trade-off:** double indirection (skill → bash). Mitigated by
keeping the skill body small (≤ 80 lines of inline bash) and
delegating heavy work to existing `lib/sensors/*.sh`.

### Reuse `discover-from-claude-md.sh`, don't reimplement
The existing parser already handles the bullet shape, escape rules,
and the empty-CLAUDE.md envelope. The skill calls it via `bash` and
post-processes the output (sort + augment).

### Sort key: `(category, source, command)`
Stable, human-readable, and matches how reviewers scan the catalog.
Sort happens in the skill, not in the discoverer scripts — keeps
discoverers single-purpose and lets future discoverers stay
order-agnostic.

### Readiness exit codes
- `0` — all declared sensors reachable
- `2` — usage error (matches existing convention in
  `discover-from-claude-md.sh`)
- `3` — Acceptance Contract not found (matches
  `verify-acceptance.sh`)
- `4` — at least one sensor unreachable (matches
  `verify-acceptance.sh`'s "no Computational section" code; the
  skill reuses the family for consistency)

### Output goes to stdout; diagnostics to stderr
Standard pattern across the repo's `lib/sensors/*.sh` scripts. The
skill follows it so its output can be piped into the Validator's
manifest parser in Part 2.

## Applicable Patterns

- **`patterns/sensors.md`** — structured-output rule (every failure
  includes `sensor`, location, expected, actual). Readiness failures
  must conform.
- **`patterns/plugin-structure.md`** — skill location
  (`skills/ack-sensors/`), file naming (`SKILL.md`), frontmatter
  shape.
- **Conventions: "Blueprints wrapping agentic nodes"** — the skill
  is a deterministic node. No LLM judgment inside.
- **Conventions: "Bash scripts target bash 4+"** — applies to the
  skill body and any helpers.

## Risks

| Risk | Likelihood | Impact | Mitigation |
| :--- | :--- | :--- | :--- |
| Acceptance Contract format drifts and the readiness parser falls out of sync with `verify-acceptance.sh` | medium | medium | Both parsers extract the same `## Sensors > ### Computational` block; Part 2 unifies them by having `verify-acceptance.sh` delegate to this skill for discovery |
| Sort key produces unstable output across locales (`LC_ALL` differences) | low | medium | Pin sort to `LC_ALL=C` inside the skill |
| Empty-catalog fallback masks a real misconfigured project | low | low | Always include `notes:` block explaining why; smoke test asserts notes present when sensors empty |
| `command -v` succeeds for shell builtins but the actual `bash -c "<command>"` would fail | low | low | Document this as a known false-positive in `SKILL.md`; Part 2's parallel runner catches it via the actual exit code |
