---
id: legacy-applies-to
type: computational
token_cost: 0
time_cost: 5
applies_to: [some-task]
command: 'true'
---

# legacy-applies-to

## How to run

Invoke true.

## Known issues

- Carries legacy `applies_to:` field; should be rejected.

## Frequent errors

- legacy applies_to field present: remove it; sensors are project-level.

