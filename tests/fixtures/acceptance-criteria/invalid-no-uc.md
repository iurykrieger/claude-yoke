---
slug: 2026-05-03-fixture-no-uc
status: draft
created_at: 2026-05-03
model: claude-opus-4-7-1m
language: en-US
---

# Acceptance Criteria: Fixture — invalid (zero UC headings)

> This fixture is intentionally malformed. The body contains zero
> `### UC-<n>` headings, which violates FR-3 of the generate-sprints PRD.
> The shape-checker
> `tests/acceptance/2026-05-03-generate-sprints-skill/_lib/check-shape.sh`
> MUST reject this fixture with stderr containing
> `wm: no UC headings found`.

## Overall objective

Negative-case fixture for `tests/smoke/acceptance-criteria-shape.test.sh`.
The body has the surface shape (frontmatter + title + Overall objective +
Use cases) but no `### UC-` blocks at all — a degenerate document the
shape-checker must catch.

## Use cases

This document intentionally does not enumerate any UCs. The author would
have started one but never did, so the artifact is not bound by any
binary-decidable use case. Downstream `/yoke:generate-sprints` cannot
consume it because there is nothing for tasks to realize.
