# Sprint 04 of 05: Sensor Cost Tiering

> Migrated from: # Spec: Sensor Cost Tiering — Part 4: Validator scheduling reads sensor files


> Generated via /vibeflow:gen-spec on 2026-04-27 (revised 2026-04-27)
> Source PRD: `.vibeflow/prds/sensor-cost-tiering.md`

## Objective

The Validator persona reads `.yoke/sensors/<id>.md` files (caveats,
calibration notes, `runs:` history) when emitting `schedule_next:` in
its per-cycle verdict, and the working-memory templates persist that
decision verbatim alongside the cycle's verdict so it is auditable
post-hoc.

## Context

Parts 1–3 deliver the inputs: Part 1 the per-sensor file format;
Part 2 the upsert that materializes them; Part 3 the hook flag that
filters by tier. Part 4 is the **decision layer**: the Validator
uses what it observed (cheap-tier results, the diff, Tech-Spec
signals, **plus the sensor files' caveats and run history**) to
authorize the next cycle's expensive sensors — or not.

The decision is lag-by-one — same model already used for inferential
judges per `patterns/sensors.md:90`. This preserves the parallel-
spawn architecture where Generator, Validator, and Orchestrator run
concurrently in one Task batch per cycle. The Validator never gates
execution inside the cycle it spawned in.

For cycle 1, with no prior `schedule_next` to read, the coordinator
default is cheap-only; the Validator's first verdict may use **type-
of-work signals** (Tech-Spec content + the cycle's diff) to authorize
expensive starting cycle 2.

The new dimension this part adds: **the Validator's reasoning cites
sensor history when present**. If `.yoke/sensors/playwright-
checkout.md` shows two consecutive flake-failures in `runs:`, the
Validator's `reason` field references that signal explicitly.

## Definition of Done

1. `agents/validator.md` requires the Validator to **read
   `.yoke/sensors/<id>.md` files** for sensors mapped to the cycle's
   targeted criterion when emitting `schedule_next`. Caveats body
   and `runs:` history feed the decision.
2. `agents/validator.md` requires `schedule_next` in every cycle
   verdict, with a fixed shape:
   ```
   schedule_next:
     sensors: [<sensor-id>...]   # explicit IDs (optional)
     tiers:   [cheap | expensive] # tier shorthand (optional)
     reason:  "..."               # required; cites at least one signal
   ```
3. `agents/validator.md` documents the **default rule**: include
   `tier:cheap` always; include `tier:expensive` when (a) cheap-tier
   was green this cycle for the targeted criterion(s), (b) the
   Validator explicitly authorizes (e.g. diff touches expensive-
   relevant surface, or a sensor's `runs:` history shows two
   consecutive greens after a fix), or (c) the cycle is the final
   merge-ready check.
4. `agents/validator.md` documents the **cycle-1 type-aware
   judgment**: with no prior `schedule_next`, the coordinator runs
   cheap only; the Validator's first verdict may authorize
   expensive starting cycle 2 using Tech-Spec signals + cycle diff.
5. **`reason` field requirements**: must cite at least one signal
   source by name — a sensor ID, a criterion ID, a Tech-Spec
   reference, or a `runs:` history entry. Free-form text is allowed
   beyond that requirement.
6. `templates/progress.md` and `templates/contracts.md` schemas
   include a per-cycle `schedule_next` block alongside the verdict
   — field shape mirrors Validator's emission, persisted verbatim
   for audit.
7. `tests/sensor-tiering.test.sh` extended:
   (a) fixture verdict has well-formed `schedule_next` with all
   required fields;
   (b) when sensor history shows flakes, the verdict's `reason`
   cites the sensor ID;
   (c) a verdict missing `schedule_next` or with empty `reason`
   fails the schema check.
8. **Craftsmanship**: persona content cites the actionable-feedback
   rationale and traces to source PRD; verdict schema follows
   existing structured-output conventions
   (`.vibeflow/conventions.md` back-pressure: structured, machine-
   parseable, no prose-only updates); no manifesto invariant
   weakened.

## Scope

- **Edit** `agents/validator.md`:
  - **New "Reads" section** entry: `.yoke/sensors/<id>.md` for
    sensors mapped to the cycle's targeted criterion(s). The
    Validator may also re-read sensor files for criteria adjacent
    to the targeted one when the diff suggests cross-criterion
    coupling.
  - **Persona contract addition**: emit `schedule_next` in every
    cycle verdict per the shape locked in DoD 2.
  - **"Always" section addition**:
    - "Always include `tier:cheap` in `schedule_next`."
    - "Include `tier:expensive` when the previous cycle's cheap-
      tier was green for the targeted criterion(s), OR when the
      diff touches sensor-applies_to surface, OR when this is the
      final merge-ready check."
    - "Always cite at least one signal source (sensor ID,
      criterion ID, Tech-Spec section, or `runs:` history entry)
      in `reason`."
  - **Cycle-1 heuristic**: no prior `schedule_next`; coordinator
    runs cheap only; first Validator verdict may authorize
    expensive starting cycle 2 using Tech-Spec signals + diff.
  - **Rationale block**: shift-feedback-left only when actionable;
    per-sensor file is the durable record; `runs:` history flake
    signals are first-class for the scheduling decision.
  - Reference `.vibeflow/prds/sensor-cost-tiering.md` for
    traceability.
- **Edit** `templates/progress.md`:
  - Add a per-cycle `schedule_next:` block under the existing
    per-cycle entry, mirroring the Validator's emission shape.
- **Edit** `templates/contracts.md`:
  - Add a `schedule_next:` field per cycle, persisted verbatim
    from the Validator's verdict.
- **Edit** `tests/sensor-tiering.test.sh` (extended from Parts
  1–3):
  - Fixture verdict (JSON or YAML, depending on the existing
    verdict-schema convention): assert all three required fields
    present (`sensors` and/or `tiers`, `reason`).
  - History-aware fixture: pre-seed `.yoke/sensors/<id>.md` with
    a `runs:` history showing two flakes; provide a fixture
    verdict and assert the Validator-persona-defined `reason`
    schema requires citing the sensor ID. (This is a contract
    test on the persona, not a live agent run — the test verifies
    that an incomplete verdict fails the schema check.)
  - Negative cases: a fixture verdict missing `schedule_next` is
    treated as malformed; a fixture with empty `reason` is
    treated as malformed.

## Anti-scope

- **No coordinator gating.** Part 5 owns reading `schedule_next`
  and acting on it.
- **No in-cycle scheduling.** Validator stays parallel-spawn;
  decisions are lag-by-one only.
- **No live-agent integration tests.** Fixture-based assertions
  only; end-to-end smoke is in Part 5.
- **No new persona responsibilities** beyond scheduling. Sensor
  consumption, consensus-with-Generator, and other behaviors
  unchanged.
- **No Orchestrator changes.** Canonization, Model C, and consult-
  mode behavior untouched.
- **No new working-memory artifacts.** Reuse `progress.md` and
  `contracts.md`; sensor history reads come from `.yoke/sensors/`
  (Part 1).
- **No `schedule_next` schema versioning** (e.g. `version: 1`
  field). Premature.
- **No flake-detection algorithm.** The Validator interprets
  `runs:` history qualitatively in `reason`; quantitative flake
  rules (e.g. "auto-quarantine after N flakes") are out of scope.

## Technical Decisions

- **`schedule_next` is structured, not prose.** Rationale: must be
  machine-parseable for Part 5's coordinator. Three keys:
  `sensors`, `tiers`, `reason`. The `reason` field is human-readable
  but must cite at least one signal source.
- **Tier shorthand and explicit sensor IDs coexist.** Rationale:
  most cycles use `tiers: [cheap]` or `tiers: [cheap, expensive]`;
  occasionally the Validator wants to authorize a specific sensor
  (one expensive sensor whose target surface is touched). Both
  shapes supported keeps the common case terse.
- **Persisted verbatim in `progress.md` / `contracts.md`.**
  Rationale: no transformation = no impedance mismatch when humans
  audit. Verdict schema and persisted schema are the same object.
- **Cycle-1 heuristic in the persona, not the coordinator.**
  Rationale: "what to authorize" is a Validator concern. The
  coordinator's cycle-1 default (cheap only) is mechanical and
  lives in Part 5.
- **`reason` field has a citation requirement, but no fixed
  format.** Rationale: forcing a structured citation list would
  bloat the schema; requiring "at least one signal source" keeps
  the bar high without over-engineering.
- **Validator reads sensor files directly, not via an
  intermediate.** Rationale: the file is in working memory (per-
  task, ephemeral); no governance overhead. Direct read keeps the
  decision path simple.

## Applicable Patterns

- `.vibeflow/patterns/roles.md` — Validator is a runtime subagent
  with judgment authority; scheduling is a refinement.
- `.vibeflow/patterns/sensors.md` — structured-output rule applies
  to the verdict (including `schedule_next`); per-sensor file is
  now the runtime context.
- `.vibeflow/patterns/ralph-loop.md` — lag-by-one model already
  documented; reused.
- `.vibeflow/patterns/memory-model.md` — Validator reads working
  memory directly (allowed); no canonical-memory access required.
- `.vibeflow/conventions.md` — structured output, machine-
  parseable; every persona change traces to a failure or
  constraint.

## Risks

- **R1 — Validator verdict schema may already be locked elsewhere.**
  Mitigation: read `agents/validator.md` in Phase 1; if there's an
  existing JSON/YAML schema definition, extend it as a new top-
  level key rather than nesting inside an existing field.
- **R2 — `templates/progress.md` and `templates/contracts.md` may
  have a per-cycle block format that conflicts with the new
  field.** Mitigation: read both templates first; place
  `schedule_next` adjacent to the verdict at the same nesting
  level. Don't restructure the template.
- **R3 — Sensor-file reads bloat Validator context.** Each sensor's
  caveats body could be long; reading all of them every cycle
  could push context limits. Mitigation: persona contract only
  requires reading sensors mapped to the targeted criterion(s),
  not all sensors. Document this scoping rule explicitly.
- **R4 — `reason` citation enforcement is a soft contract.** A
  Validator emitting an empty or token-citation `reason` is hard
  to detect mechanically. Mitigation: schema test asserts non-
  empty `reason`; deeper qualitative review remains a human
  responsibility (post-hoc audit of `progress.md`).
- **R5 — Schema-fixture drift.** If Part 5 changes the
  `schedule_next` shape during integration, Part 4's fixture and
  assertions become outdated. Mitigation: lock the shape here
  (sensors / tiers / reason — three keys, no more) and treat any
  change as a new spec.

## Dependencies

- `.vibeflow/specs/sensor-cost-tiering-part-1.md` —
  `templates/sensor.md` defines the `runs:` field the Validator
  reads.
- `.vibeflow/specs/sensor-cost-tiering-part-2.md` — upsert
  guarantees sensor files exist by the time the Validator reads
  them.
