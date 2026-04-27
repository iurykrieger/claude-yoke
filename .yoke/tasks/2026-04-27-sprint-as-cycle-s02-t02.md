---
task_id: 2026-04-27-sprint-as-cycle-s02-t02
sprint: 2
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-2
---

# Task 2026-04-27-sprint-as-cycle-s02-t02 — `git mv` every `.yoke/specs/<slug>-part-N.md` (24 distinct slugs, 62 files total) to `.yoke/sprints/<slug>-s<NN>.md` with `<NN>` = zero-padded `N`.

## Story

62 legacy spec parts live under `.yoke/specs/` from the pre-2026-04-25 `tech-spec-task-split` rollout. Each one is semantically a sprint-sized chunk (its own Objective, shipped as a separate PR), but the filename declares it as a "part" — wrong directory, wrong shape. This task renames them to the new sprint shape via `git mv`, preserving git history. After this task: `.yoke/specs/` has zero `-part-N.md` files; `.yoke/sprints/` has 62 `<slug>-s<NN>.md` files. The corresponding header reframing happens in t03.

## Technical implementation

- For each of the 24 distinct legacy slugs, enumerate the matching `.yoke/specs/<slug>-part-N.md` files. Use `find .yoke/specs -name '*-part-[0-9]*.md' -type f | sort` to get the deterministic list.
- For each match, parse `<slug>` (everything before `-part-`) and `N` (everything after `-part-`, before `.md`). Compute zero-padded `<NN>` (printf `%02d`). Target path: `.yoke/sprints/<slug>-s<NN>.md`.
- Ensure `.yoke/sprints/` exists: `mkdir -p .yoke/sprints/`.
- For each source/target pair: `git mv "<source>" "<target>"`. Use a guard: if `<target>` already exists (e.g., a slug in the migration overlaps with one we're authoring fresh), abort with a loud `wm: collision at <target>` and stop the whole task. No silent overwrites.
- Do NOT modify file contents in this task. Header reframing is t03; this task is purely path-level moves with `git mv` so history is preserved.
- Special case: legacy specs whose stem includes `-part-N-cleanup` or `-part-N-followup` (look for double `-part-` patterns) are renamed conservatively — keep the second qualifier as a body annotation, not a sprint number. If detected, abort with a `wm: ambiguous part suffix at <path>` and surface to the user. From the inventory above, `2026-04-25-tech-spec-task-split-cleanup-part-*.md` is one such case (3 files). Treat the cleanup variant as a separate slug `2026-04-25-tech-spec-task-split-cleanup` and number its sprints independently (`-s01.md`, `-s02.md`, `-s03.md`).
- Commit the moves in one git commit with message `chore(working-memory): migrate 62 legacy -part-N spec files to sprints/`.

## Validation

- Post-task globs: `find .yoke/specs -name '*-part-[0-9]*.md' -type f | wc -l` = 0; `find .yoke/sprints -name '*-s[0-9][0-9].md' -type f | wc -l` ≥ 62.
- Per-slug smoke: for slug `2026-04-25-bedrock-canonical-memory-port`, assert files `s01.md` through `s06.md` exist under `.yoke/sprints/` (it had 6 parts).
- Git-history smoke: `git log --follow .yoke/sprints/2026-04-25-bedrock-canonical-memory-port-s01.md` shows commits inherited from `.yoke/specs/2026-04-25-bedrock-canonical-memory-port-part-1.md` (proves `git mv` preserved history).
- File-content smoke: `diff .yoke/.legacy-archive/2026-04-27-pre-migration/specs/2026-04-25-bedrock-canonical-memory-port-part-1.md .yoke/sprints/2026-04-25-bedrock-canonical-memory-port-s01.md` shows zero diff (header reframing happens in t03, not here).
- Sensor smoke: `bash lib/sensors/legacy-parts-zero-residual.sh` over `.yoke/specs/` only emits zero violations for the `-part-N.md` check (the `-s<NN>-t<MM>.md` check still emits the 16 task-file violations until t04).

## Acceptance criterion

`find .yoke/specs -name '*-part-[0-9]*.md' -type f | wc -l` returns `0`, AND `find .yoke/sprints -name '*-s[0-9][0-9].md' -type f | wc -l` returns ≥ `62`, AND `git log --follow .yoke/sprints/2026-04-25-bedrock-canonical-memory-port-s01.md --oneline | wc -l` returns ≥ `2` (history preserved).
