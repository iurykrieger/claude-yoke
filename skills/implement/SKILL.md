---
name: implement
description: >
  Phase 4 — adversarial ralph loop. Orchestrator skill (runtime coordinator
  mode) spawns the Implementation Agent and Validation Agent via the Task
  tool and iterates them against the binding Acceptance Contract until
  every criterion passes or the loop pauses for human arbitration. Sprint
  contracts on consensus persist to `.yoke/contracts/<slug>.md`; runtime
  state lives under `.yoke/runtime/`. Hard bounds and the formal Trigger-4
  escalation packet ship in Sprint 6; in v0.4.0 the loop pauses with a
  clear message on divergence or contradiction.
argument-hint: ""
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /yoke:implement — Phase 4 (basic ralph loop)

Drive Implementation ↔ Validation cycles inside the envelope of the
binding Acceptance Contract.

> **Architectural note (PRD v0 amendment).** The Orchestrator is a
> *skill*, not a subagent. This skill operates in **runtime coordinator
> mode** (one of three Orchestrator modes; the others — mediator and
> canonizer — are exercised by `/yoke:ask` and `/yoke:canonize`
> respectively). It invokes the four agent subagents via the Task tool;
> no subagent spawns another. Hard bounds, full Model C, and the formal
> Trigger-4 escalation packet ship in Sprint 6.

## Process

### 1. Pre-flight (deterministic)

- Source `lib/working-memory/paths.sh`. All paths below resolve through
  `wm_*_path` helpers. The active task is read from `.yoke/.current` via
  `wm_active_slug`; if missing, abort with the helper's "no active task"
  error.
- Run `lib/ralph-loop/orchestrate.sh preflight`. The script verifies:
  - `.yoke/config.yaml` exists.
  - `.yoke/.current` exists and points at a valid slug.
  - `wm_prd_path "$slug"` exists with `Status: approved`.
  - `wm_tech_spec_path "$slug"` exists with `Status: approved`.
  - `wm_acceptance_contract_path "$slug"` exists with `Status: ratified`.
  - On any missing pre-condition, the script aborts (exit codes 3 or 4).
- Run `hooks/pre-implementation.sh` (skeleton in v0.4.0; Sprint 6
  populates it).
- Ensure `.yoke/runtime/` and `.yoke/contracts/` exist (`mkdir -p`).
  Initialize `wm_progress_path` (`.yoke/runtime/progress.md`) and
  `wm_contracts_path "$slug"` (`.yoke/contracts/<slug>.md`) from
  `templates/progress.md` and `templates/contracts.md` if they don't
  exist (cycle 0 entries).

### 2. Cycle loop

For each cycle (numbered starting at 1):

1. **Implementation Agent step (agentic).** Spawn
   `agents/implementation.md` via the Task tool, providing:
   - Approved upstream artifacts (read-only): PRD, Tech Spec, AC at
     versioned paths via `wm_*_path`.
   - Current runtime progress at `wm_progress_path` (last cycle's state).
   - Current sprint contracts at `wm_contracts_path` (so far).
   - Last `verify-acceptance.sh` snapshot from
     `wm_snapshots_dir`/`cycle-<N-1>.yaml` (if any).

   The agent applies code changes targeting the next failing
   Acceptance Contract criterion. It writes `wm_progress_path` at
   the end of its turn (per its restrictions).

2. **Sensor execution (deterministic).** Run
   `hooks/verify-acceptance.sh` against `wm_acceptance_contract_path`.
   Capture the structured YAML output.

3. **Validation Agent step (agentic).** Spawn
   `agents/validation.md` via the Task tool, providing:
   - Approved Acceptance Contract at `wm_acceptance_contract_path`.
   - Sensor output from step 2.
   - Latest sprint contracts at `wm_contracts_path`.
   - The Implementation Agent's `wm_progress_path` entry for this cycle
     (read-only).

   The agent emits structured JSON verdicts per criterion. If
   Implementation and Validation reach consensus on a sub-objective
   interpretation, both append a sprint contract to
   `wm_contracts_path` (deterministic helper:
   `lib/ralph-loop/orchestrate.sh append-contract <yaml-fragment>`).

4. **Contradiction check (deterministic).** Run
   `lib/ralph-loop/orchestrate.sh check-contradiction`. If a sprint
   contract textually contradicts an Acceptance Contract criterion
   (heuristic: contains a relax/remove/skip/disable/bypass/ignore
   verb together with a criterion identifier), the script exits 10
   and the loop pauses with a clear message: "Sprint contract
   contradicts Acceptance Contract. Pausing for human arbitration.
   (Sprint 6 will ship the formal Trigger-4 packet.)"

5. **Persist (deterministic).** Run `hooks/post-iteration.sh`. The
   hook:
   - Increments the cycle counter at `wm_cycle_counter_path`
     (`.yoke/runtime/.cycle-counter`; read by Sprint-6's
     `check-hard-bounds.sh`).
   - Snapshots `verify-acceptance.sh` output to
     `wm_snapshots_dir`/`cycle-<N>.yaml`
     (`.yoke/runtime/.snapshots/cycle-<N>.yaml`).

6. **Stop check.** If every criterion in the Acceptance Contract has
   `status: pass` in the latest sensor output AND no `divergence`
   verdict from the Validation Agent, return MERGE-READY. Otherwise,
   continue to the next cycle.

### 3. Termination paths (v0.6.0+)

- **All criteria pass** → `/yoke:implement` returns MERGE-READY. Print
  next-step pointer to `/yoke:canonize`.
- **Sprint contract contradicts Acceptance Contract** → invoke
  `lib/ralph-loop/escalate.sh --reason contract-conflict`. The script
  emits the structured Trigger-4 packet to `wm_trigger4_packet_path`
  (`.yoke/runtime/.trigger4-packet.yaml`) and stdout. Loop pauses for
  human arbitration.
- **Divergence verdict from Validation Agent** → invoke
  `lib/ralph-loop/escalate.sh --reason divergence --category <quality-policies-broken|technical-infeasibility|business-conflict|requires-contract-modification>`.
  The script writes the Trigger-4 packet. Loop pauses.
- **Hard bound reached** (cycles, timeout, or token budget — enforced
  by `hooks/check-hard-bounds.sh` after every cycle) → `check-hard-bounds.sh`
  invokes `escalate.sh --reason hard-bound` and exits 10. The skill
  treats this as a pause-with-arbitration-packet.
- **Fundamental infeasibility detected by Implementation Agent** →
  invoke `escalate.sh --reason infeasibility`. Loop pauses.

The Trigger-4 packet is non-coalescable with Triggers 1, 2, 3, 5 — see
`.vibeflow/patterns/human-triggers.md`.

## Pre-conditions

- `.yoke/config.yaml` exists.
- `.yoke/.current` exists and points at a valid slug.
- `.yoke/prds/<slug>.md` (approved), `.yoke/tech-specs/<slug>.md`
  (approved), `.yoke/acceptance-contracts/<slug>.md` (ratified).

## Output contract

- Exit 0 with merge-ready code on full convergence.
- Exit non-zero with a clear pause/abort message on divergence,
  contradiction, or pre-condition failure.

## Anti-patterns

- Do NOT let the Implementation Agent and Validation Agent share
  context. Spawn each via separate Task calls; pass only the explicit
  inputs listed in step 2's substeps.
- Do NOT skip `hooks/verify-acceptance.sh` between agent turns —
  sensor output is the structured channel through which the
  Validation Agent judges.
- Do NOT silently relax the Acceptance Contract. Sprint contracts
  that contradict the Contract pause the loop.
- Do NOT proceed past 5–8 cycles in v0.4.0 without an external
  `timeout` — hard bounds ship in Sprint 6.

## See also

- `.vibeflow/patterns/ralph-loop.md`.
- `.vibeflow/patterns/roles.md`.
- `agents/implementation.md`.
- `agents/validation.md`.
- `lib/ralph-loop/orchestrate.sh`.
- `hooks/post-iteration.sh`.
- `hooks/verify-acceptance.sh`.
