# Spec: runtime-only-agents — Part 2 (skill rewrites: spec phases + ask)

> Generated via /vibeflow:gen-spec on 2026-04-25 from
> `.vibeflow/prds/runtime-only-agents.md`. Part 2 of 6.

## Objective

Rewrite the four pre-runtime skills (`/yoke:discover`, `/yoke:tech-spec`,
`/yoke:acceptance-contract`, `/yoke:ask`) to drop subagent spawning
and embed persona + behavioral rules inline.

## Context

v1.0.0's spec-phase skills route dialogue through Task-tool subagent
spawns (`agents/generator.md`, `agents/validator.md`), which fragments
multi-round dialogue, complicates Trigger 1/2/3 surfacing, and adds no
rigor over a well-prompted skill. With the spec-phase subagents
deleted in Part 1, these skills must drive their dialogues directly.
`/yoke:ask` similarly currently invokes the Orchestrator skill in
mediator mode — with Orchestrator promoted to a runtime subagent, it
becomes a thin direct-call skill.

This part embodies the *skills deliberate* half of the new
*Skills deliberate; subagents adapt* invariant.

## Definition of Done

1. `skills/discover/SKILL.md`, `skills/tech-spec/SKILL.md`, and
   `skills/acceptance-contract/SKILL.md` each have an `allowed-tools`
   that does NOT include `Task`, and embed the relevant persona +
   dialogue rules inline (no `Spawn agents/...` step).
2. The three spec-phase skills preserve every Yoke-specific framework
   element they currently surface: Trigger 1/2/3 prompts printed
   verbatim, `.yoke/{prd,tech-spec,acceptance-contract}.md` artifact
   paths, `/yoke:ask` invocation for canonical-memory reads, and (for
   `/yoke:acceptance-contract`) sensor discovery via
   `lib/sensors/discover-from-claude-md.sh`.
3. `skills/ask/SKILL.md` calls `lib/canonical-memory/query.sh`
   directly, appends each query to `.yoke/query-trace.md`, and its
   `allowed-tools` does NOT include `Task`.
4. The four skills' structural shape mirrors Vibeflow's
   `discover`/`gen-spec` cached at
   `/Users/iury.krieger/.claude/plugins/cache/vibeflow-marketplace/vibeflow/1.10.0/skills/`
   — adopt the persona + dialogue rounds + rules layout, while
   preserving Yoke's artifact contracts and gating language.
5. **Craftsmanship gate** — every skill prompt complies with
   `.vibeflow/conventions.md` Don'ts: no direct canonical-memory reads
   outside `/yoke:ask`; structured sensor output requirements
   preserved; no skill silently advances past an unmet trigger; no
   skill produces an artifact without challenging at least one point
   (preserved from current Vibeflow `discover` discipline).

## Scope

- Rewrite `skills/discover/SKILL.md`. Drop the "Invoke the Generator
  subagent" section. Embed senior product engineer persona + clarity
  fast-track gate + 1–5 round dialogue + Trigger-1 schema inline.
  Preserve idempotency handling (`prd-v2.md`, abort) and output
  contract (`Status: approved`, `Approved by`, `Approved at`).
- Rewrite `skills/tech-spec/SKILL.md`. Same pattern — embed persona
  for sprint/use-case Tech Spec drafting; preserve Trigger-2 schema;
  preserve sprint partitioning rules from current behavior.
- Rewrite `skills/acceptance-contract/SKILL.md`. Drop the "Invoke the
  Validator subagent" section. Embed senior QA / test engineer
  persona inline. Preserve sensor-discovery step (invokes
  `lib/sensors/discover-from-claude-md.sh`), BDD scenario coverage
  rule (every Tech-Spec task → ≥1 scenario), Trigger-3 binding
  statement printed verbatim.
- Rewrite `skills/ask/SKILL.md` as a thin skill: invoke
  `lib/canonical-memory/query.sh` directly, append the query / result
  count / invoker to `.yoke/query-trace.md`, return matching entries.
  Drop any reference to the Orchestrator skill / mediator mode.

## Anti-scope

- `skills/implement/SKILL.md`, `skills/orchestrator/SKILL.md`,
  `skills/canonize/SKILL.md` — Part 3.
- `agents/*` — Part 1 (already landed).
- `templates/*` — no changes; the artifact templates stay as-is.
- Pattern docs and decisions — Part 4.
- Manifesto, version, CHANGELOG, diagram — Part 5.
- Smoke tests — Part 6.
- No changes to `lib/canonical-memory/query.sh` or
  `lib/sensors/discover-from-claude-md.sh` — these scripts are called
  as-is.

## Technical Decisions

- **Inline personas, not external prompt files.** Embed persona text
  directly in `SKILL.md`. Keeps the skill self-contained, avoids a
  second read-and-parse step, and matches Vibeflow's pattern.
- **`/yoke:ask` writes its own trace.** No mediator-subagent
  middleman; the skill writes to `.yoke/query-trace.md` directly.
  Bypass detection still works: any caller that skips `/yoke:ask` and
  calls `query.sh` directly leaves no trace, which is the bypass
  signal.
- **Reference upstream Vibeflow skills as the structural template.**
  Read the cached Vibeflow `discover` and `gen-spec` SKILL.md files
  (path in DoD #4); mirror their shape (problem dialogue → quick
  round / full round → artifact draft → save) while preserving
  Yoke's artifact contracts.
- **Persona depth: rules + format, no bios.** Adopt Vibeflow's lean
  persona style (always / never lists, behavioral rules) and drop
  the bio paragraphs that currently bloat the v1.0
  `agents/generator.md` and `agents/validator.md` prompts.

## Applicable Patterns

- `.vibeflow/patterns/phase-flow.md` — Phases 1–3 boundaries and
  Triggers.
- `.vibeflow/patterns/human-triggers.md` — Trigger 1/2/3 schemas; the
  Acceptance Contract binding statement.
- `.vibeflow/patterns/acceptance-contract.md` — Acceptance Contract
  artifact shape, BDD scenario coverage, sensor declaration.
- `.vibeflow/patterns/sensors.md` — sensor discovery + structured
  output.
- `.vibeflow/patterns/roles.md` — read/write authorities (rewritten
  in Part 4; this part's skills declare authorities consistent with
  the upcoming rewrite).
- `.vibeflow/patterns/memory-model.md` — `/yoke:ask` is the only
  canonical-memory read surface from Phases 1–3.

## Risks

- **R-B1 — Inline persona prompts bloat skill files.** Mitigation:
  follow Vibeflow's lean style; cap each skill's persona block to
  rules + format. If a skill exceeds ~400 lines, audit for redundant
  prose and trim.
- **R-B2 — Bypass-detection contract weakens without a mediator
  subagent.** Mitigation: document the new `/yoke:ask`-writes-trace
  contract in `.vibeflow/patterns/memory-model.md` (Part 4) and
  `agents/orchestrator.md` (already in Part 1). The contract: every
  legitimate canonical-memory read writes a trace entry; missing
  trace entries are bypass signals.
- **R-B3 — Multi-round dialogue inside a skill requires persona
  consistency across many turns.** Mitigation: Vibeflow's `discover`
  skill works this way today and is the reference template; drift is
  bounded by re-reading the SKILL.md each turn.
- **R-B4 — `/yoke:ask` gives every caller direct primitive access.**
  Mitigation: the primitive (`query.sh`) is read-only; no write paths
  are exposed.

## Dependencies

- `.vibeflow/specs/runtime-only-agents-part-1.md`
