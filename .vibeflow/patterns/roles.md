---
tags: [agents, roles, generator, validator, orchestrator, write-authority]
modules: []
applies_to: [agents, skills, prompts]
confidence: validated
---
# Pattern: Three Agentified Roles

<!-- vibeflow:auto:start -->
## What
Yoke structures the entire flow around three agentified roles with disjoint
functional objectives: **Generator** produces spec artifacts, **Validator**
judges conformance against determinable signals, and **Orchestrator** mediates
canonical memory, coordinates runtime, and canonizes learnings. Read and write
authority for each role is declared explicitly — there is no implicit access.

## Where
Conceptually, every task touches all three roles. Generator and Validator are
also instantiated at runtime as the Implementation Agent and the Validation
Agent. The Orchestrator is a singleton — the only role with write authority
on canonical memory.

## The Pattern

### Generator
Objective: turn declared intent into structured artifacts that describe what
and how something should be built.
- Produces: `prd.md` (Phase 1) and `tech-spec.md` (Phase 2).
- At runtime: spawns an **Implementation Agent** that iterates over the Tech Spec, writes `progress.md`, and consumes structured sensor feedback from the Validation Agent.
- Reads canonical memory: only via the Orchestrator.
- Writes canonical memory: never.
- Writes working memory: freely, inside `prd.md`, `tech-spec.md`, `progress.md`.

### Validator
Objective: judge conformance against determinable signals (declared policies,
approved fixtures, computational sensors, calibrated inferential sensors).
- Produces: `acceptance-contract.md` (Phase 3), binding once approved by the human.
- At runtime: spawns a **Validation Agent** that runs all available sensors, runs an inferential semantic judge when computational sensors cannot judge, validates progress emitted by the Implementation Agent, and emits structured pass / fail / divergence verdicts.
- Reads canonical memory: only via the Orchestrator.
- Writes canonical memory: never.
- Writes working memory: freely, inside `acceptance-contract.md`, `contracts.md`.

### Orchestrator
Three responsibilities sharing one role for operational coherence:
1. **Upstream canonical-memory mediator.** Every read of canonical memory by Generator or Validator passes through the Orchestrator, which applies progressive disclosure and emits query traces that feed future canonization.
2. **Runtime coordinator.** Spawns the Implementation Agent and the Validation Agent, observes their interaction, persists sprint contracts in `contracts.md`, escalates divergence to the user (Trigger 4), and stops the loop when hard bounds are hit.
3. **Canonizer (post-implementation).** Reads working memory, applies the canonization criteria, and proposes writes to canonical memory under Model C.

The Orchestrator is the only writer of canonical memory and is load-bearing
during Phase 4 — frequent state checkpointing and a recovery protocol from
`progress.md` + `contracts.md` mitigate this single point of failure.

## Rules
- Every read of canonical memory passes through the Orchestrator. There is no direct path.
- Only the Orchestrator writes to canonical memory, and only with Model C applied.
- Generator and Validator write freely to working memory inside their canonical files.
- An Implementation Agent is **not** the Generator. It is a runtime instance — same skill base, different context.
- A Validation Agent is **not** the Validator. Same relationship.
- Implementation Agent and Validation Agent must have separate prompts and contexts — the adversarial separation between generation and validation is by design.
- The Orchestrator loads only the subgraph of canonical memory relevant to the current phase/task. Never the whole memory.

## Examples from this codebase
> Repository is empty. Expected layout once implementation begins:

```
agents/
├── generator/
│   ├── prompt.md          # role-level prompt
│   └── skills/            # PRD, Tech Spec generation
├── validator/
│   ├── prompt.md
│   └── skills/            # Acceptance Contract generation
├── orchestrator/
│   ├── prompt.md          # role + canonization criteria
│   └── skills/            # canonical-memory-read, canonization
└── runtime/
    ├── implementation-agent/  # runtime instance of Generator
    └── validation-agent/      # runtime instance of Validator
```

<!-- vibeflow:auto:end -->

## Anti-patterns
- Generator or Validator writing directly to canonical memory — breaks Model C, pollutes doctrine.
- Generator or Validator reading canonical memory directly, bypassing the Orchestrator — breaks progressive disclosure, context explodes.
- A single agent doing both generation and validation — recreates the self-evaluation bias the role split exists to mitigate.
- Implementation Agent and Validation Agent sharing prompt/context — breaks adversariality.
- Treating the Orchestrator as a passive router instead of a stateful coordinator with checkpointing — runtime failures lose recovery state.

## Implementation Mapping

From `yoke-implementation-plan.md` (2026-04-24) — concrete artifact paths
for each role:

- **Generator** → `agents/generator.md` (memory scope: `project`; tools: read project files, `/yoke:ask`, write `.yoke/prd.md` and `.yoke/tech-spec.md`).
- **Validator** → `agents/validator.md` (memory scope: `project`; tools: read PRD + Tech Spec, `/yoke:ask`, parse host `CLAUDE.md`, write `.yoke/acceptance-contract.md`).
- **Orchestrator** → `agents/orchestrator.md` (three operating modes — mediator, coordinator, canonizer — declared explicitly when active; memory scope: `project` + canonical repo).
- **Implementation Agent** → `agents/implementation.md` (memory scope: `task`; writes `.yoke/progress.md` and `.yoke/contracts.md`; never writes `.yoke/acceptance-contract.md`).
- **Validation Agent** → `agents/validation.md` (executes `hooks/verify-acceptance.sh`; emits structured JSON verdicts; co-writes `.yoke/contracts.md`).

The Generator/Implementation and Validator/Validation distinctions are
materialized as **five separate subagent files**, not as runtime modes of
three agents (decision 2026-04-24 — Five subagents).
