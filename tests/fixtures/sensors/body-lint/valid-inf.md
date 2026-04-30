---
id: valid-inf
type: inferential
token_cost: 1000
time_cost: 60
agent: semantic-judge
---

# valid-inf

## How to run

Spawn the `semantic-judge` subagent via the Task tool.

## Known issues

- Calibration drifts on model upgrade.

## Frequent errors

- Verdict missing supporting_quotes on fail: include at least one quote.

## Calibration

### Prompt

You are a code reviewer.

### Rubric

- pass: criterion satisfied.
- fail: criterion violated.

### Verdict schema

```json
{"criterion": "...", "status": "pass", "confidence": 0.9, "supporting_quotes": []}
```

