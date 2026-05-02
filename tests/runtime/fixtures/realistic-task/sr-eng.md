---
author: sr-eng
cycle: 0
phase: a
slug: 2026-05-01-realistic-task
---

# Sr Eng — Phase A slice (realistic-task fixture)

## Phase A — own progress

cited_criterion: heading-hierarchy-sensor-shipped

- file: lib/sensors/heading-hierarchy.sh — implement the heading-hierarchy sensor (parse markdown H1/H2/H3 ordering, emit `wm: heading-hierarchy violation:` on out-of-order or skipped levels)
- file: .yoke/sensors/heading-hierarchy.md — author the per-sensor file with computational command + dispatch metadata + token/time costs
- file: tests/sensors/heading-hierarchy.test.sh — happy-path unit test asserting the sensor exits 0 on a well-formed fixture and non-zero on an engineered violation fixture

sensors_invoked:
  - shellcheck-clean: pass
  - heading-hierarchy: pass on `tests/runtime/fixtures/heading-hierarchy-pass.md`
  - heading-hierarchy: fail (expected) on `tests/runtime/fixtures/heading-hierarchy-fail.md`

self-assessment: passes — the sensor file exists, the lib script exists, the smoke test exits zero, and the cited criterion is closed against the engineered fixtures. Sr QA's acceptance-contract-anchored tests should confirm against the binding contract.

## Phase B — réplicas

(empty in this engineered fixture; the irreducibility test only inspects Phase-A shape)
