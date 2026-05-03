# Fixture: preflight / no-config

Pre-flight failure-mode fixture for
`tests/acceptance/2026-05-03-generate-sprints-skill/us-003-preflight-five-modes.test.sh`.

**Mode:** `.yoke/config.yaml` is missing entirely. The directory has
no `.yoke/` subdirectory at all (intentional — `yoke_require_provider`
returns 2 with `wm: <cfg> not found` when the file is absent).

**Expected behavior:** Pre-flight aborts non-zero with a `wm:`-prefixed
stderr line naming the missing config and pointing at `/yoke:bootstrap`.
