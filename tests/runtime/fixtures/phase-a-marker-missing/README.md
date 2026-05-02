# Fixture: phase-a-marker-missing

Engineered fixture for the Phase A orchestration test's negative case
(`tests/runtime/phase-a-orchestration.test.sh`).

The test driver materializes a cycle directory where two persona stubs
write their slice + marker normally, but the third stub fails to write
its marker (it still writes its slice). The defensive `wait-all` in
`lib/runtime/cycle.sh post-spawn` is expected to time out non-zero
with a `wm: sync-barrier timeout:` stderr line naming the missing
marker.
