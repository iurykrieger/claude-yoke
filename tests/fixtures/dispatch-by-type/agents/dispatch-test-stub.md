---
name: dispatch-test-stub
description: Stub subagent referenced exclusively by tests/fixtures/dispatch-by-type/. Spawned by tests/sensors/dispatch-by-type.test.sh to exercise the inferential-dispatch path of hooks/verify-acceptance.sh. Returns a canned verdict envelope; never invoked outside the test.
tools: Read
---

# Dispatch test stub

Test-only subagent. Real spawns route through `agents/semantic-judge.md`.
This stub exists so the dispatch-by-type test can verify, end-to-end,
that an inferential sensor pointing at an `agent:` causes
`hooks/verify-acceptance.sh` to take the Task spawn code path AND
persist a verdict JSON file under
`.yoke/runtime/.judge-verdicts/cycle-N/<criterion>--<sensor>.json`.

The hook's current implementation persists a placeholder verdict at
that path (with `status: skip` until the coordinator overwrites it
with the real subagent's output). This is sufficient for the test —
the assertion is that the file exists and parses as JSON containing
`confidence` (numeric) and `supporting_quotes` (list).

The placeholder envelope:

```json
{
  "criterion": "<criterion-id>",
  "sensor": "<sensor-id>",
  "status": "skip",
  "location": null,
  "fix_instruction": "spawn agent 'dispatch-test-stub' to produce a real verdict",
  "evidence": "placeholder verdict written by hooks/verify-acceptance.sh inferential dispatch",
  "confidence": 0.0,
  "supporting_quotes": []
}
```

Source PRD: `.yoke/prds/2026-04-30-sensor-harness-realignment.md`
(Sprint 3, t03).
