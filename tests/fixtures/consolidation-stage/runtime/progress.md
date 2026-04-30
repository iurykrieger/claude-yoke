---
slug: 2026-04-30-consolidation-fixture
current_sprint: "01"
completed_sprints: []
cycle_count: 3
---

# Progress (synthetic for tests/sensors/consolidation-stage.test.sh)

## Sensor cost observations

# Synthetic per-sensor observed durations (3 cycles each); the test's
# consolidate wrapper reads these blocks to drive the 5%-threshold
# recalibration check.

marker-comp:
  time_cost_observed: 13
  token_cost_observed: 0

marker-inf:
  time_cost_observed: 82
  token_cost_observed: 1500
