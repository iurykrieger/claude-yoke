# Fixture: working-set-three-personas

Engineered fixture for the Phase A orchestration test
(`tests/runtime/phase-a-orchestration.test.sh`).

The test driver materializes the cycle directory + Phase-A markers at
runtime by invoking three persona-stub scripts (one per persona),
each writing its slice file under
`<scratch>/.yoke/runtime/cycles/0/<persona>.md` and its marker under
`<scratch>/.yoke/runtime/.phase-a-done.<persona>` before exiting.

The fixture itself is intentionally empty — the runtime layout is
constructed in the test driver so mtimes are controlled and the
fixture stays portable across CI runners (git only preserves
second-granularity on mtime, and not at all in the indexed snapshot).

The persona stubs simulate what real Sr Eng / Sr QA / Sr Staff Tasks
would do in production: write a per-persona slice file with the Phase A
own-progress section, then drop the Phase-A marker. The orchestration
helpers in `lib/runtime/cycle.sh` validate persona files + clear stale
markers before the spawn; the SKILL.md layer issues the Task batch;
the post-spawn `wait-all` defensively confirms every marker is present
before Phase B opens.
