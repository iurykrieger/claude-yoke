---
task_id: 2026-04-27-sprint-as-cycle-s03-t05
sprint: 3
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-3
---

# Task 2026-04-27-sprint-as-cycle-s03-t05 — Update incidental references to per-task paths or `wm_task_*` in `skills/{bootstrap,discover,ack-sensors,preserve}/SKILL.md`; bootstrap creates `.yoke/sprints/` instead of `.yoke/tasks/`.

## Story

Beyond the four primary skill rewrites (tech-spec, acceptance-contract, implement, status), several other skills carry incidental references to the old shape. Bootstrap creates the working-memory skeleton — it must create `.yoke/sprints/` (not `.yoke/tasks/`). Discover, ack-sensors, and preserve may have references to per-task paths in error messages, examples, or "see also" sections. This task sweeps them all in one pass.

## Technical implementation

- Edit `skills/bootstrap/SKILL.md`:
  - Update the `.yoke/` skeleton creation instructions to create `.yoke/sprints/` instead of `.yoke/tasks/`. The directory is created lazily (only at first sprint write); the docs reflect the new structure.
  - Update the example `.yoke/` tree in the skill body to show `sprints/` instead of `tasks/`.
- Edit `skills/discover/SKILL.md`:
  - Update any reference to `.yoke/tasks/<slug>-s*-t*.md` in the "Other tasks' archives" advisory (the skill warns not to modify other tasks' archives — adapt the example to the new shape).
- Edit `skills/ack-sensors/SKILL.md`:
  - Update any reference to per-task file iteration in the readiness-mode logic (the skill validates that every sensor referenced by an Acceptance Contract has a `.yoke/sensors/<id>.md` file — its iteration source may need updating from per-task AC iteration to per-sprint).
- Edit `skills/preserve/SKILL.md`:
  - Update references in the canonization-packet example to point at sprint files instead of task files where applicable. The packet example showing what gets ratified into canonical memory should mirror the new shape.
- For each file, do NOT change behavior — only the path/identifier references. Rewrites should be `s/wm_list_task_paths/wm_list_sprint_paths/g` and `s|.yoke/tasks/|.yoke/sprints/|g`-style passes plus narrow contextual edits where the example logic refers to per-task structure.
- Cite `concepts/yoke-pattern-plugin-structure` (skill layout) and `concepts/yoke-pattern-memory-model` (working-memory structure).

## Validation

- Static smoke (each file): grep for `wm_list_task_paths` — zero matches; grep for `.yoke/tasks/` — zero matches in skill body (excluding any historical-narrative comments which should be removed too).
- Functional smoke for bootstrap: invoke `/yoke:bootstrap` from a clean state; assert `.yoke/sprints/` exists in the resulting directory tree; `.yoke/tasks/` does not.
- Cross-skill consistency smoke: `find skills/ -name 'SKILL.md' -exec grep -l 'wm_list_task_paths\|\.yoke/tasks/' {} +` returns zero files.
- Behavior-preservation smoke: each modified skill's primary functional smoke (from its own existing test suite) still passes — bootstrap creates working memory, discover starts a new task, ack-sensors lists sensors, preserve drafts a packet.

## Acceptance criterion

`find skills/{bootstrap,discover,ack-sensors,preserve} -name 'SKILL.md' -exec grep -lE "wm_list_task_paths|\.yoke/tasks/" {} +` returns no files.
