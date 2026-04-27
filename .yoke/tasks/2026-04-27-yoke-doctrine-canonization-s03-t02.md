---
task_id: 2026-04-27-yoke-doctrine-canonization-s03-t02
sprint: 3
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s03-t02 — Migrate every `.vibeflow/specs/*.md` to `.yoke/specs/` with the same slug derivation, including the long-name truncation rule.

## Story

`.vibeflow/specs/` holds ~53 sprint specs. Their migration is the same
mechanical pattern as s03-t01, but the volume and the long stems
(e.g., `tech-spec-task-split-cleanup-part-3` is 36 chars; `yoke-runtime-perf-quickwins-part-3` is 34 chars) push some slugs past the
50-char-after-date-prefix limit when combined with non-trivial dates.
The truncation rule needs to be defined and centralized.

## Technical implementation

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

## Validation

- `ls .yoke/specs/*.md | wc -l` equals the original `.vibeflow/specs/*.md` count.
- For each migrated spec, `wm_validate_slug "<slug>"` exits 0.
- `git log --follow --oneline -- .yoke/specs/<slug>.md` shows commits from before the move for at least three sampled files.
- `ls .vibeflow/specs/*.md | wc -l` returns 0.
- The truncation-rule helper has a self-test under `tests/lib/migration-helpers.test.sh` covering: a name under the limit, a name at the limit, a name over the limit, a name forcing the 4-char hash retry. The self-test exits 0.

## Acceptance criterion

`ls .yoke/specs/*.md | wc -l` equals the pre-migration `.vibeflow/specs/*.md` file count AND `ls .vibeflow/specs/ 2>&1 | grep -c '\.md$'` returns 0 AND `bash tests/lib/migration-helpers.test.sh` exits 0.
