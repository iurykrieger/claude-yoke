<!--
Migrated by .yoke/runtime/migrate-one.sh on 2026-04-30 per
.yoke/prds/2026-04-30-sensor-harness-realignment.md (Sprint 3, t01).
Frontmatter rewritten to new schema: type / token_cost / time_cost
+ command (computational) | agent (inferential). Legacy fields
(class / tier / applies_to / runs) removed. Body shape: How to run
/ Known issues / Frequent errors (+ Calibration for inferential).
-->
---
id: chosen-file-zero-vibeflow
type: computational
token_cost: 0
time_cost: 30
command: |
  test "$(grep -cF '.vibeflow/' "$(cat .yoke/runtime/cutover-slice-file.txt)")" = "0"
---

# chosen-file-zero-vibeflow

## How to run

Run the `command:` declared in the frontmatter. The command is
a deterministic shell invocation; non-zero exit equals sensor
fail. See the source PRD for the calibrated invocation context.

## Known issues

- No known caveats yet — populated by `/yoke:consolidate-sensors`.

## Frequent errors

- TODO: pattern: TODO — fix.

