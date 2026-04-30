---
id: cheap-comp
type: computational
token_cost: 0
time_cost: 10
command: 'true'
---

# cheap-comp

## How to run

Invoke `bash -c true`. Exits 0 unconditionally; serves as a `time_cost: 10`
fixture for the cost-filter test.

## Known issues

- Always green; useful only as a fixture.

## Frequent errors

- Empty file: ensure the fixture body has the required sections.
