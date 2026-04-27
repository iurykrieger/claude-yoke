# Spec: Sensor Cost Tiering — Part 2: `/yoke:ack-sensors` upsert mode

> Generated via /vibeflow:gen-spec on 2026-04-27 (revised 2026-04-27)
> Source PRD: `.vibeflow/prds/sensor-cost-tiering.md`

## Objective

`/yoke:ack-sensors` gains an **upsert mode** that creates or updates
`.yoke/sensors/<id>.md` files from the Acceptance Contract's sensor-by-
ID references, applying the class-based tier default on creation,
and preserving human-edited fields (caveats, calibration notes,
`runs:` history, explicit `tier:`) on update.

## Context

Part 1 introduces the per-sensor template and the contract-by-ID
convention. Part 2 closes the loop: a deterministic upsert path that
the human (or a future automation) can run to materialize sensor
files in `.yoke/sensors/` from the contract, and to keep them in
sync as the contract evolves.

This is a deterministic node in the Yoke sense — no LLM, just file
operations. It is also **idempotent**: running it twice with no
contract changes produces no file modifications.

## Definition of Done

1. `lib/sensors/ack-sensors.sh` accepts `--mode upsert <contract>`
   alongside `--mode catalog` and `--mode readiness`.
2. **Create path**: for every sensor referenced in the contract that
   does not yet have a file at `.yoke/sensors/<id>.md`, the upsert
   creates the file from `templates/sensor.md` with `id` and
   `applies_to` populated from the contract; `command` and `class`
   prompted for or filled from the contract's metadata block; `tier`
   filled by class-based default.
3. **Update path**: for sensors that already have a file, the upsert
   refreshes only frontmatter fields the contract owns (`applies_to`)
   and **preserves all human-edited content** — `command` (if author
   has overridden), `class`, explicit `tier:`, body content (caveats,
   calibration notes), and `runs:` history. The merge is field-level,
   not file-level.
4. **Class-based default tier** is applied only on create. Once a
   file exists, its tier (explicit or default) is treated as
   authoritative — the upsert never silently flips it.
5. **Readiness mode** (existing) verifies every contract-referenced
   sensor has a corresponding `.yoke/sensors/<id>.md` and the file
   contains the required frontmatter keys. Failure surfaces a
   structured violation per `conventions.md` back-pressure (sensor
   ID, expected file path, correction instruction: "run `/yoke:ack-
   sensors --mode upsert <contract>`").
6. `skills/ack-sensors/SKILL.md` documents the upsert mode alongside
   catalog/readiness, including the create vs update semantics and
   the idempotency guarantee.
7. `tests/sensor-tiering.test.sh` extended with: (a) create case
   (sensor file does not exist; upsert creates it with class-based
   default); (b) update case (existing file with author-edited
   caveats; upsert preserves the caveats while updating
   `applies_to`); (c) idempotency (running upsert twice with no
   contract changes produces no diff); (d) readiness mode failure
   message format on missing sensor file.
8. **Craftsmanship**: idempotency verified (no-op on second run);
   structured failure on parse errors with location + correction;
   bash 4+; no destructive operations (the upsert never deletes a
   sensor file even if the contract drops the reference — orphan
   handling is out of scope per PRD).

## Scope

- **Edit** `lib/sensors/ack-sensors.sh`:
  - Extend the mode dispatcher to recognize `--mode upsert`.
  - Implement the upsert algorithm:
    1. Parse the contract; collect referenced sensor IDs and any
       contract-level sensor metadata block (where authors register
       command + class for new sensors).
    2. For each ID, check `${wm_sensors_dir}/<id>.md`:
       - If absent: create from `templates/sensor.md`, populate
         `id`, `applies_to`, `command`, `class` from contract;
         apply class-based default for `tier`.
       - If present: parse the existing file's frontmatter; merge
         only `applies_to` from contract; preserve all other fields
         and the body verbatim.
    3. Write back atomically (`mv` from a temp file) to avoid
       partial writes.
  - Strengthen `--mode readiness` to verify referenced sensor files
    exist and parse cleanly; fail with structured violation
    pointing at missing/malformed files.
  - Preserve `--mode catalog` semantics (no change).
- **Edit** `skills/ack-sensors/SKILL.md`:
  - Document `--mode upsert <contract>`: when to run (after editing
    a contract; before `/yoke:implement`), what it does, the
    create-vs-update semantics, and the idempotency guarantee.
  - Update mode list in the skill description (add upsert).
- **Edit** `tests/sensor-tiering.test.sh` (extended from Part 1):
  - Create case: empty `.yoke/sensors/`, run upsert with a
    fixture contract referencing two sensors (one computational,
    one inferential); assert both files exist with class-based
    tier defaults.
  - Update case: pre-seed `.yoke/sensors/foo.md` with author-edited
    caveats and an explicit `tier: expensive` override (where the
    class would default to cheap); run upsert with a contract
    where `foo` now has new `applies_to`; assert
    `applies_to` updated, caveats preserved, explicit `tier`
    preserved.
  - Idempotency: run upsert twice; assert second run produces no
    file modifications (compare mtimes or hashes).
  - Readiness failure: contract references `bar` but
    `.yoke/sensors/bar.md` is missing; assert readiness exits
    non-zero with structured violation including the corrective
    invocation.

## Anti-scope

- **No execution / runtime changes.** No `--tier` flag, no Validator
  reads, no coordinator integration.
- **No automatic upsert** triggered by other skills — must be run
  explicitly. (Future: `/yoke:implement` could call it as a
  precondition; out of scope for v0.)
- **No orphan deletion.** When a contract drops a sensor reference,
  the file remains at `.yoke/sensors/<id>.md`. Drift-sense (Phase
  6) is the right place to flag orphans; not this part.
- **No `runs:` writes.** Coordinator owns history population in
  Part 5.
- **No interactive prompting** if the contract lacks a sensor's
  command/class. Fail with structured violation telling the user
  to add the metadata to the contract or to the sensor file
  directly.
- **No locking / concurrency control** beyond atomic write. We
  assume the upsert is invoked by the human between cycles, not
  concurrently with `/yoke:implement`.
- **No schema migration** for sensor files (e.g. v0 → v1). Tier
  format and runs format are stable per PRD.

## Technical Decisions

- **Field-level merge, not file-level.** Rationale: the contract
  owns only `applies_to`; everything else is authored or coordinator-
  populated. A file-level overwrite would clobber caveats and
  history; field-level merge is the only correct semantic.
- **Atomic write via tmp + `mv`.** Rationale: no partial-write risk
  if the upsert is interrupted; matches existing patterns in
  `lib/canonical-memory/*.sh` (which already use atomic moves).
- **Idempotency by content hash, not timestamps.** Rationale: a re-
  run that produces identical content is a no-op — don't bump
  mtime, which would mislead `git diff` and downstream tools.
- **No interactive prompting on missing metadata.** Rationale: Yoke
  is an autonomous-loop framework; interactive prompts break the
  ralph-loop assumption. Fail loud with a corrective instruction
  instead.
- **Readiness mode strictness increased.** Was: "verify sensors
  reachable on the local machine". Now: "verify sensor files exist
  and parse cleanly". Rationale: the file is now the source of
  truth — its absence is a hard error, not a warning.

## Applicable Patterns

- `.vibeflow/patterns/sensors.md` — primary; sensor metadata is
  now per-file; structured-output rule applies to readiness
  failures.
- `.vibeflow/patterns/memory-model.md` — `.yoke/sensors/` is
  working memory; the upsert is a working-memory write
  (allowed, no governance overhead).
- `.vibeflow/patterns/acceptance-contract.md` — contract is
  authoritative for `applies_to`; everything else is sensor-file-
  authoritative.
- `.vibeflow/conventions.md` — bash 4+; back-pressure (loud
  failures, structured); deterministic node (no LLM in the upsert
  path).

## Risks

- **R1 — Existing `ack-sensors.sh` mode dispatcher may make it
  awkward to add a third mode.** Mitigation: read the file in
  Phase 1; if the dispatcher is tightly coupled to two modes,
  refactor minimally to a function-table style.
- **R2 — Contract sensor-metadata block may not exist yet.** The
  Part-1 contract change introduces sensor-by-ID references but
  may not specify where author-supplied `command` / `class` for
  new sensors live. Mitigation: this spec assumes a top-level
  `sensors:` registry block in the contract listing each ID's
  metadata. If Part 1 didn't introduce that block, extend Part 1
  before implementing Part 2 (re-scope, don't fork).
- **R3 — Atomic-write semantics on different filesystems.**
  Cross-device `mv` is non-atomic; verify the temp file lives in
  the same directory as the target.
- **R4 — Body-content preservation under upsert is fragile.** If
  the human edits the body and the upsert miscounts the
  frontmatter delimiter, the body could be truncated. Mitigation:
  use a strict frontmatter parser (delimiter pair `---`); add a
  test specifically asserting body bytes are preserved verbatim
  on update.
- **R5 — `runs:` field merging.** If the human edits the body and
  the coordinator (Part 5) appends to `runs:` between two upserts,
  the merge must preserve `runs:` from the existing file. The
  field-level merge rule covers this, but the test must explicitly
  exercise it.

## Dependencies

- `.vibeflow/specs/sensor-cost-tiering-part-1.md` — Part 2 consumes
  `templates/sensor.md`, `wm_sensors_dir`, and the contract-by-ID
  convention introduced in Part 1.
