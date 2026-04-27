# Audit Report: sensor-cost-tiering — Part 2 (`/yoke:ack-sensors` upsert)

> Audited on 2026-04-27
> Spec: `.vibeflow/specs/sensor-cost-tiering-part-2.md`
> Source PRD: `.vibeflow/prds/sensor-cost-tiering.md`
> Depends on: `sensor-cost-tiering-part-1` (audit verdict PASS)

**Verdict: PASS**

## Test execution

- Command: `bash tests/sensor-tiering.test.sh` (extended) and
  `bash tests/run-all.sh` (full suite).
- Result: **PASS** — 36/36 assertions in `sensor-tiering.test.sh`;
  **19/19 test files PASS** in the full suite (0 regressions).

## DoD Checklist

- [x] **DoD 1 — `--mode upsert` accepted.** Dispatcher in
  `lib/sensors/ack-sensors.sh` routes the new mode alongside `catalog`
  and `readiness`. SKILL.md `argument-hint` includes `upsert`.
  *Evidence:* `lib/sensors/ack-sensors.sh` (case statement), test
  "(d) upsert created .yoke/sensors/<id>.md" — 4 PASS.

- [x] **DoD 2 — Create path renders from `templates/sensor.md`.**
  When `.yoke/sensors/<id>.md` is absent, `render_sensor_file`
  substitutes `id` / `command` / `class` / `tier` / `applies_to` from
  the contract registry + scenario references, applying class-based
  default for `tier`. Body sections (`## Caveats`, `## Calibration
  notes`) are seeded empty.
  *Evidence:* `render_sensor_file()` and `upsert_mode()` in
  `ack-sensors.sh`; tests covering all 4 fixture sensors PASS;
  applies_to populated correctly.

- [x] **DoD 3 — Update path: field-level merge.** `update_applies_to`
  rewrites only the `applies_to` line; everything else preserved
  byte-for-byte. Author-edited `command`, `class`, explicit
  `tier:` overrides, body content (caveats / calibration notes), and
  `runs:` history all survive. Atomic write via `mv` from `.tmp.$$`.
  *Evidence:* tests "(d) upsert preserved author tier override
  (expensive) on update", "(d) upsert preserved author caveat in
  body", "(d) upsert refreshed playwright-e2e applies_to with both
  task ids" — all PASS.

- [x] **DoD 4 — Class-based default applied only on create.**
  `default_tier` is computed and substituted exclusively on the create
  branch. The update branch never touches `tier`. Computational
  defaults to `cheap`, inferential defaults to `expensive`.
  *Evidence:* tests "(d) computational sensor 'linter-ruff' defaulted
  to tier: cheap" + "(d) inferential sensor 'judge-voice' defaulted
  to tier: expensive" — PASS. Update test confirms explicit override
  survives.

- [x] **DoD 5 — Readiness checks sensor files.** `readiness_mode`
  rewritten end-to-end. For every sensor referenced by the contract
  (registry ids ∪ scenario ids), it verifies the file exists at
  `.yoke/sensors/<id>.md` and contains required frontmatter keys
  (`id`, `command`, `class`, `applies_to`, `runs`). Failure surfaces
  structured violation with `sensor`, `expected`, `actual`, `reason`,
  `correction` — the correction names the upsert command verbatim.
  *Evidence:* `readiness_mode()`; tests "(e) readiness reports ready
  ...", "(e) readiness exits 4 ...", "(e) readiness reports status:
  not-ready ...", "(e) readiness names the missing sensor ...",
  "(e) readiness suggests `/yoke:ack-sensors --mode upsert` correction"
  — all PASS.

- [x] **DoD 6 — SKILL.md documents upsert.** Added "Upsert mode"
  section with create vs update semantics, idempotency guarantee,
  validation rules, output schema, and exit-code table. The mode
  table at the top of the file lists all three modes.
  *Evidence:* `skills/ack-sensors/SKILL.md` — "Upsert mode" section
  + table updates + `argument-hint` field.

- [x] **DoD 7 — Test coverage.** `tests/sensor-tiering.test.sh`
  extended from 18 to 36 assertions covering: create case (4 sensors
  materialized + tier defaults + applies_to populated); update case
  (applies_to expanded, tier override preserved, body caveat
  preserved); idempotency (sha256 hash equality before/after second
  run); readiness happy path; readiness missing-file failure (exit 4
  + structured violation + correction instruction); upsert
  unregistered-reference validation (exit 4 + named in failures).
  *Evidence:* the test file itself — 36/36 PASS.

- [x] **DoD 8 — Craftsmanship.** Idempotency proven by hash equality
  test. Structured failures everywhere (every error path emits
  `sensor / expected / actual / reason / correction`). Bash 4+
  idioms throughout. No destructive operations: upsert never deletes
  a sensor file, even when the contract drops a reference (orphan
  handling deferred to drift-sense per PRD anti-scope). Atomic write
  via temp + `mv`. PRD reference inline at the top of
  `ack-sensors.sh` and in SKILL.md.

## Pattern Compliance

- [x] **`patterns/sensors.md`** — followed. Sensor metadata is now
  per-file (the structured-output rule applies to readiness + upsert
  failures uniformly). Catalog mode unchanged. The pattern doc
  itself is intentionally untouched in Part 2 — the sensors-pattern
  subsection on tiering + scheduling lands in Part 5.

- [x] **`patterns/memory-model.md`** — followed. `.yoke/sensors/`
  is treated as project-scoped working memory. Upsert writes only
  to working memory; no canonical-memory access. Field-level merge
  preserves the working-memory tier's "free-write within files"
  contract.

- [x] **`patterns/acceptance-contract.md`** — followed. Contract
  binding semantics unchanged: BDD scenarios + functional
  requirements + fixtures + policies + binding statement preserved.
  The Sensors registry block is metadata that materializes per-
  sensor files — it is not part of the binding scope.

- [x] **`conventions.md`** — followed. Bash 4+ throughout.
  Back-pressure (loud failures, structured) on every error path.
  Deterministic node — no LLM in the upsert path; SKILL.md
  `allowed-tools` remains `Bash, Read` only. No `Task`, no `Agent`.
  No canonical-memory writes.

## Convention Violations

None identified.

## Scope Discipline

Files changed: **4 / ≤ 4 budget** (exactly at limit).

- `lib/sensors/ack-sensors.sh` (modified) — upsert + new readiness
- `skills/ack-sensors/SKILL.md` (modified) — upsert documentation
- `tests/sensor-tiering.test.sh` (modified) — Part 2 assertions
- `tests/ack-sensors-catalog.test.sh` (modified) — collateral

### Note on the catalog-test edit

The 4th file (`tests/ack-sensors-catalog.test.sh`) was not in the
spec's Scope section but was a **necessary collateral** of the
spec-mandated readiness rewrite (DoD 5). The catalog test had a
~70-line section asserting the OLD readiness contract (binary-on-
PATH, output fields like `reachable: true`, `expected: "on-PATH"`,
`reason: "binary not found: ..."`). Those assertions are by
construction invalidated by the new readiness behavior the spec
requires; leaving them in place would have left the test suite
broken (the implement skill's "tests must pass" rule applies).

The edit removed the obsolete sub-tests (no replacement assertions
added — the new readiness behavior is comprehensively tested in
`tests/sensor-tiering.test.sh` with 7 readiness-specific
assertions). The test file's header was updated to point future
readers at the new home for readiness coverage. Mode-dispatch
error-path assertions (missing contract → exit 3, missing arg →
exit 2, unknown --mode → exit 2) were retained.

This counts as scope discipline rather than scope creep: the
deletion is minimal, the coverage moved (not vanished), and the
alternative (keep readiness behavior intact) would have violated
the spec's DoD 5.

Anti-scope respected: no `hooks/verify-acceptance.sh` changes; no
`agents/`, `skills/implement`, or coordinator changes; no automatic
upsert hooks; no orphan deletion; no `runs:` history writes from
upsert (the field is initialized to `[]` and only the coordinator
in Part 5 will append); no interactive prompting; no schema
versioning; no migration tooling beyond what authors do manually
when editing the contract.

## Architectural notes / pitfalls discovered

1. **Existing test files coupled to implementation behavior.**
   `ack-sensors-discoverers.test.sh`, `ack-sensors-inferential.test.sh`,
   and `ack-sensors-parallel.test.sh` each invoke the catalog test
   as a smoke check (`bash tests/ack-sensors-catalog.test.sh`),
   creating a 4-way dependency chain. This means a single regression
   in catalog cascades to all four files. Worth noting for future
   refactors — the existing tech debt is documented in the catalog-
   test header now.

2. **Sensor `id` validation is the boundary for path safety.**
   `wm_sensor_path` (Part 1) and the upsert path both rely on the
   regex `^[a-z0-9][a-z0-9_.-]{0,63}$` to prevent path traversal
   (no slashes, no leading `..`). This is the only line of defense
   between contract content and filesystem writes. If we ever
   relax the regex (e.g. to allow uppercase), revisit the
   `mkdir -p .yoke/sensors` and atomic-write paths.

## Gaps

None. Verdict is PASS.

## Next steps

Ready to ship Part 2. Proceed to Parts 3 + 4 (which can run in
parallel — both depend only on Parts 1+2):

- Part 3 — `verify-acceptance.sh --tier` filter:
  ```
  /vibeflow:implement .vibeflow/specs/sensor-cost-tiering-part-3.md
  ```
- Part 4 — Validator scheduling reads sensor files:
  ```
  /vibeflow:implement .vibeflow/specs/sensor-cost-tiering-part-4.md
  ```

Part 5 (coordinator + pattern doc) requires both 3 and 4.
