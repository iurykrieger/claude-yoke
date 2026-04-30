---
id: legacy-runs
type: computational
token_cost: 0
time_cost: 5
runs: []
command: 'true'
---

# legacy-runs

## How to run

Invoke true.

## Known issues

- Carries legacy `runs:` field; should be rejected.

## Frequent errors

- legacy runs field present: remove it; sensor file is knowledge base, not log.

