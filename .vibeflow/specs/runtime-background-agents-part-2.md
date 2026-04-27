# Spec: runtime-background-agents — Part 2 (skill-owned inferential sensors)

> Generated via /vibeflow:gen-spec on 2026-04-26
> Source: `.vibeflow/prds/runtime-background-agents.md`

## Objective

Move inferential-sensor spawning from `agents/validator.md` into
`/yoke:implement` so judge agents run in the same per-cycle background
batch as Generator/Validator/Orchestrator and the Validator just reads
their verdicts from working memory.

## Context

Commit `1faaf3e` introduced `yoke:semantic-judge` as a runtime subagent
spawned **by the Validator** via `Agent(subagent_type:
yoke:semantic-judge, …)` (see the agent's own description in the
plugin's agent registry). This re-introduces nested subagent spawning
from inside a subagent — the rule
`skills/implement/SKILL.md:290-291` already forbids this for
Orchestrator and the same prohibition logically extends to judges.

Functionally, judge spawning inside the Validator's turn forces every
inferential sensor to run **after** the cycle's Validator wakes up,
serially in the Validator's context. That is the slowness the PRD
exists to kill: by hoisting judge spawning into `/yoke:implement`,
the judges run in parallel with Generator/Validator/Orchestrator and
the Validator simply reads their verdicts in the next cycle (lag-by-one,
matching the existing `cycle-(N-1).yaml` lag — PRD Decision #1, Model
A).

This spec assumes Part 1 has shipped: the per-cycle batch is already
in background.

## Definition of Done

1. `/yoke:implement` reads applicable inferential sensors for the
   targeted criterion from the active Acceptance Contract and spawns
   one background `Agent(subagent_type: yoke:semantic-judge, …)` per
   sensor in the **same** per-cycle Task batch as
   Generator/Validator/Orchestrator. The skill's "wait for
   completions" step (added in Part 1) is extended to wait for
   `3 + N` notifications, where `N = min(applicable_sensors,
   runtime.inferential_sensor_concurrency)`.
2. `agents/validator.md` no longer issues
   `Agent(subagent_type: yoke:semantic-judge, …)`. Grepping the file
   for `subagent_type` yields nothing. The Validator's input contract
   is updated to read judge verdicts from a deterministic
   working-memory path (see DoD #3).
3. Each judge agent writes its verdict to
   `$(wm_runtime_dir)/.judge-verdicts/cycle-<N>/<criterion-id>.json`
   (path defined and exposed via a new helper
   `wm_judge_verdict_path "$slug" "$cycle" "$criterion"` in
   `lib/working-memory/paths.sh`). The Validator reads from this path
   in cycle N+1.
4. The verdict JSON shape matches the existing semantic-judge contract
   (`criterion`, `status`, `location`, `fix_instruction`, `sensor`,
   `evidence`). No schema changes.
5. `runtime.inferential_sensor_concurrency` is added to
   `.yoke/config.yaml` (default 4). When N > the cap, the skill
   selects sensors deterministically (e.g. by criterion order, ties
   broken by sensor id) and surfaces the truncation in the cycle's
   working-memory log so the next cycle picks up the deferred ones.
6. **Craftsmanship gate:** anti-pattern rule in
   `skills/implement/SKILL.md` is extended: "Do NOT spawn
   `yoke:semantic-judge` from inside any subagent — only
   `/yoke:implement` spawns inferential-sensor agents." The
   pre-existing prohibition for Orchestrator stays.
7. **Craftsmanship gate:** `tests/acceptance-and-sensors.test.sh`
   (and/or `tests/ack-sensors-inferential.test.sh`) extended to
   present-tense assertions: (a) `agents/validator.md` contains no
   `subagent_type:` line; (b) `skills/implement/SKILL.md` describes
   skill-owned inferential-sensor spawning; (c) verdict path helper
   exists in `lib/working-memory/paths.sh`. No version literals.

## Scope

- `skills/implement/SKILL.md` — add inferential-sensor identification
  + spawn step inside the per-cycle batch; extend the
  wait-for-completions step to `3 + N`; tighten the anti-pattern
  rule (DoD #6); document the truncation policy (DoD #5).
- `agents/validator.md` — strip judge-spawning instructions; document
  the new input (read verdicts from
  `$(wm_runtime_dir)/.judge-verdicts/cycle-<N-1>/`); update the agent's
  file-write contract section.
- `.vibeflow/patterns/sensors.md` — document that inferential sensors
  are spawned by `/yoke:implement` (not the Validator); keep
  computational sensor description unchanged.
- `tests/acceptance-and-sensors.test.sh` — extend with the present-tense
  assertions in DoD #7. (If `tests/ack-sensors-inferential.test.sh`
  is the better home for assertion (a), put it there instead — only
  one test file may be touched per the budget.)

Note on `lib/working-memory/paths.sh`: adding `wm_judge_verdict_path`
is a small library change. **It does not count as a spec file under
the budget** because it is a single helper function addition that
mirrors the existing `wm_*` family — but the implementer must call
it out in the audit. If the change grows beyond a single helper,
re-scope the spec.

Budget: ≤ 4 files. Above list is exactly 4 (paths.sh treated as a
trivial helper addition per the note above).

## Anti-scope

- **Generator and Orchestrator role changes** — none.
- **Computational sensor pipeline** — `hooks/verify-acceptance.sh`
  + `xargs -P` stays unchanged. Only inferential sensors move.
- **Verdict schema redesign** — keep the existing 6-field shape.
- **Mid-cycle live arbitration on judge failures** — out of scope.
  Failure policy is "log → mark verdict `skip` → surface".
- **Hard-bound escalation on first judge failure** — out of scope.
  Threshold is two consecutive cycles with the same sensor failing
  (see Decision #2 below).
- **Status snapshot emission** — Part 3.
- **Pre-fetching judge inputs across cycles** — judges still receive
  exactly the three inputs declared in their description (criterion
  text, diff under review, calibration block). No caching.

## Technical Decisions

### 1. Lag-by-one verdict consumption (Model A)

The judges spawned in cycle N inspect the diff from the **previous**
Generator turn (cycle N-1). The Validator in cycle N reads verdicts
from `cycle-(N-1)/`. Cycle 1 has no prior verdicts; the Validator
treats them as `skip`.

**Why:** matches the PRD Decision #1 and the existing
`cycle-<N-1>.yaml` lag the Validator already tolerates today. Avoids
a second wave per cycle (Model B), which would halve the parallelism
gain.

### 2. Consecutive-failure escalation threshold = 2

When the same inferential sensor errors in two consecutive cycles,
`/yoke:implement` invokes `lib/ralph-loop/escalate.sh --reason
sensor-failure --sensor <id>` and the loop pauses. A single failure
is logged + skipped; two-in-a-row is a signal something is structurally
wrong with that sensor's environment.

**Why:** Consistent with the existing five-trigger framework — Trigger
4 (divergence arbitration) is the closest analog and uses the same
`escalate.sh` surface. Threshold 1 would be too noisy; threshold ≥ 3
risks losing a full task to a flaky sensor.

### 3. Truncation policy when N > cap

When applicable inferential sensors > `runtime.inferential_sensor_concurrency`,
the skill spawns the cap and **defers** the rest to the next cycle
(written to a queue file at
`$(wm_runtime_dir)/.deferred-sensors.json`). Next cycle's spawn pass
prepends deferred sensors before fresh ones. This guarantees every
applicable sensor eventually runs without exceeding R1's verified
spawn width.

**Rejected:** spawning all N sensors regardless of cap (risks R1
breach); randomly sampling (loses determinism).

### 4. Verdict path lives under runtime, not snapshots

Verdicts go to `.yoke/runtime/.judge-verdicts/cycle-<N>/` rather than
inside `cycle-<N>.yaml` (which `verify-acceptance.sh` owns).
Inferential and computational sensor outputs stay in separate files
to keep the existing `cycle-<N>.yaml` schema stable.

**Rejected:** merging into `cycle-<N>.yaml` (couples this spec to
sensor-snapshot schema changes; out of scope).

## Applicable Patterns

- `.vibeflow/patterns/sensors.md` — computational vs inferential
  sensors, structured output requirement. Updated by this spec.
- `.vibeflow/patterns/ralph-loop.md` — per-cycle concurrent batch.
  Updated by Part 1; Part 2 only extends the batch width prose.
- `.vibeflow/patterns/roles.md` — Validator authority. This spec
  removes a *responsibility* (judge spawning) but preserves the
  *authority* boundary (Validator still emits verdicts; Validator
  still co-writes contracts on consensus).
- `.vibeflow/conventions.md` "Sensor output for LLM consumption" —
  judges already emit structured output (location + correction
  instruction + sensor reference); this spec preserves that shape.

## Risks

- **R1 width breach** — width grows from 3 to 3+N. Default cap N=4
  → max width 7. Before merging, the test in DoD #7 must run
  successfully against width 7 in a smoke fixture. If Claude Code
  rejects width 7, lower the default cap and re-test.
- **Validator stale-verdict bug** — if cycle N's Validator reads from
  `cycle-N/` instead of `cycle-(N-1)/`, it sees no verdicts and
  declares premature `skip`. Mitigation: agent-prompt change spelt
  out explicitly + test asserts the documented path.
- **Deferred-sensor starvation** — if every cycle adds new sensors
  faster than the cap drains, the deferred queue grows unboundedly.
  Mitigation: cap is 4 and the targeted-criterion set is bounded by
  the Acceptance Contract (typically 3-8 criteria per task), so N
  rarely exceeds the cap. If observed in practice, escalate to a
  spec follow-up.
- **Schema drift in verdict JSON** — if a future change to
  `yoke:semantic-judge` adds fields, the Validator's reader must
  tolerate unknown keys. Mitigation: keep the reader tolerant; do
  not enforce a strict schema in Part 2.
- **Consecutive-failure false positives** — a flaky sensor + a
  legitimate code change might trip the threshold. Mitigation: the
  escalation packet surfaces the last two cycles' failure detail so
  the user can immediately see whether the sensor or the code is at
  fault.

## Dependencies

- `.vibeflow/specs/runtime-background-agents-part-1.md` must be
  implemented and merged first. This spec assumes the per-cycle
  batch is already issued in background and the wait-for-completions
  step exists in `skills/implement/SKILL.md`.
