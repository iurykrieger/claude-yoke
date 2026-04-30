# Sprint 02 of 03: Tech Spec Task Split

> Migrated from: # Spec: Tech Spec Task Split — Part 2 — `/yoke:tech-spec` 3-stage blueprint


> Generated via /vibeflow:gen-spec on 2026-04-25
> PRD: `.vibeflow/prds/tech-spec-task-split.md`
> Plugin version target: 0.7.0 (working-memory rev)

## Objective

Rewrite `skills/tech-spec/SKILL.md` to drive a 3-stage LLM → bash →
LLM-per-task blueprint that produces `.yoke/specs/<slug>.md` and one
`.yoke/tasks/<slug>-s<N>-t<M>.md` per task, with Trigger 2 approval
covering both artifacts as a single decision.

## Context

Part 1 has landed `wm_spec_path`, `wm_task_path`, `wm_list_task_paths`,
and `lib/working-memory/scaffold-tasks.sh`. The current
`/yoke:tech-spec` skill still drafts a single monolithic file; Part 2
swaps that body for the 3-stage blueprint declared in the PRD:

1. Generator persona drafts the sprint index at `.yoke/specs/<slug>.md`.
2. `scaffold-tasks.sh` materializes one empty task file per task ID
   parsed out of the spec.
3. Generator persona iterates the empty task files and fills each,
   one at a time, with sprint preamble in context — directly serving
   `conventions.md` "progressive disclosure".

Trigger 2 still uses `templates/approval-menu.md`. The menu is
extended (not forked) to render a per-task summary block when
`artifact_label == "Tech Spec"`. `approve` / `approve_and_continue`
writes `Status: approved` to the spec **and** every task file in the
same step. `revise` deletes everything for the slug and re-runs all
three stages. Failures in stage 3 leave a partial on-disk state that
the user recovers from with `revise` — the skill does not roll back.

## Definition of Done

1. `/yoke:tech-spec` invoked on an approved PRD produces, in order:
   (a) `.yoke/specs/<slug>.md` matching `templates/spec.md` (no
   inline task body); (b) one `.yoke/tasks/<slug>-s<N>-t<M>.md` per
   task ID parsed by `scaffold-tasks.sh`, each carrying the YAML
   frontmatter shape from `templates/task.md` and the four required
   body sections — *Story*, *Technical implementation*, *Validation*,
   *Acceptance criterion*. The skill body documents the three stages
   explicitly (LLM / bash / LLM-per-task) so a future reader can audit
   the blueprint.
2. The per-task LLM call (stage 3) carries only sprint preamble — the
   sprint name and delivery objective lifted from `.yoke/specs/<slug>.md`
   — plus the single empty task file under work, never the entire
   spec or sibling task files. Verifiable by reading the skill body's
   stage-3 prompt construction step.
3. Trigger 2 renders via `templates/approval-menu.md` and shows a
   per-task summary block: one line per task with story line + task
   ID + `wm_task_path` value. The shared menu template is **extended**
   to support this block when `artifact_label == "Tech Spec"`; no
   fork. `approve` / `approve_and_continue` writes `Status: approved`
   to the spec **and** every task file in the same step.
4. `revise` deletes every `.yoke/tasks/<slug>-s*-t*.md` plus
   `.yoke/specs/<slug>.md` for the active slug and re-runs stages
   1–3 from scratch — loud `wm:`-prefixed warning printed before the
   delete, no diff-merge of hand edits. `reject` invokes the existing
   secondary-confirmation path and exits without writing
   `Status: approved` to either artifact.
5. Stage-3 partial failure (e.g., LLM error on task 5 of 7) exits the
   skill non-zero with a clear error pointing at the failed task file
   path; files 1–4 stay on disk; no rollback. The skill prints the
   recovery instruction "re-run `/yoke:tech-spec` and pick `revise` to
   start over" and exits cleanly.
6. `templates/tech-spec.md` is deleted; `skills/tech-spec/SKILL.md`
   no longer references `wm_tech_spec_path`, `.yoke/tech-specs/`, or
   `templates/tech-spec.md` — the skill writes via `wm_spec_path`,
   reads `templates/spec.md` + `templates/task.md`, and invokes
   `lib/working-memory/scaffold-tasks.sh`. References in
   `lib/ralph-loop/orchestrate.sh`, `agents/*.md`, and the other
   skills (`acceptance-contract`, `implement`, `bootstrap`,
   `discover`, `status`) plus the `folder-isolation` /
   `sprint-4` smoke tests remain — kept green by Part 1's
   deprecated `wm_tech_spec_path` alias and migrated by the
   post-Part-3 cleanup pass tracked in the PRD (see
   `.vibeflow/decisions.md` 2026-04-25 entry "wm_tech_spec_path
   retained as deprecated soft alias").
7. **Craftsmanship gate.** The skill obeys `.vibeflow/conventions.md`
   ("progressive disclosure", "blueprints wrapping agentic nodes",
   "back-pressure: success is silent, failures are verbose"), the
   2026-04-25 runtime-only-agents decision (Generator persona stays
   inline — no subagent spawn at spec phase), the
   `patterns/human-triggers.md` shared-menu rule (extension, not
   fork), and the `patterns/memory-model.md` write-authority table
   (Generator persona writes `.yoke/specs/<slug>.md` and
   `.yoke/tasks/<slug>-s*-t*.md`; no agent reads canonical memory
   directly). `tests/smoke/sprint-2.test.sh` extends to assert the
   new artifact shape end-to-end.

## Scope

- `skills/tech-spec/SKILL.md` (rewrite) — replaces the current
  monolithic-write body with the 3-stage blueprint; preserves the
  pre-flight (config + active-slug + approved-PRD checks); preserves
  the Generator persona inline; updates the path resolution to
  `wm_spec_path` / `wm_task_path` / `wm_list_task_paths`; documents
  the partial-failure recovery contract.
- `templates/approval-menu.md` (modify) — extends the shared template
  with an optional per-task summary block, gated on
  `artifact_label == "Tech Spec"`. The block lists each task with
  story line, task ID, and on-disk path. Triggers 1 and 3 are
  unaffected (the block is conditional, not inserted unconditionally).
- `templates/tech-spec.md` (delete) — superseded by Part 1's
  `templates/spec.md` + `templates/task.md`. Removed here, not in
  Part 1, so the Sprint-2 smoke test in Part-1 DoD #7 stays green.
- `tests/smoke/sprint-2.test.sh` (modify) — extends the existing flow
  with `/yoke:tech-spec` and asserts both archive paths (`specs/` and
  `tasks/`) are populated and carry `Status: approved` at the end of
  the run.

## Anti-scope

- **No runtime subagent changes.** `agents/generator.md`,
  `agents/validator.md`, `agents/orchestrator.md` are untouched.
  Only the Generator *persona* (inline in this skill) drafts and
  fills artifacts; the runtime subagents consume them in Phase 4 and
  inherit the new shape transparently via the `wm_*` helpers.
- **No canonical-memory writes.** The frontmatter seeded in stage 2
  is working memory; promotion to canonical memory is Phase 5 /
  `/yoke:preserve` territory and out of scope for this whole PRD.
- **No diff-preserving re-run.** `revise` always deletes and
  rewrites. Hand edits to task files survive only across `approve` →
  `approve` re-runs (i.e., not at all within a single revise loop).
- **No per-task review at Trigger 2.** Approval is still spec-level
  (one decision marks the whole sprint set approved). Per-task
  rejection / revision is a follow-up PRD.
- **No `/yoke:status` rework.** Status keeps reporting at archive
  level; presence of `Status: approved` on the spec is sufficient
  signal.
- **No multi-PRD aggregation.** One PRD → one spec → N task files
  for that slug.
- **No multi-line stage-3 batching.** Stage 3 is one LLM call per
  empty task file, in order. Batching them collapses progressive
  disclosure.

## Technical Decisions

- **Three explicit stages, not a single agentic loop.** The PRD's
  three-stage flow is the architectural decision; the skill body
  must document the stages and their inputs/outputs so a reader can
  audit the deterministic-vs-agentic boundary. Trade-off: longer
  skill body and an extra `Bash` invocation between LLM calls. Win:
  predictable token cost (stage 1 cost ≈ existing skill cost; stage 2
  cost = 0; stage 3 cost = N small calls instead of one large one)
  and stage-3 isolation that directly serves progressive disclosure.
- **In-place writes, no rollback.** `conventions.md` "back-pressure:
  success is silent, failures are verbose" + the PRD's anti-atomic
  decision: on stage-3 partial failure, files 1..K-1 stay on disk
  with `Status: draft`, file K is partial or missing, files K+1..N
  do not exist. The skill exits non-zero with a precise error and
  trusts the user to re-run with `revise`. No hidden temp directory,
  no quiet rollback that could mask LLM failures.
- **`approve` writes both artifacts atomically at the bash level.**
  After approval, the skill writes `Status: approved` to the spec
  *and* iterates `wm_list_task_paths "$slug"` to write
  `Status: approved` into each task file's frontmatter. If any
  per-task write fails (filesystem error, not LLM), the skill exits
  non-zero before chaining into `/yoke:acceptance-contract`. Trade-off:
  approval is no longer a single-file edit. Win: `Status: approved`
  is meaningful — it covers the entire sprint's deliverables.
- **`templates/approval-menu.md` extension over fork.** The
  `human-triggers.md` rule "shape is shared, semantics are distinct"
  permits extending the menu's rendering with conditional blocks
  driven by `artifact_label`. Forking the template would coalesce the
  triggers' surfaces post-hoc and re-introduce the anti-pattern the
  pattern doc calls out.
- **Stage 3 prompt construction.** The skill constructs a tight
  prompt per task: a fixed preamble (sprint name + delivery objective
  + the per-task body sections required by `templates/task.md`),
  the empty task file's current contents (frontmatter only), and the
  request to fill the four body sections. No retrieval of sibling
  tasks, no canonical-memory read (those go through `/yoke:ask` if
  needed by the persona, but the persona is encouraged not to need
  them at this stage — the spec's contracts/dependencies sections
  carry the cross-cutting context).

## Applicable Patterns

- `.vibeflow/patterns/phase-flow.md` — Phase 2 (Tech Spec) artifact
  contract. Splits "the spec" into a sprint index + per-task files;
  Phase 3 inputs change shape (handled in Part 3) but Phase 2's gate
  semantics (Trigger 2, blocking) are preserved.
- `.vibeflow/patterns/human-triggers.md` — Trigger 2 schema, the
  shared `templates/approval-menu.md` shape, and the rule that
  shapes are shared while decision spaces and audit logs remain
  distinct per trigger. The per-task summary block is rendered
  conditionally on `artifact_label`, honoring the rule.
- `.vibeflow/patterns/memory-model.md` — write-authority table
  (Generator persona writes spec + task files; Validator, Orchestrator
  read them later in Phases 3 and 4); working-memory archive layout.
- `.vibeflow/conventions.md` — "blueprints wrapping agentic nodes",
  "progressive disclosure", "shift feedback left",
  "back-pressure: success is silent, failures are verbose".

No new pattern introduced. `memory-model.md` is updated alongside
this part to swap the legacy `tech-spec.md` row for the new
`spec.md` + per-task entries (one-line edit in the working-memory
table).

## Risks

- **Stage-3 LLM hallucinating fields outside the four required body
  sections.** Trade-off: the persona's freedom inside each section is
  what makes the artifact valuable; over-constraining would
  recreate the original granularity problem. **Mitigation:** the
  persona prompt explicitly bounds the four sections with required
  headings; a post-stage validation in the skill body verifies each
  task file contains all four headings before moving on; missing
  heading → stage-3 partial failure with the precise heading
  identified.
- **Per-task LLM cost vs the prior monolithic call.** Stage 3 multiplies
  LLM invocations by task count. **Mitigation:** the prompt is
  deliberately tight (sprint preamble + empty task only); for typical
  Yoke sprints (3–7 tasks per `templates/spec.md` shape), total
  stage-3 cost is bounded by ~7 small calls and is on the order of
  the prior monolithic call. For the rare large sprint, the
  per-cycle progressive-disclosure benefit dominates.
- **Trigger-2 menu drift.** Extending `templates/approval-menu.md`
  conditionally risks the per-task block leaking into Triggers 1 or
  3 if the gating condition is wrong. **Mitigation:** the gating
  condition is the existing `artifact_label` input (already passed
  by `/yoke:discover` and `/yoke:acceptance-contract` with their own
  literals), and the rendering rule is exercised in the smoke test
  for both the Tech Spec path (block present) and the PRD path
  (block absent).
- **Smoke test flake on per-task LLM determinism.** Stage 3 invokes
  the LLM N times. **Mitigation:** the smoke test asserts only
  structural properties (file presence, required headings,
  frontmatter shape, `Status: approved`), not content — content
  determinism is not part of the contract.

## Dependencies

- `.vibeflow/specs/tech-spec-task-split-part-1.md` (must merge first;
  Part 2 calls `wm_spec_path`, `wm_task_path`, `wm_list_task_paths`,
  and invokes `lib/working-memory/scaffold-tasks.sh`).
