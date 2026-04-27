---
task_id: 2026-04-27-yoke-doctrine-canonization-s03
sprint: 3
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-yoke-doctrine-canonization.md#sprint-3
Migrated-from: [.yoke/tasks/2026-04-27-yoke-doctrine-canonization-s03-t01.md, .yoke/tasks/2026-04-27-yoke-doctrine-canonization-s03-t02.md]
---

# Sprint 03: Working-memory bulk migration (project history)

## Sprint objective

Every spec and PRD from `.vibeflow/` exists under `.yoke/specs/` and `.yoke/prds/` with date-prefixed slugs that satisfy `wm_validate_slug`, with git history preserved via `git mv`.

## Sprint DoD

- 2026-04-27-yoke-doctrine-canonization-s03-t01: `ls .yoke/prds/*.md | wc -l` returns exactly 13 AND `ls .vibeflow/prds/*.md 2>&1 | grep -c '^.vibeflow'` returns 0 AND `wm_validate_slug` exits 0 for every migrated slug (deterministic loop in the validation script).
- 2026-04-27-yoke-doctrine-canonization-s03-t02: `ls .yoke/specs/*.md | wc -l` equals the pre-migration `.vibeflow/specs/*.md` file count AND `ls .vibeflow/specs/ 2>&1 | grep -c '\.md$'` returns 0 AND `bash tests/lib/migration-helpers.test.sh` exits 0.

## Tasks

### Task 2026-04-27-yoke-doctrine-canonization-s03-t01

**Story:**

PRDs are project history — the Phase-1 artifacts that drove every
prior Yoke change. They belong in working memory, not canonical memory.
After this migration, every historical PRD lives at `.yoke/prds/`
alongside the current PRD, satisfying the PRD's invariant that working
memory holds task scratchpads while canonical memory holds doctrine.

**Technical implementation:**

- Iterate every file under `.vibeflow/prds/` (12 files: `ack-sensors-skill.md`, `ask-source-agnostic-read.md`, `bedrock-canonical-memory-port.md`, `framework-tests-rewrite.md`, `phase-persona-rebalance.md`, `plan-options.md`, `runtime-background-agents.md`, `runtime-only-agents.md`, `tech-spec-task-split.md`, `yoke-runtime-perf-quickwins.md`, `yoke-v1.md`, `yoke-working-memory-folders.md`).
- For each file, derive its slug:
  - Date prefix: `git log --diff-filter=A --follow --format=%cs --reverse -- <path> | head -1` (first-commit date in `YYYY-MM-DD`).
  - Stem: filename without `.md`.
  - Slug: `<YYYY-MM-DD>-<stem>`.
  - Verify the slug satisfies `wm_validate_slug` (regex `^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]{0,49}$`); if the stem exceeds the 50-char limit after the date prefix, hard-fail and surface the conflict so the long-name truncation rule from s03-t02 can be applied here too.
- For each file, run `git mv .vibeflow/prds/<file>.md .yoke/prds/<slug>.md`. `git mv` preserves history so `git log --follow` continues to show pre-migration commits.
- Add `.yoke/prds/` to staging if not already; the destination directory exists from sprint 1's bootstrap.
- Single commit for all 12 moves with title `yoke: migrate .vibeflow/prds/ → .yoke/prds/` and a body listing source-to-destination pairs.

**Validation:**

- `ls .yoke/prds/*.md | wc -l` returns 13 (12 migrated + the current PRD `2026-04-27-yoke-doctrine-canonization.md`).
- For each migrated PRD, `bash -c 'source lib/working-memory/paths.sh && wm_validate_slug "$1"' _ "<slug>"` exits 0.
- For each migrated PRD, `git log --follow --oneline -- .yoke/prds/<slug>.md` shows commits dating from the original `.vibeflow/prds/<file>.md` history (not just the move commit).
- `ls .vibeflow/prds/*.md | wc -l` returns 0 (every file moved out).

**Acceptance criterion:**

`ls .yoke/prds/*.md | wc -l` returns exactly 13 AND `ls .vibeflow/prds/*.md 2>&1 | grep -c '^.vibeflow'` returns 0 AND `wm_validate_slug` exits 0 for every migrated slug (deterministic loop in the validation script).

### Task 2026-04-27-yoke-doctrine-canonization-s03-t02

**Story:**

`.vibeflow/specs/` holds ~53 sprint specs. Their migration is the same
mechanical pattern as s03-t01, but the volume and the long stems
(e.g., `tech-spec-task-split-cleanup-part-3` is 36 chars; `yoke-runtime-perf-quickwins-part-3` is 34 chars) push some slugs past the
50-char-after-date-prefix limit when combined with non-trivial dates.
The truncation rule needs to be defined and centralized.

**Technical implementation:**

- Iterate every file under `.vibeflow/specs/`. For each file:
  - Date prefix and stem derived as in s03-t01.
  - Candidate slug: `<YYYY-MM-DD>-<stem>`.
- Define the long-name truncation rule. Implement it as a reusable bash function `wm_migrate_slug` in a new file `lib/working-memory/migration-helpers.sh`:
  - If `length(<stem>) <= 50`: candidate slug is `<YYYY-MM-DD>-<stem>` directly.
  - If `length(<stem>) > 50`: truncate to 47 chars and append a 2-char short hash derived from the original stem (`echo -n "<stem>" | sha1sum | head -c 2`), separated by a hyphen. Final shape: `<YYYY-MM-DD>-<truncated-47>-<hash-2>` — total 50 chars after the date prefix.
  - Validate against `wm_validate_slug` after construction; if a collision arises (different stems hash to the same 2 chars and truncate to the same 47), increase hash length to 4 and retry once. If still colliding, hard-fail with the offending pair.
- Run `git mv .vibeflow/specs/<file>.md .yoke/specs/<slug>.md` for each file using the resolved slug.
- Single commit for all moves: `yoke: migrate .vibeflow/specs/ → .yoke/specs/ (+truncation-rule helper)`.
- Document the truncation rule inline in `lib/working-memory/paths.sh` next to `wm_validate_slug` so future readers find it without traversing migration helpers.

**Validation:**

- `ls .yoke/specs/*.md | wc -l` equals the original `.vibeflow/specs/*.md` count.
- For each migrated spec, `wm_validate_slug "<slug>"` exits 0.
- `git log --follow --oneline -- .yoke/specs/<slug>.md` shows commits from before the move for at least three sampled files.
- `ls .vibeflow/specs/*.md | wc -l` returns 0.
- The truncation-rule helper has a self-test under `tests/lib/migration-helpers.test.sh` covering: a name under the limit, a name at the limit, a name over the limit, a name forcing the 4-char hash retry. The self-test exits 0.

**Acceptance criterion:**

`ls .yoke/specs/*.md | wc -l` equals the pre-migration `.vibeflow/specs/*.md` file count AND `ls .vibeflow/specs/ 2>&1 | grep -c '\.md$'` returns 0 AND `bash tests/lib/migration-helpers.test.sh` exits 0.

## Functional acceptance criteria

- (criterion IDs to be resolved from .yoke/acceptance-contracts/2026-04-27-yoke-doctrine-canonization.md when that AC artifact migrates to the new shape; left empty for now since the doctrine task already shipped)

## Sensors

- (post-shipped sprint; sensors recorded in audit reports)
