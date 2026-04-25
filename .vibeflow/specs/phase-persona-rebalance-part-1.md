# Spec: phase-persona-rebalance — Part 1 of 2 (Spec-phase persona split)

> Generated via /vibeflow:gen-spec on 2026-04-25
> Source PRD: `.vibeflow/prds/phase-persona-rebalance.md`
> Part 1 of 2 — runs first; Part 2 depends on this part.

## Objective

Split the shared "Generator persona: senior product engineer" inline
prompt across `skills/discover/SKILL.md` and `skills/tech-spec/SKILL.md`
into two literal, mutually disjoint personas — a **Product Manager
persona** in `/yoke:discover` and a **Senior Engineer / CTO persona**
in `/yoke:tech-spec` — and document the rebalance in
`.vibeflow/decisions.md` and `docs/lineage.md`.

## Context

Today both `skills/discover/SKILL.md` (line 30 area) and
`skills/tech-spec/SKILL.md` (line 28 area) declare their inline
persona as "Generator persona: senior product engineer with strong
… instinct" — the literal string overlaps. Their clarity-check
gates ask near-symmetric questions (problem/audience/scope vs.
use-cases/constraints/sprint-partition) that, in practice, blur the
distinct deliberations Phase 1 and Phase 2 are supposed to drive:
Phase 1 is product framing (real pain vs. nice-to-have, audience
specificity, success-metric forcing, anti-scope aggressiveness);
Phase 2 is engineering deliberation (architecture viability,
framework choice, integration-contract shape, dependency direction,
sprint partitionability with binary acceptance criteria).

This part lands the spec-phase persona split. Part 2 lands the
runtime Generator subagent persona refinement; the two parts are
independently auditable and can be reviewed as separate PRs.

## Definition of Done

1. **Discover persona is literal Product Manager.**
   `skills/discover/SKILL.md`'s `## Your role` section is renamed and
   rewritten so its first line names the persona literally as
   "Product Manager persona" (or "CPO persona" — equivalent). The
   umbrella "Generator persona" label is removed from this skill.
2. **Discover dialogue is product-only.** Every clarity-evaluation
   check and every Round 1–4 question in `skills/discover/SKILL.md`
   targets product framing (problem / audience / success metric /
   scope / anti-scope / common scenario). The diff contains zero
   occurrences of "architecture", "framework", "stack", "file
   layout", "integration contract", "dependency direction" inside
   the persona or dialogue sections (canonical-memory / `/yoke:ask`
   references and pre-existing scaffolding text don't count).
3. **Tech-spec persona is literal Senior Engineer / CTO.**
   `skills/tech-spec/SKILL.md`'s `## Your role` section is renamed
   and rewritten so its first line names the persona literally as
   "Senior Engineer persona" or "CTO persona" — purely technical.
   The umbrella "Generator persona" label is removed from this
   skill.
4. **Tech-spec clarity check is engineering-shaped.** The clarity-
   evaluation block in step 3 of `skills/tech-spec/SKILL.md`
   contains exactly three engineering questions, each binary and
   decidable, drawn from this set: architecture viability against
   the project stack named in `.vibeflow/index.md`; framework /
   library choice with explicit trade-offs; integration-contract
   shape (API / data model / message schema) named per task;
   dependency direction sanity (no cycles); sprint partitionability
   into coherent value increments; per-task binary acceptance
   criteria. The product-shaped check trio (use-cases / constraints /
   sprint-partition) is replaced, not appended.
5. **Sprint + use-case-task + binary-acceptance-criterion mandate
   survives.** Step 4 of `skills/tech-spec/SKILL.md` continues to
   require: ≥ 1 sprint with delivery objective, ≥ 1 task per sprint
   described as a use case (Given/When/Then or
   input/process/output), explicit acceptance criterion per task
   that is binary and observable, plus contracts/interfaces and
   dependencies. Regression: any line removed from step 4 must be
   re-added or have an explicit replacement; the step's mandate
   strengthens, never weakens.
6. **Decision log + lineage are updated.**
   `.vibeflow/decisions.md` carries **two** new decision entries
   dated `2026-04-25`, one per refined skill, each in the existing
   format (`### YYYY-MM-DD — <title>`, `**Decision:**`,
   `**Context:**`, `**Discarded alternatives:**`). `docs/lineage.md`
   exists (created if absent) with at least the rows
   `vibeflow:discover` → `skills/discover/SKILL.md` (persona +
   dialogue-round shape) and `vibeflow:gen-spec` →
   `skills/tech-spec/SKILL.md` (persona + engineering clarity-
   check ethos).
7. **Craftsmanship — no scaffolding regression.** Every `wm_*_path`
   call, every Trigger menu invocation, every `Skill`-tool
   availability fallback, every `/yoke:ask`-only canonical-memory
   constraint, every entry in each skill's `## Anti-patterns`
   section, every `## Pre-conditions` and `## Output contract` line,
   and every `## See also` reference is preserved verbatim from the
   pre-edit version. The diff for each skill is bounded to: the
   `## Your role` section and the clarity-evaluation block (step 2
   in discover, step 3 in tech-spec); no other line moves or
   changes. Verified by `git diff --stat skills/discover/SKILL.md
   skills/tech-spec/SKILL.md` showing only those line ranges
   touched.

## Scope

- Edit `skills/discover/SKILL.md`:
  - Replace `## Your role (Generator persona, inline)` with
    `## Your role (Product Manager persona, inline)`.
  - Rewrite the persona body to describe a CPO-style product
    manager: shipped real product, knows real pain vs. wishlist,
    challenges audience specificity, forces success metrics, cuts
    scope. Keep the existing tone clause ("direct, constructive,
    opinionated; criticize the idea, not the person").
  - Confirm the existing Round 1–4 questions and 5-round cap are
    product-only (no architectural language).
- Edit `skills/tech-spec/SKILL.md`:
  - Replace `## Your role (Generator persona, inline)` with
    `## Your role (Senior Engineer persona, inline)` (or
    `## Your role (CTO persona, inline)` — pick one and use it).
  - Rewrite the persona body to describe a senior engineer / CTO:
    challenges architecture viability, forces framework decisions
    with trade-offs, insists on binary observable acceptance
    criteria, partitions delivery into coherent sprints with use-
    case tasks, refuses vague task descriptions.
  - Replace the three product-shaped clarity-evaluation checks
    (use-cases unambiguous? / constraints documented? /
    sprint-partitionable?) with three engineering-shaped checks
    drawn from the DoD #4 list.
  - Reinforce step 4's sprint + use-case-task + binary-acceptance-
    criterion mandate by tightening any soft language already
    there ("≥ 1 sprint" stays as ≥ 1; the language around binary/
    observable criteria moves to the top of the step's bullet
    list).
- Update `.vibeflow/decisions.md` with two entries dated
  `2026-04-25`:
  - "Discover persona = Product Manager" — title, decision,
    context (this PRD's symptom), discarded alternatives (kept
    umbrella "Generator persona"; named "Product Engineer").
  - "Tech-spec persona = Senior Engineer / CTO" — title, decision,
    context, discarded alternatives.
- Create or update `docs/lineage.md`. If the file does not exist
  (likely, since Sprint 8 hasn't landed it yet), create it with a
  short header explaining its purpose ("Yoke skills derived from
  Vibeflow / Bedrock — lineage table") and a markdown table with
  columns `Yoke component | Upstream source | What was ported`
  seeded with the two rows from DoD #6.

## Anti-scope

- **No edits to `agents/generator.md`.** That's Part 2.
- **No edits to other skill files** (`acceptance-contract`,
  `implement`, `bootstrap`, `status`, `ask`, `preserve`,
  `drift-sense`, `compress`, `teach`, `memory`,
  `confluence-to-markdown`, `gdoc-to-markdown`).
- **No template changes.** `templates/prd.md`,
  `templates/tech-spec.md`, `templates/approval-menu.md`,
  `templates/progress.md`, `templates/contracts.md`,
  `templates/canonical-entry-frontmatter.yaml` stay untouched.
- **No `lib/` or `hooks/` changes.** Working-memory helpers,
  ralph-loop scripts, sensors are out of scope.
- **No working-memory schema changes.** `wm_*_path`, `.yoke/.current`,
  per-category folders, query-trace contract are untouched.
- **No new patterns.** `roles.md`, `phase-flow.md`,
  `human-triggers.md` are read-only inputs to this work.
- **No `.vibeflow/index.md` edits.** The Pattern Registry stays as-
  is.
- **No port of Vibeflow's PRD-validation 5-check gate verbatim** —
  only the *ethos* (engineering questions) crosses over; the gate
  shape stays as Yoke's 3-check fast-track for consistency with
  `skills/discover/SKILL.md`'s structure.
- **No `Task` tool usage by either skill** — both stay skill-only,
  no subagent spawn at spec phase. This is invariant
  `roles.md`/Rules ("Spec-phase skills do not spawn subagents.
  Their `allowed-tools` must not include `Task`.").

## Technical Decisions

### Decision 1 — Persona naming: literal per skill, drop the umbrella label

Each skill carries its own literal persona name in the section
heading and first line:
- `skills/discover/SKILL.md` → "Product Manager persona" (CPO-style).
- `skills/tech-spec/SKILL.md` → "Senior Engineer persona" (CTO-style).

**Trade-off.** Keeping the umbrella "Generator persona" label
preserves doctrinal continuity with the manifesto's three-role
naming (Generator / Validator / Orchestrator). Dropping it
introduces two new persona names readers must learn. **Why drop
it anyway:** the manifesto's "Generator role" is an *abstract*
container ("captures intent, generates spec / code"); inside the
skills, a literal persona name disambiguates which hat the
deliberation wears. The `roles.md` pattern doc already
distinguishes "spec-phase Generator persona inline in skills"
from "runtime Generator subagent" — naming the spec-phase persona
literally per skill simply pushes that distinction one level
deeper without violating the role contract.

### Decision 2 — Engineering clarity-check shape: three binary checks, replacing the product-shaped trio

Replace the existing three product-shaped clarity checks in
`skills/tech-spec/SKILL.md` step 3 with three engineering-shaped
ones. The exact three are an editorial call inside the DoD #4 set;
recommended trio:
1. "Stack fit confirmed against `.vibeflow/index.md`?" (technical
   viability without major stack changes)
2. "Framework / library choices named with trade-offs?"
   (architecture decision is explicit, not implied)
3. "Sprint partitionable with binary acceptance criterion per
   task?" (decomposition is decidable)

**Trade-off.** Adding new questions instead of replacing keeps the
fast-track structure familiar to existing users. **Why replace:**
appending would make the gate ask 6 questions, half product and
half engineering — exactly the symptom the PRD is fixing. The
product shape belongs to discover, the engineering shape belongs
to tech-spec; one persona, one shape.

### Decision 3 — Lineage doc creation: now, in this part

`docs/lineage.md` is created in Part 1 (not deferred to Sprint 8)
with two seed rows. Part 2 appends one more row.

**Trade-off.** Sprint 8 owns the consolidated lineage doc per the
implementation plan. Creating the file now duplicates Sprint-8
work scope. **Why now:** the `conventions.md` "Lineage is
documented honestly" rule is a *runtime invariant* of every
Vibeflow / Bedrock-derived component, not a Sprint-8 deliverable.
Having three rows (after Part 2) ahead of Sprint 8 lets Sprint 8
extend rather than originate the file, which is cheaper to review.

### Decision 4 — Decision-log entries are per-component, not per-PR

`.vibeflow/decisions.md` gets two entries here (one per refined
skill), not one entry covering both. This matches the existing
log's convention: every prior decision dated `2026-04-25` (Three
runtime subagents only / Three agentified roles reaffirmed /
Skills deliberate, subagents adapt / Consult live, canonize on
termination) is per-decision, not per-PR. One refined component,
one decision.

## Applicable Patterns

- **`patterns/roles.md`** — declares the spec-phase Generator
  persona as inline in `skills/discover/SKILL.md` and
  `skills/tech-spec/SKILL.md`. This part edits the inline persona
  text without changing the pattern's *contract* (skills don't
  spawn subagents; canonical-memory reads go via `/yoke:ask`).
  Compliance check: the post-edit skills still have no `Task` in
  `allowed-tools`, still route canonical reads through
  `/yoke:ask`, still don't share context across phases.
- **`patterns/phase-flow.md`** — Phase 1 (Discovery, gate Trigger 1)
  and Phase 2 (Tech Spec, gate Trigger 2). The persona edit must
  preserve every gate property: each phase pauses at its gate, the
  binding artifact shape is unchanged, the next-phase chain via
  `Skill` tool is preserved.
- **`patterns/human-triggers.md`** — Triggers 1 and 2. The approval
  menu invocation, the open-questions detection block, and the
  `Skill`-tool fallback all live in the parts of each skill this
  spec keeps verbatim. Compliance check: the edit's diff does not
  touch any line inside step 7 (discover) or step 5 (tech-spec) —
  the trigger surfaces.
- **`patterns/plugin-structure.md`** — `skills/<name>/SKILL.md`
  layout, `docs/` folder for plugin docs (this is where
  `lineage.md` lands).
- **`conventions.md` § Lineage is documented honestly** — the
  reason `docs/lineage.md` is updated in this part rather than
  later.

No new pattern is introduced.

## Risks

- **R-P1.1 — Persona body drifts back into shared territory.** A
  rewrite that says "Senior Engineer persona; understands product
  framing too" reintroduces the overlap. **Mitigation:** DoD #2
  forbids architectural language in discover; symmetrically,
  enforce "no product-only language" in tech-spec by reading the
  diff and rejecting wishlist words. Reviewer reads both personas
  side-by-side before merge.
- **R-P1.2 — Engineering questions list grows.** Three checks may
  feel insufficient; the temptation is to add a fourth and fifth.
  **Mitigation:** the existing fast-track is three; mirror it.
  Anything beyond goes into the full-flow rounds (discover already
  has Rounds 1–4 for that case; tech-spec doesn't currently have
  multi-round dialogue and this part does NOT add one — keep that
  decision deferred).
- **R-P1.3 — `docs/lineage.md` clashes with a Sprint-8 plan.** If
  Sprint 8 already drafted a different shape for `lineage.md`,
  the file shape created here may diverge. **Mitigation:** keep
  the file minimal (header + table); Sprint 8 can extend the
  table or wrap it in additional sections without rewriting it.
- **R-P1.4 — Smoke-test regression.** If a smoke test parses
  persona text from `skills/discover/SKILL.md` or
  `skills/tech-spec/SKILL.md`, the rename breaks it.
  **Mitigation:** before editing, grep `tests/` for any reference
  to "Generator persona" inside discover/tech-spec; if a smoke
  test asserts on that string, update the assertion in the same
  PR.
- **R-P1.5 — Decision-log convention drift.** Two new entries with
  slightly different formatting from prior entries makes the log
  inconsistent. **Mitigation:** copy the exact section header
  pattern (`### YYYY-MM-DD — <title>`) and field order
  (`**Decision:**`, `**Context:**`, `**Discarded alternatives:**`)
  from the most recent existing entry; do not invent new fields.

## Dependencies

None. Part 1 is independent.

## See also

- `.vibeflow/prds/phase-persona-rebalance.md` — source PRD.
- `.vibeflow/specs/phase-persona-rebalance-part-2.md` — depends on
  this part.
- `.vibeflow/conventions.md` § Lineage is documented honestly +
  Don'ts.
- `.vibeflow/patterns/roles.md`, `phase-flow.md`,
  `human-triggers.md`, `plugin-structure.md`.
