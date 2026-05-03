# Partition large-24-tasks fixture

`plan-input.yaml` carries 24 tasks split into three decision-anchor
groups (A, B, C) of 8 tasks each. The partition algorithm MUST
produce ≥ 3 sprints (one per group), each at the 8-task cap.

`expected-sprint-count` carries the integer `3`.

Used by `us-005-task-count-bounds.test.sh` and
`us-005-partition-determinism.test.sh` (cross-run diff invariant).
