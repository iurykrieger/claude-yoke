---
tags: [runtime, blueprint, hard-bounds, sprint-contracts, terminating, ralph-loop, parallel-spawn]
modules: []
applies_to: [agents, runtime-orchestration, sensors, contracts, canonization]
confidence: validated
---
# Pattern: Ralph Loop with Parallel Subagent Spawn and Hard Bounds

<!-- vibeflow:auto:start -->
## What
Phase 4's runtime is a coordinated loop where `/yoke:implement` (a
**deterministic skill coordinator**) spawns three runtime subagents —
**Generator**, **Validator**, **Orchestrator** — concurrently per cycle
in a single Task batch. The loop is structured as a **blueprint** (an
explicit sequence of deterministic and agentic nodes) with **hard
bounds** that guarantee termination. Generator and Validator are
functionally adversarial; the Orchestrator subagent consults canonical
memory live, monitors for divergence, and owns the canonization
handoff at loop termination.

## Where
Spawned by `/yoke:implement` after Trigger 3 (Acceptance Contract
ratification). Lives until either every Acceptance Contract criterion
passes (merge-ready), the loop hits a stop condition, or a hard bound
triggers escalation. At termination, one final Orchestrator-only call
fires with `mode=canonize` to propose Model C canonical-memory writes.

## The Pattern

### Concurrent agentic batch (per cycle, single assistant turn)
The skill issues **one assistant turn with three Task calls**
spawning the three runtime subagents simultaneously. Each receives
disjoint inputs from the freshest snapshot of working memory:

- **Generator (`agents/generator.md`)** — writes code targeting the
  next failing Acceptance Contract criterion; persists
  `.yoke/progress.md`.
- **Validator (`agents/validator.md`)** — runs sensors via
  `hooks/verify-acceptance.sh` (or reads its prior snapshot); emits
  structured JSON verdicts.
- **Orchestrator (`agents/orchestrator.md`)** in consult+monitor
  mode — invokes `/yoke:ask` via the Skill tool to read canonical
  memory and reasons over the response in-conversation; detects
  divergence and escalates via `lib/ralph-loop/escalate.sh`.

Per-agent file-write contracts (declared in `agents/*.md`) prevent
within-batch collisions: Generator owns `progress.md`; Validator and
Orchestrator do not write working-memory artifacts in consult/monitor
mode; `contracts.md` is appended only on consensus events post-batch.

### Deterministic nodes (no agent decision)
- Sensor execution: `hooks/verify-acceptance.sh` runs after each
  cycle's agentic batch to capture cycle-N's post-Generator state.
- Persisting `progress.md` at the end of every cycle (Generator's
  responsibility).
- Verifying Acceptance Contract state (which criteria pass/fail)
  after every cycle.
- Verifying that emergent sprint contracts do not contradict the
  Acceptance Contract — `lib/ralph-loop/orchestrate.sh
  check-contradiction`.
- Writing a sprint contract to `contracts.md` when consensus
  emerges.
- Counting cycles and checking hard bounds via
  `hooks/check-hard-bounds.sh`.
- Executing approved fixtures.

### Two contract levels
- **Acceptance Contract (pre-runtime).** Binding, human-ratified in
  Phase 3. Defines what "done" means for the task. Cannot be
  modified inside the loop.
- **Sprint contracts (during runtime).** Micro-agreements between
  the Generator and Validator about how to interpret each
  sub-objective inside the Acceptance Contract envelope. Recorded
  in `contracts.md` as they emerge.

If a sprint contract being formed conflicts with the Acceptance
Contract, the loop pauses and escalates via Trigger 4 — never
auto-resolves by relaxing the Contract.

### Hard bounds (terminating guarantees)
- **N cycles without complete convergence.** Recommended initial
  value: N = 5–8.
- **Total runtime timeout.** Recommended initial value: 2–4 h.
- **Token / compute budget.** Configurable per organization and
  task class.

Hitting any bound is **not failure** — it signals that the task
left the regime where the ralph loop is reliable, and now deserves
human attention.

### Stop conditions (in precedence order)
1. Every Acceptance Contract criterion passes → MERGE-READY →
   canonize handoff.
2. Irreconcilable divergence from Validator → Trigger 4 → canonize
   handoff (with termination reason `divergence`).
3. Emergent sprint contract contradicts Acceptance Contract →
   Trigger 4 → canonize handoff (`contract-conflict`).
4. Hard bound reached → escalate to user → canonize handoff
   (`hard-bound`).
5. Generator detects fundamental infeasibility → escalate →
   canonize handoff (`infeasibility`).

### Termination canonization handoff
On any termination path, `/yoke:implement` issues one final
Orchestrator-only Task call with `mode=canonize`. The Orchestrator:

- Reads `.yoke/progress.md`, `.yoke/contracts.md`, and all
  `.yoke/.snapshots/cycle-*.yaml`.
- Applies the five-criterion cascade via
  `lib/canonical-memory/canonization-criteria.sh`.
- Classifies impact per Model C
  (`patterns/model-c-governance.md`).
- Calls `lib/canonical-memory/propose-write.sh` for each candidate
  passing 1–4 and non-contradicting (5).

This is the **only** canonical-memory write path during the loop.
Mid-loop Orchestrator invocations (consult / monitor mode) never
invoke `propose-write.sh`.

### Divergence categories
Divergence happens when the agents cannot converge on a sprint
contract because the proposed approach:

- Breaks quality, standards, or canonical policies — Validator
  rejects on a sensor or policy violation.
- Has technical infeasibility — Generator argues it cannot be done
  with available means.
- Conflicts with business needs — two legitimate interpretations of
  the PRD/Tech Spec are in tension.
- Would require modifying the Acceptance Contract — tacit agreement
  between agents to change something that needs human ratification.

In each case the Orchestrator pauses the loop and invokes the user.
The user can: reformulate the Acceptance Contract, reformulate the
Tech Spec, accept the trade-off, or abort.

## Rules
- Default to deterministic nodes. Agentic nodes are reserved for
  genuine judgment calls.
- Sensor output must be structured (precise location, correction
  instruction when deterministic, reference to the rule that
  fired). Generic output is treated as a sensor bug.
- Hard bounds are configured before the loop starts. There is no
  live override.
- Sprint contracts can never override the Acceptance Contract. They
  negotiate inside its envelope.
- The Generator always writes `progress.md` at end of cycle, even
  on failure — recovery depends on it.
- Generator and Validator co-write `contracts.md` only when they
  reach consensus on a sub-objective.
- The three runtime subagents must launch in a **single concurrent
  Task batch per cycle**, not sequentially across turns. Sequential
  spawning defeats parallelism.
- Canonical-memory writes happen **only** at loop termination via
  the Orchestrator's canonize mode. Mid-loop writes are forbidden.
- The runtime subagents do not share context. Communication is via
  working-memory files only.

## Examples from this codebase
The control loop, expressed as a blueprint:

```
loop:
  cycle = cycle + 1
  if cycle > N or elapsed > timeout or budget_spent:
    escalate(reason="hard-bound"); break
  # --- single assistant turn, 3 concurrent Task calls ---
  parallel_spawn:
    Generator(.yoke/, last_snapshot)        # writes code + progress.md
    Validator(.yoke/, last_snapshot)        # emits structured verdicts
    Orchestrator(mode="consult+monitor")    # /yoke:ask + escalate on divergence
  # --- deterministic nodes ---
  sensor_output = run_sensors()                                     # verify-acceptance.sh
  if contradicts(latest_contract, acceptance_contract):
    escalate(reason="contract-conflict"); break
  if validator_emits_divergence:
    escalate(reason="divergence"); break
  persist_snapshot(progress, contracts, sensor_output)              # post-iteration.sh
  if all_criteria_pass(acceptance_contract):
    result = MERGE_READY; break

# termination handoff (single Orchestrator call)
Orchestrator(mode="canonize", trigger=result)  # 5-criteria + Model C → propose-write.sh
return result
```

<!-- vibeflow:auto:end -->

## Anti-patterns
- "One more cycle" — letting the loop run past N cycles because the agents agree they are "almost there". This is the failure mode hard bounds exist to prevent.
- Letting agents share context to "speed up convergence" — destroys adversariality.
- Logging sensor failures as plain text instead of structured output — agents cannot consume it; counts as a sensor bug.
- Allowing a sprint contract to silently relax the Acceptance Contract — must escalate.
- Aborting on hard bound without surfacing the partial state to the user — discards context valuable for canonization.
- Spawning the three runtime subagents in three separate assistant turns instead of one concurrent Task batch — defeats parallelism and adds latency.
- Mid-loop canonical-memory writes — bypasses Model C governance windows; auto-canonize at termination is the only allowed write surface.

## Implementation Mapping

From `yoke-implementation-plan.md` (2026-04-24, refreshed 2026-04-25
— see `.vibeflow/decisions.md` "Consult live, canonize on
termination") — concrete artifacts for the loop:

- **Orchestration entry point** — `/yoke:implement`
  (`skills/implement/SKILL.md`). The skill is a deterministic
  coordinator; it spawns subagents but is not itself a subagent.
- **Concurrent subagent batch** — `agents/generator.md`,
  `agents/validator.md`, `agents/orchestrator.md` (consult+monitor
  mode), launched in a single Task batch per cycle.
- **Hard-bound enforcement** — `hooks/check-hard-bounds.sh`.
  Defaults: N = 5–8, timeout 2–4 h, budget configurable.
  Per-project overrides in `.yoke/config.yaml`.
- **Per-cycle persistence** — `hooks/post-iteration.sh` (writes
  `.yoke/progress.md` and `.yoke/contracts.md`, snapshots
  `verify-acceptance` output, increments cycle count).
- **Acceptance Contract verification** —
  `hooks/verify-acceptance.sh` (runs each declared sensor, returns
  structured `pass` / `fail` / `skip` per criterion).
- **Human escalation (Trigger 4)** — `lib/ralph-loop/escalate.sh`
  (emits arbitration packet with full state).
- **Termination canonization** — final Orchestrator-only Task call
  from `/yoke:implement` with `mode=canonize`; invokes
  `lib/canonical-memory/canonization-criteria.sh` then
  `lib/canonical-memory/propose-write.sh`.

Sprint roll-out: Sprint-4 ships the parallel-spawn loop without
full hard-bound enforcement; Sprint-5 wires Orchestrator
canonical-memory consultation; Sprint-6 wires hard bounds and the
five-trigger formalization. Until Sprint-6, smoke tests must use
an external timeout (`timeout 600 ...`) to avoid hanging CI.
