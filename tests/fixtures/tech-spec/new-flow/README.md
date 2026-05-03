# Tech-spec / new-flow fixture

> Anchors the post-cutover `/yoke:tech-spec` invariant: the skill
> writes ONLY `.yoke/specs/<slug>.md` and never any file under
> `.yoke/sprints/`. The fixture ships an approved PRD and an empty
> sprints / acceptance-criteria area; AC-001-3 / AC-001-4 of the
> binding contract are exercised against this fixture.

## Slug

`2026-05-03-tech-spec-new-flow-fixture`

## Files

- `.yoke/prds/<slug>.md` — approved PRD (the input to `/yoke:tech-spec`).

## Used by

- `tests/acceptance/2026-05-03-generate-sprints-skill/us-001-tech-spec-no-sprint-output.test.sh`
  (AC-001-3, AC-001-4 dynamic branch — but the test uses a static-grep
  short-circuit so dynamic invocation is not required).
