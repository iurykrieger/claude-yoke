<!--
Migrated by .yoke/runtime/migrate-one.sh on 2026-04-30 per
.yoke/prds/2026-04-30-sensor-harness-realignment.md (Sprint 3, t01).
Frontmatter rewritten to new schema: type / token_cost / time_cost
+ command (computational) | agent (inferential). Legacy fields
(class / tier / applies_to / runs) removed. Body shape: How to run
/ Known issues / Frequent errors (+ Calibration for inferential).
-->
---
id: wm-task-helpers-still-callable
type: computational
token_cost: 0
time_cost: 30
command: bash -c 'source lib/working-memory/paths.sh && { ! type wm_task_path >/dev/null 2>&1 && grep -q "Sprint 04 contract" .yoke/contracts/2026-04-27-sprint-as-cycle.md; } || wm_task_path 2026-04-27-sprint-as-cycle 1 1 >/dev/null'
---

# wm-task-helpers-still-callable

## How to run

Run the `command:` declared in the frontmatter. The command is
a deterministic shell invocation; non-zero exit equals sensor
fail. See the source PRD for the calibrated invocation context.

## Known issues

AC scenario 1's additive-helper guarantee. The sensor passes if **either**:
- The legacy `wm_task_path` helper is still callable (the additive guarantee held in cycles 1–3); **or**
- The helper has been hard-removed AND the AC-envelope-authorized supersession is documented in `.yoke/contracts/2026-04-27-sprint-as-cycle.md` "Sprint 04 contract" section (the cycle-4 post-supersession state).
This dual predicate encodes the binding-envelope supersession edge declared by AC scenario 19 (`paths-sh-no-task-helpers`): scenario 1's intent is "the additive helpers were operational while consumers needed them"; once consumers migrate (sprint 3) and the helpers are hard-removed (sprint 4 t02), the supersession satisfies the original intent.

## Frequent errors

- TODO: pattern: TODO — fix.

