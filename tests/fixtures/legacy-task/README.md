# Legacy-task fixture

> Frozen snapshot of a legacy task — produced under the legacy
> `/yoke:tech-spec` stage 3 flow (sprint files emitted by tech-spec).
> The defining marker of a legacy task is the **presence** of
> `.yoke/acceptance-contracts/<slug>.md` AND the **absence** of
> `.yoke/acceptance-criteria/<slug>.md`. Re-running
> `/yoke:generate-sprints` against this fixture MUST be a no-op
> rejection (per AC-007-2 of the binding contract); `/yoke:implement`
> MUST consume it unchanged (per AC-007-1).

## Slug

`2026-04-15-legacy-fixture`

## Files

- `.yoke/specs/2026-04-15-legacy-fixture.md` — legacy spec stub.
- `.yoke/acceptance-contracts/2026-04-15-legacy-fixture.md` — legacy
  binding contract (the legacy-flow marker).
- `.yoke/sprints/2026-04-15-legacy-fixture-s01.md` — legacy sprint
  bundle emitted by `/yoke:tech-spec` stage 3 (no `(Realizes: US-NNN)`
  clause, frontmatter `traceability` cites only the spec).
- `.yoke/runtime/.current` — pinning the active slug for status / implement
  resolution.

## Used by

- `tests/acceptance/2026-05-03-generate-sprints-skill/us-007-generate-sprints-rejects-legacy.test.sh`
- `tests/acceptance/2026-05-03-generate-sprints-skill/us-006-status-awaiting-state.test.sh`
  (legacy-ladder branch)
- `tests/acceptance/2026-05-03-generate-sprints-skill/us-006-implement-refuses-awaiting.test.sh`
  (legacy-walks-clean branch)

This fixture is intentionally minimal. It anchors the legacy-vs-new
flow detection rule (`test -f .yoke/acceptance-criteria/<slug>.md`)
without bringing in unrelated fixture detail.
