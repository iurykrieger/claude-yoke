# PRD: Granular Tech Spec — Sprint Index + Per-Task Files

> Generated via /vibeflow:discover on 2026-04-25

## Problem

Today `/yoke:tech-spec` writes a single monolithic file at
`.yoke/tech-specs/<slug>.md` that bundles sprint-level objectives, task
descriptions, acceptance criteria, contracts and dependencies inline. In
practice the resulting tasks are coarse: the existing v1 specs themselves
illustrate the failure mode — `.vibeflow/specs/yoke-v1-sprint-3.md`
collapses seven concerns (scaffolding, sensor discovery, verification,
fallback, smoke test, craftsmanship, prompt-diff DoD) into a flat DoD
list, and "Scope" is a bullet list of artifacts rather than a list of
discrete, individually decidable tasks.

This hurts the framework in three places:

- **Phase 3 (Acceptance Contract).** The Validator persona is asked to
  produce one BDD scenario per task, but tasks have no stable identity
  and no isolated technical description — so scenarios drift and become
  paragraph-level rather than task-level.
- **Phase 4 (Runtime).** The Generator subagent iterates "the spec" with
  no granular cursor — every cycle re-reads the whole monolith,
  competing for attention against unrelated tasks (violates
  *progressive disclosure* in `conventions.md`).
- **Human review at Trigger 2.** Reviewers cannot accept/reject tasks
  individually; the only available decision is on the whole spec.

The pain is felt by every Yoke user once they reach a non-trivial sprint
with more than ~3 tasks, and by the framework author iterating on
Yoke v1 itself today.

## Target Audience

Primary: developers running `/yoke:tech-spec` against a non-trivial PRD
(≥ 1 sprint with ≥ 3 tasks). Secondary: the runtime subagents
(Generator, Validator) that consume the artifacts in Phases 3 and 4.

## Proposed Solution

Split the Tech Spec into a **versioned sprint index** and a **versioned
per-task archive**, both committed to git:

- **`.yoke/specs/<slug>.md`** — the index. Per sprint: name + delivery
  objective + ordered task list, where each task is rendered as a
  one-line story plus a stable task ID linking to its dedicated file.
  Also carries cross-cutting sections (overall objective, contracts and
  interfaces, dependencies, out of scope).
- **`.yoke/tasks/<task-id>.md`** — one file per task. Holds the
  full technical implementation description, the validation description
  (which feeds Phase 3), the per-task acceptance criterion (binary,
  observable), and any task-level dependencies. Versioned in git
  alongside the spec — both are source-of-truth artifacts.

Task IDs follow `<slug>-s<N>-t<M>` (e.g., `2026-04-25-tech-spec-task-split-s1-t3`)
so ordering is encoded positionally and the task file is reachable
deterministically from any sprint+task pair.

Consumer flow:

- `/yoke:acceptance-contract` reads the spec **plus** every
  `.yoke/tasks/<slug>-s*-t*.md` and emits one BDD scenario per task
  file. The task file's "Validation" section is the *input*, not the
  replacement — the Acceptance Contract remains the binding artifact.
- The Generator subagent iterates tasks **one at a time** with the
  containing sprint's objective preloaded as preamble (so the cycle
  context = sprint purpose + current task file, not the entire spec).

The legacy archive at `.yoke/tech-specs/` is renamed to `.yoke/specs/`
and the helpers in `lib/working-memory/paths.sh` adopt the new layout.

**Three-stage generation flow** (LLM → bash → LLM-per-task) — the skill
is a blueprint wrapping agentic nodes, per `conventions.md`:

1. **LLM (sprint index).** Generator persona drafts
   `.yoke/specs/<slug>.md` end-to-end: sprint purposes, ordered task
   stories, task IDs, contracts, dependencies. No task bodies.
2. **Bash (deterministic scaffold).** `lib/working-memory/scaffold-tasks.sh`
   parses the spec's task IDs and creates one empty file per task at
   `.yoke/tasks/<slug>-s<N>-t<M>.md`, each carrying the canonical
   frontmatter stub (`task_id`, `sprint`, `slug`, `status: draft`,
   plus the canonization-ready fields described under Technical
   Context). No LLM in this step.
3. **LLM (per-task fill).** Generator persona iterates the empty task
   files and fills each with *Story*, *Technical implementation*,
   *Validation*, *Acceptance criterion*. One task at a time — the cycle
   context is sprint preamble + the single empty task — directly
   serving progressive disclosure.

Migration of an existing `.yoke/tech-specs/<slug>.md` reuses the same
pipeline: stage 1's input becomes the legacy monolith instead of the
PRD; stages 2 and 3 are identical.

## Success Criteria

1. Running `/yoke:tech-spec` on an approved PRD produces, in the
   declared 3-stage order:
   - one `.yoke/specs/<slug>.md` file matching the new sprint-index
     template (one-line stories + task IDs only — no inline task body);
   - one `.yoke/tasks/<slug>-s<N>-t<M>.md` file per task, each
     carrying YAML frontmatter (`task_id`, `sprint`, `slug`, `status`,
     plus canonization fields) and **at minimum** four body sections:
     *Story*, *Technical implementation*, *Validation*, *Acceptance
     criterion*.
   Files are written in place as each stage completes; the skill does
   not roll back on partial failure (see Anti-scope).
2. Every task file produced satisfies the binary-criterion bar already
   enforced by today's skill — vague criteria ("works correctly", "looks
   good") fail review, just like today.
3. `/yoke:acceptance-contract` consumes the new layout and produces one
   BDD scenario *per task file* without operator intervention; the
   binding statement still references the Acceptance Contract, not the
   Tech Spec.
4. `/yoke:implement` (when Sprint 4 lands the runtime) iterates task
   files in lexical order; each cycle's Generator context contains
   exactly the sprint preamble + the current task file (not the whole
   spec).
5. `lib/working-memory/paths.sh` exposes:
   - `wm_spec_path "<slug>"` → `.yoke/specs/<slug>.md`
   - `wm_task_path "<slug>" <N> <M>` → `.yoke/tasks/<slug>-s<N>-t<M>.md`
   - `wm_list_task_paths "<slug>"` → all task files for a slug, sorted
   and `tech-specs` is removed from `WM_ARCHIVE_CATEGORIES`, replaced
   by `specs` and `tasks`.
6. Trigger 2 (Tech Spec approval) blocks on the spec **and** every task
   file together — approval marks both as `Status: approved`.

## Scope v0

- New skill output: `.yoke/specs/<slug>.md` (sprint index) +
  `.yoke/tasks/<slug>-s<N>-t<M>.md` (one per task), both versioned.
- Updated `lib/working-memory/paths.sh` with `wm_spec_path`,
  `wm_task_path`, `wm_list_task_paths`; `WM_ARCHIVE_CATEGORIES`
  becomes `(prds specs tasks acceptance-contracts contracts query-traces)`.
- New deterministic helper `lib/working-memory/scaffold-tasks.sh` —
  parses task IDs out of an approved spec and creates the empty task
  files with frontmatter stubs. Pure bash; no LLM.
- New templates: `templates/spec.md` (sprint index) and
  `templates/task.md` (per-task body, with the frontmatter shape).
- `skills/tech-spec/SKILL.md` rewritten as a 3-stage blueprint:
  (a) Generator drafts the spec, (b) `scaffold-tasks.sh` materializes
  empty task files, (c) Generator fills each task one-by-one with
  sprint preamble in context. Writes happen in place; partial failure
  surfaces a clear error and lets the user re-run with `revise`.
- `skills/tech-spec/SKILL.md` re-run on an existing slug with `revise`
  deletes every `.yoke/tasks/<slug>-s*-t*.md` plus the spec and runs
  the 3 stages from scratch — no diff-merge, loud warning before delete.
- `skills/acceptance-contract/SKILL.md` updated to read the spec + all
  task files and emit one BDD scenario per task.
- Trigger 2 approval menu shows the per-task summary (story line + task
  ID + file path) so reviewers know what they are approving. Approval
  marks the spec **and** every task file `Status: approved`.
- Migration: `lib/working-memory/migrate-tech-specs.sh` reuses the
  3-stage pipeline against the legacy monolith — Generator drafts the
  new spec from the old file, the scaffold step creates task stubs,
  the Generator fills each. One-shot, not a runtime fallback.

## Anti-scope

- **No git-ignore for tasks.** Both the spec and the task files are
  versioned source-of-truth artifacts. Ephemeral runtime state stays in
  `.yoke/runtime/`.
- **No backward-compat shim** at `.yoke/tech-specs/`. The `tech-specs`
  category is removed from `WM_ARCHIVE_CATEGORIES`. The migration
  helper is one-shot, not a runtime fallback.
- **No atomic-write semantics.** Files are written in place as each
  of the 3 stages completes. The skill does not stage to a temp
  directory or roll back on partial failure. If stage 3 fails on
  task 5 of 7, files 1–4 are on disk and the skill exits with a clear
  error pointing at the failed task. Recovery is the user re-running
  with `revise` (which deletes + rewrites everything per the policy
  above).
- **No diff-preserving re-run.** `revise` always deletes every existing
  `.yoke/tasks/<slug>-s*-t*.md` plus the spec before regenerating. Hand
  edits to task files are not preserved across `revise` — they belong
  in a follow-up commit after approval.
- **No task-level review at Trigger 2.** Approval is still spec-level
  (one decision marks the whole sprint set approved). Per-task
  rejection / revision is out of scope for v0 — the user can `revise`
  the whole batch and the skill regenerates everything.
- **No runtime changes** to the Generator or Validator subagent
  prompts. Only the upstream artifacts change shape; Sprint 4 already
  consumes "the spec" through `wm_*_path` helpers and gets the new
  shape transparently.
- **No multi-PRD aggregation.** One PRD → one spec → N task files for
  that slug. Cross-slug dependencies are still captured inside the spec
  body, not in the task IDs.
- **No `/yoke:status` rework.** The status skill keeps reporting at
  artifact level; "tasks present and approved" is captured by the
  spec's `Status: approved` flag, which is only written when all task
  files are present.
- **No retroactive rewrite of `.vibeflow/specs/yoke-v1-sprint-*.md`.**
  Those are the meta-spec for building Yoke itself, generated by
  Vibeflow, not Yoke. They stay as-is.

## Technical Context

Based on `.vibeflow/`, `lib/working-memory/paths.sh`, and the current
skill bodies:

- **Working-memory layout** is centralized in
  `lib/working-memory/paths.sh:13-21` and `:45` (`WM_ARCHIVE_CATEGORIES`).
  Adding a new archive category is a one-place change. Slug regex at
  `:44` already supports the date-prefixed form
  `^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]{0,49}$`; task IDs
  reuse the slug as a prefix and append `-s<N>-t<M>`.
- **Generator persona** is embedded inline in
  `skills/tech-spec/SKILL.md` (decision 2026-04-25 — runtime-only
  agents). The persona stays; only the artifact shape it produces
  changes.
- **Acceptance Contract** is the binding artifact (manifesto §8.3 +
  `patterns/acceptance-contract.md`). Splitting the upstream spec does
  not change that property.
- **Trigger 2** is the human gate; the shared approval menu at
  `templates/approval-menu.md` already abstracts the prompt shape, so
  the rendering work is concentrated on building the right summary
  payload (one line per task with file path).
- **Patterns to obey.** `.vibeflow/conventions.md` "Progressive
  disclosure" and "Sensor output for LLM consumption" — the per-task
  file scoped to the Generator's cycle directly serves both.
- **Naming.** `.yoke/specs/` collides nominally with `.vibeflow/specs/`
  but the two live in different roots (host project's `.yoke/` vs the
  framework's `.vibeflow/`) and are never traversed together.
  Acceptable.
- **Frontmatter doubles as a canonization seed.** Task-file frontmatter
  is the input vector for Phase 5 / `/yoke:canonize` later — when a
  task's `Validation` outcome rises to a canonical-memory candidate,
  the Orchestrator hydrates the canonical frontmatter (ratification
  date, model calibrated against, traceability, impact level — per
  `conventions.md` §"Canonical memory — per-item format") from the
  task's frontmatter. Field shape (suggested): `task_id`, `sprint`,
  `slug`, `status`, `created_at`, `model`, `traceability` (free-form
  link to the failure/constraint that motivated the task). Final field
  list pinned in `templates/task.md` during gen-spec.

## Open Questions

- **Validator BDD-per-task contract.** Concrete shape of the BDD
  scenario the Validator emits per task file (Given/When/Then template
  fields, fixture references). Pin in
  `templates/acceptance-contract.md` during gen-spec.
