# Spec: runtime-only-agents — Part 3 (skill rewrites: implement + cleanup)

> Generated via /vibeflow:gen-spec on 2026-04-25 from
> `.vibeflow/prds/runtime-only-agents.md`. Part 3 of 6.

## Objective

Rewrite `/yoke:implement` to spawn the three runtime subagents in
parallel per cycle, retire the `/yoke:orchestrator` skill, and
reposition `/yoke:canonize` as a manual escape hatch.

## Context

v1.0.0's `/yoke:implement` spawns Implementation and Validation Agents
sequentially per cycle and treats canonization as a separate Phase-5
invocation via `/yoke:canonize`. The new model spawns Generator +
Validator + Orchestrator subagents concurrently per cycle; the
Orchestrator's final cycle invocation handles termination
canonization. The `/yoke:orchestrator` skill is collapsed — its three
modes have been redistributed (mediator → `/yoke:ask` skill from
Part 2; runtime-coordinator → `/yoke:implement` here; canonizer →
`agents/orchestrator.md` subagent's terminal mode).

This part embodies the *subagents adapt* half of the new
*Skills deliberate; subagents adapt* invariant, plus the
*Consult live; canonize on termination* canonization stance.

## Definition of Done

1. `skills/implement/SKILL.md` issues a single concurrent Task batch
   per cycle that spawns `agents/generator.md`, `agents/validator.md`,
   and `agents/orchestrator.md` (consult+monitor modes), each with
   disjoint inputs from working memory.
2. `skills/implement/SKILL.md` issues a final Orchestrator-only Task
   call at loop termination with an explicit canonize signal (e.g.,
   input parameter `mode=canonize` or equivalent).
3. `skills/orchestrator/SKILL.md` is deleted, OR reduced to a
   ≤5-line deprecation stub that points readers to
   `agents/orchestrator.md`.
4. `skills/canonize/SKILL.md` documents itself as a manual escape
   hatch: reads existing `.yoke/` artifacts, invokes
   `agents/orchestrator.md` in canonize mode, never auto-runs;
   `description` and `argument-hint` reflect this scope.
5. Loop semantics preserved end-to-end: hard bounds
   (`hooks/check-hard-bounds.sh`), contradiction check
   (`lib/ralph-loop/orchestrate.sh check-contradiction`), Trigger-4
   escalation (`lib/ralph-loop/escalate.sh`) all fire at the same
   logical boundaries as v1.0.
6. No mid-loop canonical-memory writes — verifiable by reading the
   implement skill flow: only the loop-termination Orchestrator call
   reaches `lib/canonical-memory/propose-write.sh`.
7. **Craftsmanship gate** — ralph-loop semantics from
   `.vibeflow/patterns/ralph-loop.md` (post-rewrite, Part 4) honored;
   `.vibeflow/conventions.md` Don'ts preserved (no infinite loops, no
   Acceptance Contract relaxation, no sensor output without
   correction instructions, no agent context-sharing).

## Scope

- Rewrite the cycle-loop section of `skills/implement/SKILL.md` to
  issue 3 concurrent Task calls per cycle. Document
  freshest-snapshot semantics: each subagent reads working-memory
  files at spawn time, emits its writes by end of turn, the next
  cycle reads what's there. Within-cycle file-write contracts are
  enforced by per-agent restrictions (already declared in
  `agents/*.md`).
- Add the loop-termination handoff: when the loop terminator fires
  (criteria pass, or hard bound, or Trigger-4 escalation), invoke
  the Orchestrator one last time with the canonize signal. Document
  the input shape.
- Delete `skills/orchestrator/SKILL.md`, or replace with a deprecation
  stub. Decide during implementation based on whether
  `/yoke:orchestrator` was advertised externally as a slash command
  (default: delete; v1.0 has no active users).
- Lightly edit `skills/canonize/SKILL.md` to clarify its escape-hatch
  role and update its `description` / `argument-hint` accordingly.
  The skill body remains a thin wrapper that invokes the Orchestrator
  subagent in canonize mode against an existing `.yoke/`.

## Anti-scope

- Cross-cycle pipelining (Generator on cycle N+1 while Validator on
  cycle N) — explicit non-goal; deferred.
- Mid-loop canonical-memory writes — explicit non-goal.
- Long-lived persistent subagent processes — Claude Code's Task tool
  is request/response.
- IPC between subagents — communication via files only.
- Hard-bound default changes — preserved as-is.
- `agents/*` (Part 1).
- Spec-phase / `/yoke:ask` skills (Part 2).
- Pattern docs, decisions — Part 4.
- Manifesto, version, CHANGELOG, diagram — Part 5.
- Smoke tests — Part 6.

## Technical Decisions

- **Concurrent Task batch = one assistant turn with N tool-use
  blocks.** Per Claude Code semantics, multiple Task calls in a
  single assistant message execute concurrently. The skill prompt
  must instruct the runtime to issue all three Task calls in one
  response per cycle.
- **Canonization signal via Task input, not a separate subagent.**
  The Orchestrator subagent's prompt branches on whether the input
  declares `mode=canonize`. Same subagent file, two contexts —
  symmetric with how `verify-acceptance.sh` is parameterized.
- **Stub vs. delete for `skills/orchestrator/`.** Default to outright
  delete. Leave a stub only if `/yoke:orchestrator` was advertised
  externally — confirm during implementation.
- **`/yoke:canonize` stays — but as escape hatch, not primary.** Auto
  canonization at loop termination is the primary path; the manual
  skill remains for re-runs after a failed auto-canonize or for
  re-evaluating an existing `.yoke/` directory after a model upgrade.
- **File-ownership invariants enforce concurrent-write safety.** Per
  `agents/*.md` restrictions: Generator writes
  `.yoke/progress.md` and (jointly) `.yoke/contracts.md`; Validator
  writes (jointly) `.yoke/contracts.md`; Orchestrator writes
  `.yoke/query-trace.md`. The "joint" `.yoke/contracts.md` is
  appended only on consensus events, which by definition occur after
  Validator's verdict — i.e., not concurrently within the same
  cycle's Task batch.

## Applicable Patterns

- `.vibeflow/patterns/ralph-loop.md` — loop structure, hard bounds,
  sprint contracts (rewritten in Part 4; this part's skill declares
  semantics consistent with the upcoming rewrite).
- `.vibeflow/patterns/roles.md` — runtime subagent contracts
  (rewritten in Part 4).
- `.vibeflow/patterns/model-c-governance.md` — termination-time write
  protocol; impact classification; per-class PR behavior.
- `.vibeflow/patterns/sensors.md` — structured sensor output;
  Validator emits structured JSON verdicts.
- `.vibeflow/patterns/human-triggers.md` — Trigger-4 schema for
  escalation.

## Risks

- **R-C1 — Concurrent file writes within a cycle.** If two
  subagents try to write the same file in the same Task batch, the
  later writer overwrites the earlier. Mitigation: per-agent
  file-ownership contracts (declared in `agents/*.md`, Part 1) make
  concurrent writes impossible by design — Generator owns
  `progress.md`, Orchestrator owns `query-trace.md`, and
  `contracts.md` is appended only on consensus (after Validator's
  verdict, never within the spawn batch).
- **R-C2 — Loop-termination canonization delays MERGE-READY return.**
  The Orchestrator's canonize phase fires after the loop terminator
  hits, possibly delaying the user's next action. Mitigation: keep
  the canonize phase short — Model C low-impact PRs auto-merge after
  CI; medium / high / regulatory PRs surface for human review without
  blocking. Document expected canonize-phase latency in CHANGELOG
  (Part 5).
- **R-C3 — `/yoke:orchestrator` deletion breaks installations
  relying on the slash command.** Mitigation: v1.0 has no active
  users; clean break is safe. Keep stub if uncertain.
- **R-C4 — Three concurrent Task calls may exceed model-side
  rate limits or token budgets.** Mitigation: cycle is bounded by
  hard bounds (5–8 cycles, timeout, budget); each Task call's input
  is the freshest snapshot of working memory (small, bounded files).
  No single cycle should approach platform limits.

## Dependencies

- `.vibeflow/specs/runtime-only-agents-part-1.md`
- `.vibeflow/specs/runtime-only-agents-part-2.md`
