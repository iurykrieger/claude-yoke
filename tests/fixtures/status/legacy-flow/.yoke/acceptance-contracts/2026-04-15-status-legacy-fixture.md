# Acceptance Contract — Status legacy-flow fixture

> Frozen legacy contract.
> Status: ratified
> Ratified by: fixture
> Ratified at: 2026-04-15T00:00:00Z

## Use cases (BDD scenarios)

### Scenario 1 — Legacy stub
Task: 2026-04-15-status-legacy-fixture-s01-t01
Given the legacy fixture
When `/yoke:status` is invoked
Then the legacy ladder is selected.

## Functional requirements

### Criterion FR-1 — Legacy gate ladder selection

The presence of `.yoke/acceptance-contracts/<slug>.md` (and the
absence of `.yoke/acceptance-criteria/<slug>.md`) selects the legacy
gate ladder.

### Validation

- **tests-runtime** — pass = legacy ladder reported.
