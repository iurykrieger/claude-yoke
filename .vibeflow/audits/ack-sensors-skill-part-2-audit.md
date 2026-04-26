# Audit Report: ack-sensors-skill-part-2

> Audited 2026-04-25 against `.vibeflow/specs/ack-sensors-skill-part-2.md`

**Verdict: PASS**

## Test execution

Test runners:
- `bash tests/smoke/ack-sensors-parallel.test.sh` → **0 failures**, exit 0
- `bash tests/smoke/ack-sensors-catalog.test.sh` (regression check, run as
  the final assertion of the Part 2 smoke) → **0 failures**, exit 0

Total: 42 + 28 = 70 assertions across both smoke suites; all pass.

## Dependencies

- `ack-sensors-skill-part-1.md` — audit verdict: **PASS** (see
  `.vibeflow/audits/ack-sensors-skill-part-1-audit.md`). Confirmed.

## DoD Checklist

- [x] **DoD #1 — Validator parallel-spawn protocol with `Bash(run_in_background=true)`
  + `Monitor`.**
  Evidence: `agents/validator.md` "Sensor execution protocol" section
  documents the per-cycle blueprint. Asserted by smoke checks
  "Validator declares Sensor execution protocol", "references Bash
  run_in_background", "references Monitor tool", and "delegates
  discovery to ack-sensors readiness".

- [x] **DoD #2 — Wall-clock proof of parallelism.**
  Evidence: smoke test "parallel-spawn wall-clock ≤ 1950ms (got
  1528ms)". Three parallel `sleep` jobs of durations 0.2/0.5/1.5s
  complete in ~1.5s wall-clock. Serial would be ≥ 2.2s. Ratio:
  ~1.02× the slowest sensor — well under the 1.3× threshold.
  Uses the same primitive (`&` + `wait`) the Validator applies to
  background sensor jobs.

- [x] **DoD #3 — Per-sensor hard timeout (60s computational default,
  override via `(timeout: <Ns>)`); timeout produces `status=skip`,
  `exit_code=124`, `reason="timeout: <Ns>s"`.**
  Evidence: `agents/validator.md` documents 60s default + override
  syntax + exit code 124. `hooks/verify-acceptance.sh:65`
  `DEFAULT_COMPUTATIONAL_TIMEOUT=60`; per-sensor override extracted at
  lines 102–109 (`SENSOR_TIMEOUT[$bullet_name]`). Smoke test
  fixture `slow-sleep: \`sleep 5\` (timeout: 1s)` produces exit
  code 124 + `reason: "timeout: 1s"` in 0.2–1s wall-clock —
  asserted directly.

- [x] **DoD #4 — Verdict aggregation: any-fail-wins.**
  Evidence: `agents/validator.md` "Verdict aggregation:
  any-fail-wins" subsection; same rule echoed in
  `.vibeflow/patterns/sensors.md` "Parallel execution &
  acknowledgement". Smoke test bash reducer fixture
  (`combine_verdicts`) verifies all four cases:
    - all-pass → pass
    - any-fail → fail
    - skip + pass → skip
    - pass + fail + skip → fail (fail dominates skip)

- [x] **DoD #5 — Backwards-compatible fallback. Hook delegates to
  `/yoke:ack-sensors --mode readiness`. YAML schema unchanged.**
  Evidence: `hooks/verify-acceptance.sh:75-83` calls
  `bash "$ack_sensors" --mode readiness "$contract"` and parses its
  YAML. Per-sensor YAML schema (sensor / command / status /
  exit_code / output_excerpt / reason) preserved exactly — asserted
  by 6 schema-field smoke checks. Top-level `results:` key
  preserved. Sensor outcome counts (2 pass + 2 skip + 0 fail)
  asserted for the mixed-fixture contract.

- [x] **DoD #6 — Verdict shape preserved across both classes.**
  Evidence: Validator's verdict shape declares the canonical six
  keys (criterion / status / location / fix_instruction / sensor /
  evidence). Smoke test asserts each of the six keys appears in
  the agent file's documented JSON shape. Hook YAML emits the
  same shape on a per-sensor basis (no class distinction at v0.4.0
  since inferential is a Part-3 addition).

- [x] **DoD #7 — Validator allowed-tools = `Read, Write, Edit, Grep,
  Glob, Bash, Monitor`. `Agent` NOT added in this part.**
  Evidence: `agents/validator.md:5` `tools: Read, Write, Edit,
  Grep, Glob, Bash, Monitor`. Smoke test asserts `Bash` and
  `Monitor` are present, and `Agent` is **absent** (will be added
  in Part 3 with the strict `subagent_type: yoke:semantic-judge`
  constraint).

## Pattern Compliance

- [x] **`patterns/ralph-loop.md` — sensor execution.**
  The pattern's "Sensor execution: deterministic node, runs after
  each cycle's agentic batch" is now refined: at runtime, the
  Validator orchestrates parallel spawns inside its agentic node;
  the synchronous hook remains as the deterministic fallback. The
  `agents/validator.md` Sensor execution protocol references the
  ralph-loop semantics by referring to per-cycle execution.

- [x] **`patterns/sensors.md` — structured-output rule preserved.**
  The new "Parallel execution & acknowledgement" subsection
  documents the topology, default timeouts (60s computational),
  any-fail-wins, and the cycle-budget caveat. Per-sensor verdicts
  preserve the existing structured-fields requirement. No
  prose-only verdicts permitted.

- [x] **`patterns/roles.md` — Validator's role contract.**
  The Validator continues to "judge conformance against
  determinable signals" without writing host code. The protocol
  change is purely about *how* it runs the sensors (parallel vs.
  serial), not about *what* it produces.

- [x] **Conventions: "Hard bounds on autonomous loops".**
  Per-sensor 60s default + per-sensor override is the per-job
  bound. The cycle-budget caveat is documented in
  `patterns/sensors.md` so per-task overrides do not silently
  defeat the ralph-loop's per-cycle hard bound.

- [x] **Conventions: "Back-pressure: success is silent, failures
  are verbose."**
  Validator emits verdicts incrementally as sensor events arrive
  (per Sensor execution protocol step 3), so a fast-failing sensor
  surfaces immediately even if a slow sensor is still running.

- [x] **Conventions: "Bash scripts target bash 4+".**
  The hook uses bash-4-only idioms (`declare -A`, `BASH_REMATCH`,
  `[[ ]]`). Smoke test runs cleanly under bash 5.3.

- [x] **Conventions: "Blueprints wrapping agentic nodes".**
  The Validator's agentic node now contains a **deterministic
  inner blueprint** (readiness check → parallel spawn → Monitor
  aggregation → verdict reduction). Each step is well-defined; the
  judgment node is only the per-sensor verdict-shape decision. No
  scope creep into LLM-as-router patterns.

## Convention Violations
None detected.

## Notes

### `timeout` portability

The hook implements a `run_with_timeout` helper that prefers GNU
`timeout --foreground`, then `timeout` without `--foreground`, then
falls back to a backgrounded watchdog with `kill -TERM` mapped to
exit code 124 (matching GNU `timeout` convention). On macOS (where
neither GNU `timeout` nor `gtimeout` is on `$PATH` by default), the
watchdog path was exercised end-to-end by the smoke test
(`slow-sleep: sleep 5 (timeout: 1s)` reliably produces exit 124 in
~1s wall-clock). No new dependencies added.

### Hook YAML parser dedup fix

Initial implementation ingested sensor records from both `sensors:`
and `failures:` sub-blocks in the readiness output, producing
duplicate emissions. Fixed by limiting parsing to the `sensors:`
section only (top-level YAML key detection at column 0). Asserted by
the "two sensors skip" count and "two sensors pass" count in the
smoke test.

### Risk R1 (Monitor reliability with ≥4 concurrent jobs)

The spec's R1 risk concerned `Monitor` event-loss with ≥4
concurrent backgrounded Bash jobs. The smoke test demonstrates 3
concurrent jobs successfully via `&`+`wait`, which is the same
primitive Bash `run_in_background` uses underneath. Real `Monitor`
behavior under heavier load is not exercised in this smoke test
and remains a follow-up concern — recommend a Tech-Spec spike
during Part 3 work or a Sprint-7 stress test.

## Files in this part

| File | Status | Lines (approx) |
| :--- | :--- | :---: |
| `agents/validator.md` | modified | +120 |
| `hooks/verify-acceptance.sh` | modified | +90 / -45 |
| `.vibeflow/patterns/sensors.md` | modified | +30 |
| `tests/smoke/ack-sensors-parallel.test.sh` | created | 245 |

Total: 4 files / ≤ 4 budget.

## Next step

**Ready to ship.** Proceed to Part 3:

```
/vibeflow:implement .vibeflow/specs/ack-sensors-skill-part-3.md
```
