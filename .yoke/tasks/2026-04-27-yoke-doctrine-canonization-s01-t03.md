---
task_id: 2026-04-27-yoke-doctrine-canonization-s01-t03
sprint: 1
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s01-t03 — Migrate one of each artifact type as the proof slice.

## Story

Before bulk migration in sprints 2 and 3, prove the migration shape
works for one of each artifact type. If `/yoke:teach` chokes on a
particular shape (e.g., the decision-log split, or a frontmatter the
upstream Bedrock skill doesn't expect), we discover it on six
ingestions, not eighty. The slice is the recursive-failure-of-dogfood
canary from the PRD's risk list.

## Technical implementation

- Pick the slice (one of each kind):
  - **Pattern:** `.vibeflow/patterns/roles.md` (most-referenced pattern in framework code, per the s01-t01 inventory; highest-value to migrate first).
  - **Decision:** the most-recent decision in `.vibeflow/decisions.md` (today: "2026-04-25 — Generator subagent persona = Senior Developer").
  - **Policy:** `.vibeflow/conventions.md` (single entity for the whole conventions doc, `kind: policy`).
  - **Audit:** the most-recent file in `.vibeflow/audits/` (alphabetic last after sort).
  - **Spec:** `.vibeflow/specs/yoke-v1-sprint-1.md` (oldest spec; lowest risk for slug truncation).
  - **PRD:** `.vibeflow/prds/yoke-v1.md` (the seed PRD).
- For pattern, decision, policy, audit: invoke `/yoke:teach` with the source path plus a target-shape spec (kind, tags, destination path, ratification date preserved verbatim from source). Each call writes one entity into the vault checkout.
- For spec and PRD: derive a slug from the file's first-commit date (`git log --diff-filter=A --follow --format=%cs --reverse -- <path> | head -1`); `git mv` the file to `.yoke/specs/<slug>.md` or `.yoke/prds/<slug>.md`. Confirm the slug matches `wm_validate_slug`.
- After each migration, perform a `/yoke:ask` round-trip (one query per migrated entity, picked to hit a substring unique to that entity).
- Append each migrated entity's path to the `## Doctrine entities` section of `projects/claude-yoke.md` (created in s01-t02). Open a Model C PR for that single change.

## Validation

- Six entities exist at expected paths: `concepts/yoke-pattern-roles.md`, `concepts/yoke-decision-2026-04-25-generator-subagent-persona-senior-developer.md` (or equivalent slug), `concepts/yoke-conventions.md`, one `discussions/yoke-audit-*.md` file, one `.yoke/specs/<slug>.md`, one `.yoke/prds/<slug>.md`.
- Each entity's frontmatter contract is satisfied (every required key present and non-empty).
- Six `/yoke:ask` round-trip queries return non-empty hits whose responses include the entity's filename or a substring lifted verbatim from the entity's body.
- `projects/claude-yoke.md` now lists six bullets under `## Doctrine entities` (the four canonical-memory entities; specs/PRDs are working memory and do NOT backlink to the project entity).

## Acceptance criterion

The four canonical-memory slice entities exist in `iury-brain`'s checkout AND the two working-memory slice files exist in `.yoke/specs/` and `.yoke/prds/`, AND running the six pre-defined `/yoke:ask` round-trip queries (committed in this task file's Validation section as a script) produces six non-empty responses each containing the corresponding entity's filename verbatim.
