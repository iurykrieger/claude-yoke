<!--
Migrated by .yoke/runtime/migrate-one.sh on 2026-04-30 per
.yoke/prds/2026-04-30-sensor-harness-realignment.md (Sprint 3, t01).
Frontmatter rewritten to new schema: type / token_cost / time_cost
+ command (computational) | agent (inferential). Legacy fields
(class / tier / applies_to / runs) removed. Body shape: How to run
/ Known issues / Frequent errors (+ Calibration for inferential).
-->
---
id: ask-roundtrip-patterns
type: inferential
token_cost: 1500
time_cost: 60
agent: semantic-judge
---

# ask-roundtrip-patterns

## How to run

Spawned by `hooks/verify-acceptance.sh` as a Task call against
the `semantic-judge` subagent. Verdict JSON is persisted at
`.yoke/runtime/.judge-verdicts/cycle-N/<criterion>--<sensor>.json`.
Legacy backing script (pre-realignment): `bash lib/sensors/yoke-ask-roundtrip.sh patterns`.

## Known issues

- No known caveats yet — populated by `/yoke:consolidate-sensors`.

## Frequent errors

- TODO: pattern: TODO — fix.

## Calibration

### Prompt

TODO: populate the exact prompt the `semantic-judge` subagent receives.

### Rubric

TODO: enumerate the pass/fail criteria the subagent applies.

### Verdict schema

Standard inferential envelope:

```json
{
  "criterion": "<criterion-id>",
  "sensor": "ask-roundtrip-patterns",
  "status": "pass" | "fail",
  "location": "<file:line>" | null,
  "fix_instruction": "<text>" | null,
  "evidence": "<text>",
  "confidence": 0.0,
  "supporting_quotes": ["<quote>", "..."]
}
```

