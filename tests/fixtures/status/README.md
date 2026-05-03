# Status fixtures

Engineered states for `/yoke:status` testing under
`tests/acceptance/2026-05-03-generate-sprints-skill/us-006-status-awaiting-state.test.sh`.

## Branches

### `new-flow-awaiting/`

- Slug: `2026-05-03-status-new-flow-fixture`
- Approved spec at `.yoke/specs/<slug>.md`.
- Ratified acceptance-criteria at `.yoke/acceptance-criteria/<slug>.md`.
- ZERO sprint files under `.yoke/sprints/`.
- Active slug pinned via `.yoke/runtime/.current`.

This is the engineered state that selects the new gate ladder and
surfaces the new `awaiting:generate-sprints` state per AC-006-2.

### `legacy-flow/`

- Slug: `2026-04-15-status-legacy-fixture`
- Approved spec at `.yoke/specs/<slug>.md`.
- Ratified `.yoke/acceptance-contracts/<slug>.md` (legacy artifact).
- NO `.yoke/acceptance-criteria/<slug>.md`.
- One sprint file under `.yoke/sprints/<slug>-s01.md`.

This is the engineered state that selects the legacy ladder
(`awaiting:tech-spec` → `awaiting:acceptance-contract` →
`running:implement` → `done`) per AC-006-2 (legacy branch).
