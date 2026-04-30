---
id: dispatch-marker-comp
type: computational
token_cost: 0
time_cost: 5
command: touch /tmp/yoke-dispatch-marker-comp
---

# dispatch-marker-comp

## How to run

Touch the marker file `/tmp/yoke-dispatch-marker-comp`. Used
exclusively by `tests/sensors/dispatch-by-type.test.sh` to assert
the computational dispatch path runs the `command:` via shell.

## Known issues

- Marker leaks across runs; the test cleans up before invocation.

## Frequent errors

- Stale marker from a prior crash: rm `/tmp/yoke-dispatch-marker-comp` and re-run.
