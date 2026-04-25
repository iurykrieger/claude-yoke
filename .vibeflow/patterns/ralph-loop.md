---
tags: [runtime, blueprint, hard-bounds, sprint-contracts, terminating, ralph-loop]
modules: []
applies_to: [agents, runtime-orchestration, sensors, contracts]
confidence: validated
---
# Pattern: Ralph Loop with Blueprint Wrapping and Hard Bounds

<!-- vibeflow:auto:start -->
## What
Phase 4's runtime is a coordinated loop between an Implementation Agent and a
Validation Agent, structured as a **blueprint** (an explicit sequence of
deterministic and agentic nodes) with **hard bounds** that guarantee
termination. Implementation and Validation are functionally adversarial;
sprint contracts capture the consensus that emerges between them, scoped
inside the envelope of the Acceptance Contract.

## Where
Spawned by the Orchestrator after Trigger 3 (Acceptance Contract ratification).
Lives until either every Acceptance Contract criterion passes (merge-ready),
the loop hits a stop condition, or a hard bound triggers escalation.

## The Pattern

### Deterministic nodes (no agent decision)
- Computational sensors run on every Implementation Agent iteration: linters, type checks, structural tests, unit tests. Each emits structured output for agent consumption.
- Persisting `progress.md` at the end of every cycle.
- Verifying Acceptance Contract state (which criteria pass, which fail) after every cycle.
- Verifying that emergent sprint contracts do not contradict the Acceptance Contract.
- Writing a new sprint contract to `contracts.md` when Implementation and Validation reach consensus.
- Counting cycles and checking hard bounds.
- Executing approved fixtures.

### Agentic nodes (LLM judgment required)
- Implementation Agent decides the next implementation step from `progress.md`, sensor feedback, and `contracts.md`.
- Validation Agent judges artifact quality against the Acceptance Contract and accumulated sprint contracts.
- Both negotiate ambiguous interpretations (a sprint contract being formed).
- Validation Agent runs the inferential semantic judge when computational sensors cannot judge.

### Two contract levels
- **Acceptance Contract (pre-runtime).** Binding, human-ratified in Phase 3. Defines what "done" means for the task. Cannot be modified inside the loop.
- **Sprint contracts (during runtime).** Micro-agreements between Implementation and Validation about how to interpret each sub-objective inside the Acceptance Contract envelope. Recorded in `contracts.md` as they emerge.

If a sprint contract being formed conflicts with the Acceptance Contract, the
loop pauses and escalates via Trigger 4 — never auto-resolves by relaxing
the Contract.

### Hard bounds (terminating guarantees)
- **N cycles without complete convergence.** Recommended initial value: N = 5–8.
- **Total runtime timeout.** Recommended initial value: 2–4 h.
- **Token / compute budget.** Configurable per organization and task class.

Hitting any bound is **not failure** — it is a signal that the task left
the regime where the ralph loop is reliable, and now deserves human attention.

### Stop conditions (in precedence order)
1. Every Acceptance Contract criterion passes → code is merge-ready.
2. Irreconcilable divergence between Implementation and Validation → Trigger 4.
3. Emergent sprint contract contradicts Acceptance Contract → Trigger 4.
4. Hard bound reached → escalate to user with current state.
5. Agent detects fundamental infeasibility → escalate.

### Divergence categories
Divergence happens when the agents cannot converge on a sprint contract because the proposed approach:
- Breaks quality, standards, or canonical policies — Validation rejects on a sensor or policy violation.
- Has technical infeasibility — Implementation argues it cannot be done with available means.
- Conflicts with business needs — two legitimate interpretations of the PRD/Tech Spec are in tension.
- Would require modifying the Acceptance Contract — tacit agreement between agents to change something that needs human ratification.

In each case the Orchestrator pauses the loop and invokes the user. The user
can: reformulate the Acceptance Contract, reformulate the Tech Spec, accept
the trade-off, or abort.

## Rules
- Default to deterministic nodes. Agentic nodes are reserved for genuine judgment calls.
- Sensor output must be structured (precise location, correction instruction when deterministic, reference to the rule that fired). Generic output is treated as a sensor bug.
- Hard bounds are configured before the loop starts. There is no live override.
- Sprint contracts can never override the Acceptance Contract. They negotiate inside its envelope.
- The Implementation Agent always writes `progress.md` at end of cycle, even on failure — recovery depends on it.
- Both agents co-write `contracts.md` only when they reach consensus on a sub-objective.

## Examples from this codebase
> Repository is empty. The control loop, expressed as a blueprint:

```
loop:
  cycle = cycle + 1
  if cycle > N or elapsed > timeout or budget_spent: escalate(reason="hard-bound")
  step = ImplementationAgent.next_step(progress, contracts, sensor_feedback)  # agentic
  apply(step)                                                                  # deterministic
  sensor_feedback = run_sensors()                                              # deterministic
  verdict = ValidationAgent.judge(step, sensor_feedback, contract)             # agentic
  if verdict == DIVERGENCE: escalate(reason="divergence")
  if new_contract = negotiate(implementation, validation):                     # agentic + deterministic
    if contradicts(new_contract, acceptance_contract): escalate(reason="contract-conflict")
    contracts.append(new_contract)
  persist(progress, contracts)                                                 # deterministic
  if all_criteria_pass(acceptance_contract): return MERGE_READY
```

<!-- vibeflow:auto:end -->

## Anti-patterns
- "One more cycle" — letting the loop run past N cycles because the agents agree they are "almost there". This is the failure mode hard bounds exist to prevent.
- Letting agents share context to "speed up convergence" — destroys adversariality.
- Logging sensor failures as plain text instead of structured output — agents cannot consume it; counts as a sensor bug.
- Allowing a sprint contract to silently relax the Acceptance Contract — must escalate.
- Aborting on hard bound without surfacing the partial state to the user — discards context valuable for canonization.

## Implementation Mapping

From `yoke-implementation-plan.md` (2026-04-24) — concrete artifacts for the loop:

- **Orchestration entry point** — `/yoke:implement` (`skills/implement/SKILL.md`).
- **Loop coordinator** — `lib/ralph-loop/orchestrate.sh` (cycles, agent spawning, persistence trigger).
- **Hard-bound enforcement** — `hooks/check-hard-bounds.sh` (cycles vs N, elapsed vs timeout, tokens vs budget). Defaults: N = 5–8, timeout 2–4 h, budget configurable. Per-project overrides in `.yoke/config.yaml`.
- **Per-cycle persistence** — `hooks/post-iteration.sh` (writes `.yoke/progress.md` and `.yoke/contracts.md`, snapshots `verify-acceptance` output, increments cycle count).
- **Acceptance Contract verification** — `hooks/verify-acceptance.sh` (runs each declared sensor, returns structured `pass` / `fail` / `skip` per criterion).
- **Human escalation (Trigger 4)** — `lib/ralph-loop/escalate.sh` (emits arbitration packet with full state).

Sprint roll-out: Sprint-4 ships the basic loop without full Orchestrator
coordination; Sprint-5 adds full Orchestrator coordination; Sprint-6 wires
hard bounds and the five-trigger formalization. Until Sprint-6, smoke tests
must use an external timeout (`timeout 600 ...`) to avoid hanging CI.
