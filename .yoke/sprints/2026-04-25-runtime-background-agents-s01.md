# Sprint 01 of 03: runtime-background-agents

> Migrated from: # Spec: runtime-background-agents — Part 1 (background spawning)


> Generated via /vibeflow:gen-spec on 2026-04-26
> Source: `.vibeflow/prds/runtime-background-agents.md`

## Objective

Switch the per-cycle Generator/Validator/Orchestrator Task batch in
`/yoke:implement` from foreground to `run_in_background: true` so the
assistant turn no longer blocks for the full cycle.

## Context

`skills/implement/SKILL.md:84-145` issues three concurrent foreground
Task calls per cycle. The turn blocks until all three return, then the
deterministic tail (sensors, contradiction check, persist, hard-bound
check, stop check) runs sequentially. Even though the three subagents
execute concurrently, the user sees nothing until the tail completes —
a black-box experience that fights the existing pattern doc's intent
(`patterns/ralph-loop.md`: "Concurrent agentic batch (per cycle, single
assistant turn)") by leaving no room for live signal.

This spec is the **foundation** of the multi-part runtime refactor.
Parts 2 (skill-owned inferential-sensor spawning) and 3 (cycle status
snapshots) both assume the per-cycle batch is already issued in
background.

## Definition of Done

1. The per-cycle three-Task batch in `skills/implement/SKILL.md`
   (Generator, Validator, Orchestrator) is issued with
   `run_in_background: true`. Foreground spawning is removed; there is
   no dual-mode toggle.
2. The skill explicitly waits for **all three** background-task
   completion notifications before invoking
   `hooks/verify-acceptance.sh` for the cycle. No deterministic-tail
   step runs against partial state.
3. Per-role model resolution from `lib/runtime/agent-config.sh`
   continues to be honoured: when `yoke_resolve_model` returns a
   non-empty string the `model:` argument is passed to the background
   Task; when empty it is omitted (session inheritance). Resolved
   values are still logged via
   `yoke_log_resolved_models "$(wm_runtime_dir)/.task-spawn-log"`.
4. The termination canonization handoff in §3 of `implement/SKILL.md`
   stays foreground (single Orchestrator-only Task call,
   `mode=canonize`). Background spawning applies only to the per-cycle
   batch.
5. `.vibeflow/patterns/ralph-loop.md` is updated to (a) state that the
   per-cycle batch uses `run_in_background: true`, (b) clarify that
   the canonize handoff stays foreground, and (c) keep all existing
   anti-patterns intact.
6. **Craftsmanship gate:** anti-pattern list in
   `skills/implement/SKILL.md` adds "Do NOT spawn the per-cycle batch
   in foreground". No removal of the existing
   sequential-spawn / shared-context / mid-loop-canonize prohibitions.
7. **Craftsmanship gate:** `tests/ralph-loop-bounds.test.sh` extended
   with a present-tense assertion that `run_in_background: true`
   appears in the per-cycle batch instructions and that the canonize
   handoff does not. No version literals, no chronology
   (per `conventions.md` "Test file per framework concept").

## Scope

- `skills/implement/SKILL.md` — switch the per-cycle Task batch to
  `run_in_background: true`; insert an explicit "wait for three
  completion notifications" step between the agentic batch (step 2.1)
  and sensor execution (step 2.2); update anti-pattern list.
- `.vibeflow/patterns/ralph-loop.md` — update the "Concurrent agentic
  batch" section and the blueprint pseudocode to reflect background
  spawning; add an anti-pattern entry for foreground per-cycle
  batches.
- `tests/ralph-loop-bounds.test.sh` — extend with the
  present-tense assertions described in DoD #7.
- `lib/ralph-loop/orchestrate.sh` — only if a `wait-for-batch` helper
  is needed to keep `SKILL.md` readable; otherwise unchanged. Counts
  toward the budget if touched.

Budget: ≤ 4 files. Above list is exactly 4.

## Anti-scope

- **Inferential sensor spawning** — Part 2's responsibility. Part 1
  changes the spawning *mode* of the existing three-agent batch only.
- **Status snapshots** — Part 3's responsibility. The skill must
  still emit nothing user-visible mid-cycle in Part 1.
- **Validator role changes** — `agents/validator.md` is untouched in
  Part 1. The judge-spawning logic stays where it is until Part 2.
- **Orchestrator role changes** — consult / monitor / canonize modes
  unchanged. Only the spawning mode changes for consult+monitor.
- **Per-cycle batch width** — stays at 3 in Part 1. Width 3+N lands
  in Part 2.
- **Notification polling / sleep loops** — explicitly forbidden. The
  skill must rely on Claude Code's automatic completion notifications
  per the Agent tool contract.
- **New canonical-memory reads/writes** — none. `Consult live,
  canonize on termination` precedent is preserved.

## Technical Decisions

### 1. Single concurrent batch, just background

The three Task calls remain in **one assistant turn**. Sequential
spawning across turns is still forbidden
(`patterns/ralph-loop.md` Rules). Only the `run_in_background: true`
flag is added per call.

**Rejected:** dual-mode (foreground for short tasks, background for
long ones). Adds branch logic with no test value; users want one
path.

### 2. Wait-for-completion as a deterministic node

The "wait for all three completions" step is treated as a deterministic
node in the blueprint (alongside sensor execution, contradiction
check, etc.) — not as an agentic decision. The skill's prose just
says "wait for the three background tasks to complete; do not poll
or sleep; rely on completion notifications".

**Why:** matches `conventions.md` "Blueprints wrapping agentic nodes"
— deterministic where possible, agentic only where judgment is
required.

### 3. Canonize handoff stays foreground

The termination Orchestrator call (`mode=canonize`) is a single
synchronous handoff — there is no parallelism gain from background
mode and the skill's exit message depends on its result. Keep it
foreground.

**Why:** zero-benefit change with non-trivial sequencing risk
(the skill's exit summary "Merge-ready. Canonization summary: <count>
PRs opened." needs the canonize result inline).

### 4. Helper script: optional, only if SKILL.md gets unreadable

Prefer inlining the wait step in `SKILL.md` prose. If readability
suffers (e.g. if the wait state needs explicit ordering with the
contradiction check on early-completion), add a helper. The
implementer decides at edit time; if added, count it against the
file budget and document it in the spec audit.

## Applicable Patterns

- `.vibeflow/patterns/ralph-loop.md` — single concurrent batch per
  cycle, hard bounds, sprint contracts ⊂ Acceptance Contract,
  termination canonization handoff. Updated by this spec.
- `.vibeflow/patterns/roles.md` — role boundaries unchanged. This
  spec preserves Generator/Validator/Orchestrator authorities exactly.
- `.vibeflow/conventions.md` — "Blueprints wrapping agentic nodes",
  "Test file per framework concept" (test goes into existing
  `tests/ralph-loop-bounds.test.sh`).

## Risks

- **R1 width still at 3** — this spec does not stress the parallel
  spawn budget beyond the verified Sprint-1 baseline. Part 2
  introduces width 3+N and re-tests R1.
- **Notification semantics under load** — if Claude Code drops or
  delays a completion notification, the skill stalls indefinitely.
  Mitigation: the existing hard-bound timeout (`timeout 600` smoke
  guard pre-Sprint-6, `hooks/check-hard-bounds.sh` post-Sprint-6)
  still bounds the wait. No new timeout layer.
- **Termination handoff regression** — accidentally flipping the
  canonize call to background would silently break the skill's exit
  summary. Mitigation: DoD #4 + test assertion in DoD #7.
- **Pattern-doc drift** — if Part 1 ships without the
  `ralph-loop.md` update, Part 2's "width 3+N" change inherits a
  stale pattern doc. Mitigation: DoD #5 is binary.

## Dependencies

None. This is the foundation spec.
