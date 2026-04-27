# Sprint 03 of 03: runtime-background-agents

> Migrated from: # Spec: runtime-background-agents — Part 3 (cycle status snapshots)


> Generated via /vibeflow:gen-spec on 2026-04-26
> Source: `.vibeflow/prds/runtime-background-agents.md`

## Objective

Emit one user-visible markdown status block per ralph-loop cycle, at
cycle end, so the user can confirm `/yoke:implement` is alive and
advancing without waiting for the loop's terminal exit message.

## Context

After Parts 1 and 2 ship, the per-cycle batch is `3 + N` background
tasks with verdicts under `.yoke/runtime/.judge-verdicts/cycle-<N>/`
and computational-sensor output under `.yoke/.snapshots/cycle-<N>.yaml`.
The user, however, still sees nothing user-visible until the loop
exits — the original PRD problem (#1, "no live visibility").

This spec adds a deterministic node at the end of each cycle that
reads the cycle's scratch state and prints a compact markdown status
block. It is the simplest user-facing affordance that turns the
cycle from a black box into a confirmable heartbeat. Per PRD Decisions
#2 and #3: one snapshot per cycle, at cycle end, minimal fidelity
(`running` / `done` / `failed` per agent + sensor pass/fail counts +
elapsed + distance to bounds).

## Definition of Done

1. `lib/ralph-loop/status-snapshot.sh` exists. It accepts the cycle
   scratch directory path as `$1` and emits a markdown status block
   to stdout. Exits 0 on success; exits non-zero with a structured
   error to stderr on missing inputs (per `conventions.md` "Sensor
   output for LLM consumption").
2. `/yoke:implement` invokes `status-snapshot.sh` exactly **once per
   cycle**, after `hooks/post-iteration.sh` and
   `hooks/check-hard-bounds.sh` complete and before the next cycle's
   batch is issued. Output is emitted to the user (the
   skill's prose explicitly relays it; the helper writes to stdout
   only).
3. The status block contains, in order: cycle number; per-agent
   state for **Generator**, **Validator**, **Orchestrator**, and each
   spawned **inferential sensor** (label = sensor id) — values
   restricted to `running` / `done` / `failed`; sensor verdict
   counts (computational pass/fail/skip + inferential pass/fail/skip);
   cycle elapsed time; cycles remaining vs hard-bound N; time
   remaining vs hard-bound timeout.
4. No mid-cycle / per-notification status emission. The skill emits
   nothing user-visible between the per-cycle batch dispatch and the
   end-of-cycle snapshot. (The terminal exit summary at loop
   termination — "Merge-ready. Canonization summary: …" — is
   unchanged.)
5. **Craftsmanship gate:** `lib/ralph-loop/status-snapshot.sh` targets
   bash 4+, is shellcheck-clean, and emits its block in a structured
   format (fixed section order, fenced code block, one fact per line)
   so future automation can read it back without parsing prose.
6. **Craftsmanship gate:** `tests/ralph-loop-bounds.test.sh` extended
   with present-tense assertions: (a) helper script exists and is
   executable; (b) `skills/implement/SKILL.md` invokes it exactly
   once per cycle (single grep for the helper path inside the cycle
   loop body); (c) status block fields enumerated in DoD #3 are all
   referenced in the helper's output template.

## Scope

- `lib/ralph-loop/status-snapshot.sh` (NEW) — formats the status
  block from the cycle's scratch state. Reads `wm_progress_path`,
  `wm_contracts_path`, `$(wm_snapshots_dir)/cycle-<N>.yaml`,
  `$(wm_runtime_dir)/.judge-verdicts/cycle-<N>/`, the
  `.task-spawn-log`, and `wm_cycle_counter_path`.
- `skills/implement/SKILL.md` — invoke the helper at cycle end (after
  `post-iteration.sh` + `check-hard-bounds.sh`, before the next
  cycle's batch dispatch). Update the anti-pattern list to forbid
  mid-cycle status emission.
- `hooks/verify-acceptance.sh` — only if a stable pass/fail-counts
  block is not already present in `cycle-<N>.yaml`. Most likely
  unchanged; if changed, the change is additive and minimal. If
  touched, counts toward the budget.
- `tests/ralph-loop-bounds.test.sh` — extend with the present-tense
  assertions in DoD #6.

Budget: ≤ 4 files. Above list is exactly 4 in the worst case (with
`verify-acceptance.sh` change), or 3 (without).

## Anti-scope

- **Per-notification status emission** — explicitly forbidden by
  PRD Decision #2.
- **Live progress (mid-cycle)** — same.
- **Rich UI / TUI / spinner** — PRD Anti-scope. The block is plain
  markdown.
- **Status emission at loop termination** — covered by the existing
  exit summary; do not duplicate.
- **Status emission on hard-bound abort** — the hard-bound escalation
  packet (`lib/ralph-loop/escalate.sh`) already surfaces full state
  to the user; status snapshot is for normal-flow cycles.
- **Per-agent partial signals** — no "Generator targeted criterion
  `auth-3`" lines (PRD Decision #3). The Generator's
  `citing_criterion:` lives in `progress.md`; do not surface it in
  the status block.
- **Snapshot format negotiation with downstream tooling** — first
  ship a fixed format; redesign later if a real consumer appears.

## Technical Decisions

### 1. Helper script, not inlined bash in SKILL.md

`status-snapshot.sh` is a separate script under `lib/ralph-loop/`.
The skill invokes it as `bash lib/ralph-loop/status-snapshot.sh
"$(wm_runtime_dir)"` and relays the output.

**Why:** matches the existing `lib/ralph-loop/escalate.sh` and
`orchestrate.sh` conventions; testable in isolation; keeps the
skill's prose readable.

**Rejected:** an awk/jq one-liner embedded in `SKILL.md` (loses
testability + readability).

### 2. Status block format (fixed)

```
### Cycle <N> · <elapsed>

- Generator:    done
- Validator:    done
- Orchestrator: done
- judge:<sensor-id-1>: done
- judge:<sensor-id-2>: failed

Sensors: <comp-pass>/<comp-fail>/<comp-skip> computational · <inf-pass>/<inf-fail>/<inf-skip> inferential
Bounds:  <cycles-used>/<N> cycles · <time-used>/<timeout> elapsed
```

Section order: title → agent states → sensor counts → bounds. One
fact per line. Fenced inside a `### …` markdown header so it stays
distinct from the surrounding skill output.

**Why:** PRD Decision #3 + `conventions.md` "structured for direct
agent consumption" + future-readability for automation.

### 3. Agent state derivation rules

- `done` — the task's completion notification fired and exit was 0.
- `failed` — completion fired with non-zero exit (or escalate.sh was
  invoked from inside the agent).
- `running` — should not appear on the cycle-end snapshot since the
  helper runs after wait-for-completions; if it does appear, treat
  it as a logic bug in the wait step from Part 1.

The helper reads completion state from the per-cycle scratch log
(`$(wm_runtime_dir)/.task-spawn-log` + a sibling completion log). No
new IPC.

### 4. Distance-to-bounds derivation

- Cycles: `N - <cycles-used>` from `wm_cycle_counter_path`. Hard-bound
  N from `.yoke/config.yaml`'s `runtime.hard_bounds.cycles` (default
  the value used by `check-hard-bounds.sh`).
- Time: `timeout - <elapsed-since-loop-start>`. Loop start timestamp
  recorded by `hooks/pre-implementation.sh`; if not yet recorded
  there, add it as part of this spec (counts toward the
  `pre-implementation.sh` change but is single-line).

**Rejected:** computing budget remaining (token budget). Out of scope
for v0; ship cycles + time in v0.

## Applicable Patterns

- `.vibeflow/patterns/ralph-loop.md` — deterministic nodes inside the
  blueprint (sensor execution, contradiction check, persist,
  hard-bound check, status snapshot is the new addition). Updated
  inline if needed.
- `.vibeflow/conventions.md` — "Back-pressure: success is silent,
  failures are verbose" tension: Part 3 explicitly emits even on
  successful cycles. Justified by PRD Problem #1 (the user needs a
  liveness signal) and bounded to one block per cycle.
- `.vibeflow/conventions.md` — "Sensor output for LLM consumption"
  applies to the helper's stderr error format on missing inputs.

## Risks

- **Convention tension** — emitting per-cycle status appears to
  violate "success is silent". Mitigation: this is the smallest
  exception that satisfies the PRD (one block per cycle, fixed
  format, no prose), and it is documented in `patterns/ralph-loop.md`
  as the user-visibility node — not retrofitted as a generic logging
  primitive.
- **Helper failure crashing the loop** — if `status-snapshot.sh`
  errors, naive integration would abort the cycle. Mitigation: the
  skill invokes it as a non-fatal step (e.g. `... || echo "(status
  snapshot unavailable)"`). DoD #5 requires structured stderr so the
  user sees a real error, not a stack trace.
- **Snapshot format churn** — fixing the format now bakes in a
  schema. Mitigation: §2 is intentionally minimal; future consumers
  can consume more lines without breaking, and we add a
  `status-snapshot.sh --version` flag if a real consumer ever lands.
- **Test brittleness** — DoD #6's grep-based assertions can break
  on cosmetic edits. Mitigation: assert on the helper *invocation*
  and the *field labels* in the helper script, not on the rendered
  output verbatim.

## Dependencies

- `.vibeflow/specs/runtime-background-agents-part-1.md` — the
  cycle-end wait-for-completions step is the hook point.
- `.vibeflow/specs/runtime-background-agents-part-2.md` — inferential
  sensor agents need to exist before the status block can list them.
  The helper must enumerate them dynamically (read the
  `.task-spawn-log` for the cycle), not hard-code `judge:*` labels.
