# PRD: Phase persona rebalance — split product, engineering, and senior-developer roles across `/yoke:discover`, `/yoke:tech-spec`, and the Generator subagent

> Generated via /vibeflow:discover on 2026-04-25

## Problem

Yoke's three role-bearing artifacts are leaking into each other:

- **`/yoke:discover`** and **`/yoke:tech-spec`** both declare their inline
  persona as "Generator persona: senior product engineer" (literally the
  same string). Their clarity-evaluation gates ask near-symmetric questions
  ("is the problem concrete? is the scope closable?" vs. "are use cases
  unambiguous? is v0 partitionable?"). The two phases feel like the same
  conversation twice rather than two distinct deliberations: one product,
  one engineering.
- **`/yoke:implement`** spawns the Generator subagent (`agents/generator.md`)
  whose persona is a single sentence — "Engineer focused on shipping" —
  with behavioral rules but no anchored mindset. Compared to
  `vibeflow:implement`'s "Coding Agent" role (explicit non-goals: no
  architectural decisions, no spec questioning, no scope creep, no
  while-I'm-here refactors), the Generator under-specifies its
  discipline. Senior-developer judgment is implied but not codified.

Concrete impact: discovery dialogues drift into technical solutioning;
tech-spec dialogues skip architectural challenges (frameworks,
integration shape, trade-offs); the Generator silently makes
architectural decisions inside the ralph loop instead of stopping and
escalating. The phases stop being adversarial in mindset.

## Target Audience

The maintainer of the Yoke plugin (you, `iurykrieger`) and any
contributor extending the spec-phase skills or the Generator subagent.
Indirect audience: every Yoke user whose `/yoke:discover →
/yoke:tech-spec → /yoke:implement` flow is downstream of these
personas.

## Proposed Solution

Three coordinated edits — one per file — to enforce role specialization
without changing Yoke's six-phase architecture, the ralph-loop runtime,
or the per-task working-memory layout.

1. **`skills/discover/SKILL.md` — pure Product Manager persona.**
   Replace the inline "senior product engineer" persona with a
   **Product Manager (CPO-style)** persona, ported in spirit from
   `vibeflow:discover`'s "experienced CPO/CTO conducting a discovery
   session". Strip every technical-instinct cue; keep only product
   judgment (real pain vs. nice-to-have, audience specificity,
   success-metric forcing, anti-scope aggressiveness, alternative
   proposals when the *problem framing* — not the *implementation* —
   seems wrong). Keep the existing Yoke-specific scaffolding intact:
   slug proposal + collision resolution, working-memory paths via
   `wm_*_path`, Trigger 1 approval menu, `/yoke:ask` as the only path
   to canonical memory, the open-questions detection block, the
   `Skill`-tool fallback. The dialogue rounds stay product-only:
   Round 1 (problem) → Round 2 (audience + success) → Round 3 (scope
   + anti-scope) → Round 4 optional consolidation → 5-round cap.

2. **`skills/tech-spec/SKILL.md` — pure Engineering / CTO persona.**
   Replace the shared "senior product engineer" persona with a
   **Senior Engineer / CTO persona** whose mandate is purely
   technical. The clarity-evaluation gate becomes an engineering gate:
   architecture viability against the project's stack, framework
   choice with trade-offs, integration-contract shape (API / data /
   message schemas), dependency-direction sanity, sprint
   partitionability into coherent value increments, per-task
   acceptance criteria that are binary and observable. Sprint
   partitioning into use-case tasks (Given/When/Then or
   input/process/output) with explicit acceptance criteria is already
   mandated in step 4 — this stays and is reinforced as the core of
   the engineering deliberation, not a side artifact. Keep all
   existing Yoke-specific scaffolding intact: PRD-must-be-approved
   precondition, `wm_tech_spec_path`, Trigger 2 approval menu, no
   shadow versioning, `/yoke:ask` for canonical-memory reads,
   `Skill`-tool fallback.

3. **`agents/generator.md` — Senior Developer persona with Coding-Agent
   discipline.** Replace the one-sentence persona with a
   **Senior Developer / Coding Agent** persona, ported in spirit from
   `vibeflow:implement`'s "Role: Coding Agent" block. Codify the
   discipline: receives the binding Acceptance Contract, implements
   it; does NOT make architectural decisions, does NOT question the
   spec's technical decisions, does NOT refactor outside scope, does
   NOT add features outside scope, does NOT change patterns the spec
   doesn't mention; on ambiguity STOPS and escalates via
   `.yoke/runtime/progress.md` so the Orchestrator can detect it
   (Trigger 4) — never silently proceeds. Keep every existing Yoke
   invariant unchanged: cycle-end persistence to
   `.yoke/runtime/progress.md`, structured reading of
   `verify-acceptance.sh` YAML, citation of the addressed
   Acceptance-Contract criterion, consensus-only writes to
   `.yoke/contracts/<slug>.md`, no canonical-memory reads/writes, no
   context-sharing with Validator, no Acceptance-Contract relaxation,
   no recursive subagent spawn. Do **not** import
   `vibeflow:implement`'s 7-phase orchestration (find spec → extract
   guardrails → load patterns → plan → implement → test →
   self-verify) — that orchestration is the ralph loop's job in Yoke,
   not the Generator's. Only the persona + discipline rules cross
   over.

## Success Criteria

Observable, decidable on inspection of the three files:

1. `skills/discover/SKILL.md`'s persona section names the role
   "Product Manager" (or CPO-equivalent) and contains zero
   architecture / framework / file-layout language. Every dialogue
   question targets product framing (problem, audience, success,
   scope, anti-scope).
2. `skills/tech-spec/SKILL.md`'s persona section names the role
   "Senior Engineer" or "CTO" (or equivalent), and the clarity-check
   block contains at least one explicit architecture / framework /
   integration-contract question. Sprint partitioning with use-case
   tasks and binary acceptance criteria remains mandated in the draft
   step.
3. `agents/generator.md`'s persona section names the role "Senior
   Developer" (or Coding-Agent equivalent) and lists, as explicit
   "Never" rules, at minimum: no architectural decisions, no
   questioning of approved upstream artifacts, no scope creep, no
   pattern invention beyond what the spec authorizes, stop-and-escalate
   on ambiguity. The 7-phase pipeline from `vibeflow:implement` is NOT
   present (the ralph loop owns orchestration).
4. The personas across the three files are mutually distinct on a
   diff: no string is repeated verbatim across two of them at the
   role-description level.
5. All existing Yoke-specific behavior survives: every `wm_*_path`
   call, every Trigger menu, every `/yoke:ask` constraint, every
   approval-menu fallback, every "Never" rule already in
   `agents/generator.md`. (Regression check: the existing smoke tests
   under `tests/smoke/` still pass; nothing in `lib/` or `hooks/`
   needs to change.)

## Scope v0

- Edit `skills/discover/SKILL.md` — replace persona + tighten
  dialogue questions to product-only. Keep all infrastructure intact.
- Edit `skills/tech-spec/SKILL.md` — replace persona + replace
  clarity-check questions with engineering questions (architecture,
  frameworks, integration contracts, trade-offs). Keep sprint /
  use-case / acceptance-criterion mandate intact and reinforce it.
- Edit `agents/generator.md` — replace one-sentence persona with a
  Senior-Developer block (role, must-do, must-not-do, stop-and-ask
  rule). Keep all existing Always / Never / Memory scope / Allowed
  tools / Restrictions sections intact.
- Update `docs/lineage.md` (or whichever file records the
  vibeflow→yoke port mapping) to reflect that
  `/yoke:discover`'s persona and dialogue derive from
  `vibeflow:discover`, `/yoke:tech-spec`'s engineering questions
  derive from gen-spec's PRD-validation-gate ethos, and
  `agents/generator.md`'s persona derives from
  `vibeflow:implement`'s Coding-Agent role.
- Update `.vibeflow/decisions.md` with one decision entry per
  persona, citing the rebalance and its rationale (so the canonical
  memory record stays consistent with the manifesto).

## Anti-scope

- **No structural / architectural changes.** No new skills, no
  removed skills, no new subagents, no removed subagents. Yoke's
  three runtime subagents (Generator, Validator, Orchestrator), the
  five human triggers, and the six phases all stay exactly as they
  are.
- **No ralph-loop redesign.** The 7-phase pipeline from
  `vibeflow:implement` is **not** ported into the Generator; only the
  persona / discipline rules cross over. The cycle-by-cycle parallel
  spawn in `skills/implement/SKILL.md` is untouched.
- **No template changes.** `templates/prd.md`,
  `templates/tech-spec.md`, `templates/progress.md`,
  `templates/contracts.md`, `templates/approval-menu.md` are not
  edited. The artifact shapes are stable.
- **No working-memory schema changes.** `wm_*_path` helpers,
  `.yoke/.current`, the per-category folders under `.yoke/`, and the
  query-trace contract are untouched.
- **No canonical-memory protocol changes.** Model C, the five-criteria
  filter, `/yoke:preserve`, and the Orchestrator's write authority all
  stay as-is.
- **No Validator / Orchestrator persona edits.** The user explicitly
  scoped the agent-persona work to the Generator. Validator and
  Orchestrator personas are not in this PRD.
- **No new tooling, hooks, or libraries.**

## Technical Context

What grounds this PRD in the current repo:

- The current "senior product engineer" persona string appears
  verbatim in both `skills/discover/SKILL.md` (line 30 area) and
  `skills/tech-spec/SKILL.md` (line 28 area). This is the literal
  duplication driving the symptom.
- The Generator's current persona at `agents/generator.md` line 26
  is one sentence; the rest of the file is behavioral rules, which
  partially substitute for a persona but do not substitute for the
  *mindset* anchor the user is after.
- `vibeflow:discover` (cached at
  `~/.claude/plugins/cache/vibeflow-marketplace/vibeflow/1.10.0/skills/discover/SKILL.md`)
  carries the CPO/CTO discovery persona and the round-by-round
  dialogue this PRD imports the *spirit* of. Yoke's `/yoke:discover`
  already follows the same dialogue shape; only the persona framing
  needs to shift to pure product.
- `vibeflow:gen-spec` (same cache location, `gen-spec/SKILL.md`)
  carries the PRD-validation-gate that surfaces engineering
  questions like "no conflict with `.vibeflow/`?" and "technically
  viable in current stack?". These questions, generalized
  ("framework choice with trade-offs?", "integration-contract
  shape?", "architecture viable in stack?"), become the basis for
  the new engineering clarity-check in `/yoke:tech-spec`.
- `vibeflow:implement` (same cache, `implement/SKILL.md`) defines
  the explicit "Role: Coding Agent" block. That role description and
  its non-goals are what `agents/generator.md` imports.
- **Architectural constraint, non-negotiable.** `/yoke:implement` is
  *not* a single-agent pipeline — it spawns three subagents in
  parallel each cycle. The 7-phase orchestration in
  `vibeflow:implement` is incompatible with this design and is
  explicitly out of scope; only the persona + discipline rules port
  across.
- **Manifesto alignment.** The rebalance reinforces, not violates,
  the manifesto's role separation: Discovery → product framing
  (Generator-as-PM at spec phase), Tech Spec → engineering decisions
  (Generator-as-CTO at spec phase), Implementation → senior-dev
  execution (Generator-as-Coding-Agent at runtime). All within the
  existing "skills deliberate; subagents adapt" guidance from
  `.vibeflow/index.md` and the v1.1.0 runtime-only-agents refactor.

## Open Questions

None. (Resolved 2026-04-25 — see § Decisions resolved.)

## Decisions resolved

1. **Depth of the `vibeflow:implement` → `agents/generator.md` port:
   persona + discipline only.** Import the "Coding Agent" role block,
   the must-do / must-not-do rules, and the stop-and-ask-on-ambiguity
   clause into `agents/generator.md`. Do **not** restructure each
   Generator cycle into a mini 7-phase pipeline. Cycle shape stays as
   today; the ralph loop continues to own orchestration.
2. **Persona naming: literal per skill.** Drop the umbrella "Generator
   persona" label inside the skills. Name each persona literally:
   `skills/discover/SKILL.md` → "Product Manager persona" (CPO-style);
   `skills/tech-spec/SKILL.md` → "Senior Engineer persona" (CTO-style);
   `agents/generator.md` → "Senior Developer persona" (Coding-Agent
   role). Each file's persona section is mutually disjoint on a diff.
3. **Decision-log granularity: three separate entries** in
   `.vibeflow/decisions.md`, one per refined component
   (`skills/discover/SKILL.md`, `skills/tech-spec/SKILL.md`,
   `agents/generator.md`). One refined component, one decision —
   manifesto convention.
4. **Lineage doc: append now.** Update `docs/lineage.md` in this
   change. If the file does not yet exist, create it with the
   per-skill mapping table seeded:
   `vibeflow:discover` → `skills/discover/SKILL.md` (persona,
   dialogue rounds); `vibeflow:gen-spec` → `skills/tech-spec/SKILL.md`
   (persona, engineering clarity-checks); `vibeflow:implement` →
   `agents/generator.md` (persona, Coding-Agent discipline). Sprint 8
   may extend the file but does not own creation.
