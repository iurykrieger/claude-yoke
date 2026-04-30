# Sprint 05 of 05: Sensor Cost Tiering

> Migrated from: # Spec: Sensor Cost Tiering — Part 5: Coordinator two-phase + run-history persistence + pattern doc


> Generated via /vibeflow:gen-spec on 2026-04-27
> Source PRD: `.vibeflow/prds/sensor-cost-tiering.md`

## Objective

`/yoke:implement` runs sensors per cycle in two phases (cheap first,
expensive only when authorized by the previous cycle's
`schedule_next`), preserves the parallel-spawn architecture, persists
each cycle's per-sensor result back to `.yoke/sensors/<id>.md`'s
`runs:` history, runs the full suite at merge-ready, and the sensors-
pattern doc records the new behavior with its actionable-feedback
rationale.

## Context

Parts 1–4 deliver the inputs: Part 1 the per-sensor file format;
Part 2 the upsert path; Part 3 the hook's `--tier` filter; Part 4
the Validator's `schedule_next` emission and persistence. Part 5 is
the **integration point** — the coordinator that consumes all four,
plus the durable history feedback loop that closes the design.

Before Part 5, none of the user-visible runtime behavior has changed.
Part 5 flips the switch: cycles run cheap synchronously, expensive
only when the previous cycle's Validator authorized it; merge-ready
runs the full suite; per-cycle results land in `.yoke/sensors/<id>.md`'s
`runs:` history, capped at the most recent N entries. The pattern
doc captures the rationale so future contributors don't accidentally
re-violate "shift feedback left" by arguing the principle in
isolation.

## Definition of Done

1. `skills/implement/SKILL.md` runs sensors per cycle in two phases:
   - **Phase A** (after Generator diff): invokes
     `hooks/verify-acceptance.sh --tier cheap --criterion <last-
     target>` synchronously; persists results to
     `$(wm_snapshots_dir)/cycle-<N>.yaml`.
   - **Phase B** (after Phase A, gated): invokes
     `hooks/verify-acceptance.sh --tier expensive --criterion
     <last-target>` **only when** authorized by cycle N-1's
     `schedule_next` (i.e. `tier:expensive` in tiers, or specific
     sensor IDs whose applies_to includes the targeted criterion).
2. **Cycle-1 default**: no prior `schedule_next` exists; Phase A
   only. Phase B becomes possible from cycle 2 onward via the
   Validator's authorization.
3. **Merge-ready convergence check** runs the **full sensor suite**
   (`--tier all`) regardless of `schedule_next`; convergence is
   declared only when every sensor passes. No early "done" while
   any expensive sensor is unrun or failing.
4. **Per-sensor history persistence**: after Phase A and Phase B
   complete (per cycle), the coordinator appends an entry to each
   executed sensor's `.yoke/sensors/<id>.md` `runs:` list with:
   `cycle`, `started_at`, `duration_ms`, `status`
   (pass | fail | skip), `criterion`, optional `evidence_snippet`
   (truncated). Sensors that did not run this cycle are not
   touched.
5. **Retention cap**: `runs:` keeps the most recent N=20 entries.
   Older entries roll off on append. The cap is enforced by the
   coordinator on every append, not by a separate cleanup step.
6. `.vibeflow/patterns/sensors.md` gains a "Cost tiering, sensor
   persistence, and Validator-owned scheduling" subsection
   covering: per-sensor file layout, class-based default, two-phase
   per-cycle execution, lag-by-one Validator scheduling, run-
   history persistence with retention, merge-ready full sweep, and
   the actionable-feedback rationale (with explicit reconciliation
   against shift-feedback-left).
7. `tests/sensor-tiering.test.sh` extended with end-to-end smoke:
   a 3-cycle fixture run with one cheap-passing and one expensive-
   passing sensor — assert (a) cycle 1 runs Phase A only;
   (b) cycle 2 runs Phase A + B (Validator authorized); (c) cycle 3
   runs Phase A only (Validator does not authorize, e.g. diff
   doesn't touch expensive surface); (d) `runs:` history correctly
   appended for executed sensors only, with retention cap working
   when seeded near the limit; (e) merge-ready check runs the full
   suite regardless of `schedule_next`.
8. **Craftsmanship**: skill changes preserve parallel-spawn
   architecture (no new in-cycle synchronization between Validator
   and coordinator); pattern doc edit follows the existing section
   structure (What / Where / The Pattern / Rules / Examples /
   Anti-patterns); no manifesto invariant weakened or removed; the
   actionable-feedback rationale traces to source PRD by inline
   reference.

## Scope

- **Edit** `skills/implement/SKILL.md`:
  - Per-cycle protocol gains an explicit two-phase block:
    - Phase A: `hooks/verify-acceptance.sh --tier cheap --criterion
      <last-target>`; persist to
      `$(wm_snapshots_dir)/cycle-<N>.yaml`.
    - Phase B: read cycle N-1's `schedule_next` from
      `progress.md` (or `contracts.md`); if `tier:expensive` is
      authorized OR specific expensive sensor IDs applicable to
      the targeted criterion are listed, invoke
      `hooks/verify-acceptance.sh --tier expensive --criterion
      <last-target>` and merge results into the same per-cycle
      YAML.
  - **Cycle-1 explicit default**: hard-coded "Phase A only" branch
    when no prior cycle exists. Don't infer from missing
    `schedule_next` — make the boundary explicit.
  - **History-append step**: after both phases finish (or after
    Phase A alone, in cycle 1), iterate executed sensor IDs;
    parse each `.yoke/sensors/<id>.md`; append a `runs:` entry;
    enforce N=20 cap; atomic write back.
  - **Merge-ready convergence**: `hooks/verify-acceptance.sh
    --tier all` (or omit `--tier` for the same effect); convergence
    requires all sensors green. Document explicitly that
    `schedule_next` is ignored at this step.
- **Edit** `.vibeflow/patterns/sensors.md`:
  - Add a new subsection after the parallel-execution section
    (around line 119, where the inferential-sensor failure policy
    ends): "### Cost tiering, sensor persistence, and Validator-
    owned scheduling".
  - Cover:
    - Per-sensor file layout (`.yoke/sensors/<id>.md`) with
      frontmatter + caveats body + `runs:` history.
    - Class-based tier default (computational → cheap; inferential
      → expensive).
    - Two-phase per-cycle execution (Phase A / Phase B / merge-
      ready).
    - Lag-by-one Validator scheduling via `schedule_next`.
    - Run-history persistence with N=20 retention cap.
    - Actionable-feedback rationale, with explicit reconciliation
      vs. shift-feedback-left (cheap stays in-loop; expensive is
      gated only because pre-convergence failures aren't
      actionable).
  - Add anti-pattern entry: "Running all expensive sensors every
    cycle when the feature is mid-assembly — failures are
    incompleteness signals, not bug signals; the Generator cannot
    act on them."
  - Reference `.vibeflow/prds/sensor-cost-tiering.md` for
    traceability.
- **Edit** `tests/sensor-tiering.test.sh` (extended from Parts 1–4):
  - End-to-end smoke fixture with 2 sensors (`cheap-comp`,
    `expensive-comp`) and a 3-cycle scripted run.
  - Cycle 1: Phase A runs cheap only; Validator fixture verdict
    authorizes `tier:expensive` for cycle 2 in `schedule_next`;
    coordinator appends 1 entry to `cheap-comp`'s `runs:`.
  - Cycle 2: Phase A + B both run; coordinator appends entries to
    both sensors' `runs:`.
  - Cycle 3: Validator fixture verdict does not authorize
    expensive; assert Phase B did not run; coordinator appends 1
    entry to `cheap-comp` only.
  - Retention test: pre-seed a sensor file with `runs:` already
    at 20 entries; run one more cycle; assert the oldest entry
    rolled off and the new entry was appended.
  - Merge-ready: invoke the merge-ready code path with a
    `schedule_next` that authorizes nothing; assert all sensors
    still ran (full suite).

## Anti-scope

- **No new architecture.** Parallel-spawn (Generator + Validator +
  Orchestrator concurrent per cycle) is preserved. No new
  synchronization primitive between Validator and coordinator
  inside one cycle.
- **No tier authoring or parsing changes.** Parts 1–3 own those.
- **No `schedule_next` schema changes.** Part 4 owns the shape;
  Part 5 only consumes it.
- **No tier-aware budget accounting.** Cycle budget stays uniform
  — Phase B runs within the existing per-cycle wall-clock budget.
- **No retry semantics for expensive sensors.**
- **No CI / Sprint-8 wiring.**
- **No flake auto-quarantine.** `runs:` history enables it as a
  future addition; this part only persists data.
- **No `runs:` field migration** for pre-existing sensor files
  with a different shape. (Such files don't exist; sensors are
  introduced fresh in Part 1.)
- **No removal of any existing manifesto invariant.** Shift-
  feedback-left is **refined**, not rescinded.

## Technical Decisions

- **Phase B reads `schedule_next` from the persisted snapshot, not
  from a live Validator query.** Rationale: Validator may have
  already finished its turn for cycle N when Phase B for cycle
  N+1 starts; the snapshot is the durable record. Matches the
  lag-by-one model.
- **Merge-ready uses `--tier all` explicitly.** Rationale:
  convergence semantics must be obvious to anyone reading the
  skill source.
- **Cycle-1 default hard-coded, not derived from missing
  `schedule_next`.** Rationale: makes the boundary explicit;
  failing to read N-1 (because N-1 doesn't exist) shouldn't be
  silently equivalent to "no expensive authorized" — it should
  be an explicit branch.
- **History append is part of the cycle, not a separate
  finalization step.** Rationale: keeping it in the cycle means
  failures during append fail the cycle clearly; a separate
  finalization step risks orphaning data.
- **Retention cap N=20, enforced on append.** Rationale: bounded
  per-file size; predictable disk usage; recent-history dominance
  is what the Validator needs (older history is rarely informative
  for scheduling decisions). N=20 is a starting point; revisit
  after observing real-world `.yoke/sensors/` over multi-month
  use.
- **Atomic write back to sensor files.** Rationale: same as
  Part 2's upsert — no partial-write risk if the coordinator is
  interrupted mid-append.
- **Pattern-doc placement after the existing parallel-execution
  section.** Rationale: contiguous reading order; new behavior
  layers on top of existing model.

## Applicable Patterns

- `.vibeflow/patterns/sensors.md` — primary; this part edits it.
- `.vibeflow/patterns/ralph-loop.md` — cycle protocol invariants
  (deterministic node, hard bounds, parallel spawn) preserved.
- `.vibeflow/patterns/roles.md` — Validator scheduling is a
  refinement; coordinator (deterministic node) consumes the output
  and writes history.
- `.vibeflow/patterns/acceptance-contract.md` — binding semantics
  preserved by merge-ready full sweep.
- `.vibeflow/patterns/memory-model.md` — coordinator writes to
  working memory (`.yoke/sensors/`); no canonical-memory access.
- `.vibeflow/conventions.md` — shift-feedback-left rationale
  reconciled in the new pattern subsection (not violated).

## Risks

- **R1 — `skills/implement/SKILL.md` cycle protocol may inline a
  fixed `verify-acceptance.sh` call site that's hard to split into
  Phases A/B.** Mitigation: read the file in Phase 1; refactor
  minimally to introduce two distinct invocations. Narrow blast
  radius.
- **R2 — Cycle 1's "Phase A only" branch delays first expensive-
  sensor failure by one cycle.** Acceptance: this is the design
  (lag-by-one). Merge-ready full sweep is the safety net; document
  explicitly in the pattern doc.
- **R3 — `schedule_next` schema may evolve in future work.**
  Mitigation: read only the keys this part needs (`tiers:`,
  `sensors:`); ignore unknown keys; document forward-compatibility
  inline in the skill.
- **R4 — Pattern-doc edit overlaps textually with existing
  parallel-execution coverage.** Mitigation: new subsection
  references (does not duplicate) the existing coverage; new
  content stays focused on tiering + persistence + scheduling.
- **R5 — Sensor-file append performance on large `runs:` lists.**
  With cap N=20, append is O(20) per cycle per sensor — trivial.
  Mitigation: just enforce the cap; no other concern.
- **R6 — End-to-end fixture run might be slow.** Mitigation: use
  trivially-passing sensors (`echo ok`) for both cheap and
  expensive in the test fixture; the test verifies *gating
  behavior + persistence*, not *sensor payload*.
- **R7 — Coordinator writes to sensor files concurrent with a
  human-invoked upsert.** Both write atomically (Part 2's upsert,
  this part's append), so the worst case is a clobbered intermediate
  state — not file corruption. Documented assumption: humans run
  upsert between cycles, not concurrently.

## Dependencies

- `.vibeflow/specs/sensor-cost-tiering-part-1.md` — sensor file
  schema with `runs:` field, `wm_sensors_dir`.
- `.vibeflow/specs/sensor-cost-tiering-part-2.md` — upsert ensures
  files exist; coordinator's append assumes the field-level merge
  rule.
- `.vibeflow/specs/sensor-cost-tiering-part-3.md` — `--tier` flag
  on `verify-acceptance.sh` (Phase A and Phase B both call it).
- `.vibeflow/specs/sensor-cost-tiering-part-4.md` — Validator's
  `schedule_next` emission and persistence (consumed here).
