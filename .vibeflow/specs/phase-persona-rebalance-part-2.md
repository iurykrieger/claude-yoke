# Spec: phase-persona-rebalance — Part 2 of 2 (Generator subagent persona)

> Generated via /vibeflow:gen-spec on 2026-04-25
> Source PRD: `.vibeflow/prds/phase-persona-rebalance.md`
> Part 2 of 2 — depends on Part 1.

## Objective

Replace the one-sentence Generator subagent persona ("Engineer
focused on shipping") in `agents/generator.md` with an explicit
**Senior Developer persona** that imports the Coding-Agent role and
discipline rules from `vibeflow:implement` — without porting that
skill's 7-phase orchestration (the ralph loop owns orchestration in
Yoke).

## Context

`agents/generator.md` line 26 area declares the persona in a single
sentence: "Engineer focused on shipping. Strong instinct for mapping
use cases into concrete file changes." Compared to
`vibeflow:implement`'s explicit "Role: Coding Agent" block (which
codifies non-goals: no architectural decisions, no spec questioning,
no scope creep, no while-I'm-here refactors, stop-and-ask on
ambiguity), the Generator's mindset is implied through the
Always/Never bullet rules but not anchored as a role. In practice
this lets the runtime Generator silently make architectural
decisions inside the ralph loop instead of stopping and surfacing
them via `.yoke/runtime/progress.md` for the Orchestrator to
escalate (Trigger 4).

This part lands the runtime persona refinement. Part 1 already
established the spec-phase persona split and seeded
`docs/lineage.md`; this part appends one more row to that file and
adds one decision entry to `.vibeflow/decisions.md`.

The architectural separation is non-negotiable: `vibeflow:implement`
is a **single-agent 7-phase pipeline** (find spec → extract
guardrails → load patterns → plan → implement → test → self-verify);
`/yoke:implement` is **a deterministic coordinator that spawns
three adversarial subagents in parallel each cycle** inside a ralph
loop. Only the persona + discipline crosses over from the upstream
skill — not the orchestration shape.

## Definition of Done

1. **Generator persona is literal Senior Developer.**
   `agents/generator.md`'s `## Persona` section is rewritten so its
   first line names the role literally as "Senior Developer
   persona" (Coding-Agent equivalent) and contains the role
   description (receives the binding Acceptance Contract, executes
   it).
2. **Discipline rules are explicit.** The persona block (or a new
   `## Discipline` subsection adjacent to it) lists, as explicit
   must-do and must-not rules: follow patterns exactly; follow
   conventions; minimum change (no while-I'm-here refactors);
   anti-scope is sacred; technical decisions in upstream artifacts
   are constraints, not suggestions; new dependencies require
   justification (stop and surface); no architectural decisions —
   if undecided, stop and surface.
3. **Stop-and-surface clause is operational.** The persona block
   names the operational mechanism Generator uses when it hits
   ambiguity: write the diagnosis to `.yoke/runtime/progress.md` so
   the Orchestrator detects it (Trigger 4 / `escalate.sh
   --reason infeasibility`), never silently proceeds. The clause
   names the file path verbatim and references the existing
   "Never advance past a criterion you cannot make pass" rule in
   the `### Never` block.
4. **No 7-phase pipeline import.** The diff does not introduce any
   numbered "Phase 1 / Phase 2 / Phase 3 …" pipeline inside
   `agents/generator.md`. The cycle shape (read upstream artifacts +
   prior progress + query trace + sensor snapshot → write code →
   persist `progress.md` + consensus-append `contracts.md`) stays
   exactly as today; the ralph loop in `skills/implement/SKILL.md`
   continues to own orchestration. Regression-checked by `grep -c
   "^### Phase " agents/generator.md` returning 0.
5. **Existing Always / Never / Memory scope / Allowed tools /
   Restrictions / Pattern references survive verbatim.** The diff
   for `agents/generator.md` is bounded to the `## Persona` section
   (and an optional new `## Discipline` block immediately after it).
   Every line in `## Behaviors` (`### Always` and `### Never`),
   `## Memory scope`, `## Allowed tools`, `## Restrictions`, and
   `## Pattern references` is preserved unchanged. Verified by
   `git diff agents/generator.md` showing edits only in the persona
   region.
6. **Decision log + lineage updated.** `.vibeflow/decisions.md`
   carries one new decision entry dated `2026-04-25` titled
   something like "Generator subagent persona = Senior Developer
   (Coding-Agent discipline)" in the existing format
   (`### YYYY-MM-DD — <title>`, `**Decision:**`, `**Context:**`,
   `**Discarded alternatives:**`). `docs/lineage.md` (created in
   Part 1) gains one more row: `vibeflow:implement` →
   `agents/generator.md` (persona + Coding-Agent discipline; **not**
   the 7-phase orchestration).
7. **Craftsmanship — invariant preservation.** The post-edit
   `agents/generator.md` still satisfies every `roles.md` rule for
   the runtime Generator: writes only `.yoke/runtime/progress.md`
   and `.yoke/contracts/<slug>.md` + host code; reads upstream
   artifacts read-only; never reads or writes canonical memory
   directly; never shares context with the Validator; never
   relaxes the Acceptance Contract; never spawns other subagents.
   Smoke test for the Phase-4 ralph loop (the relevant sprint's
   `tests/smoke/sprint-N.test.sh`, when it exists) still passes
   with `timeout 600`.

## Scope

- Edit `agents/generator.md`:
  - Replace `## Persona` body. New first line names "Senior
    Developer persona" (or "Coding Agent" — equivalent) and
    states the role: "You receive the approved PRD, Tech Spec, and
    binding Acceptance Contract; you execute against them. You do
    not redesign the system."
  - Add the must-do / must-not bullet list (DoD #2) inline under
    the persona, or as a `## Discipline` subsection immediately
    after `## Persona`. Either is acceptable as long as it sits in
    the file before `## Behaviors` so cycle-time readers internalize
    the role before the rule list.
  - Add the stop-and-surface clause (DoD #3) referencing
    `.yoke/runtime/progress.md` and the existing
    `### Never` "Never advance past a criterion you cannot make
    pass" rule.
- Update `.vibeflow/decisions.md` with one entry dated
  `2026-04-25` for the Generator persona refinement: title,
  decision, context (this PRD's symptom), discarded alternatives
  (kept thin one-sentence persona; ported full 7-phase pipeline).
- Append one row to `docs/lineage.md` (created in Part 1) for the
  `vibeflow:implement` → `agents/generator.md` mapping. The "What
  was ported" cell explicitly names "persona + Coding-Agent
  discipline (must-do / must-not / stop-and-surface)" and the "What
  was deliberately not ported" sub-clause names "the 7-phase
  orchestration — owned by the ralph loop in
  `skills/implement/SKILL.md`".

## Anti-scope

- **No edits to spec-phase skills.** That's Part 1.
- **No edits to `agents/validator.md` or `agents/orchestrator.md`.**
  The user explicitly scoped the agent-persona work to Generator
  in the PRD.
- **No edits to `skills/implement/SKILL.md`** (the ralph-loop
  coordinator). Cycle orchestration stays where it is.
- **No new behavioral rules in `### Always` or `### Never`.** The
  rule list is craftsmanship-stable; the persona refinement
  changes the *framing* of those rules, not the rules themselves.
  Adding new bullets is out of scope.
- **No `## Memory scope`, `## Allowed tools`, `## Restrictions`,
  or `## Pattern references` edits.** All five sections stay
  byte-identical.
- **No port of `vibeflow:implement`'s 7-phase pipeline** (find
  spec → extract guardrails → load patterns → plan → implement →
  test → self-verify). The ralph loop owns orchestration; the
  Generator is one of three subagents inside one cycle.
- **No port of `vibeflow:implement`'s budget enforcement, test-
  detection heuristics, or audit-suggestion footer.** Those belong
  to a single-agent pipeline; Yoke's equivalent is
  `hooks/check-hard-bounds.sh` + the Acceptance Contract sensors.
- **No `templates/`, `lib/`, `hooks/`, or `tests/` changes.**

## Technical Decisions

### Decision 1 — Persona + discipline only; reject the 7-phase port

Import the role definition + non-goals from
`vibeflow:implement`'s "Role: Coding Agent" block. Reject the
7-phase orchestration import.

**Trade-off.** A deeper port — restructuring each Generator cycle
as a mini 7-phase pass (read failing criterion → load query-trace
subgraph → plan → write → invoke `verify-acceptance.sh` →
self-verify YAML → persist `progress.md`) — is more faithful to
"vibeflow:implement is equivalent to the Generator subagent". It
also adds shape-prescription this subagent doesn't carry today.
**Why reject the deeper port:** Yoke's ralph-loop pattern
(`patterns/ralph-loop.md`) declares the cycle steps deterministically
in `skills/implement/SKILL.md` step 2 (concurrent batch → sensor
execution → contradiction check → persist → hard-bound check →
stop check). Adding a parallel 7-phase pipeline inside the
Generator's prompt creates two competing orchestration shapes — a
documented anti-pattern in `roles.md` ("Treating the Orchestrator
as a passive router instead of a stateful coordinator"). The PRD
resolved this as Open Question 1, choosing persona + discipline
only.

### Decision 2 — Discipline placement: persona-block-adjacent, before `## Behaviors`

The discipline rules (must-do / must-not / stop-and-surface) sit
inline at the bottom of `## Persona`, or as a `## Discipline`
subsection immediately after `## Persona` and before `## Behaviors`.

**Trade-off.** Embedding inside `## Persona` keeps the file
shorter but mixes role description with rules. A separate
`## Discipline` section is cleaner but adds a header.
**Recommendation:** separate `## Discipline` section. Rationale:
the existing `## Behaviors` section uses `### Always` /
`### Never` headings — keeping `## Persona` as pure narrative and
`## Discipline` as a parallel rule-list mirrors that shape one
level up. The reader's eye flows: who I am → what I always do /
what I never do → file ownership → tools.

### Decision 3 — Decision-log entry granularity: one entry, this part

One decision entry covers Generator persona refinement (this part);
Part 1 already added two for the spec-phase skills. Total of three
new entries across both parts, matching `## Decisions resolved` #3
in the PRD.

**Trade-off.** A single PRD-level decision entry would be shorter.
**Why three:** the decision log convention is per-component;
deviating from it in this PRD would silently set a precedent.

## Applicable Patterns

- **`patterns/roles.md`** — declares the runtime Generator
  subagent's contract: writes `.yoke/runtime/progress.md` +
  `.yoke/contracts/<slug>.md` only; reads upstream artifacts
  read-only; never reads or writes canonical memory directly;
  spawned in single concurrent Task batch with Validator and
  Orchestrator; never shares context with Validator. Compliance
  check: every line in `roles.md` "Generator (runtime subagent)"
  bullet still describes the post-edit `agents/generator.md`.
- **`patterns/ralph-loop.md`** — declares the cycle shape, the
  parallel-spawn invariant, hard-bound semantics. Compliance
  check: the post-edit Generator still operates inside one cycle
  (no internal multi-step pipeline); `verify-acceptance.sh`
  remains the single sensor channel.
- **`patterns/phase-flow.md`** — Phase 4 (Runtime). The runtime
  Generator subagent participates in this phase; the persona
  refinement must not change Phase 4's binding artifact (working
  memory under `.yoke/`) or the trigger surfaces (Trigger 4).
- **`patterns/plugin-structure.md`** — `agents/<name>.md` layout
  for runtime subagents.
- **`conventions.md` § Lineage is documented honestly** — the
  reason for the lineage row.
- **`conventions.md` § Don'ts** — specifically: "Do NOT pin Yoke
  to a specific upstream version of Vibeflow or Bedrock" — this
  spec imports persona text *as text*, not as a live dependency.
  The lineage row records origin, not subscription.

No new pattern is introduced.

## Risks

- **R-P2.1 — 7-phase pipeline creeps into the persona body.** The
  rewrite, if too literal, copies vibeflow's "Phase 0 / Phase 1
  / …" headers into `agents/generator.md` and recreates a parallel
  orchestration. **Mitigation:** DoD #4 grep regression check
  blocks merge if `^### Phase ` appears in the file. Reviewer
  reads the full diff against `vibeflow:implement` to confirm only
  role + non-goals + stop-and-surface crossed over.
- **R-P2.2 — Discipline rules duplicate `### Never` bullets.**
  Some discipline items ("never share context with Validator",
  "never relax the Acceptance Contract") already live in
  `### Never`. Adding them again under `## Discipline` is
  redundant and risks divergence on later edits. **Mitigation:**
  the new discipline list is *role-framing* (what kind of agent
  am I) not *file-ownership rules* (which `### Never` already
  carries). Keep the two distinct: discipline = mindset; behaviors
  = file mechanics. Reviewer rejects items that overlap with
  existing `### Never` content.
- **R-P2.3 — Diff scope creeps into `## Behaviors` or
  `## Restrictions`.** While editing the persona, the temptation
  is to "fix" wording in adjacent sections. **Mitigation:** DoD
  #5 forbids it; verified by `git diff` line ranges.
- **R-P2.4 — `docs/lineage.md` doesn't exist if Part 1 hasn't
  shipped.** This spec depends on Part 1; if Part 2 is implemented
  first by accident, the lineage append fails (or creates the file
  with only the Generator row, leaving the spec-phase rows
  missing). **Mitigation:** dependency declared in
  `## Dependencies`; `/vibeflow:implement` should refuse to start
  Part 2 until Part 1's audit lands a PASS verdict in
  `.vibeflow/audits/`.
- **R-P2.5 — Smoke-test parses persona string.** If a Phase-4
  smoke test asserts "Engineer focused on shipping" appears in
  `agents/generator.md`, the rename breaks it. **Mitigation:**
  before editing, grep `tests/` for the existing persona string
  and update the assertion in the same PR.
- **R-P2.6 — `vibeflow:implement` upstream evolves and the lineage
  row becomes stale.** **Mitigation:** the `## Don'ts` invariant
  forbids tracking upstream — the lineage row is a frozen-at-
  creation snapshot. The cell records "ported at v0.2.0 / v1.1.0
  refresh", which is sufficient.

## Dependencies

- `.vibeflow/specs/phase-persona-rebalance-part-1.md` — must be
  implemented and audited PASS before Part 2 starts. Reasons:
  (1) Part 2 appends to `docs/lineage.md` which Part 1 creates;
  (2) Part 2's decision-log entry is the third in a series of
  three, and the convention (per-component, dated `2026-04-25`)
  is established by Part 1's two entries.

## See also

- `.vibeflow/prds/phase-persona-rebalance.md` — source PRD.
- `.vibeflow/specs/phase-persona-rebalance-part-1.md` — must
  ship and audit before this part.
- `.vibeflow/conventions.md` § Don'ts (no upstream pinning) +
  Lineage is documented honestly.
- `.vibeflow/patterns/roles.md`, `ralph-loop.md`,
  `phase-flow.md`, `plugin-structure.md`.
- Upstream reference (read-only, frozen snapshot):
  `~/.claude/plugins/cache/vibeflow-marketplace/vibeflow/1.10.0/skills/implement/SKILL.md`
  — section `## Role: Coding Agent`.
