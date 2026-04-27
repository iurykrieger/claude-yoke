---
task_id: 2026-04-27-yoke-doctrine-canonization-s01-t04
sprint: 1
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s01-t04 — Cut over one framework file end-to-end as proof of the rewrite path.

## Story

Before bulk cutover in sprint 4, prove the rewrite path on a single
file. The chosen file should have multiple `.vibeflow/` references so
the rewrite covers both `/yoke:ask` invocations (for doctrine) and
working-memory paths (for project history). If `/yoke:ask`
invocation patterns don't compose cleanly inside skill prose, we
catch it once, not 50 times.

## Technical implementation

- Read `.yoke/runtime/vibeflow-inventory.txt` (produced by s01-t01) and pick the file with the highest count of distinct `.vibeflow/` references inside `skills/` or `agents/`. Tie-break alphabetically. The chosen path is recorded in this task's `traceability` field at completion.
- For each `.vibeflow/` reference in the chosen file:
  - **Doctrine reference** (matches `.vibeflow/patterns/*` or `.vibeflow/decisions.md` or `.vibeflow/conventions.md`): rewrite to a `/yoke:ask` invocation phrase. The exact phrasing pattern is documented inline in this task's Validation section so sprint-4 tasks reuse it verbatim.
  - **Project-history reference** (matches `.vibeflow/specs/*` or `.vibeflow/prds/*`): rewrite to the corresponding `.yoke/specs/<slug>.md` or `.yoke/prds/<slug>.md` path. For specs/PRDs not yet migrated, hold the rewrite until s01-t03's slice migration covers them, OR pick a different file. The slice contains one spec and one PRD — the chosen file should reference at most those two project-history items.
  - **Index reference** (`.vibeflow/index.md`): rewrite to a `/yoke:ask` invocation about the project entity (`projects/claude-yoke.md`).
- Preserve all surrounding prose verbatim. The rewrite is a pure string substitution at the reference; nothing else in the file changes.
- The rewrite-pattern decisions made here (exact `/yoke:ask` phrasing, query verb form, citation style) become the convention sprint 4's bulk cutover follows.

## Validation

- `grep -F '.vibeflow/' <chosen-file>` returns 0 matches.
- The file's YAML frontmatter (if a skill) parses as valid YAML; if a Markdown agent file, the frontmatter is unchanged.
- Diff the file against its pre-cutover version: only `.vibeflow/`-bearing lines are altered, plus minimal prose adjustments to maintain sentence structure.
- A documented "rewrite-pattern key" is committed in this task file's Validation section, listing each reference category and its replacement template (e.g., `.vibeflow/patterns/X.md → /yoke:ask "describe the X pattern (concepts/yoke-pattern-X)"`).
- The chosen file is hand-read end-to-end after the rewrite to verify internal consistency.

## Acceptance criterion

`grep -cF '.vibeflow/' <chosen-file>` returns 0 AND the file's first 10 lines (frontmatter region for skills, intro region for agents) parse without YAML / markdown errors AND this task file's Validation section contains the rewrite-pattern key as a committed artifact for sprint 4's bulk cutover.
