# Sprint 03 of 05: Sensor Cost Tiering

> Migrated from: # Spec: Sensor Cost Tiering — Part 3: Tier-aware sensor execution


> Generated via /vibeflow:gen-spec on 2026-04-27 (revised 2026-04-27)
> Source PRD: `.vibeflow/prds/sensor-cost-tiering.md`

## Objective

`hooks/verify-acceptance.sh` accepts `--tier cheap | expensive | all`
(orthogonal to the existing `--criterion <id>`), reads tier from each
sensor's `.yoke/sensors/<id>.md` frontmatter (with class-based default
when `tier:` is absent), and runs only the matching subset.

## Context

Parts 1–2 turned sensors into per-file artifacts and made the upsert
the canonical way to materialize them. Part 3 is the **runtime
filter**: the hook learns to scope its execution by tier.

Without Part 3, downstream consumers (the Validator's reasoning in
Part 4 and the coordinator's two-phase per-cycle execution in Part 5)
have no way to actually run only the cheap or only the expensive
subset of sensors per invocation.

The flag is orthogonal to `--criterion <id>` — `--criterion` filters
*which sensors apply to a cycle*; `--tier` filters *which of those
fire this invocation*. Both filters compose by intersection.

## Definition of Done

1. `hooks/verify-acceptance.sh` accepts
   `--tier cheap | expensive | all`. The flag is parsed alongside
   (not instead of) `--criterion <id>`; both can be combined in any
   order on the command line.
2. Tier is resolved per sensor by reading `.yoke/sensors/<id>.md`
   frontmatter. When `tier:` is absent, the class-based default
   applies (computational → `cheap`; inferential → `expensive`).
3. **Default behavior preserved**: when `--tier` is omitted, the hook
   runs every applicable sensor — identical to current behavior.
   `--tier all` is explicit and equivalent.
4. `--tier cheap` runs only sensors whose resolved tier is `cheap`;
   `--tier expensive` runs only the `expensive` set.
5. **Combined filters intersect**: `--tier cheap --criterion C-3`
   runs only the cheap-tier sensors that apply to criterion `C-3`.
   Empty intersection → exit 0 (no violations possible).
6. **Unknown `--tier` value** (e.g. `--tier slow`) causes the hook
   to exit non-zero with a structured violation naming the
   offending value, the allowed set, and the corrected invocation —
   per `conventions.md` back-pressure.
7. **Sensor file missing or malformed** — exit non-zero with
   structured violation pointing at the offending file and the
   corrective instruction (`/yoke:ack-sensors --mode upsert`).
8. `tests/sensor-tiering.test.sh` extended with assertions for each
   case: omitted, `cheap`, `expensive`, `all`, intersection with
   `--criterion`, empty intersection, unknown-value error, missing-
   sensor-file error.
9. **Craftsmanship**: per-sensor YAML output schema unchanged when
   filtering — only the set of sensors run changes; no new fields,
   no schema drift; bash 4+ idioms; no new external dependencies.

## Scope

- **Edit** `hooks/verify-acceptance.sh`:
  - Extend the existing argparse block to recognize
    `--tier <cheap|expensive|all>`. Default value: `all` (preserves
    current behavior when flag is omitted).
  - When `--tier cheap` or `--tier expensive` is passed:
    1. Resolve sensor IDs as today (via the contract or
       `--criterion` filter).
    2. For each resolved sensor ID, read
       `${wm_sensors_dir}/<id>.md` and parse `tier` from
       frontmatter (apply class-based default if absent).
    3. Filter the sensor list to those matching the requested tier.
    4. Execute the filtered set via the existing parallel-execution
       path (`xargs -P "$(yoke_sensor_concurrency)"`).
  - When `--tier all` (or omitted): run the resolved set without
    tier filtering.
  - When `--tier <unknown>`: fail-fast before executing any sensor;
    emit a structured violation message; exit non-zero.
  - When a referenced sensor file is missing or unparseable: fail-
    fast with a structured violation; exit non-zero.
  - Combine cleanly with `--criterion <id>` — both filters apply
    (intersection).
- **Edit** `tests/sensor-tiering.test.sh` (extended from Parts 1–2):
  - Fixture: a contract referencing 4 sensors (cheap-comp,
    expensive-comp, cheap-inferential, expensive-inferential — to
    cover both class+tier combinations) with corresponding
    `.yoke/sensors/<id>.md` files (some with explicit `tier:`,
    some relying on class default).
  - Assert: `--tier cheap` runs exactly the cheap pair (regardless
    of class); `--tier expensive` runs the expensive pair;
    `--tier all` runs all four; flag-omitted runs all four.
  - Assert intersection: `--tier expensive --criterion <id-with-
    only-cheap-applicable>` runs zero sensors and exits 0.
  - Assert unknown-value error: `--tier slow` exits non-zero with
    the structured-violation format (test parses the error message
    for the required fields).
  - Assert missing-sensor-file: rename one sensor file to simulate
    absence; the hook exits non-zero with the structured violation
    pointing at the missing path.

## Anti-scope

- **No tier authoring or default inference changes.** Parts 1–2 own
  the source of truth.
- **No Validator scheduling or coordinator gating.** Parts 4–5 own
  those.
- **No timeout / concurrency model changes.** Existing per-sensor
  timeouts and `xargs -P` are untouched.
- **No output-schema changes.** Per-sensor YAML keeps every
  existing field; tier filtering only changes which sensors appear,
  not their shape.
- **No caching of tier resolution across invocations.** Re-read the
  sensor file each time — the file is the source of truth and may
  have been edited between invocations.
- **No retry / flake handling.**
- **No new flags beyond `--tier`.**

## Technical Decisions

- **`--tier all` is first-class and explicit.** Rationale: callers
  (CI, smoke tests) may want to pin all-tiers without relying on a
  default; first-class `all` removes a "default vs explicit"
  surprise.
- **Filter at the sensor-list level, not by per-sensor early-exit.**
  Rationale: the existing parallel execution uses `xargs -P`;
  filtering the input list is composable. Per-sensor early-exit
  would require touching the execution body — bigger blast radius.
- **Re-read sensor files on every invocation.** Rationale: the
  sensor file is the source of truth and may change between cycles.
  Caching would introduce stale-tier risk for marginal speed gain.
- **Unknown `--tier` is fatal**, not fallback to `all`. Same
  rationale as Parts 1–2: silent fallback hides typos.
- **Missing sensor file is fatal at the hook level.** Rationale:
  Part 2's readiness mode is the *intended* place to catch missing
  files; the hook fails as a defense-in-depth, with a corrective
  instruction pointing at `--mode upsert`.
- **`--tier` and `--criterion` intersect.** Rationale: both are
  narrowing filters by user intent — "cheap sensors that apply to
  this criterion", not "everything in either set".

## Applicable Patterns

- `.vibeflow/patterns/sensors.md` — primary; tier filter is a new
  execution-stage filter; structured-output rule applies to
  failures.
- `.vibeflow/patterns/ralph-loop.md` — cycle protocol invariants
  (deterministic node, structured per-cycle output) preserved.
- `.vibeflow/conventions.md` — back-pressure on unknown flags and
  missing sensor files; bash 4+.

## Risks

- **R1 — Existing argparse may not parse two flags cleanly.**
  Mitigation: read the file in Phase 1; if argparse is positional
  rather than flag-based, align `--tier` with the existing style.
  This spec assumes flags; downgrade gracefully if needed.
- **R2 — Sensor file parsing in bash adds complexity.**
  Mitigation: parse only the frontmatter (between two `---`
  delimiters) using awk or sed; do not depend on a YAML library.
  Sensor frontmatter is intentionally simple.
- **R3 — Combined-filter empty result must still pass.** Edge case:
  `--tier expensive` against a criterion that maps only cheap
  sensors. Without any sensor to run, the hook should exit 0 with
  empty per-cycle YAML output — not error. Test asserts this.
- **R4 — Class-based default fallback must match Part 1's parser.**
  If Part 1 changes its default rule, Part 3's resolution must
  follow. Mitigation: factor the resolution helper into
  `lib/sensors/`-shared code so both paths use the same logic; OR
  document the duplication and mark it as a Part-2 readiness check
  responsibility.

## Dependencies

- `.vibeflow/specs/sensor-cost-tiering-part-1.md` — sensor file
  schema, `wm_sensors_dir`.
- `.vibeflow/specs/sensor-cost-tiering-part-2.md` — upsert
  guarantees that referenced sensor files exist and are well-formed
  by the time the hook runs.
