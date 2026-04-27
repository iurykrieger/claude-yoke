# Spec: Validator parallel computational sensor execution (Part 2 of 4)

> Generated via /vibeflow:gen-spec on 2026-04-25 from `.vibeflow/prds/ack-sensors-skill.md`

## Dependencies

- `.vibeflow/specs/ack-sensors-skill-part-1.md` — must be merged first;
  this spec wires the Validator to call `/yoke:ack-sensors --mode readiness`
  and assumes the skill's output schema.

## Objective

Refactor the Validator runtime subagent to spawn computational sensors
as background Bash jobs and aggregate their verdicts incrementally via
the `Monitor` tool, replacing the serial `verify-acceptance.sh` hot
path on the agentic side while preserving the hook as a synchronous
fallback for CI.

## Context

Today the Validator blocks on `hooks/verify-acceptance.sh`, which runs
sensors serially in a `while` loop. A 30s typecheck blocks a 2s lint;
the Validator can't stream partial verdicts; cycle latency is
dominated by the slowest sensor. Part 1 shipped the readiness skill;
this part teaches the Validator to consume it and parallelize.

## Definition of Done

1. Validator subagent (`agents/validator.md`) spawns each computational
   sensor declared in the active Acceptance Contract via
   `Bash(run_in_background=true)` after a successful
   `/yoke:ack-sensors --mode readiness` call; `Monitor` streams
   completion events and the Validator emits structured JSON verdicts
   incrementally as events arrive.
2. **Wall-clock proof of parallelism.** Smoke test fixture with three
   computational sensors (durations 2s, 5s, 30s) completes the
   Validator cycle in ≤ 39s (≤ 1.3× the slowest sensor). Serial
   execution would take ≥ 37s with no upper bound on coordination
   overhead.
3. **Per-sensor hard timeout.** Default 60s for computational
   sensors; per-sensor override via Acceptance Contract bullet
   (`- linter: \`npm run lint\` (timeout: 30s)` syntax). Timeout
   produces `status: "skip"`, `reason: "timeout: <seconds>s"`,
   `exit_code: 124`. Verified by a smoke-test sensor that sleeps
   past the budget.
4. **Verdict aggregation: any-fail-wins.** When multiple sensors map
   to the same Acceptance Contract criterion, the Validator's
   combined verdict is `fail` if any sensor reports `fail` —
   regardless of how many `pass`. Verified by a smoke-test fixture
   with two sensors on the same criterion (one pass, one fail) and
   asserting combined verdict is `fail`.
5. **Backwards-compatible fallback.** `hooks/verify-acceptance.sh`
   still runs sensors serially when invoked directly (CI / headless
   callers). Output YAML schema is unchanged. The hook now delegates
   to `/yoke:ack-sensors --mode readiness` for discovery (single
   source of truth), then runs the discovered sensors serially in
   its own loop. Existing CI smoke tests pass with no changes.
6. **Quality gate (structured output preserved).** Every verdict
   emitted by the parallel path matches the existing JSON shape:
   `criterion / status / location / fix_instruction / sensor /
   evidence`. No prose-only verdicts. Asserted by smoke-test
   golden-diff against a verdict fixture.
7. **Quality gate (Validator tool list explicit).** `agents/validator.md`
   "Allowed tools" section is updated to `Read, Write, Edit, Grep,
   Glob, Bash, Monitor`. **`Agent` is NOT added in this part** —
   inferential spawning is Part 3. The change is auditable in PR.

## Scope

- Modify `agents/validator.md`:
  - Update functional-objective + behaviors to describe the
    parallel-spawn flow.
  - Update "Allowed tools" to add `Monitor` and document
    `Bash(run_in_background=true)` usage.
  - Add a new "Sensor execution protocol" section with the
    pseudo-code for: readiness check → parallel Bash spawn → Monitor
    event aggregation → verdict emission → any-fail-wins reduction.
- Modify `hooks/verify-acceptance.sh`:
  - Replace the inline bullet-extraction block with a call to
    `/yoke:ack-sensors --mode readiness <contract>` and parse its
    output (single source of truth for sensor discovery).
  - Keep the serial execution loop unchanged for CI compatibility.
  - Output YAML schema unchanged.
- Modify `.vibeflow/patterns/sensors.md`:
  - Add a "Parallel execution & acknowledgement" subsection
    describing the new topology (Validator orchestrates parallel
    jobs; hook is fallback) and the timeout / aggregation rules.
- New `tests/smoke/ack-sensors-parallel.test.sh`:
  - Three-sensor wall-clock fixture.
  - Timeout-firing fixture.
  - Same-criterion any-fail-wins fixture.
  - All against a fixture host project under
    `tests/fixtures/ack-sensors/`.

## Anti-scope

- **No** inferential-sensor support — Part 3 owns `Agent` spawning,
  the `semantic-judge` template, and the new
  `agents/semantic-judge.md` subagent file.
- **No** changes to the Acceptance Contract's `## Sensors > ###
  Computational` syntax beyond the optional `(timeout: <Ns>)`
  suffix. The bullet shape stays identical for backwards
  compatibility.
- **No** replacement of `hooks/verify-acceptance.sh` — it remains
  the synchronous fallback. Removing it is a separate, future
  decision.
- **No** caching of sensor results across cycles.
- **No** changes to `.yoke/contracts.md` writing protocol; the
  Validator still co-writes consensus events through its existing
  flow.
- **No** parallelism in `verify-acceptance.sh` itself — the hook
  stays serial. Parallelism is a Validator-side capability only.

## Technical Decisions

### Validator drives parallelism, not the hook
The hook stays a pure deterministic fallback. The Validator
subagent — which already has tool access to `Bash` — gains
`Monitor` and uses `run_in_background=true`. This puts the agentic
node in charge of orchestration (where judgment about timeouts,
aggregation, and partial verdicts lives), while keeping the
deterministic node simple and auditable.

**Trade-off:** Validator prompt becomes longer (it must encode the
spawn protocol). Mitigated by keeping the protocol pseudo-code
short (~20 lines) and referencing the readiness-skill output schema
rather than duplicating it.

### `Monitor`-driven incremental verdicts
The Validator emits verdicts as events arrive — not after all
sensors finish. This means `progress.md` and `contracts.md` get
partial updates within a cycle, which Part 3's inferential sensors
benefit from (they're slow and shouldn't block fast computational
results). Trade-off: the cycle's final verdict is determined by
the **last-arriving** event, so the Validator must hold the event
loop open until either every sensor completes or every running
sensor times out.

### Timeout enforcement: per-sensor, not per-cycle
Per-sensor timeouts (60s computational default) prevent one slow
sensor from starving the cycle. Per-cycle timeout would re-introduce
the head-of-line problem we're trying to solve. The Acceptance
Contract's bullet syntax is the override surface — declared
inline so reviewers see it during Trigger 3.

**Trade-off:** total cycle time can theoretically reach
`max(declared_timeouts)`, which for a contract with one 300s
override could exceed the ralph-loop's per-cycle budget. Documented
in `patterns/sensors.md` and surfaces as a Risk.

### Hook delegates to skill for discovery
`verify-acceptance.sh` calls `/yoke:ack-sensors --mode readiness`
instead of re-extracting the `## Sensors` block. Single source of
truth for the bullet-parsing logic. Trade-off: hook now depends on
the skill being installed — but this is implicit in any Yoke
context anyway (the hook lives inside the plugin).

### Bash exit code 124 for timeout (matches GNU `timeout` convention)
Reuses the well-known semantics so existing tooling (CI dashboards,
log parsers) can recognize it without special handling.

## Applicable Patterns

- **`patterns/ralph-loop.md`** — "Sensor execution: deterministic
  node, runs after each cycle's agentic batch." This part shifts
  computational sensor execution INSIDE the agentic node (Validator)
  to enable parallelism. The hook remains the deterministic-node
  fallback. Update the pattern to reflect both paths.
- **`patterns/sensors.md`** — structured-output requirement (any-fail
  aggregation must preserve per-sensor evidence in the combined
  verdict). New "Parallel execution & acknowledgement" subsection
  documents the topology.
- **`patterns/roles.md`** — Validator's "runs sensors via
  `hooks/verify-acceptance.sh`" line must be updated; the Validator
  now orchestrates parallel jobs and falls back to the hook only
  when invoked outside the loop.
- **Conventions: "Hard bounds on autonomous loops"** — per-sensor
  timeouts honor this principle inside the cycle.
- **Conventions: "Back-pressure: success is silent, failures are
  verbose"** — preserved: incremental verdicts surface failures as
  soon as detected.

## Risks

| Risk | Likelihood | Impact | Mitigation |
| :--- | :--- | :--- | :--- |
| `Monitor` tool reliability degrades with ≥4 concurrent backgrounded Bash jobs (event-loss, ordering anomalies) | medium | high | Smoke test runs 4 concurrent sensors and asserts every event is captured in stdout-event-log; if flakes appear, document fallback to `wait` + post-hoc parsing in a Tech-Spec follow-up |
| Per-sensor timeout overrides in the Contract create cycle-budget overruns | medium | medium | Document in `patterns/sensors.md`: per-sensor timeouts must respect `(N_sensors × max_timeout) ≤ cycle_budget`. Optional: add a future readiness-mode warning when sum of timeouts exceeds a threshold (Part 4 candidate) |
| Hook ↔ skill output-schema drift breaks CI consumers | low | high | The smoke test diff-asserts hook YAML against a golden file. Any schema change requires updating the golden file and is reviewed in PR |
| Validator subagent prompt becomes too long, degrading judgment quality (the manifesto's "ETH Zurich evidence" risk) | low | medium | Keep the new "Sensor execution protocol" section ≤ 40 lines; reference patterns rather than inlining them; Section length is asserted in the audit |
| Parallel execution masks order-dependent test suites that previously passed serially in the host project | low | medium | Documented in `patterns/sensors.md` as a known limitation; host projects with order-dependent suites declare them via a future `(serial: true)` Contract bullet flag — not implemented in v0 but reserved syntax |
