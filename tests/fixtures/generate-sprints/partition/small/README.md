# Partition small fixture (5 tasks → 1 sprint)

`plan-input.yaml` carries 5 tasks all sharing decision-A + decision-B
overlap. The partition algorithm MUST group them into 1 sprint
(≤ 8-task cap).

`expected-sprint-count` carries the integer `1` — assertion fixture
for `us-005-task-count-bounds.test.sh`.
