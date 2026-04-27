---
task_id: 2026-04-27-sprint-as-cycle-s03-t01
sprint: 3
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-3
---

# Task 2026-04-27-sprint-as-cycle-s03-t01 — Rewrite `skills/tech-spec/SKILL.md` to invoke `scaffold-sprints.sh` instead of `scaffold-tasks.sh`, fill sprint files (not task files) in stage 3, and apply approval to sprint files via `wm_list_sprint_paths`.

## Story

`/yoke:tech-spec` is the producer of the working-memory shape for every future task. Rewriting it is the single largest consumer-side change: the 3-stage blueprint stays (Stage 1 spec index, Stage 2 deterministic scaffold, Stage 3 LLM-per-unit), but Stage 2 now scaffolds sprint files and Stage 3 fills sprint files. The skill keeps its `task_summary` block in the approval menu — but now each entry is one sprint with its tasks listed inline, not one task file. Approval applies status to sprint files via `wm_list_sprint_paths`. After this task, every NEW task created via `/yoke:tech-spec` lands directly in the sprint shape with no per-task files.

## Technical implementation

- Edit `skills/tech-spec/SKILL.md`.
- Replace every reference to `lib/working-memory/scaffold-tasks.sh` with `lib/working-memory/scaffold-sprints.sh`.
- Replace every reference to `wm_list_task_paths` with `wm_list_sprint_paths`.
- Replace every reference to `.yoke/tasks/<slug>-s<NN>-t<MM>.md` with `.yoke/sprints/<slug>-s<NN>.md`.
- Update Stage 1 instructions: the spec body uses `### Sprint <N> — <name>` headings (existing template shape) but body of the sprint section in the spec is now just the delivery objective and the task list as one-liners (no `#### Task <ID>` sub-headings inside the spec; those move to the sprint file's `## Tasks` section).
- Update Stage 2 instructions: invoke `scaffold-sprints.sh` against the spec; expect one empty sprint file per `### Sprint <N>` heading.
- Update Stage 3 instructions: for each sprint file in `wm_list_sprint_paths`, fill (a) `## Sprint objective`, (b) `## Sprint DoD`, (c) `## Tasks` — one `### Task <ID>` subsection per task with the four inline labels (`**Story:**`, `**Technical implementation:**`, `**Validation:**`, `**Acceptance criterion:**`), (d) `## Functional acceptance criteria` placeholder (criterion IDs are filled by Phase 3 / `/yoke:acceptance-contract`), (e) `## Sensors` (sensor IDs from the manifest, scoped to the sprint).
- Update the approval menu inputs: `task_summary` becomes `sprint_summary` (preserve the variable name in the menu template per `templates/approval-menu.md`'s contract — actually keep `task_summary` for backward shape compatibility, but each entry is now `(sprint_id, sprint name, file_path)`).
- Update the `revise` semantics: deletion now removes `wm_spec_path` + every path returned by `wm_list_sprint_paths` for the active slug.
- Update the approval-recording step: iterate `wm_list_sprint_paths` and set `status: approved` on each sprint file's frontmatter.
- DO NOT remove references to OLD helpers in this task — sprint 4 hard-removes them. The skill rewrite assumes the new helpers (sprint 1) exist; OLD helpers may still be present in `paths.sh` until sprint 4 t02 retires them.
- Cite `concepts/yoke-pattern-phase-flow` (Phase 2), `concepts/yoke-pattern-roles` (Generator persona), and the new `concepts/yoke-pattern-sprint-runtime-bundle` (drafted in sprint 4 t06).

## Validation

- Static smoke: grep `skills/tech-spec/SKILL.md` for `scaffold-tasks.sh` — zero matches; for `scaffold-sprints.sh` — at least one match.
- Static smoke: grep `skills/tech-spec/SKILL.md` for `wm_list_task_paths` — zero matches; for `wm_list_sprint_paths` — at least one match.
- Static smoke: grep `skills/tech-spec/SKILL.md` for `.yoke/tasks/` — zero matches in skill body.
- Functional smoke: invoke `/yoke:tech-spec` from a clean state on a tiny PRD with 2 sprints; assert that `.yoke/sprints/<slug>-s01.md` and `<slug>-s02.md` are created (no `.yoke/tasks/` files); each sprint file has the 5 required H2 sections; approval flips `status: approved` on both sprint files.
- Existing-skill regression: this task touches ONLY `skills/tech-spec/SKILL.md`. No other consumer is modified here; siblings are scope of t02–t08.

## Acceptance criterion

`! grep -qE "scaffold-tasks\.sh|wm_list_task_paths|\.yoke/tasks/" skills/tech-spec/SKILL.md && grep -qE "scaffold-sprints\.sh|wm_list_sprint_paths|\.yoke/sprints/" skills/tech-spec/SKILL.md` exits 0.
