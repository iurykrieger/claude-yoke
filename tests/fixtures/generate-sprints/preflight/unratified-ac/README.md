# Fixture: preflight / unratified-ac

Pre-flight failure-mode fixture for
`tests/acceptance/2026-05-03-generate-sprints-skill/us-003-preflight-five-modes.test.sh`.

**Mode:** Provider is configured, the spec is approved, but the
acceptance-criteria file's frontmatter `status` is `draft`.

**Expected behavior:** Pre-flight aborts non-zero with a `wm:`-
prefixed stderr line naming the unapproved acceptance-criteria path.

**Note:** The fixture uses `acceptance-criteria/` (post-rename name),
which the binding PRD US-003 names verbatim. The legacy directory
`acceptance-contracts/` is only used for back-compat reads via the
frozen historical helper that the spec retired in v4.0.0; the new
skill writes against `acceptance-criteria/` only.
