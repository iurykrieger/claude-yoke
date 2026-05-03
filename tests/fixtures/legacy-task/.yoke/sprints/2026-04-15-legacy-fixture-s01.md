---
task_id: 2026-04-15-legacy-fixture-s01
sprint: 1
slug: 2026-04-15-legacy-fixture
status: approved
created_at: 2026-04-15T00:00:00Z
model: ""
traceability: .yoke/specs/2026-04-15-legacy-fixture.md
Migrated-from: []
---

# Sprint 01 of 01: Legacy stub

> Frozen legacy sprint bundle — produced by the legacy tech-spec
> stage 3 flow. The legacy marker is in the YAML frontmatter:
> `traceability:` cites only the spec path. Combined with the
> absence of `.yoke/acceptance-criteria/<slug>.md`, this fixture
> selects the legacy gate ladder under the new gate-state helper.

## Sprint objective

Stub sprint for the legacy-task fixture. Exists only so
`/yoke:implement`'s Phase A pre-spawn step has at least one sprint
file to load.

## Sprint DoD

- Phase A pre-spawn succeeds against this fixture.

## Tasks

### Task 2026-04-15-legacy-fixture-s01-t01

**Story:** As the legacy-task fixture, I provide a stub sprint that
exercises the legacy gate ladder under `/yoke:implement`.

**Technical implementation:** None (fixture stub).

**Validation:** Phase A pre-spawn succeeds.

**Acceptance criterion:** `/yoke:implement` enters its first cycle
without abort.

## Functional acceptance criteria

- legacy-fixture-stub

## Sensors

- tests-runtime
