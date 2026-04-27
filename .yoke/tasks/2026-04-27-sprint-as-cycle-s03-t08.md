---
task_id: 2026-04-27-sprint-as-cycle-s03-t08
sprint: 3
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-3
---

# Task 2026-04-27-sprint-as-cycle-s03-t08 — Update `templates/spec.md` to render the sprint section as `### Sprint <NN> — <name>` heading whose body lives in `.yoke/sprints/<slug>-s<NN>.md` (instead of inline `#### Task` entries); the spec keeps the cross-sprint architecture and now points to the sprint files.

## Story

`templates/spec.md` defines what `/yoke:tech-spec` Stage 1 produces. Today the template includes inline `#### Task <ID>` entries inside each sprint section. Under the new shape, the spec is the *cross-sprint architecture* — overall objective, contracts and interfaces, dependencies, out-of-scope. Each `### Sprint <NN> — <name>` heading just declares the sprint's existence and its delivery objective; the task list moves to the sprint file. Updating the template is what makes Stage 1's output match the post-migration shape.

## Technical implementation

- Edit `templates/spec.md`.
- Replace the existing sprint block:
  ```
  ### Sprint 1 — <name>
  **Delivery objective:** <…>
  
  #### Task <slug>-s01-t01 — <one-line story>
  #### Task <slug>-s01-t02 — <one-line story>
  ```
  with:
  ```
  ### Sprint 1 — <name>
  **Delivery objective:** <…>
  **Tasks:** <see `.yoke/sprints/<slug>-s01.md` `## Tasks` section>
  ```
- Update the explanatory paragraph above the sprint list:
  - Remove: "Each task is rendered as a one-line story anchored on a stable task ID. The full technical implementation and validation for each task lives in `.yoke/tasks/<task-id>.md`"
  - Replace with: "Each sprint declares its delivery objective. The full sprint runtime bundle — sprint objective, sprint DoD, per-task body (Story / Technical implementation / Validation / Acceptance criterion), functional acceptance criteria (referenced by ID), and sensors (referenced by ID) — lives in `.yoke/sprints/<slug>-s<NN>.md`."
- Update the "Task ID shape" paragraph:
  - Replace with a "Sprint ID shape" paragraph: `<slug>-s<NN>` where `<slug>` matches the existing slug regex, `<NN>` is the sprint number zero-padded to 2 digits. Padding is what makes lexical sort = positional order in `wm_list_sprint_paths`. Tasks within a sprint use `t<MM>` zero-padded by convention but are anchors inside the sprint file (not separate files).
- Preserve every other section: Overall objective, Contracts and interfaces, Dependencies, Out of scope, the trailing "When ready, run /yoke:acceptance-contract" line.
- Cite `concepts/yoke-pattern-phase-flow` (Phase 2), and the new `concepts/yoke-pattern-sprint-runtime-bundle` for the cross-sprint vs. per-sprint split.

## Validation

- Static smoke: grep `templates/spec.md` for `#### Task` and `\.yoke/tasks/` — zero matches.
- Static smoke: grep `templates/spec.md` for `\.yoke/sprints/<slug>-s<NN>.md` and `## Tasks` (in the explanatory text) — at least one match each.
- Section-preservation smoke: `templates/spec.md` retains the H2 headings `## Overall objective`, `## Sprints`, `## Contracts and interfaces`, `## Dependencies`, `## Out of scope`.
- Functional smoke: invoke `/yoke:tech-spec` Stage 1 against a tiny PRD; the produced spec body matches the new template (no `#### Task` entries inside sprint sections; "Tasks: see .yoke/sprints/..." reference present).
- Backward-narrative smoke: any historical comment in the template referring to per-task files (e.g., the lineage paragraph) is updated to mention "post-sprint-as-cycle" naming where it referred to "post-tech-spec-task-split".

## Acceptance criterion

`! grep -qE "^#### Task |\.yoke/tasks/" templates/spec.md && grep -qE "\.yoke/sprints/" templates/spec.md && grep -qE "^## Sprints$" templates/spec.md` exits 0.
