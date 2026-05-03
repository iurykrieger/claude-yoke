# Acceptance Contract — Implement legacy-flow fixture

> Frozen legacy contract.
> Status: ratified
> Ratified by: fixture
> Ratified at: 2026-04-15T00:00:00Z

## Use cases (BDD scenarios)

### Scenario 1 — Legacy walk
Task: 2026-04-15-implement-legacy-fixture-s01-t01
Given the legacy-flow fixture
When `/yoke:implement` is invoked
Then the legacy ladder is selected and Phase A pre-spawn succeeds.

## Functional requirements

### Criterion FR-1 — Phase A pre-spawn succeeds

`/yoke:implement` enters its first cycle without abort.

### Validation

- **tests-runtime** — pass = pre-spawn succeeds; fail = abort.
