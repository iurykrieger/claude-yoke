---
task_id: 2026-04-27-yoke-doctrine-canonization-s02-t01
sprint: 2
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s02-t01 — Migrate the remaining eight patterns from `.vibeflow/patterns/` into `concepts/yoke-pattern-*.md`.

## Story

Sprint 1's slice migrated `roles.md` to prove the path. Eight patterns
remain: `acceptance-contract`, `human-triggers`, `memory-model`,
`model-c-governance`, `phase-flow`, `plugin-structure`, `ralph-loop`,
`sensors`. After this task, every framework pattern is queryable via
`/yoke:ask` — the precondition for sprint-4's bulk cutover under
`skills/` and `agents/`.

## Technical implementation

- Iterate the eight pattern files in alphabetical order. For each:
  - Source: `.vibeflow/patterns/<stem>.md`.
  - Destination: `<iury-brain-checkout>/concepts/yoke-pattern-<stem>.md`.
  - Frontmatter: `kind: pattern`, `tags: [yoke-framework]`, `ratified: <date>` (preserved from the pattern's own ratification or first commit), `last_validated: 2026-04-27`, `traceability: <link to motivating decision in concepts/yoke-decision-*>`, `status: active`, `project: claude-yoke`.
  - Body: pattern doc verbatim, with intra-doc references rewritten to point at the migrated entity names (e.g., a `[see roles.md](roles.md)` becomes `[see roles pattern](concepts/yoke-pattern-roles.md)`).
- Invoke `/yoke:teach` per file with the source path + target shape; the skill ingests, frontmatters, and writes. If `/yoke:teach` cannot accept eight invocations cleanly (rate-limit, batch-size cap), surface the error per the PRD's recursive-failure-of-dogfood signal — do not bypass the skill.
- After each migration, run a one-query `/yoke:ask` round-trip (e.g., for `yoke-pattern-sensors`: `/yoke:ask "describe Yoke's sensors pattern"`).
- Append all eight new entity paths to `projects/claude-yoke.md`'s `## Doctrine entities` section in a single Model C PR after all eight are written.

## Validation

- `ls <iury-brain-checkout>/concepts/yoke-pattern-*.md | wc -l` returns 9 (the slice from s01-t03 plus the eight added here).
- Each new entity's frontmatter passes the deterministic key check (every required key present, non-empty).
- Eight `/yoke:ask` round-trip queries — one per new pattern — return responses that cite the entity by filename and include a substring lifted from the entity body.
- The single Model C PR appending eight bullets to `projects/claude-yoke.md` is merged; checkout is sync'd.

## Acceptance criterion

`ls <iury-brain-checkout>/concepts/yoke-pattern-*.md | wc -l` returns exactly 9 AND a script of eight `/yoke:ask` queries (committed in the Validation section) produces eight non-empty responses each containing the corresponding `concepts/yoke-pattern-<stem>.md` filename verbatim.
