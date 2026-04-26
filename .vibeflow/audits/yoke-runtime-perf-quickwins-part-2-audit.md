# Audit Report: Yoke Runtime Perf Quick Wins — Part 2

**Verdict: PASS**

> Audited 2026-04-25 against
> `.vibeflow/specs/yoke-runtime-perf-quickwins-part-2.md`.
> Tests run: `tests/smoke/perf-quickwins-part-2.test.sh` (PASS,
> 42/42 internal checks), `tests/smoke/perf-quickwins-part-1.test.sh`
> regression (PASS), `tests/smoke/sprint-8.test.sh` full audit gate
> (PASS — every sprint smoke + plugin-install + skills-format).

## Test Suite

- `tests/smoke/perf-quickwins-part-2.test.sh` → **PASS** (42/42)
- `tests/smoke/perf-quickwins-part-1.test.sh` → **PASS** (regression)
- `tests/smoke/sprint-8.test.sh` → **PASS** (full audit gate;
  sprints 2–7 + plugin-install + skills-format all green)

Test FAIL → automatic FAIL rule does NOT trigger.

## DoD Checklist

- [x] **DoD #1** — Plan-first behavior mandated in `agents/generator.md`.
  Evidence: `agents/generator.md` "Behaviors → Always" section now
  opens with "**Plan before you edit, every cycle.**" followed by a
  numbered 5-step sequence: (1) read all currently-failing criteria
  from the snapshot, (2) group coupled criteria by overlapping files
  / sensor-evidence locations, (3) name the change set as a
  file → intent map, (4) write the `plan:` block to `progress.md`
  **before** applying edits, (5) only then apply edits. Smoke (a)
  asserts each phrase: "Plan before you edit, every cycle", "Read
  every currently-failing criterion", "Name the change set", "BEFORE
  applying any edits", plus the sharpened persona framing "Senior
  engineer who plans". All 5 assertions green.

- [x] **DoD #2** — Batched coupled criteria are licensed.
  Evidence: `agents/generator.md` "Behaviors → Always" carries
  "**Batch coupled criteria within a cycle when (and only when)
  planning shows shared change surface.**" The coupling heuristic is
  conservative-by-design: two named signals (`tech-spec-overlap`,
  `sensor-evidence-overlap`); explicit non-batching default ("When
  failing criteria don't share files, work one per cycle"); explicit
  conservative bias ("When in doubt, **do not couple**"). The plural
  citing field `citing_criteria:` is documented for batched cycles
  vs. the singular `citing_criterion:` for one-criterion cycles.
  Acceptance Contract still binds — verdicts stay per-criterion.
  Smoke (b) green on all 6 assertions.

- [x] **DoD #3** — `templates/progress.md` carries the `plan:` block.
  Evidence: schema now includes `plan:` with all required fields:
  `cycle`, `failing_criteria_read`, `coupled_groups[].group_id`,
  `coupled_groups[].criteria`, `coupled_groups[].shared_files`,
  `coupled_groups[].coupling_signal`, `change_set` (file → intent
  map). The `citing_criteria:` (plural) field added next to the
  existing `citing_criterion:` (singular). Schema notes document
  semantics, allowed `coupling_signal` values
  (`tech-spec-overlap` | `sensor-evidence-overlap` | `both`), and
  the rule that "single-element groups are a self-bug". Backward
  compatible: every prior field (`timestamp`, `next_step`,
  `files_touched`, `sensor_feedback_consumed`,
  `contract_consensus_reached`, `citing_criterion`) is preserved
  verbatim. Smoke (c) green: 10 new fields + 6 backward-compat
  fields + 3 enum values + self-bug rule, all asserted.

- [x] **DoD #4** — Smoke / fixture test verifies plan presence.
  Evidence: `tests/smoke/perf-quickwins-part-2.test.sh` runs
  against `tests/fixtures/perf-quickwins-part-2/progress-with-plan.md`
  (a 2-criterion fixture where FR-1 + FR-2 share
  `src/api/refund.py`) and asserts (a) `plan:` block presence,
  (b) every required subfield populated, (c) the explicit spec
  assertion that `coupled_groups[0].criteria` length ≥ 2 — the
  fixture parses to length 2, green. The fixture also exercises
  `citing_criteria:` (plural) as required for batched cycles.
  Smoke (d) green on all 9 assertions.

- [x] **DoD #5** — Craftsmanship gate.
  - Generator authority preserved per `patterns/roles.md`: bullet
    "Never write canonical memory" is intact; "Never modify
    `.yoke/prds/`, `.yoke/tech-specs/`, `.yoke/acceptance-contracts/`"
    is intact; task memory scope unchanged. Smoke "(b) Generator
    authority preserved" + "(anti) Generator still cannot modify
    upstream artifacts" — both green.
  - No `conventions.md` Don't violated. The persona changes only
    sharpen the instinct to plan before editing — no canonical
    memory writes introduced, no Acceptance Contract relaxation
    surface, no rubber-stamp Trigger handling, no removal of
    structured-output requirement.
  - No new manifesto invariant introduced. Existing invariants
    (binding spec, adversarial loop with hard bounds,
    sprint-contracts ⊂ Acceptance Contract, governed canonical
    memory, progressive disclosure) all preserved.
  - `templates/progress.md` schema change is additive and
    backward-compatible: older snapshots without `plan:` parse
    fine; absent or null is documented as "not yet populated".
  - Validator authority + structured-JSON verdict shape untouched.
    Smoke "(anti) Validator's structured-JSON verdict shape
    preserved" — green.

## Pattern Compliance

- [x] **`patterns/roles.md`** — followed. Generator role contract
  preserved verbatim: still no canonical-memory writes, still task
  memory scope, still no upstream artifact modification, still
  jointly co-writes `contracts.md` with the Validator on consensus.
  The persona rewrite is a *prompt-engineering* change, not a
  *protocol-engineering* change. Evidence: `agents/generator.md`
  "Memory scope" / "Allowed tools" / "Restrictions" sections — all
  preserved. The new Allowed-tools wording removes the explicit
  authorization to invoke `hooks/verify-acceptance.sh` — see Part 1
  follow-up note below.

- [x] **`patterns/ralph-loop.md`** — followed. Cycle structure
  unchanged: still 3 concurrent subagents per cycle in a single
  Task batch; still five stop conditions; still the same termination
  canonize handoff. The Generator's plan step is part of its agentic
  contribution, not promoted to a separate deterministic node — so
  no new node added to the blueprint. Evidence:
  `skills/implement/SKILL.md` step 2.1 unchanged in shape (the
  per-cycle parallel batch description still names Generator,
  Validator, Orchestrator).

- [x] **`patterns/sensors.md`** — followed. Sensor evidence
  (`location:` field) is the data source for the
  "sensor-evidence-overlap" coupling signal; no schema change on the
  sensor side — `run_one_sensor()` in `hooks/verify-acceptance.sh`
  emits the same 6-field structure as before. The coupling
  heuristic only *reads* sensor output, never modifies the contract.

- [x] **`conventions.md`** (Cross-cutting → "Shift feedback left")
  — followed. Plan-first reduces wasted cycles by encouraging the
  Generator to consume all current sensor feedback before editing,
  not just the latest violation — the same shift-left principle
  applied at the agent-instinct level rather than the sensor-timing
  level.

## Convention Violations (none)

Audited against `.vibeflow/conventions.md` Don'ts list — none
violated.

- ✅ Working-memory tree path conventions preserved (no new files
  introduced in `.yoke/runtime/`).
- ✅ Schema is YAML-in-markdown for diff-friendliness, matching the
  existing `templates/progress.md` style and the broader artifact
  convention (PRD, Tech Spec, Acceptance Contract).
- ✅ Adversarial separation preserved: the Generator's plan is
  written to its own working-memory file (`progress.md`); the
  Validator reads the snapshot independently and emits independent
  per-criterion verdicts.

## Files Changed (4 / ≤ 6 budget)

| File | Change | LOC delta |
|---|---|---|
| `agents/generator.md` | Persona rewrite + new "Plan before you edit" Always-bullet + batching license + Allowed-tools update (Bash no longer auths `verify-acceptance.sh`) | ~+50 |
| `templates/progress.md` | Additive `plan:` block + `citing_criteria:` field + schema-notes section | ~+50 |
| `tests/smoke/perf-quickwins-part-2.test.sh` (new) | Fixture-driven smoke, 42 assertions, 600 s watchdog | ~+200 |
| `tests/fixtures/perf-quickwins-part-2/progress-with-plan.md` (new) | Sample populated `progress.md` exercising the coupling case (FR-1 + FR-2 sharing `src/api/refund.py`) | ~+30 |

Within budget (spec scope listed 3 files + 1 fixture asset; ≤ 6
revised budget per index.md "minimum, revisable upward").

## Anti-scope Compliance

All 8 anti-scope items respected:

- ✅ Generator read/write authorities unchanged (no canonical
  memory writes, no upstream artifact mutation, task memory
  scope).
- ✅ Validator per-criterion verdict shape unchanged.
- ✅ Parallel-spawn architecture untouched.
- ✅ No new agentic step introduced; the `plan:` block is a
  Generator artifact, not a separate deterministic node.
- ✅ `agents/orchestrator.md` untouched (Part 3 territory).
- ✅ Sensor execution untouched (Part 1 territory).
- ✅ No stagnation early-exit heuristic introduced.
- ✅ Existing `progress.md` schema fields preserved (additive
  change only).

## Part 1 Follow-up — Generator Allowed Tools

While editing `agents/generator.md`, identified a Part 1 spec gap:
the original Generator persona's `Bash` Allowed-tools entry
authorized invoking `hooks/verify-acceptance.sh` directly ("after
applying changes"). Part 1's "exactly once per cycle" invariant
required removing this — the spec only listed `agents/validator.md`
in scope, missing the symmetric Generator update. Closed in Part 2
as a natural co-edit:

```
- `Bash` — for code-related operations on the host project workspace
  only. **Never** invoke `hooks/verify-acceptance.sh`; sensor execution
  is the coordinator's responsibility, scoped to exactly once per
  cycle. Read the cycle's snapshot at
  `$(wm_snapshots_dir)/cycle-<N-1>.yaml` instead.
```

This brings the Generator into alignment with the Validator's
Part 1 update. Tests confirm no regression (Part 1 smoke still
PASS).

Recommendation: log this as a decision in `.vibeflow/decisions.md`
("Generator + Validator both consume snapshot; coordinator owns
single sensor execution per cycle").

## Risks Status

- **R1** (LLM ignores persona) — Mitigated by smoke-test
  fixture asserting `coupled_groups[0].criteria` length ≥ 2.
  Stub `plan:` blocks would not reach length-2; the smoke would
  fail. Beyond v0, cycle-count delta archived in
  `.vibeflow/audits/` will provide longitudinal evidence.
- **R2** (over-batching cascade) — Mitigated by per-criterion
  Validator verdicts (untouched in Part 2). Conservative coupling
  heuristic (overlapping files only) bounds the blast radius.
- **R3** (`progress.md` bloat) — Open as documented; no immediate
  mitigation needed at v0 file sizes.
- **R4** (false-positive coupling) — Mitigated by the explicit
  "When in doubt, **do not couple**" persona instruction; future
  field reports become canonical-memory candidates under Model C.

## Next Steps

Ready to ship Part 2. Proceed to
`/vibeflow:implement .vibeflow/specs/yoke-runtime-perf-quickwins-part-3.md`.

Optional pre-merge polish:
- Update `.vibeflow/decisions.md` with the
  "Generator + Validator consume snapshot; coordinator owns
  single sensor execution" decision (Part 1 follow-up).
- After Parts 1+2+3 ship, archive a baseline measurement
  (cycle-count delta on a real task) to demonstrate the
  Generator persona change is observable, not just textual.
