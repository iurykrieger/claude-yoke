<!--
Migrated by .yoke/runtime/migrate-one.sh on 2026-04-30 per
.yoke/prds/2026-04-30-sensor-harness-realignment.md (Sprint 3, t01).
Frontmatter rewritten to new schema: type / token_cost / time_cost
+ command (computational) | agent (inferential). Legacy fields
(class / tier / applies_to / runs) removed. Body shape: How to run
/ Known issues / Frequent errors (+ Calibration for inferential).
-->
---
id: legacy-parts-residual-shape
type: computational
token_cost: 0
time_cost: 30
command: bash -c 'output=$(bash lib/sensors/legacy-parts-zero-residual.sh 2>/dev/null); [ -z "$output" ] || echo "$output" | head -1 | jq -e ".criterion and .status and .location and .fix_instruction and .sensor and .evidence" >/dev/null'
---

# legacy-parts-residual-shape

## How to run

Run the `command:` declared in the frontmatter. The command is
a deterministic shell invocation; non-zero exit equals sensor
fail. See the source PRD for the calibrated invocation context.

## Known issues

Sensor registered for the `2026-04-27-sprint-as-cycle` Acceptance Contract.

## Frequent errors

- TODO: pattern: TODO — fix.

