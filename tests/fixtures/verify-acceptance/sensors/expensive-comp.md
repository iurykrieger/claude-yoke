---
id: expensive-comp
type: computational
token_cost: 0
time_cost: 60
command: 'true'
---

# expensive-comp

## How to run

Invoke `bash -c true`. Exits 0 unconditionally; serves as a `time_cost: 60`
fixture for the cost-filter test (filtered out by `--max-time-cost 30`).

## Known issues

- Always green; useful only as a fixture.

## Frequent errors

- Empty file: ensure the fixture body has the required sections.
