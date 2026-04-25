# Spec: Yoke v1 — Sprint 2 — Discovery + Tech Spec (Phases 1-2)

> Generated via /vibeflow:gen-spec on 2026-04-24
> PRD: `.vibeflow/prds/yoke-v1.md`
> Plugin version target: 0.2.0

## Objective

Ship a working `idea → PRD → Tech Spec` pipeline. The Generator subagent
exists; `/yoke:discover` and `/yoke:tech-spec` produce versioned,
human-approved artifacts in `.yoke/`. Minimal `/yoke:ask` (text grep)
supports Generator queries against canonical memory.

## Context

Sprint 1 shipped the scaffolding. Sprint 2 implements the
binding-spec pillar's first two phases (manifesto §11). Heavily
inspired by `/vibeflow:discover` and `/vibeflow:gen-spec` — Yoke's
versions adapt to the manifesto's specific PRD shape (product
invariants, business context, constraints, risks) and Tech Spec shape
(sprints with use-case tasks and per-task acceptance criteria).

## Definition of Done

1. `/yoke:discover "<idea>"` produces a valid `.yoke/prd.md` matching
   `templates/prd.md` (invariants, business context, constraints, risks,
   open questions).
2. The Generator asks at least one clarifying question if the idea is
   ambiguous; the command does not return until the human approves
   explicitly (Trigger 1 shape).
3. `/yoke:tech-spec` (only after `prd.md` is approved) produces
   `.yoke/tech-spec.md` with ≥1 sprint, ≥1 task, an explicit acceptance
   criterion per task; aborts with a clear message if PRD is missing or
   unapproved.
4. `/yoke:ask "<term>"` returns text-matched canonical-memory entries
   (or a clear empty-state message); never loads full memory in one shot.
5. The Generator subagent is distinct from any future Implementation
   Agent — verifiable by prompt diff.
6. `tests/smoke/sprint-2.test.sh` exercises
   `/yoke:bootstrap → /yoke:discover → /yoke:tech-spec` end-to-end with a
   mocked idea and pre-recorded approval, in a clean test repo.
7. **Craftsmanship gate:** the Generator never reads canonical memory
   directly — every read goes through `/yoke:ask` (verifiable by static
   inspection of `agents/generator.md`); no `conventions.md` Don'ts
   violated.

## Scope

- `agents/generator.md` — full subagent definition: persona, behaviors,
  memory scope = `project`, allowed tools, restrictions per
  `patterns/roles.md`.
- Real `skills/discover/SKILL.md`.
- Real `skills/tech-spec/SKILL.md`.
- Basic `skills/ask/SKILL.md` + `lib/canonical-memory/query.sh` — text
  grep over the canonical-memory repo, no graph or progressive
  disclosure yet.
- Templates `templates/prd.md` and `templates/tech-spec.md`.
- `tests/smoke/sprint-2.test.sh`.

## Anti-scope

- Validator subagent or Acceptance Contract — Sprint 3.
- Progressive disclosure / graph queries — Sprint 6.
- Implementation Agent / runtime / sensors — Sprints 3–4.
- Canonical-memory writes — Sprint 5.
- Production-grade `/yoke:ask` performance — Sprint 6.

## Technical Decisions

- **Upstream source for Generator skills:** `skills/discover/SKILL.md`
  and `skills/tech-spec/SKILL.md` are forked from
  <https://github.com/pe-menezes/vibeflow> (specifically the upstream
  `discover` and `gen-spec` skills). Fork is one-time at the start of
  Sprint 2; Yoke evolves them autonomously (per
  `decisions.md` — "Embed upstream skills as a single fork at creation
  time"). Adaptation work: rename to `/yoke:*` namespace, switch
  templates to the manifesto's PRD and Tech Spec shapes (invariants /
  context / constraints / risks for PRD; sprints with use-case tasks
  and per-task acceptance criteria for Tech Spec), wire the Generator
  subagent in as the LLM driver, and route reads through `/yoke:ask`
  (no direct canonical-memory access). Lineage recorded per-skill
  in `docs/lineage.md` at Sprint 8.
- **Generator pauses for explicit approval** at the end of each artifact
  (Trigger 1 / Trigger 2 per `patterns/human-triggers.md`). No automatic
  advancement.
- **Idempotency:** re-running `/yoke:discover` on an existing `prd.md`
  offers overwrite or `prd-v2.md` fallback (per implementation plan
  Task 2.2). Same for `/yoke:tech-spec`.
- **`/yoke:ask` empty-state UX:** when the canonical-memory repo is
  empty, return "no entries indexed yet — see `docs/canonical-memory-setup.md`
  to populate the substrate", not an error. Trade-off: hides a real
  warning that bootstrap content is missing (PRD Open Question 9), but
  preserves a usable Sprint-2 demo.
- **No grep beyond the canonical-memory repo.** `/yoke:ask` does not
  index `.yoke/` — that's working memory, not doctrine.

## Applicable Patterns

- `roles.md` — Generator definition; `## Implementation Mapping` lists
  exact tools and memory scope.
- `phase-flow.md` — Phases 1 and 2 (mapping to slash commands).
- `memory-model.md` — working-memory file ownership (`prd.md` and
  `tech-spec.md` are Generator-write).
- `human-triggers.md` — Triggers 1 and 2 (per-trigger schemas).

No new patterns introduced.

## Risks

- **PRD Open Question 9 — empty canonical memory.** Generator
  produces useful PRDs even with empty memory, but it never gets to use
  the "applicable templates" path. **Mitigation:** Sprint-2 docs note
  the limitation; Sprint-5 enables real canonization; Sprint-8 may seed
  starter content for the example.
- **Approval-prompt UX.** Generator's pause-for-approval message must
  be unmistakable. **Mitigation:** one external reviewer tests the
  prompt before DoD; modification rate measurement comes online in
  Sprint 6.
- **Prompt-diff drift.** As Sprint 4's Implementation Agent ships, the
  diff requirement (DoD #5) re-applies. **Mitigation:** a CI check
  comparing prompts ships in Sprint 8 (CI gate).

## Dependencies

- `.vibeflow/specs/yoke-v1-sprint-1.md`
