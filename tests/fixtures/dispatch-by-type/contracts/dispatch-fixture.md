# Acceptance Contract — dispatch-by-type fixture

> Test-only contract consumed by tests/sensors/dispatch-by-type.test.sh.
> Source PRD: .yoke/prds/2026-04-30-sensor-harness-realignment.md (Sprint 3, t03).
> One criterion gated by one computational + one inferential sensor.
> Uses the new per-criterion `### Validation` shape so the hook
> resolves dispatch metadata via `.yoke/sensors/<id>.md`.

## Use cases

### Scenario 1 — dispatch by type produces correct artifacts

Given a fixture with one `type: computational` sensor and one `type: inferential` sensor referenced by the same criterion
When `hooks/verify-acceptance.sh --criterion 'Scenario 1'` runs
Then the marker file `/tmp/yoke-dispatch-marker-comp` exists post-run AND the inferential verdict JSON exists with `confidence` and `supporting_quotes`

### Validation

- **dispatch-marker-comp** — computational; touches `/tmp/yoke-dispatch-marker-comp` to prove the shell dispatch path ran the command.
- **dispatch-marker-inf** — inferential; spawns `dispatch-test-stub` and persists a verdict JSON envelope at the deterministic path.
