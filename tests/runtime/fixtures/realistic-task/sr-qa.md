---
author: sr-qa
cycle: 0
phase: a
slug: 2026-05-01-realistic-task
---

# Sr QA — Phase A slice (realistic-task fixture)

## Phase A — own progress

tests_authored:
  - tests/acceptance/2026-05-01-realistic-task/heading-hierarchy-sensor-shipped.test.sh
  - tests/acceptance/2026-05-01-realistic-task/heading-hierarchy-violation-message-shape.test.sh
  - tests/acceptance/2026-05-01-realistic-task/heading-hierarchy-contract-wired.test.sh

verdicts:
  - criterion: heading-hierarchy-sensor-shipped
    status: PASS
    sensor: tests-runtime
    location: tests/sensors/heading-hierarchy.test.sh
    fix_instruction: ""
    evidence: "smoke test exits 0; sensor file present at .yoke/sensors/heading-hierarchy.md"

  - criterion: heading-hierarchy-violation-message-shape
    status: PARTIAL
    sensor: tests-sensors
    location: lib/sensors/heading-hierarchy.sh:42
    fix_instruction: "violation message currently prints `error:` prefix in two branches; convention requires `wm: heading-hierarchy violation:` consistently — see concepts/yoke-conventions"
    evidence: "fixture run on tests/runtime/fixtures/heading-hierarchy-fail.md emitted `error: H3 follows H1` not `wm: heading-hierarchy violation: H3 follows H1`"

  - criterion: heading-hierarchy-contract-wired
    status: PASS
    sensor: tests-runtime
    location: tests/runtime/fixtures/realistic-task/acceptance-contracts/2026-05-01-realistic-task.md
    fix_instruction: ""
    evidence: "criterion's `### Validation` block names heading-hierarchy as a gating sensor"

## Phase B — réplicas

(empty in this engineered fixture; the irreducibility test only inspects Phase-A shape)
