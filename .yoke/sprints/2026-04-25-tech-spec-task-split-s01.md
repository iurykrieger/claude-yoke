# Sprint 01 of 03: Tech Spec Task Split

> Migrated from: # Spec: Tech Spec Task Split — Part 1 — Working-memory layout + bash scaffold


> Generated via /vibeflow:gen-spec on 2026-04-25
> PRD: `.vibeflow/prds/tech-spec-task-split.md`
> Plugin version target: 0.7.0 (working-memory rev)

## Objective

Add the new versioned archive categories `specs/` and `tasks/` to the
working-memory layout, expose helpers for them, and provide a
deterministic bash scaffolder that materializes empty task files from
a spec's task IDs — landing the infrastructure that Parts 2 and 3 will
consume, with no skill-body changes yet.

## Context

The current `lib/working-memory/paths.sh` documents
`tech-specs/<slug>.md` and exposes `wm_tech_spec_path`. The PRD (and
the manifesto's "blueprints wrapping agentic nodes" convention) calls
for tech-spec generation to become a 3-stage blueprint: LLM drafts a
sprint index, **bash** materializes empty per-task files, LLM fills
each. Part 1 lands the bash node and the path helpers — the
deterministic infrastructure that brackets the LLM stages — without
yet rewriting the skill bodies. Parts 2 and 3 then drop in on top.

This part is independently auditable: every change is mechanical, and
the existing Sprint-2 smoke test (`/yoke:bootstrap` → `/yoke:discover`)
must still pass after Part 1 lands, even though no skill consumes the
new helpers yet.

## Definition of Done

1. `lib/working-memory/paths.sh` exposes `wm_spec_path "<slug>"`,
   `wm_task_path "<slug>" <N> <M>`, and `wm_list_task_paths "<slug>"`
   with documented signatures; `WM_ARCHIVE_CATEGORIES` becomes
   `(prds specs tasks tech-specs acceptance-contracts contracts query-traces)`
   — `specs` and `tasks` are added; `tech-specs` is **kept** as a
   transitional category so `wm_tech_spec_path` stays callable. The
   old `wm_tech_spec_path` is preserved as a **deprecated soft alias**
   that continues to return `.yoke/tech-specs/<slug>.md`, prefixed
   with a `# DEPRECATED:` block comment that names the consumers
   still calling it (`lib/ralph-loop/orchestrate.sh`, three
   `agents/*.md`, `skills/{tech-spec,acceptance-contract,implement,bootstrap,discover,status}/SKILL.md`,
   `tests/smoke/{folder-isolation,sprint-4}.test.sh`) and points at
   the final cleanup pass that removes it.
2. `wm_task_path` validates that the slug matches `WM_SLUG_REGEX`,
   that `<N>` and `<M>` are positive integers (non-numeric or zero
   fail), and emits `wm:`-prefixed stderr + non-zero exit on every
   error path; `wm_list_task_paths` echoes one path per line, sorted
   lexically (= positional order via the `s<N>-t<M>` suffix), and
   prints nothing when no task files exist for the slug.
3. `lib/working-memory/scaffold-tasks.sh <spec-path>` parses task IDs
   out of an approved spec body via a deterministic regex (no LLM),
   creates one empty task file per ID at the path `wm_task_path`
   would return, and seeds each with the canonical YAML frontmatter
   stub (`task_id`, `sprint`, `slug`, `status: draft`, `created_at`,
   `model: ""`, `traceability: ""`); existing files at the same path
   are not overwritten — the script exits non-zero with the
   conflicting paths listed.
4. `templates/spec.md` defines the sprint-index shape: per-sprint
   name + delivery objective + ordered task list rendered as one-line
   stories anchored on stable task IDs of the form
   `<slug>-s<N>-t<M>`; cross-cutting sections (overall objective,
   contracts and interfaces, dependencies, out of scope) preserved
   from `templates/tech-spec.md`. **No inline task body** — that lives
   in the per-task file.
5. `templates/task.md` defines the per-task body with the YAML
   frontmatter stub from DoD #3 plus four required body sections —
   *Story*, *Technical implementation*, *Validation*, *Acceptance
   criterion* — and documents that frontmatter doubles as the
   canonization seed for Phase 5 (per
   `.vibeflow/patterns/memory-model.md` rippability fields).
6. **Craftsmanship gate.** All four files pass `shellcheck` (bash
   files), conform to `.vibeflow/conventions.md` Don'ts, follow the
   `patterns/memory-model.md` rules (versioned archive, slug
   discipline, no canonical-memory writes), preserve the idempotent
   re-source guard in `paths.sh`, and target bash 4+. The
   `wm_tech_spec_path` alias carries a `# DEPRECATED:` block comment
   that lists every consumer call site and names the cleanup pass
   that removes it; no consumer of the deprecated alias is expected
   to *break* — calling `wm_tech_spec_path "$slug"` still returns
   `.yoke/tech-specs/<slug>.md` exactly as before.
7. The Sprint-2 smoke test (`tests/smoke/sprint-2.test.sh`) still
   passes end-to-end against a clean test repo. Part 1 introduces no
   regression in the existing `/yoke:bootstrap` → `/yoke:discover`
   path; the new helpers are additive infrastructure not yet wired
   into any skill.

## Scope

- `lib/working-memory/paths.sh` (modify) — replace
  `wm_tech_spec_path` with `wm_spec_path`, add `wm_task_path` and
  `wm_list_task_paths`, swap `tech-specs` → `specs` + `tasks` in
  `WM_ARCHIVE_CATEGORIES`, update the layout doc-comment block at the
  top of the file.
- `lib/working-memory/scaffold-tasks.sh` (new) — pure-bash
  scaffolder. Reads a spec path on argv, parses task IDs, calls
  `wm_task_path` for each, creates the empty file with frontmatter
  stub. No-op if file already exists; exit non-zero on conflict.
- `templates/spec.md` (new) — sprint-index template; shape pinned in
  DoD #4.
- `templates/task.md` (new) — per-task body template; shape pinned in
  DoD #5.

## Anti-scope

- **No skill-body changes** in this part. `skills/tech-spec/SKILL.md`
  and `skills/acceptance-contract/SKILL.md` keep referencing the old
  helpers and the old archive — they will be migrated wholesale in
  Parts 2 and 3, not piecemeal here. The repo will be in a transient
  state where Part 1's helpers exist but no skill calls them; that is
  intentional and bounded by the merge of Part 2.
- **No `templates/tech-spec.md` deletion.** That file is removed in
  Part 2, when the skill no longer references it. Removing it here
  would break the Sprint-2 smoke test (DoD #7).
- **No migration helper.** `migrate-tech-specs.sh` is Part 3 territory.
- **No new pattern doc.** Part 1 *uses* `memory-model.md` and
  `plugin-structure.md`; it does not extend them. Updates to those
  pattern docs to reference the new archive categories ride along in
  Part 2 (where the user-visible behavior changes).
- **No frontmatter consumption.** The task-file frontmatter is *seeded*
  here. The fields are inert until Part 2 has the LLM populate them
  and Phase 5 / `/yoke:preserve` consumes them — which is out of scope
  for this whole PRD.

## Technical Decisions

- **Deprecation, not removal, of `wm_tech_spec_path`** (revised
  decision, 2026-04-25 — supersedes the original "removal" choice
  in this spec's draft). Surface analysis surfaced 11 consumer files
  outside Part 1's 4-file budget — `lib/ralph-loop/orchestrate.sh`,
  three `agents/*.md`, six `skills/*/SKILL.md` files, and two smoke
  tests. A hard removal in Part 1 would either explode the budget or
  leave the runtime broken between merges. The alias is a 10-line
  bridge that keeps every consumer green; a final cleanup pass
  removes it once Parts 2, 3, and the consumer migrations land.
  Trade-off: `wm_tech_spec_path` lives in two places transitively —
  the deprecated alias and the final-cleanup PR. Win: no big-bang
  refactor, no transient broken state, audits remain decidable
  per-part.
- **Task-ID parsing via regex, not YAML/markdown library.** Spec body
  contains task IDs in a fixed shape (`<slug>-s<N>-t<M>`) anchored on
  stable lines per `templates/spec.md`. A `grep -oE` regex is enough;
  pulling in a markdown parser violates "every deterministic node
  saves tokens, reduces errors and guarantees repeatable execution"
  (`conventions.md`). Trade-off: tightly couples the scaffolder to the
  spec template — acceptable, both are owned by Yoke and version-locked.
- **Frontmatter stubs, not full canonical-memory frontmatter.** The
  task file is working memory at this stage; the rippability fields
  (`ratified_at`, `model_calibrated_against`, `last_validated`,
  `traceability`, `impact_level`) are populated only if/when Phase 5
  promotes the task to canonical memory. Seeding `model: ""` and
  `traceability: ""` keeps the field set canonization-ready without
  forging metadata that should come from the Orchestrator under
  Model C.
- **Empty-file creation strict no-overwrite.** The scaffolder is the
  bridge between two LLM stages — surprising overwrites would silently
  destroy LLM-produced content. Better to fail loudly and let the
  caller pick `revise` (Part 2 territory) than to lose work.
- **Bash 4+ only.** Existing convention (`conventions.md` and
  `index.md`); `scaffold-tasks.sh` uses associative arrays and
  `[[ ... =~ ... ]]` features.

## Applicable Patterns

- `.vibeflow/patterns/memory-model.md` — working-memory archive layout,
  per-task lifetime, slug discipline, frontmatter rules. The new
  `specs/` and `tasks/` categories slot into the existing archive
  shape without changing the two-tier model.
- `.vibeflow/patterns/plugin-structure.md` — `templates/` and `lib/`
  conventions for the new files. No new top-level directories.
- `.vibeflow/conventions.md` — "Blueprints wrapping agentic nodes"
  (the deterministic scaffolder bracket between LLM stages) and
  "Bash scripts target bash 4+".

No new pattern introduced. Pattern docs are *referenced*; updates to
`memory-model.md` to reflect the new archive entries land in Part 2
alongside the user-visible behavior change.

## Risks

- **Forgotten cleanup of the deprecated alias.** The
  `wm_tech_spec_path` alias is intentionally short-lived. If the
  consumer migration in Parts 2/3 + final cleanup never lands, the
  alias becomes load-bearing technical debt that contradicts the
  PRD's "no backward-compat shim" anti-scope. **Mitigation:** the
  alias's `# DEPRECATED:` block comment names every consumer call
  site (deterministic punch-list) and the cleanup PR that removes
  it; the comment is intentionally noisy so a casual `grep
  DEPRECATED` surfaces the work; the final cleanup is tracked in
  this PRD as a follow-up part once Parts 2 and 3 are audited PASS.
- **Task-ID regex collision with body text.** A user-edited spec might
  contain text matching the `<slug>-s<N>-t<M>` shape outside the task
  list. **Mitigation:** anchor the regex to the structural
  `templates/spec.md` markers (e.g., scan only inside the
  `## Sprints` section, restrict matches to lines starting with
  `#### Task ` followed by the ID) — pin in `scaffold-tasks.sh` with a
  one-line comment explaining the anchor.
- **Frontmatter drift over time.** Frontmatter shape lives in
  `templates/task.md`; `scaffold-tasks.sh` and (in Part 2) the LLM
  fill stage both must produce the same shape. **Mitigation:** the
  scaffolder reads its frontmatter stub from `templates/task.md`
  (single source of truth), not from an inline heredoc.

## Dependencies

None. This is the foundation part.
