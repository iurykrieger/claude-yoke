---
task_id: 2026-04-27-sprint-as-cycle-s03-t02
sprint: 3
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-3
---

# Task 2026-04-27-sprint-as-cycle-s03-t02 — Rewrite `skills/acceptance-contract/SKILL.md` to address task IDs as `### Task <ID>` anchors inside `.yoke/sprints/<slug>-s<NN>.md` instead of standalone task files; criterion IDs unchanged.

## Story

The acceptance-contract skill drafts BDD scenarios per task. Today it iterates `.yoke/tasks/<slug>-s<NN>-t<MM>.md` files; under the new shape it iterates `### Task <ID>` anchors inside sprint files. The criterion IDs (AC-1, AC-2.3) are unchanged — they continue to live in `.yoke/acceptance-contracts/<slug>.md` as the binding source of truth, referenced by sprint files via the `## Functional acceptance criteria` section. This task rewires the iteration source without changing the AC artifact's shape.

## Technical implementation

- Edit `skills/acceptance-contract/SKILL.md`.
- Replace every reference to `wm_list_task_paths` with `wm_list_sprint_paths` + an inner pass that extracts `### Task <ID>` anchors from each sprint file body (use `grep -nE "^### Task " <sprint-file>` to enumerate anchors).
- Replace every reference to `.yoke/tasks/<slug>-s<NN>-t<MM>.md` with the anchor form: `.yoke/sprints/<slug>-s<NN>.md#task-<task-id>` (the GitHub-style heading anchor; downstream tooling resolves `#task-<id>` to the H3 location).
- Update the BDD scenario authoring instructions: each scenario maps to a `### Task <ID>` anchor inside a sprint file. The Validator iterates the sprint file's task anchors and resolves Acceptance criterion via the `**Acceptance criterion:**` inline label per task.
- Preserve every OTHER aspect of the skill: the binding statement, the criterion ID format (`AC-1`, `AC-2.3`), the rippability frontmatter contract, the sensor binding rules, the approval-menu integration. Only the working-memory iteration source changes.
- Update the `revise` semantics: deletion now removes `wm_acceptance_contract_path` (unchanged — AC artifacts stay one-file-per-task).
- Cite `concepts/yoke-pattern-phase-flow` (Phase 3), `concepts/yoke-pattern-acceptance-contract`, and the new `concepts/yoke-pattern-sprint-runtime-bundle` for the anchor-based reference.

## Validation

- Static smoke: grep `skills/acceptance-contract/SKILL.md` for `wm_list_task_paths` — zero matches; for `wm_list_sprint_paths` — at least one match.
- Static smoke: grep `skills/acceptance-contract/SKILL.md` for `.yoke/tasks/` — zero matches; for `.yoke/sprints/` and `### Task` — at least one match each.
- Functional smoke: invoke `/yoke:acceptance-contract` against a slug with 2 sprints (4 tasks total spread across them); assert it iterates 4 task anchors (not 4 task files), produces 4 BDD scenarios, references criterion IDs in the sprint files' `## Functional acceptance criteria` lists.
- Binding-shape preservation smoke: the AC artifact at `.yoke/acceptance-contracts/<slug>.md` shape is unchanged (single file, criterion IDs, BDD scenarios) — verify by diffing the doctrine-canonization AC's shape vs. a freshly-generated one for a small synthetic slug.

## Acceptance criterion

`! grep -qE "wm_list_task_paths|\.yoke/tasks/" skills/acceptance-contract/SKILL.md && grep -qE "wm_list_sprint_paths" skills/acceptance-contract/SKILL.md && grep -qE "### Task " skills/acceptance-contract/SKILL.md` exits 0.
