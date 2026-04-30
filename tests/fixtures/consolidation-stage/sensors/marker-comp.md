---
id: marker-comp
type: computational
token_cost: 0
time_cost: 30
command: 'true'
---

# marker-comp

## How to run

Test fixture sensor used by tests/sensors/consolidation-stage.test.sh
to exercise the deterministic body-append + cost-recalibration path
of the /yoke:consolidate-sensors skill. Never run outside the test.

## Known issues

- Test fixture only — no real-world caveats.

## Frequent errors

- curated baseline pattern: a curated bullet that must survive consolidate.
