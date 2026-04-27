---
task_id: 2026-04-27-sprint-as-cycle-s01-t01
sprint: 1
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-1
---

# Task 2026-04-27-sprint-as-cycle-s01-t01 — Add `wm_sprint_path`, `wm_list_sprint_paths`, and `wm_validate_sprint_id` to `lib/working-memory/paths.sh` as additive helpers (old `wm_task_*` helpers untouched).

## Story

The new sprint-bundle shape needs path helpers before any consumer can be migrated. Adding them additively (without touching the existing `wm_task_*` helpers) means the codebase keeps shipping green: old consumers continue to work, new consumers can be authored against the new helpers, and the migration of consumers can happen sprint-by-sprint without a flag-day break. This task is the first additive step; nothing on disk consumes the new helpers yet.

## Technical implementation

- Edit `lib/working-memory/paths.sh`. Add three new functions alongside the existing `wm_*` family, in the same shape and style:
  - `wm_sprint_path <slug> <sprint>` — returns `.yoke/sprints/<slug>-s<NN>.md` where `<NN>` is the zero-padded 2-digit form of `<sprint>`. Uses the existing `_wm_archive_path` helper if present, otherwise composes the path from `WM_ROOT` (or the equivalent constant). Errors with `wm: invalid sprint number` if `<sprint>` is not a positive integer 1–99.
  - `wm_list_sprint_paths <slug>` — globs `.yoke/sprints/<slug>-s*.md` and emits matches in lexical order (which equals positional order via the zero-pad). Returns zero matches as empty stdout (not error).
  - `wm_validate_sprint_id <id>` — exits 0 if `<id>` matches `^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]{0,49}-s[0-9]{2}$`, exits non-zero with `wm: invalid sprint id <id>` otherwise.
- Add `sprints` to `WM_ARCHIVE_CATEGORIES` (alongside the existing `tasks` entry — both coexist this sprint). The category list is what `_wm_archive_path` iterates over to validate path requests.
- Do NOT touch `wm_task_path`, `wm_list_task_paths`, `wm_validate_task_id`, or any other existing helper in this task.
- Do NOT create the `.yoke/sprints/` directory eagerly; `mkdir -p` happens lazily at first write (consistent with how `wm_prd_path` handles `prds/`).
- Cite pattern `concepts/yoke-pattern-memory-model` for the working-memory archive layout invariants the new helpers must satisfy.

## Validation

- Unit-style smoke: invoke `wm_sprint_path "2026-04-27-sprint-as-cycle" 3` from a bash subshell and assert stdout equals `.yoke/sprints/2026-04-27-sprint-as-cycle-s03.md`.
- Padding smoke: `wm_sprint_path "test" 1` returns `…-s01.md`; `wm_sprint_path "test" 12` returns `…-s12.md`.
- Validation smoke: `wm_validate_sprint_id "2026-04-27-sprint-as-cycle-s03"` exits 0; `wm_validate_sprint_id "2026-04-27-sprint-as-cycle-s3"` exits non-zero.
- List smoke: with no sprint files on disk, `wm_list_sprint_paths "any-slug"` exits 0 with empty stdout.
- Backward-compat smoke: every existing `wm_task_path` / `wm_list_task_paths` / `wm_validate_task_id` call site in the codebase continues to resolve (no signature change to the old helpers).
- The existing test in `tests/smoke/sprint-2.test.sh` (working-memory invariants) passes unchanged, since the new functions are additive.

## Acceptance criterion

`bash -c 'source lib/working-memory/paths.sh && wm_sprint_path "2026-04-27-sprint-as-cycle" 3 && wm_validate_sprint_id "2026-04-27-sprint-as-cycle-s03" && wm_list_sprint_paths "no-such-slug"'` exits 0 with stdout containing `.yoke/sprints/2026-04-27-sprint-as-cycle-s03.md`, and `tests/smoke/sprint-2.test.sh` exits 0.
