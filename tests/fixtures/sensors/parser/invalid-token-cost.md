---
id: invalid-token-cost
type: computational
token_cost: -1
time_cost: 5
command: 'true'
---

# invalid-token-cost

## How to run

Invoke true.

## Known issues

- token_cost is negative; parser should reject.

## Frequent errors

- negative token_cost: use a non-negative integer.

