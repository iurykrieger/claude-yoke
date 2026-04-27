# Spec: Yoke v1 — Sprint 4 — Basic ralph loop (Phase 4 without full Orchestrator)

> Generated via /vibeflow:gen-spec on 2026-04-24
> PRD: `.vibeflow/prds/yoke-v1.md`
> Plugin version target: 0.4.0

## Objective

Ship the adversarial loop in its minimum viable form: an Implementation
Agent and a Validation Agent iterating on a trivial task with
`progress.md` and `contracts.md` accumulating consensus. The Orchestrator
skill is minimal — it spawns the two runtime agents and lets them
iterate. No hard bounds yet; smoke tests guarded by external `timeout`.

## Context

This is the riskiest sprint — adversarial coordination is the heart of
Yoke. The PRD's amendment locked Orchestrator-as-skill, so at this
sprint that skill is just a thin coordinator. Hard bounds, full
Model C, escalation packets, and progressive disclosure ship in
Sprints 5–6.

## Definition of Done

1. `/yoke:implement` (after Acceptance Contract approved) spawns the
   Implementation and Validation Agents (via the Task tool from the
   Orchestrator skill) and runs at least one cycle.
2. The Implementation Agent writes `.yoke/progress.md` at the end of each
   cycle, including failure cycles.
3. The Validation Agent emits a structured JSON verdict
   (`criterion` / `status` / `location` / `fix_instruction`) per cycle;
   `.yoke/contracts.md` is appended whenever the two agents reach
   consensus on a sub-objective.
4. Sprint contracts that contradict the Acceptance Contract are detected
   (basic check: textual mention of a contradicted criterion) and pause
   the loop with a clear message.
5. The two subagents (`agents/implementation.md`, `agents/validation.md`)
   have prompts distinct from Generator/Validator — verifiable by diff.
6. `tests/smoke/sprint-4.test.sh` runs the full pipeline on a trivial
   project (Hello World + 1 tested function) end-to-end with external
   `timeout 600`; the Acceptance Contract passes.
7. **Craftsmanship gate:** agents share no context (per `patterns/ralph-loop.md`);
   no `conventions.md` Don'ts violated; Validation Agent rejects
   unstructured verdicts and re-asks itself for structure.

## Scope

- `agents/implementation.md` — runtime instance per `patterns/roles.md`
  (memory scope = `task`; writes `progress.md`, `contracts.md`; never
  writes `acceptance-contract.md`).
- `agents/validation.md` — runtime instance per `patterns/roles.md`
  (executes `verify-acceptance.sh`; emits structured JSON).
- Basic `skills/implement/SKILL.md` — Orchestrator-skill mode "runtime
  coordinator".
- `lib/ralph-loop/orchestrate.sh` — cycle loop, agent spawning,
  persistence trigger.
- `hooks/post-iteration.sh` — persistence + cycle counter (cycle count
  is read by Sprint-6 hard bounds).
- Sprint-contract detection: textual contradiction check against
  `acceptance-contract.md`.
- Templates `templates/progress.md`, `templates/contracts.md`.
- `tests/smoke/sprint-4.test.sh` (with external `timeout 600`).

## Anti-scope

- Hard bounds — Sprint 6.
- Full Model C / canonization — Sprint 5.
- Trigger-4 escalation logic beyond "pause and exit" — Sprint 6.
- Progressive disclosure / graph queries — Sprint 6.
- Inferential semantic-judge sensor — Sprint 5+.
- Recovery from Orchestrator failure mid-loop — basic crash leaves
  `progress.md` + `contracts.md` on disk; full resumption protocol
  later.

## Technical Decisions

- **Orchestrator-as-skill:** `skills/implement/SKILL.md` orchestrates by
  invoking the two subagents via the Task tool. No agent spawns another
  agent. R1 stays sidestepped. Trade-off: slightly heavier coordination
  in the skill prompt vs lighter subagents.
- **Sprint-contract format:** structured YAML inside `contracts.md`
  with `id`, `topic`, `decision`, `rationale`, `timestamp`,
  `agents_involved`. Trade-off: parser brittleness vs schema readability;
  schema is short enough to keep parsing simple.
- **Validation Agent rejects unstructured verdicts** and re-asks itself
  with a structured prompt. Trade-off: extra cycles vs. structured
  output as a hard contract (per `patterns/sensors.md`).
- **Implementation Agent always writes `progress.md`** even on failure.
  Trade-off: extra disk I/O vs. enabling recovery (Sprint 5 reads
  `progress.md` for canonization).
- **Sprint-contract contradiction detection is naive (textual mention).**
  Trade-off: false-positives possible; Sprint 5 refines after observing
  real consensus shapes.

## Applicable Patterns

- `roles.md` — Implementation and Validation Agents (runtime instances,
  not modes of Generator/Validator).
- `ralph-loop.md` — loop structure; deterministic vs agentic nodes;
  Acceptance Contract as the binding envelope.
- `phase-flow.md` — Phase 4 entry point.
- `sensors.md` — structured output from the Validation Agent;
  computational sensors via `verify-acceptance.sh`.

No new patterns introduced.

## Risks

- **R5 — no hard bounds yet.** Loop can run away. **Mitigation:** every
  Sprint-4 test runs under `timeout 600`; spec explicitly states this
  is mandatory. Sprint 6 ships real bounds.
- **Adversarial separation collapse.** If prompts drift toward
  similarity over time, self-evaluation bias returns. **Mitigation:**
  DoD #5 prompt-diff check; CI gate ships in Sprint 8.
- **Naive contradiction detection misses real conflicts.** **Mitigation:**
  spec explicit that v0.4.0 detects only textual contradictions; Sprint 6
  refines once we have observed consensus shapes from real loop runs.
- **R2 — query latency at scale (foreshadowed).** Sprint 4 uses the
  basic grep `/yoke:ask`. Loops with many queries may be slow on big
  canonical memories. **Mitigation:** measure in Sprint 4 testing;
  Sprint 6 ships subgraph queries if needed.

## Dependencies

- `.vibeflow/specs/yoke-v1-sprint-3.md`
