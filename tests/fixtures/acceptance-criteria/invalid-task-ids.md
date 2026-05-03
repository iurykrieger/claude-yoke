---
slug: 2026-01-01-foo
status: draft
created_at: 2026-01-01
model: claude-opus-4-7-1m
language: en-US
---

# Acceptance Criteria: Fixture — invalid (carries forbidden task-ID reference)

> This fixture is intentionally malformed. The `### UC-1` block below
> carries a forbidden `2026-01-01-foo-s01-t02` task-ID reference inline,
> which violates FR-4 of the generate-sprints PRD. The shape-checker
> `tests/acceptance/2026-05-03-generate-sprints-skill/_lib/check-shape.sh`
> MUST reject this fixture with stderr containing
> `wm: forbidden task-ID reference`.

## Overall objective

Negative-case fixture for `tests/smoke/acceptance-criteria-shape.test.sh`.
The body is otherwise well-formed: it carries a `### UC-1` heading and the
five sub-fields. The single rule it violates is the no-task-IDs rule.

## Use cases

### UC-1: Reference a task ID that the AC must not name

**Name:** Reference a task ID that the AC must not name

**Definition of done:**
- The legacy task at 2026-01-01-foo-s01-t02 is migrated.
- The new task list is bound by Trigger 3.

**Acceptance criteria:**
- The forbidden reference 2026-01-01-foo-s01-t02 is detected by grep.

**Functional requirements realized:** FR-4

**Sensors:** tests-smoke, lint
