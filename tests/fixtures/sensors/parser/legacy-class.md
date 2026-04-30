---
id: legacy-class
type: computational
token_cost: 0
time_cost: 5
command: 'true'
class: computational
---

# legacy-class

## How to run

Invoke true.

## Known issues

- Carries legacy `class:` field; should be rejected by the parser.

## Frequent errors

- legacy class field present: remove `class:` and rely on `type:`.

