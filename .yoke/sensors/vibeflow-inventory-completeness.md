<!--
Migrated by .yoke/runtime/migrate-one.sh on 2026-04-30 per
.yoke/prds/2026-04-30-sensor-harness-realignment.md (Sprint 3, t01).
Frontmatter rewritten to new schema: type / token_cost / time_cost
+ command (computational) | agent (inferential). Legacy fields
(class / tier / applies_to / runs) removed. Body shape: How to run
/ Known issues / Frequent errors (+ Calibration for inferential).
-->
---
id: vibeflow-inventory-completeness
type: computational
token_cost: 0
time_cost: 30
command: |
  test "$(comm -23 <(grep -rn --include='*.md' --include='*.sh' --include='*.yaml' --include='*.json' '.vibeflow/' skills/ agents/ hooks/ lib/ templates/ | grep -oE '[a-z]+/[^ ]+:[0-9]+' | sort -u) <(awk '/^## Validation/,/^## Acceptance criterion/' .yoke/tasks/2026-04-27-yoke-doctrine-canonization-s01-t01.md | grep -oE '[a-z]+/[^ ]+:[0-9]+' | sort -u) | wc -l | tr -d ' ')" = "0"
---

# vibeflow-inventory-completeness

## How to run

Run the `command:` declared in the frontmatter. The command is
a deterministic shell invocation; non-zero exit equals sensor
fail. See the source PRD for the calibrated invocation context.

## Known issues

- No known caveats yet — populated by `/yoke:consolidate-sensors`.

## Frequent errors

- TODO: pattern: TODO — fix.

