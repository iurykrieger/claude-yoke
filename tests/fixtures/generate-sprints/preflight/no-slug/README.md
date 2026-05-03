# Fixture: preflight / no-slug

Pre-flight failure-mode fixture for
`tests/acceptance/2026-05-03-generate-sprints-skill/us-003-preflight-five-modes.test.sh`.

**Mode:** Provider is configured but no active task is set
(`.yoke/runtime/.current` is absent). `wm_active_slug` returns 1 with
the literal stderr `wm: no active task; run /yoke:discover first`.

**Expected behavior:** Pre-flight aborts non-zero with a `wm:`-
prefixed stderr line naming the missing active-task pointer.
