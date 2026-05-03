# Full-flow fixture

End-to-end fixture for the `us-008-full-flow-smoke.test.sh` and
parts of US-006 Trigger 2.5 tests.

Files:

- `prd.md` — approved PRD stub.
- `spec.md` — approved Tech Spec carrying ≥ 3 contract anchors.
- `acceptance-criteria.md` — ratified AC carrying 4 USs.
- `expected-sprint-count` — integer; expected number of produced
  sprint files for assertion parity. Set to `4` because the QA
  stub-tasks builder (`_lib/build-stub-tasks.sh`) emits one task per US
  with a single shared decision anchor; the partition algorithm
  requires ≥ 2 shared decision anchors to cluster tasks into a single
  sprint, so 4 disjoint tasks → 4 sprints. The real LLM-driven
  synthesis stage is expected to share more decision anchors across
  tasks and may produce fewer sprints; this fixture intentionally
  exercises the disjoint-anchors corner.

The full flow walks `/yoke:discover` → `/yoke:tech-spec` →
`/yoke:acceptance-criteria` → `/yoke:generate-sprints` → first
`/yoke:implement` cycle dry-run.
