# Spec: runtime-only-agents — Part 4 (decisions and patterns)

> Generated via /vibeflow:gen-spec on 2026-04-25 from
> `.vibeflow/prds/runtime-only-agents.md`. Part 4 of 6.

## Objective

Update `.vibeflow/decisions.md`, `.vibeflow/patterns/roles.md`,
`.vibeflow/patterns/ralph-loop.md`, and `.vibeflow/index.md` to record
the new architectural decisions and reflect the 3-runtime-subagent
topology.

## Context

The "Five subagents" decision (2026-04-24) and the PRD-v0 amendment
("Orchestrator is a skill") both need explicit supersession in the
decision log. The pattern docs that codify role/runtime authority and
ralph-loop cycle semantics need rewriting to match the new layout.
`.vibeflow/index.md`'s Structural Units section currently advertises
the 5-subagent layout — it must reflect the 3-subagent reality.

This part is purely documentation alignment — no code changes — but
it is load-bearing because every future `/vibeflow:gen-spec` and
`/vibeflow:implement` invocation reads these files for project
context.

## Definition of Done

1. `.vibeflow/decisions.md` has 4 new entries dated 2026-04-25, each
   in the standard "Decision / Context / Discarded alternatives"
   format used by existing entries:
   (a) supersedes "Five subagents (2026-04-24)" → "Three runtime
       subagents only";
   (b) reaffirms "Three agentified roles (2026-04-24)" with the new
       *instantiated only at runtime* clause;
   (c) declares the *Skills deliberate; subagents adapt* invariant;
   (d) declares the *Consult live; canonize on termination*
       canonization stance.
2. `.vibeflow/patterns/roles.md` describes 3 runtime subagents
   (Generator, Validator, Orchestrator). All references to
   "Implementation Agent" / "Validation Agent" as separate runtime
   instances are removed (they ARE the Generator/Validator now).
   Spec-phase Generator/Validator subagent instances are removed
   entirely. Read/write authorities preserved
   (Orchestrator-only canonical-memory writes, etc.).
3. `.vibeflow/patterns/ralph-loop.md` describes parallel-spawn cycle
   semantics: 3 concurrent Task calls per cycle (Generator,
   Validator, Orchestrator); termination canonization (final
   Orchestrator call signals canonize mode). Hard bounds,
   contradiction check, and Trigger-4 escalation contracts
   preserved.
4. `.vibeflow/index.md`'s `## Structural Units` section reflects the
   3-subagent topology and the *Skills deliberate; subagents adapt*
   principle. The Pattern Registry block is unchanged.
5. **Craftsmanship gate** — every new decision entry has a
   `Discarded alternatives` block (matches existing decision-log
   convention); pattern docs preserve their YAML frontmatter
   (`tags`, `confidence`); markdown lint clean per
   `.vibeflow/conventions.md`.
6. Cross-pattern audit: any other pattern doc that currently
   references the 5-subagent layout (e.g., `memory-model.md`,
   `plugin-structure.md`, `phase-flow.md`) is updated to match. If
   no other pattern doc requires changes, declare so in the
   implementation notes.

## Scope

- Append 4 entries to the **top** of `.vibeflow/decisions.md`
  (newest-first convention).
- Rewrite `.vibeflow/patterns/roles.md`: drop spec-phase
  Generator/Validator role descriptions; collapse Implementation
  Agent / Validation Agent into Generator / Validator runtime
  descriptions; refresh Orchestrator description to cover
  consult / monitor / canonize runtime modes.
- Rewrite `.vibeflow/patterns/ralph-loop.md`: replace sequential
  Implementation→Validation cycle with parallel-spawn 3-subagent
  cycle; add termination canonization step; keep hard-bound and
  Trigger-4 sections.
- Update `.vibeflow/index.md`'s `## Structural Units` section.
- Audit and update other pattern docs (`memory-model.md`,
  `plugin-structure.md`, `phase-flow.md`) if they reference the
  superseded layout. Within Part 4's scope.

## Anti-scope

- `yoke.md` manifesto — Part 5.
- `docs/architecture.md` — Part 5.
- `.claude-plugin/plugin.json` and `CHANGELOG.md` — Part 5.
- Smoke tests — Part 6.
- New pattern files — none. The new invariants live inside existing
  pattern docs (`roles.md` for *Skills deliberate; subagents adapt*;
  `ralph-loop.md` and `memory-model.md` for *Consult live; canonize
  on termination*).
- Pattern Registry restructure — the `<!-- vibeflow:patterns:start -->`
  block in `index.md` stays as-is; only the Structural Units prose
  changes.

## Technical Decisions

- **Newest-first decision log.** Append the 4 new entries at the
  top, matching the existing format
  (`### YYYY-MM-DD — <title>` / `**Decision:**` / `**Context:**` /
  `**Discarded alternatives:**`).
- **Pattern docs are rewritten in place.** No new filenames; no
  migration. Section anchors are preserved where possible to avoid
  breaking cross-references.
- **`<!-- vibeflow:auto:start/end -->` markers preserved.** Several
  pattern docs use these markers; rewrites stay inside the markers
  to keep `/vibeflow:analyze` re-runs idempotent.
- **No new pattern files.** Adding a doc per invariant would explode
  the registry; co-locating invariants in existing thematic docs
  matches current discipline.

## Applicable Patterns

- `.vibeflow/patterns/roles.md` — primary edit target.
- `.vibeflow/patterns/ralph-loop.md` — primary edit target.
- `.vibeflow/patterns/memory-model.md` — likely needs an update for
  the consult/canonize boundary; in scope per DoD #6.
- `.vibeflow/patterns/plugin-structure.md` — likely lists the
  `agents/` 5-file layout; in scope per DoD #6.
- `.vibeflow/patterns/phase-flow.md` — references Orchestrator
  responsibilities across phases; in scope per DoD #6.

## Risks

- **R-D1 — Pattern doc rewrites invalidate cross-references.** Skill
  files, agent files, and other pattern docs cross-link to specific
  sections via anchors. Mitigation: preserve top-level section
  headers (`## What`, `## Where`, `## The Pattern`, `## Rules`,
  `## Anti-patterns`); any anchor change triggers a grep audit
  across `.vibeflow/`, `agents/`, `skills/`, and `docs/`.
- **R-D2 — Other pattern docs may reference the old topology and
  silently survive the rewrite.** Mitigation: DoD #6 mandates a
  cross-pattern audit; the implementation notes must enumerate which
  pattern docs were touched and which were verified clean.
- **R-D3 — Decision-log format drift.** New entries deviating from
  the existing `Decision / Context / Discarded alternatives` shape
  break tooling that parses the log. Mitigation: copy the shape from
  any of the 2026-04-24 entries verbatim.
- **R-D4 — Budget creep.** This part may touch up to 7 files
  (`decisions.md`, `index.md`, `roles.md`, `ralph-loop.md`,
  `memory-model.md`, `plugin-structure.md`, `phase-flow.md`),
  exceeding the ≤4 budget. Mitigation: documentation-only updates
  carry lower change-risk than code; declare the over-budget reason
  in the audit.

## Dependencies

- `.vibeflow/specs/runtime-only-agents-part-1.md`
- `.vibeflow/specs/runtime-only-agents-part-2.md`
- `.vibeflow/specs/runtime-only-agents-part-3.md`
