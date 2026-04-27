---
task_id: 2026-04-27-sprint-as-cycle-s04-t02
sprint: 4
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-4
---

# Task 2026-04-27-sprint-as-cycle-s04-t02 — Hard-remove `wm_task_path`, `wm_list_task_paths`, `wm_validate_task_id` from `lib/working-memory/paths.sh`; remove `tasks` from `WM_ARCHIVE_CATEGORIES` (`sprints` already added in sprint 1).

## Story

After all consumers are rewritten (sprint 3) and all data is migrated (sprints 2 + this sprint's t01), the legacy path helpers become unused. The PRD's anti-scope mandates a hard cut — no deprecated alias, no soft delegation. This task removes the three functions and the `tasks` archive category in one commit. After this commit, any reintroduction of `wm_task_*` callers fails at sourcing because the function doesn't exist.

## Technical implementation

- Edit `lib/working-memory/paths.sh`.
- Remove the function definitions for `wm_task_path`, `wm_list_task_paths`, `wm_validate_task_id` (and any helper they call internally that has no other consumer).
- Remove `tasks` from the `WM_ARCHIVE_CATEGORIES` array (or equivalent registration mechanism).
- Verify no other helper depends on those functions (e.g., a `wm_active_slug` doesn't call `wm_validate_task_id` indirectly). If it does, refactor before removing.
- Update any `# DEPRECATED:` block comment in `paths.sh` if one exists for the soon-to-be-removed helpers (cleanup).
- Optionally remove `lib/working-memory/scaffold-tasks.sh` in this same task. If kept (e.g., for git-history reasons), add a `# RETIRED 2026-04-27 — see scaffold-sprints.sh` comment at the top.
- Cite `concepts/yoke-pattern-memory-model` (working-memory archive layout) and `concepts/yoke-conventions` (the no-deprecated-alias rule, ratified per the PRD).
- Commit message: `feat(working-memory): hard-remove wm_task_* helpers and tasks archive category`.

## Validation

- Static smoke: grep `lib/working-memory/paths.sh` for `wm_task_path`, `wm_list_task_paths`, `wm_validate_task_id` — zero matches.
- Static smoke: grep `lib/working-memory/paths.sh` for `tasks` in `WM_ARCHIVE_CATEGORIES` — zero matches; for `sprints` — at least one match.
- Source-and-call smoke: `bash -c 'source lib/working-memory/paths.sh && wm_task_path 2>&1 || true'` exits non-zero with `command not found: wm_task_path`.
- Cross-codebase smoke: `find . -name '*.sh' -o -name '*.md' -path '*/skills/*' -o -name '*.md' -path '*/agents/*' | xargs grep -l 'wm_task_path\|wm_list_task_paths\|wm_validate_task_id' 2>/dev/null | wc -l` returns 0.
- Smoke-test smoke: `bash tests/smoke/sprint-2.test.sh` exits 0 (tests still pass; sensors are now scoped to sprint paths).

## Acceptance criterion

`! grep -qE "wm_task_path|wm_list_task_paths|wm_validate_task_id" lib/working-memory/paths.sh && find skills/ agents/ lib/ -type f \( -name '*.sh' -o -name '*.md' \) -exec grep -lE "wm_task_path|wm_list_task_paths|wm_validate_task_id" {} + | head -1 | wc -l | grep -qE "^\s*0\s*$"` exits 0.
