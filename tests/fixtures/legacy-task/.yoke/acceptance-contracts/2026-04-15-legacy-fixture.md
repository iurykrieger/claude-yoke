# Acceptance Contract — Legacy-task fixture

> Frozen legacy contract — produced under the legacy
> `/yoke:acceptance-contract` skill (pre-rename).
> Status: ratified
> Ratified by: fixture
> Ratified at: 2026-04-15T00:00:00Z

> **Binding statement (Trigger 3).** Approving this contract operationally
> defines "done" for this task as "passes every criterion below". (Stub
> for fixture purposes only.)

## Use cases (BDD scenarios)

### Scenario 1 — Legacy stub
Task: 2026-04-15-legacy-fixture-s01-t01
Given the legacy-flow fixture
When `/yoke:implement` is invoked
Then the legacy gate ladder is selected and Phase A pre-spawn succeeds.
Sensors: [tests-runtime]

## Functional requirements

### Criterion FR-1 — Legacy-flow detection

The presence of this `.yoke/acceptance-contracts/<slug>.md` (combined
with the absence of `.yoke/acceptance-criteria/<slug>.md`) selects
the legacy gate ladder.

### Validation

- **tests-runtime** — pass = the gate-detection ladder reports a
  legacy state on this fixture; fail = a `awaiting:generate-sprints`
  state surfaces.

## Applicable policies

- None (fixture stub).
