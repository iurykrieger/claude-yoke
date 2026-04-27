# Audit Report: sensor-cost-tiering — Part 1 (Working-memory layout)

> Audited on 2026-04-27
> Spec: `.vibeflow/specs/sensor-cost-tiering-part-1.md`
> Source PRD: `.vibeflow/prds/sensor-cost-tiering.md`

**Verdict: PASS**

## Test execution

- Command: `bash tests/sensor-tiering.test.sh` (new) and
  `bash tests/run-all.sh` (full suite).
- Result: **PASS** — 18/18 assertions in the new test; **19/19 test
  files PASS** in the full suite (no regressions).

## DoD Checklist

- [x] **DoD 1 — `templates/sensor.md` schema.** Template exists with
  YAML frontmatter (`id`, `command`, `class`, `tier` optional,
  `applies_to`, `runs`) and body sections `## Caveats` +
  `## Calibration notes`. Inline HTML-comment guidance documents the
  class-based default rule and references the source PRD.
  *Evidence:* `templates/sensor.md`; new test (a) — 4 assertions PASS.

- [x] **DoD 2 — `wm_sensors_dir` helper.** Resolves to `.yoke/sensors`,
  consistent with the existing `wm_*_dir` family. Companion
  `wm_sensor_path "<id>"` added with id-validation regex
  (`^[a-z0-9][a-z0-9_.-]{0,63}$`) — same pattern used by every other
  dir helper in the file (every dir has at least one path helper).
  *Evidence:* `lib/working-memory/paths.sh`:75 (constant), :191
  (`wm_sensors_dir`), :207 (`wm_sensor_path`); new test (b) — 7
  assertions PASS, including path-traversal guard rejection.

- [x] **DoD 3 — Acceptance Contract by-ID.** Contract scenarios
  reference sensors via `Sensors: [<sensor-id>]` only. New
  `## Sensors registry` section provides the place to register each
  sensor's `id`, `command`, and `class`. Inline guidance explicitly
  references `templates/sensor.md` (gap closed during audit — see
  "Audit-time corrections" below). No inline `command:`, `class:`,
  or `tier:` declarations remain in the template.
  *Evidence:* `templates/acceptance-contract.md`; new test (c) — 7
  assertions PASS (registry section present, registry block declares
  id+command+class, no inline command bullets, no inline `tier:`,
  bracketed `Sensors: [...]` references retained).

- [x] **DoD 4 — Test coverage.** `tests/sensor-tiering.test.sh`
  exercises template presence + frontmatter keys, body sections,
  `wm_sensors_dir`/`wm_sensor_path` happy and invalid-input paths,
  and contract-by-ID layout assertions. All 18 assertions PASS.
  *Evidence:* `tests/sensor-tiering.test.sh`.

- [x] **DoD 5 — Craftsmanship.** Bash 4+ idioms in `paths.sh`
  (regex match, `printf`, `[[ ]]`); structured failure on invalid
  sensor id (`wm:`-prefixed message + non-zero exit) — back-
  pressure preserved. PRD reference inline in all four touched
  files for traceability. No manifesto invariant weakened: working
  memory remains per-project; canonical memory untouched; binding
  Acceptance Contract semantics unchanged; sensors-pattern
  structured-output rule preserved.
  *Evidence:* `templates/sensor.md` HTML comment; `paths.sh:184-209`;
  `templates/acceptance-contract.md` (Sensors registry intro);
  `tests/sensor-tiering.test.sh` header.

## Pattern Compliance

- [x] **`patterns/sensors.md`** — followed. Sensor metadata moved to
  per-sensor file; structured-output rule observed in id-validation
  failure path. The pattern doc itself is intentionally untouched in
  Part 1 (the tier-and-scheduling subsection lands in Part 5 per the
  multi-part split).

- [x] **`patterns/acceptance-contract.md`** — followed. Binding
  semantics unchanged: BDD scenarios, functional requirements,
  fixtures, policies, and the binding statement are untouched. Only
  the sensor declaration shape changed (inline → by-ID). Generation
  contract (Validator producing the artifact) is preserved.

- [x] **`patterns/memory-model.md`** — followed. `.yoke/sensors/` is
  added as a project-scoped working-memory category. The path layout
  comment in `paths.sh` was updated to document the new category
  alongside the existing slug-keyed and runtime ones. Sensors are
  *not* added to `WM_ARCHIVE_CATEGORIES` (correct: that array drives
  slug-collision detection, and sensors are id-keyed, not
  slug-keyed). No canonical-memory writes.

- [x] **`conventions.md`** — followed. Bash 4+; back-pressure (loud
  failure with `wm:`-prefixed structured message + non-zero exit on
  invalid id); machine-parseable error output; traceability via
  inline PRD reference. The Don'ts list is respected — no canonical-
  memory access added; no agent given write authority outside its
  domain; no infinite-loop risk introduced.

## Convention Violations

None identified.

## Scope Discipline

Files changed: **4 / ≤ 4 budget** (exactly at limit).

- `templates/sensor.md` (created)
- `templates/acceptance-contract.md` (modified)
- `lib/working-memory/paths.sh` (modified)
- `tests/sensor-tiering.test.sh` (created)

Anti-scope respected: no `lib/sensors/ack-sensors.sh` changes; no
runtime / hook / Validator / coordinator changes; no actual
`.yoke/sensors/<id>.md` files seeded; no migration tooling; no skill
SKILL.md edits; no `runs:` retention policy; no schema versioning.

### Note on `wm_sensor_path` adjunct

Implementation added `wm_sensor_path "<id>"` alongside `wm_sensors_dir`.
DoD 2 only required the dir helper, but every other dir helper in
`paths.sh` is paired with at least one artifact-path helper
(`wm_runtime_dir` → `wm_progress_path`, `wm_cycle_counter_path`,
`wm_snapshots_dir`, etc.). Adding `wm_sensor_path` follows the
established library convention and is consumed by Parts 2/3/5
without those parts needing to reach into `paths.sh`. The
id-validation regex it carries is also a security-relevant
boundary (path-traversal guard). Treated as a justifiable
extension of the existing pattern, not scope creep.

## Audit-time corrections

One small gap surfaced and was closed during audit:

- `templates/acceptance-contract.md` originally pointed authors at
  `.yoke/sensors/<id>.md` and `/yoke:ack-sensors --mode upsert` but
  did not literally reference `templates/sensor.md`, which DoD 3
  specifies. Edited the Sensors-registry intro to add the explicit
  reference; tests still pass (test does not encode this assertion,
  but the human-readable guidance now matches the spec verbatim).

## Gaps

None. Verdict is PASS.

## Next steps

Ready to ship. Proceed to Part 2 (`/yoke:ack-sensors` upsert mode):

```
/vibeflow:implement .vibeflow/specs/sensor-cost-tiering-part-2.md
```
