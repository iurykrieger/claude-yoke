---
id: legacy-tier
type: computational
token_cost: 0
time_cost: 5
tier: cheap
command: 'true'
---

# legacy-tier

## How to run

Invoke true.

## Known issues

- Carries legacy `tier:` field; should be rejected.

## Frequent errors

- legacy tier field present: remove `tier:` and rely on token_cost / time_cost.

