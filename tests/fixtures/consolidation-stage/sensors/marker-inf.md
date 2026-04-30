---
id: marker-inf
type: inferential
token_cost: 1500
time_cost: 60
agent: semantic-judge
---

# marker-inf

## How to run

Test fixture sensor used by tests/sensors/consolidation-stage.test.sh
to exercise the deterministic body-append + cost-recalibration path
of the /yoke:consolidate-sensors skill on inferential sensors. Never
run outside the test.

## Known issues

- Test fixture only — no real-world caveats.

## Frequent errors

- curated baseline pattern: a curated bullet that must survive consolidate.

## Calibration

### Prompt

Test fixture stub prompt — never spawned outside the test.

### Rubric

Test fixture stub rubric — never evaluated outside the test.

### Verdict schema

```json
{
  "criterion": "<criterion-id>",
  "sensor": "marker-inf",
  "status": "pass" | "fail",
  "location": null,
  "fix_instruction": null,
  "evidence": "<text>",
  "confidence": 0.0,
  "supporting_quotes": []
}
```
