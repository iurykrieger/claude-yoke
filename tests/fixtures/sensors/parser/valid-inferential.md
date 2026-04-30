---
id: valid-inferential
type: inferential
token_cost: 1000
time_cost: 60
agent: semantic-judge
---

# valid-inferential

## How to run

Spawned via the Task tool with the `semantic-judge` subagent. Reads
the criterion id and the changeset; writes a verdict JSON to the
deterministic path documented by `hooks/verify-acceptance.sh`.

## Known issues

- Drifts when the model is upgraded; recheck calibration after model upgrade.

## Frequent errors

- Verdict missing supporting_quotes on fail: include at least one quote.

## Calibration

### Prompt

You are a code reviewer. Decide whether the changeset satisfies the
criterion. Return a verdict JSON.

### Rubric

- pass: criterion satisfied with high confidence.
- fail: criterion violated; explain in fix_instruction.

### Verdict schema

```json
{
  "criterion": "<id>",
  "sensor": "valid-inferential",
  "status": "pass|fail",
  "confidence": 0.0,
  "supporting_quotes": ["..."]
}
```

