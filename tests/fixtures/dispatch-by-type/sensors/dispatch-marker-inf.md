---
id: dispatch-marker-inf
type: inferential
token_cost: 100
time_cost: 5
agent: dispatch-test-stub
---

# dispatch-marker-inf

## How to run

Spawned by `hooks/verify-acceptance.sh` as a Task call against the
`dispatch-test-stub` subagent. Verdict JSON persists at
`.yoke/runtime/.judge-verdicts/cycle-N/<criterion>--<sensor>.json`.
Used exclusively by `tests/sensors/dispatch-by-type.test.sh`.

## Known issues

- Stub agent — never spawn outside the test fixture.

## Frequent errors

- Missing verdict file: confirm the hook completed without error.

## Calibration

### Prompt

Stub prompt — the dispatch-test-stub agent does not consume real
context. It exists only to exercise the dispatch path.

### Rubric

Stub rubric — pass iff the placeholder verdict was written.

### Verdict schema

```json
{
  "criterion": "<criterion-id>",
  "sensor": "dispatch-marker-inf",
  "status": "pass" | "fail" | "skip",
  "location": null,
  "fix_instruction": null,
  "evidence": "<text>",
  "confidence": 0.0,
  "supporting_quotes": []
}
```
