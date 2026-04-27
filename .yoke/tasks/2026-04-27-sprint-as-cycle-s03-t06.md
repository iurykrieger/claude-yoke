---
task_id: 2026-04-27-sprint-as-cycle-s03-t06
sprint: 3
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-3
---

# Task 2026-04-27-sprint-as-cycle-s03-t06 — Update `agents/{generator,validator,orchestrator}.md` contracts to read `.yoke/sprints/<slug>-s<NN>.md` as the cycle's working set; sensor and AC-criterion references resolve via ID lookups.

## Story

The runtime subagents (Generator, Validator, Orchestrator) consume working-memory files as their cycle's reading material. Today they iterate per-task files; under the new shape they read one sprint file per cycle. The agent contracts in `agents/*.md` declare what files each agent reads / writes / does not touch — those declarations must match the new shape. Sensor IDs (in the sprint file's `## Sensors` list) and AC criterion IDs (in `## Functional acceptance criteria`) resolve via ID lookups against `.yoke/sensors/<id>.md` and `acceptance-contracts/<slug>.md` respectively.

## Technical implementation

- Edit `agents/generator.md`:
  - Update the "reads" list: `.yoke/sprints/<slug>-s<current_sprint>.md` (the cycle's working set), `.yoke/runtime/progress.md`, `.yoke/contracts/<slug>.md`, `.yoke/acceptance-contracts/<slug>.md` (binding), `.yoke/sensors/<id>.md` (resolved by ID from the sprint file's `## Sensors` list).
  - Update the "writes" list: continues to write to `.yoke/sprints/<slug>-s<current_sprint>.md` (via Edit on `### Task <ID>` anchors), `.yoke/runtime/progress.md` (cycle-log entries), `.yoke/contracts/<slug>.md` on consensus.
  - Remove any reference to `.yoke/tasks/<slug>-s<NN>-t<MM>.md`.
- Edit `agents/validator.md`:
  - Update the "reads" list similarly. Add the sensor-resolution flow: each sensor ID in the sprint file's `## Sensors` list is loaded from `.yoke/sensors/<id>.md`; each AC criterion ID in `## Functional acceptance criteria` is loaded from `.yoke/acceptance-contracts/<slug>.md`.
  - Update verdict-emission: verdicts continue to land at `.yoke/runtime/.judge-verdicts/cycle-<N>/<sensor-id>.json` (sensor ID directly indexes file naming).
- Edit `agents/orchestrator.md`:
  - Update consult-mode reads: `.yoke/sprints/<slug>-s<current_sprint>.md` is the working set the consult queries derive context from.
  - Monitor-mode: divergence detection now per-sprint (not per-task).
  - Canonize-mode: the post-loop canonization packet at `.yoke/runtime/.preserve-packet.md` consumes sprint files for traceability links.
- Replace every `wm_list_task_paths` with `wm_list_sprint_paths` and every `.yoke/tasks/` with `.yoke/sprints/`.
- Cite `concepts/yoke-pattern-roles`, `concepts/yoke-pattern-ralph-loop`, `concepts/yoke-pattern-memory-model`, and the new `concepts/yoke-pattern-sprint-runtime-bundle`.

## Validation

- Static smoke: grep across `agents/{generator,validator,orchestrator}.md` for `wm_list_task_paths` and `.yoke/tasks/` — zero matches.
- Static smoke: grep across the same files for `.yoke/sprints/`, `current_sprint`, sensor-ID-resolution language — at least one match per file.
- Cross-agent consistency smoke: `find agents/ -name '*.md' -exec grep -lE "wm_list_task_paths|\.yoke/tasks/" {} +` returns zero files.
- Reads/writes consistency smoke: the writes list of the Generator does not include any path the Validator's reads list excludes, and vice versa (no role-boundary violations).

## Acceptance criterion

`find agents -name "*.md" -exec grep -lE "wm_list_task_paths|\.yoke/tasks/" {} +` returns no files, AND `grep -l "current_sprint" agents/generator.md agents/validator.md agents/orchestrator.md | wc -l` returns `3`.
