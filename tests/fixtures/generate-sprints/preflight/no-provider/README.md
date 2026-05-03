# Fixture: preflight / no-provider

Pre-flight failure-mode fixture for
`tests/acceptance/2026-05-03-generate-sprints-skill/us-003-preflight-five-modes.test.sh`.

**Mode:** `.yoke/config.yaml` exists but `canonical_memory.provider`
is empty. The `yoke_require_provider` helper treats `""`, `null`, and
`~` as unset.

**Expected behavior:** Pre-flight aborts non-zero with a `wm:`-prefixed
stderr line naming the missing provider and pointing at
`/yoke:bootstrap`.
