# Implement fixtures

Engineered states for `/yoke:implement` testing under
`tests/acceptance/2026-05-03-generate-sprints-skill/us-006-implement-refuses-awaiting.test.sh`.

## Branches

### `new-flow-awaiting/`

- Slug: `2026-05-03-implement-new-flow-fixture`
- Approved spec at `.yoke/specs/<slug>.md`.
- Ratified acceptance-criteria at `.yoke/acceptance-criteria/<slug>.md`.
- ZERO sprint files under `.yoke/sprints/`.
- Active slug pinned via `.yoke/runtime/.current`.

This is the engineered state that `/yoke:implement` MUST refuse on,
surfacing the literal stderr `wm: run /yoke:generate-sprints to
advance to Phase 4` per AC-006-3.

### `legacy-flow/`

- Slug: `2026-04-15-implement-legacy-fixture`
- Approved spec at `.yoke/specs/<slug>.md`.
- `.yoke/acceptance-contracts/<slug>.md` (legacy artifact).
- NO `.yoke/acceptance-criteria/<slug>.md`.
- One legacy sprint file under `.yoke/sprints/<slug>-s01.md`.

This is the engineered state that selects the legacy ladder and
allows Phase A pre-spawn to proceed without abort.
