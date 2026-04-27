# Spec: runtime-only-agents — Part 1 (agents/ reshape)

> Generated via /vibeflow:gen-spec on 2026-04-25 from
> `.vibeflow/prds/runtime-only-agents.md`. Part 1 of 6.

## Objective

Reshape `agents/` from 5 subagent files (the v1.0 "Five subagents"
layout) to 3 runtime-only subagent files: `generator.md`, `validator.md`,
`orchestrator.md`.

## Context

`agents/` today materializes the superseded 2026-04-24 "Five subagents"
decision — separate spec-phase (`generator.md`, `validator.md`) and
runtime (`implementation.md`, `validation.md`) instances, plus an
Orchestrator demoted to a skill via the PRD-v0 amendment. The new model
keeps adversarial Generator/Validator separation **only at runtime** and
restores the Orchestrator to a proper subagent. Spec-phase subagents are
deleted; their personas move into skills (Part 2).

This is the foundational change — Parts 2, 3, 4, 5, 6 all reference the
new agent files, so this part lands first.

## Definition of Done

1. `agents/` contains exactly 3 files: `generator.md`, `validator.md`,
   `orchestrator.md`. No `implementation.md`, no `validation.md`.
2. `agents/generator.md` (renamed from `implementation.md`) preserves
   runtime-instance behaviors — writes `.yoke/progress.md` every cycle,
   co-writes `.yoke/contracts.md` on consensus, never modifies upstream
   `.yoke/{prd,tech-spec,acceptance-contract}.md`, never writes canonical
   memory — and drops all "Distinct from Generator" disclaimers.
3. `agents/validator.md` (renamed from `validation.md`) preserves
   runtime-instance behaviors — runs `hooks/verify-acceptance.sh` every
   cycle, emits structured JSON verdicts (`criterion`, `status`,
   `location`, `fix_instruction`, `sensor`, `evidence`), co-writes
   `.yoke/contracts.md`, never patches code, never writes canonical
   memory — and drops all "Distinct from Validator subagent"
   disclaimers.
4. `agents/orchestrator.md` is new and declares three runtime modes:
   **consult** (read canonical memory via
   `lib/canonical-memory/query.sh` during cycles, append every query to
   `.yoke/query-trace.md`), **monitor** (detect Generator↔Validator
   divergence, escalate via `lib/ralph-loop/escalate.sh`), and
   **canonize** (at loop termination, apply five-criteria filter,
   classify Model C impact, propose writes via
   `lib/canonical-memory/propose-write.sh`).
5. `agents/orchestrator.md` frontmatter declares it the **sole writer
   of canonical memory** under Model C.
6. **Craftsmanship gate** — all three files comply with
   `.vibeflow/conventions.md` Don'ts: no agent reads canonical memory
   directly except Orchestrator (consult mode); no agent writes
   canonical memory except Orchestrator (canonize mode); structured
   sensor output requirement preserved; no agent shares context with
   another at runtime (communication via files only).

## Scope

- `git rm agents/generator.md` (removes the spec-phase variant).
- `git rm agents/validator.md` (removes the spec-phase variant).
- `git mv agents/implementation.md agents/generator.md`; edit content
  to drop disclaimers and clean up persona/lineage references.
- `git mv agents/validation.md agents/validator.md`; same cleanup.
- Create `agents/orchestrator.md` from scratch with the three-mode
  prompt.

## Anti-scope

- Skill rewrites — Parts 2 and 3.
- `.vibeflow/decisions.md` and pattern doc updates — Part 4.
- `yoke.md` manifesto and `docs/architecture.md` — Part 5.
- Smoke test updates — Part 6.
- No new tools or memory scopes added to any agent.
- No changes to existing template files (`templates/progress.md`,
  `templates/contracts.md` stay as-is).
- No changes to `lib/ralph-loop/*.sh` or `lib/canonical-memory/*.sh`
  scripts (the orchestrator subagent calls them; it does not modify
  them here).

## Technical Decisions

- **Use `git mv` for renames** (preserves history) — not delete-and-recreate.
  Rationale: `git blame` continues to work on the renamed runtime
  agents; archaeology of past Implementation/Validation Agent decisions
  remains traceable.
- **Three Orchestrator modes are runtime-only.** The mediator-mode
  responsibility (servicing `/yoke:ask` queries from spec phases) moves
  into the `/yoke:ask` skill itself (Part 2). The Orchestrator subagent
  consults canonical memory during the runtime loop, not during
  Phases 1–3.
- **Orchestrator frontmatter `tools` list**: `Read, Write, Edit, Grep,
  Glob, Bash` (matches the runtime agents — needs Bash for
  `lib/canonical-memory/*.sh` and `lib/ralph-loop/escalate.sh`).
- **Canonize-mode signal via Task input.** The skill (Part 3) signals
  canonization via an input parameter (e.g., `mode=canonize`). Same
  subagent file, two contexts — symmetric with how
  `verify-acceptance.sh` is parameterized rather than maintaining two
  scripts.
- **Lineage notes preserved.** The Implementation/Validation Agents'
  Bedrock + ralph-loop lineage stays in the renamed files (now
  Generator/Validator). The Orchestrator subagent's lineage credits
  Bedrock for canonical-memory primitives.

## Applicable Patterns

- `.vibeflow/patterns/roles.md` — authoritative read/write authority
  contract (rewritten in Part 4 to match the new layout; this part's
  agent files declare authorities consistent with the upcoming
  rewrite).
- `.vibeflow/patterns/memory-model.md` — working vs. canonical memory
  boundary; Orchestrator-only canonical-memory write authority.
- `.vibeflow/patterns/model-c-governance.md` — impact classification
  and per-class write protocol; Orchestrator subagent honors all
  classes (low / medium / high / regulatory).
- `.vibeflow/patterns/ralph-loop.md` — runtime cycle structure;
  Generator and Validator are the runtime instances referenced.

## Risks

- **R-A1 — Rename without history preservation.** Using delete+create
  instead of `git mv` would lose `git blame` continuity. Mitigation:
  enforce `git mv` in the implementation; verify via
  `git log --follow agents/generator.md` after the rename.
- **R-A2 — Stale references in skill files until Part 3 lands.**
  `skills/implement/SKILL.md` and `skills/orchestrator/SKILL.md`
  reference `agents/implementation.md` and `agents/validation.md`. After
  Part 1 lands and before Part 3 lands, those skill references are
  broken. Mitigation: Part 3 declares Part 1 as a dependency; merge
  order Part 1 → Part 2 → Part 3 keeps each commit shippable, but the
  intermediate state between Parts 1 and 3 is not exercisable for
  `/yoke:implement` — document this in the merge commit.
- **R-A3 — Orchestrator subagent prompt drift.** Splitting the
  three-mode behavior across one prompt risks the modes contaminating
  each other (consult-mode behavior leaking into canonize-mode).
  Mitigation: the prompt declares the active mode explicitly and
  branches at the top; persona blocks are mode-scoped.

## Dependencies

None — this part is foundational.
