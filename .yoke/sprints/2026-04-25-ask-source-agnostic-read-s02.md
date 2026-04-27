# Sprint 02 of 06: `/yoke:ask` source-agnostic

> Migrated from: # Spec: `/yoke:ask` source-agnostic — Part 2 / Runtime agent contracts


> Generated via /vibeflow:gen-spec on 2026-04-25
> PRD: `.vibeflow/prds/ask-source-agnostic-read.md`

## Objective

Switch Generator, Validator, and Orchestrator from "consume canonical-memory
subgraph via `.yoke/query-traces/<slug>.md`" to "invoke `/yoke:ask` via the
Skill tool when canonical-memory context is needed", and replace the
"absence of trace entry is a bypass" rule with a declarative bypass discipline.

## Context

Today the trace acts as a once-per-cycle Orchestrator → Generator/Validator
handoff: Orchestrator consult mode reads canonical memory and surfaces a
subgraph to the trace; Generator and Validator read the trace at the start
of every cycle. With the trace gone (Part 1), each subagent calls
`/yoke:ask` directly and consumes the response in-conversation. The
Orchestrator's consult-mode role narrows from "surface and persist" to
"invoke and reason inline." Bypass detection becomes a declarative rule on
each subagent prompt rather than a scan over the trace file.

## Definition of Done

1. `agents/orchestrator.md` consult-mode section instructs the subagent to
   invoke `/yoke:ask` via the Skill tool and reason over the response
   in-conversation; no instructions to write `.yoke/query-traces/<slug>.md`
   or any equivalent file.
2. `agents/orchestrator.md` no longer asserts "any read that does not leave
   a trace entry is a bypass." Bypass discipline is restated declaratively:
   "Generator and Validator MUST invoke `/yoke:ask` for canonical-memory
   reads; direct filesystem reads of the registered memory are prohibited."
3. `agents/generator.md` and `agents/validator.md` no longer require reading
   `.yoke/query-traces/<slug>.md` at the start of every cycle. Each subagent
   prompt instructs invoking `/yoke:ask` via the Skill tool when canonical
   context is needed.
4. The three subagent YAML `description` fields no longer mention
   `.yoke/query-traces/<slug>.md` or "trace lands in …".
5. `agents/orchestrator.md`, `agents/generator.md`, and `agents/validator.md`
   `allowed-tools` lists include `Skill`; no `Write` access targets
   `.yoke/query-traces/`. Other tool grants (Read, Edit, Bash on the file
   ownerships each agent already has) are preserved.
6. The Orchestrator's monitor and canonize sections are not modified by
   this part — only consult, the bypass rule, the description, and
   allowed-tools.

## Scope

- Edit `agents/orchestrator.md`.
- Edit `agents/generator.md`.
- Edit `agents/validator.md`.

## Anti-scope

- Skill or lib changes (Part 1).
- Test updates (Part 3).
- Doctrine `.vibeflow/` updates (Part 4).
- File-ownership changes for `.yoke/contracts/<slug>.md`,
  `.yoke/runtime/progress.md`, etc.
- Any change to the Orchestrator's canonize-mode logic, the five-criterion
  filter, or the `propose-write.sh` wiring.
- Introducing a new file-based handoff to replace the trace.

## Technical Decisions

1. **Bypass discipline becomes declarative.** Stated as a rule in each
   subagent prompt; no automated detection in v0. Trade-off: weaker
   automated signal than the trace scan provided. Justification: PRD
   anti-scope explicitly defers replacement instrumentation; the rule is
   enforced at review and by `allowed-tools` envelope.
2. **Per-question vs per-cycle context delivery.** Generator and Validator
   query on demand via `/yoke:ask` instead of reading a cycle-start
   handoff. Trade-off: extra Skill-tool invocations during a cycle.
   Justification: avoids accumulating unused canonical context; matches
   PRD intent ("receives a query from any source").
3. **Orchestrator consult mode shape.** Invoke `/yoke:ask` and reason
   inline; no persisted artifact. Trade-off: nothing for other subagents
   to read offline. Justification: PRD open question 2 — checkpointing
   across resumed runs is a separate concern; do not re-introduce the
   trace as that mechanism.
4. **No new shared file.** Specifically, do not introduce a replacement
   like `.yoke/runtime/consult.md` or similar. The PRD forbids
   re-introducing the same problem under a different name.
5. **Explicit "do not read query-traces" line during transition.** Each
   subagent prompt includes one line stating that `.yoke/query-traces/`
   does not exist and must not be read or written. This guards against
   reflexive behavior during the transition window. The line may be
   removed in a future cleanup once the cohort is stable.

## Applicable Patterns

- `.vibeflow/patterns/roles.md` — write/read authority per runtime
  subagent; single-Skill-call discipline; no shared context between
  Generator and Validator.
- `.vibeflow/patterns/memory-model.md` — read-mediator role; consult-live
  access timing.

## Risks

- **R1 / Subagents reflexively try to read `.yoke/query-traces/<slug>.md`.**
  Mitigation: explicit negative instruction in each prompt (Decision 5).
- **R2 / Generator or Validator reasons without canonical grounding when
  it should have queried.** Mitigation: prompt-level instruction —
  "before relying on prior knowledge for X (where X = ratified policy,
  domain ownership, prior decision), invoke `/yoke:ask`."
- **R3 / Edit accidentally touches the Orchestrator's canonize or monitor
  sections.** Mitigation: scope each edit to the consult section, the
  bypass rule, the description, and allowed-tools; reviewer diffs the
  file by section.
- **R4 / Allowed-tools loses something the agent still needs.**
  Mitigation: enumerate the existing grants; only the trace-write
  privilege is removed; everything else is preserved.

## Dependencies

- `.vibeflow/specs/ask-source-agnostic-read-part-1.md`
