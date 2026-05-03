# Fixture: preflight / unapproved-spec

Pre-flight failure-mode fixture for
`tests/acceptance/2026-05-03-generate-sprints-skill/us-003-preflight-five-modes.test.sh`.

**Mode:** Provider is configured, the active slug points at
`2026-05-03-fixture-unapproved-spec`, the spec file exists but its
frontmatter `status` is `draft` (not `approved`).

**Expected behavior:** Pre-flight aborts non-zero with a `wm:`-
prefixed stderr line naming the unapproved spec path.
