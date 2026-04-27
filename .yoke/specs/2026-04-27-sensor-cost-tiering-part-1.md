# Spec: Sensor Cost Tiering — Part 1: Working-memory layout

> Generated via /vibeflow:gen-spec on 2026-04-27 (revised 2026-04-27)
> Source PRD: `.vibeflow/prds/sensor-cost-tiering.md`

## Objective

Sensors become first-class persistent artifacts in `.yoke/sensors/`,
with a per-sensor markdown template, a working-memory path helper,
and an Acceptance Contract that **references sensors by ID** instead
of inlining their command, class, and tier.

## Context

Today, sensor metadata (command, class) is inlined inside
`acceptance-contract.md` and has no place to grow. There is no per-
sensor home for accumulated caveats, recent run results, calibration
notes, or "this sensor flakes when the test DB is cold" knowledge.

The PRD redirects this: sensors get their own per-file home in
`.yoke/sensors/<id>.md`, mirroring how the rest of the framework
treats persistent knowledge. The Acceptance Contract becomes a list
of references; the per-sensor file is the source of truth for
`command`, `class`, `tier`, `applies_to`, and a growing `runs:`
history (populated by the coordinator in Part 5).

This part is the **foundation**. It introduces the layout, the
template, and the contract-by-ID convention. No execution behavior
changes yet — Part 2 wires the upsert; Parts 3–5 wire the consumers.

## Definition of Done

1. `templates/sensor.md` exists and defines a per-sensor markdown
   template with YAML frontmatter (`id`, `command`,
   `class: computational | inferential`, `tier: cheap | expensive`
   optional, `applies_to: [<criterion-id>...]`, `runs: []`) and a
   body with a "Caveats" section header. Inline guidance documents
   the class-based default rule for `tier`.
2. `lib/working-memory/paths.sh` exposes a `wm_sensors_dir` helper
   resolving to `.yoke/sensors/` under the host project (consistent
   with the existing `wm_*_dir` family — `wm_runtime_dir`,
   `wm_snapshots_dir`).
3. `templates/acceptance-contract.md` declares sensors by reference
   only (`sensor: <id>`) inside the per-criterion sensor list. No
   inline `command`, no inline `tier`, no inline `class`. Inline
   guidance points authors at `templates/sensor.md` for sensor
   definition.
4. `tests/sensor-tiering.test.sh` exists and asserts:
   (a) `templates/sensor.md` is present, parses as YAML frontmatter
   + markdown body, and contains the required frontmatter keys;
   (b) `wm_sensors_dir` returns the expected path under a fixture
   `.yoke/`; (c) the contract template parses successfully with a
   pure sensor-by-ID reference.
5. **Craftsmanship**: template follows existing template conventions
   in `templates/` (frontmatter shape, comment-based inline
   guidance, traceable reference to the source PRD); no manifesto
   invariant is weakened; bash 4+ idioms in `paths.sh`.

## Scope

- **Create** `templates/sensor.md`:
  - Frontmatter:
    - `id` (required, string)
    - `command` (required, string — shell command to execute)
    - `class` (required, `computational | inferential`)
    - `tier` (optional, `cheap | expensive` — defaults from class)
    - `applies_to` (required, list of criterion IDs)
    - `runs` (required, list — initially empty `[]`; populated by
      coordinator in Part 5)
  - Body:
    - `## Caveats` heading with placeholder guidance.
    - `## Calibration notes` heading (for inferential sensors;
      computational sensors leave it empty).
  - Inline guidance comment block documenting the class-based
    default rule and a cross-reference to
    `.vibeflow/prds/sensor-cost-tiering.md` for traceability.
- **Edit** `lib/working-memory/paths.sh`:
  - Add `wm_sensors_dir()` returning `${YOKE_HOME:-.yoke}/sensors`
    (or the equivalent path used by sibling helpers — match the
    existing convention exactly).
  - No change to existing helpers.
- **Edit** `templates/acceptance-contract.md`:
  - Replace any inline sensor declarations with sensor-by-ID
    references. Each criterion's sensor list contains only IDs:
    ```
    sensors:
      - id: <sensor-id-1>
      - id: <sensor-id-2>
    ```
  - Add inline guidance: "Define each sensor in
    `.yoke/sensors/<id>.md` using `templates/sensor.md`. Reference
    only the ID here."
  - Preserve all other contract sections unchanged (BDD scenarios,
    fixtures, policies).
- **Create** `tests/sensor-tiering.test.sh`:
  - Smoke check: `templates/sensor.md` exists and round-trips
    through a YAML+markdown parser.
  - `wm_sensors_dir` test: source `paths.sh`, assert function
    returns the expected path under a temp `YOKE_HOME`.
  - Contract round-trip: a fixture `acceptance-contract.md`
    referencing two sensor IDs parses, and the parser surfaces
    those IDs as a clean list (parsing into a temp variable; no
    sensor-resolution yet — that's Part 2's upsert + Part 3's
    runtime).

## Anti-scope

- **No `ack-sensors.sh` changes.** Upsert lands in Part 2.
- **No execution / runtime changes.** No `--tier` flag, no
  Validator changes, no coordinator changes.
- **No actual `.yoke/sensors/<id>.md` files seeded.** The template
  exists; the upsert that populates real sensor files is Part 2.
- **No migration tooling for existing contracts.** Authors update
  manually for v0; we ship the new shape and let users adopt.
- **No sensor-file schema versioning** (`version: 1` field).
- **No `runs:` retention policy.** The field is introduced as an
  empty list; retention lives in Part 5.
- **No skill (`skills/ack-sensors/SKILL.md`) edits.** Part 2 owns
  the skill doc.

## Technical Decisions

- **`runs: []` introduced empty in Part 1, populated in Part 5.**
  Rationale: locking the field name + position in the frontmatter
  schema upfront avoids a schema break later. The retention cap
  lives where the appending happens.
- **`templates/sensor.md` keeps inferential-sensor calibration in
  the body, not the frontmatter.** Rationale: calibration notes
  vary in length and structure (false-positive examples,
  rubric text); markdown body is the right home. Frontmatter stays
  small + machine-parseable.
- **Contract-by-ID is enforced in the template, not by parser
  rejection.** Rationale: Part 1 ships the convention; Part 2's
  readiness check verifies sensor files exist. A contract with
  inline definitions is a Part-2-readiness failure, not a Part-1
  template failure.
- **`wm_sensors_dir` follows the `wm_*_dir` naming convention.**
  Rationale: consistency with existing helpers
  (`wm_snapshots_dir`, `wm_runtime_dir`); a maintainer reading
  `paths.sh` should not need to learn a new naming scheme.

## Applicable Patterns

- `.vibeflow/patterns/sensors.md` — primary; tier metadata moves to
  the per-sensor file, but the structured-output rule is unchanged.
- `.vibeflow/patterns/acceptance-contract.md` — contract format
  changes (by-reference) but binding semantics unchanged.
- `.vibeflow/patterns/memory-model.md` — `.yoke/sensors/` lives in
  working memory (per host project); promotion to canonical is
  out of scope per PRD.
- `.vibeflow/conventions.md` — framework-knowledge artifacts use
  per-file markdown with frontmatter; bash 4+ in helpers.

## Risks

- **R1 — Existing `templates/acceptance-contract.md` may inline
  sensor definitions in a format incompatible with simple
  by-reference replacement.** Mitigation: read the file in Phase 1
  and preserve all non-sensor sections verbatim. Document the
  diff in `progress.md`.
- **R2 — `lib/working-memory/paths.sh` may not exist yet, or may
  use a different naming convention.** Mitigation: read the file
  first; create only if missing; otherwise, add `wm_sensors_dir`
  alongside existing helpers and match their style.
- **R3 — Parser tooling for round-trip tests.** The test asserts
  YAML+markdown parsing, but the project may not ship a parser
  helper. Mitigation: use a minimal awk/grep-based round-trip
  (verify the frontmatter delimiter and required keys), not a
  full parser dependency.
- **R4 — Inline guidance bloats the template.** Mitigation: keep
  template guidance to ≤ 10 lines of HTML comments; link to PRD
  + pattern doc for the long-form rationale.

## Dependencies

None. This is the foundation part.
