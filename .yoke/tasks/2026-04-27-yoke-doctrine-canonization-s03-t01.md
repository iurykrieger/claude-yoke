---
task_id: 2026-04-27-yoke-doctrine-canonization-s03-t01
sprint: 3
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s03-t01 — Migrate every `.vibeflow/prds/*.md` to `.yoke/prds/` with date-prefixed slugs derived from each file's first-commit date.

## Story

PRDs are project history — the Phase-1 artifacts that drove every
prior Yoke change. They belong in working memory, not canonical memory.
After this migration, every historical PRD lives at `.yoke/prds/`
alongside the current PRD, satisfying the PRD's invariant that working
memory holds task scratchpads while canonical memory holds doctrine.

## Technical implementation

- Iterate every file under `.vibeflow/prds/` (12 files: `ack-sensors-skill.md`, `ask-source-agnostic-read.md`, `bedrock-canonical-memory-port.md`, `framework-tests-rewrite.md`, `phase-persona-rebalance.md`, `plan-options.md`, `runtime-background-agents.md`, `runtime-only-agents.md`, `tech-spec-task-split.md`, `yoke-runtime-perf-quickwins.md`, `yoke-v1.md`, `yoke-working-memory-folders.md`).
- For each file, derive its slug:
  - Date prefix: `git log --diff-filter=A --follow --format=%cs --reverse -- <path> | head -1` (first-commit date in `YYYY-MM-DD`).
  - Stem: filename without `.md`.
  - Slug: `<YYYY-MM-DD>-<stem>`.
  - Verify the slug satisfies `wm_validate_slug` (regex `^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]{0,49}$`); if the stem exceeds the 50-char limit after the date prefix, hard-fail and surface the conflict so the long-name truncation rule from s03-t02 can be applied here too.
- For each file, run `git mv .vibeflow/prds/<file>.md .yoke/prds/<slug>.md`. `git mv` preserves history so `git log --follow` continues to show pre-migration commits.
- Add `.yoke/prds/` to staging if not already; the destination directory exists from sprint 1's bootstrap.
- Single commit for all 12 moves with title `yoke: migrate .vibeflow/prds/ → .yoke/prds/` and a body listing source-to-destination pairs.

## Validation

- `ls .yoke/prds/*.md | wc -l` returns 13 (12 migrated + the current PRD `2026-04-27-yoke-doctrine-canonization.md`).
- For each migrated PRD, `bash -c 'source lib/working-memory/paths.sh && wm_validate_slug "$1"' _ "<slug>"` exits 0.
- For each migrated PRD, `git log --follow --oneline -- .yoke/prds/<slug>.md` shows commits dating from the original `.vibeflow/prds/<file>.md` history (not just the move commit).
- `ls .vibeflow/prds/*.md | wc -l` returns 0 (every file moved out).

## Acceptance criterion

`ls .yoke/prds/*.md | wc -l` returns exactly 13 AND `ls .vibeflow/prds/*.md 2>&1 | grep -c '^.vibeflow'` returns 0 AND `wm_validate_slug` exits 0 for every migrated slug (deterministic loop in the validation script).
