---
task_id: 2026-04-27-sprint-as-cycle-s02-t01
sprint: 2
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-2
---

# Task 2026-04-27-sprint-as-cycle-s02-t01 — Pre-flight backup: copy `.yoke/specs/<slug>-part-*.md` and `.yoke/tasks/2026-04-27-yoke-doctrine-canonization-s*-t*.md` to `.yoke/.legacy-archive/2026-04-27-pre-migration/` (gitignored), preserving relative structure.

## Story

The migration sprint moves and concatenates 78 files. A bad regex on header reframing or a partial concatenation could damage spec content. Restoring from `git reflog` works but is tedious. The pre-flight backup gives a one-step rollback: `cp -R .yoke/.legacy-archive/2026-04-27-pre-migration/* .yoke/`. This task lands the safety net before any move happens, in the FIRST task of sprint 2, so every subsequent migration task assumes the archive exists.

## Technical implementation

- Create the archive root: `mkdir -p .yoke/.legacy-archive/2026-04-27-pre-migration/specs/ .yoke/.legacy-archive/2026-04-27-pre-migration/tasks/`. The `.yoke/.legacy-archive/` directory is gitignored (add to `.yoke/.gitignore` if not already covered by the existing pattern).
- Copy every `.yoke/specs/*-part-[0-9]*.md` to `.yoke/.legacy-archive/2026-04-27-pre-migration/specs/`, preserving filenames. Use `cp -p` to preserve mtime.
- Copy every `.yoke/tasks/2026-04-27-yoke-doctrine-canonization-s*-t*.md` (the 16 doctrine-canonization task files; THIS spec's own task files at `.yoke/tasks/2026-04-27-sprint-as-cycle-s*-t*.md` migrate in sprint 4 and are backed up then) to `.yoke/.legacy-archive/2026-04-27-pre-migration/tasks/`.
- Compute a manifest at `.yoke/.legacy-archive/2026-04-27-pre-migration/MANIFEST.txt` listing each archived path with its sha256 sum (`sha256sum <path> >> MANIFEST.txt`). The manifest is the integrity check: post-migration, restore-and-rehash must reproduce the same sums.
- Update `.yoke/.gitignore` if needed to ensure `.legacy-archive/` is ignored (check with `git check-ignore .yoke/.legacy-archive/test`).
- Cite `concepts/yoke-pattern-memory-model` for the working-memory archive rules and the rationale for keeping the backup off git history (it's a transient one-shot artifact, not doctrine).

## Validation

- Manifest smoke: `wc -l .yoke/.legacy-archive/2026-04-27-pre-migration/MANIFEST.txt` reports 78 lines (62 spec parts + 16 doctrine-canonization task files).
- File-count smoke: `find .yoke/.legacy-archive/2026-04-27-pre-migration/specs -name '*-part-*.md' | wc -l` = 62; `find .yoke/.legacy-archive/2026-04-27-pre-migration/tasks -name '2026-04-27-yoke-doctrine-canonization-s*-t*.md' | wc -l` = 16.
- Gitignore smoke: `git check-ignore .yoke/.legacy-archive/2026-04-27-pre-migration/MANIFEST.txt` exits 0 (path is ignored).
- Hash-roundtrip smoke: pick any one archived file, compute its sha256, compare against the line in MANIFEST.txt — they match.
- Idempotency: re-running the backup is safe (overwrites archive contents; manifest re-emitted).

## Acceptance criterion

`test -f .yoke/.legacy-archive/2026-04-27-pre-migration/MANIFEST.txt && [ "$(wc -l < .yoke/.legacy-archive/2026-04-27-pre-migration/MANIFEST.txt)" = "78" ] && git check-ignore .yoke/.legacy-archive/2026-04-27-pre-migration/MANIFEST.txt` exits 0.
