# Realistic-task fixture

Engineered fixture for the Sprint 03 persona-retooling tests. The
fixture stands in for a real Yoke task description so the runtime
tests can assert each persona's distinct-lens behaviour without
spawning live council subagents on a real cycle.

## Task description (the input the council would read)

A host project wants to add a new sensor that grades a markdown
file's heading hierarchy. The sensor must:

- live at `.yoke/sensors/heading-hierarchy.md` (per-sensor file);
- expose a computational command (`bash lib/sensors/heading-hierarchy.sh <file>`);
- emit `wm: heading-hierarchy violation: <reason>` on failure;
- be wired into one Acceptance Contract criterion's `### Validation`
  block in a fixture contract under
  `tests/runtime/fixtures/realistic-task/acceptance-contracts/2026-05-01-realistic-task.md`;
- carry a smoke test under `tests/sensors/heading-hierarchy.test.sh`.

The cycle's failing criterion (engineered) is
`heading-hierarchy-sensor-shipped` — a binary observable assertion
that the sensor file exists, the lib script exists, the contract
references the sensor id, and the smoke test exits zero.

## Why this fixture is "realistic"

The five constraints above mirror the Yoke conventions that ship in
canonical memory at `concepts/yoke-conventions` and
`concepts/yoke-pattern-sensors`. A council cycle on this fixture
should produce findings from each persona's distinct lens:

- **Sr Eng** ships the sensor + lib script + smoke test (production
  code + happy-path unit test). Sr Eng's slice records `- file:`
  lines under `## Phase A — own progress` and stays out of
  `tests/acceptance/`.
- **Sr QA** writes one acceptance-contract-anchored test per
  criterion in the fixture contract under
  `tests/acceptance/2026-05-01-realistic-task/<criterion-id>.test.sh`,
  judges the gating sensor verdicts, and refutes any "passes" claim
  the test contradicts.
- **Sr Staff** invokes the configured `review-skill` (default
  `/review`) once against the cycle's diff, queries canonical
  memory via `/yoke:search-canonical-memory` for the ratified
  sensor pattern (`concepts/yoke-pattern-sensors`), and writes the
  long-term-sustainability verdict.

## Slice files committed in this fixture

The three `*.md` files at the fixture root are the engineered
post-Phase-A slice outputs for the realistic-task cycle:

- `sr-eng.md` — engineered Sr Eng slice (carries `- file:` lines,
  no `tests/acceptance/` reference, names a unit test under
  `tests/sensors/`).
- `sr-qa.md` — engineered Sr QA slice (per-criterion verdicts,
  references tests under
  `tests/acceptance/2026-05-01-realistic-task/`).
- `sr-staff.md` — engineered Sr Staff slice (exactly one
  `### Review output` subsection, at least one
  `/yoke:search-canonical-memory` query record, zero `/ultrareview`
  tokens, names the ratified pattern from canonical memory).

The runtime tests `tests/runtime/sr-eng-prompt-shape.test.sh`,
`tests/runtime/sr-qa-prompt-shape.test.sh`,
`tests/runtime/sr-qa-test-directory.test.sh`,
`tests/runtime/sr-staff-prompt-shape.test.sh`, and
`tests/runtime/sr-staff-review-invocation.test.sh` consume these
slice files (or assert on the persona prompt files directly), and
the sensor test
`tests/sensors/personas-irreducible-on-fixture-cycle.test.sh`
asserts the irreducibility property across the three slices.
