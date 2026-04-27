---
tags: [sensors, shift-left, computational, inferential, structured-output, back-pressure]
modules: []
applies_to: [validator, validation-agent, sensors, fixtures, error-output]
confidence: validated
---
# Pattern: Sensors — Computational and Inferential, with Structured Output

<!-- vibeflow:auto:start -->
## What
Sensors are the mechanism by which the Validator (a runtime subagent in
Phase 4, and a persona inline in `/yoke:acceptance-contract` at spec
phase) judges conformance against determinable signals. Yoke
distinguishes **computational sensors** (deterministic checks) and
**inferential sensors** (LLM-based semantic judgment), all required to
emit **structured output for agent consumption** — never plain prose.

## Where
Declared in the Acceptance Contract per scope. Computational sensors run
every cycle in Phase 4 alongside the Generator's code changes
(shift-feedback-left). Inferential sensors run when computational sensors
cannot decide — they are calibrated for the specific Contract's scope.

## The Pattern

### Computational sensors
Deterministic, framework-aware checks that run without agent decision:
- Linters (ruff, eslint, golangci-lint, etc.)
- Type checks (mypy, tsc, etc.)
- Structural tests (contract tests against fixtures, schema validators)
- Unit tests
- Approved fixtures replayed against the implementation

Run on every cycle. Cheap. Catch regressions early. Output is structured
(see below).

### Inferential sensors
LLM-based semantic judges, used only when computational sensors cannot judge:
- Did the diff implement the use case as described in the Tech Spec?
- Does the error message follow team voice and surface actionable info?
- Is the README change consistent with the API change?

Calibrated against the specific Acceptance Contract scope — not generic
prompts. Calibration metadata (model id, calibration date, known
false-positive/negative rates) lives in canonical memory.

### Structured output (back-pressure principle)
**Success is silent. Failures are verbose and structured.**

Every sensor that fails emits:
- **Violation identification.** Specific rule / fixture / scenario name.
- **Location.** File path and (when applicable) line range.
- **Correction instruction.** When deterministic, the exact fix; when not, the criterion to satisfy.
- **Reference.** Canonical-memory link to the policy or fixture that fired.

Generic output ("tests failed", "build broken") is treated as a sensor bug —
it provides no signal the agent can act on without re-running and inspecting.

### Parallel execution — coordinator-owned spawn (v0.5.0+)
Sensor execution is owned by `/yoke:implement` — the deterministic
skill coordinator — not by the Validator subagent. Splitting it by
sensor class:

1. **Acknowledge first.** Both paths call
   `bash lib/sensors/ack-sensors.sh --mode readiness <contract>` to
   verify every declared sensor is reachable. The skill is the
   single source of truth for sensor discovery.
2. **Computational sensors — synchronous, deterministic.**
   `/yoke:implement` runs them via `hooks/verify-acceptance.sh` with
   `xargs -P "$(yoke_sensor_concurrency)"` (default 4) exactly once
   per cycle, immediately after the per-cycle background batch
   completes. Output lands in
   `$(wm_snapshots_dir)/cycle-<N>.yaml` per the structured schema.
   Default per-sensor timeout: **60s**.
3. **Inferential sensors — background agents in the per-cycle batch.**
   `/yoke:implement` spawns one
   `Agent(subagent_type: semantic-judge, run_in_background: true)`
   per applicable inferential sensor on the targeted criterion,
   inside the same per-cycle Task batch as
   Generator/Validator/Orchestrator. Cap on parallel judges is
   `runtime.inferential_sensor_concurrency` in `.yoke/config.yaml`
   (default 4); surplus sensors are deferred to the next cycle via
   `$(wm_runtime_dir)/.deferred-sensors.json`. Default per-judge
   timeout: **120s**. Each judge writes its verdict JSON to
   `wm_judge_verdict_path "$slug" "$cycle" "$criterion-id"`
   (`.yoke/runtime/.judge-verdicts/cycle-<N>/<criterion-id>.json`).
   The Validator never spawns judges itself; its tool list excludes
   `Agent` and `Task`.
4. **Aggregate via working memory (Model A — lag-by-one).** The
   Validator in cycle `<N+1>` reads inferential-sensor verdicts from
   `wm_judge_verdict_dir "$slug" "$cycle"` and merges them with
   cycle-`<N>`'s computational verdicts. Cycle wall-clock is bounded
   by `max(judge_timeout, post_iteration_tail)`, not
   `sum(duration_i)`.
5. **Any-fail-wins aggregation.** When multiple sensors map to the
   same Acceptance Contract criterion, the combined verdict is
   `fail` if any sensor reports `fail`. Per-sensor evidence is
   preserved inside the combined verdict.

The synchronous hook (`hooks/verify-acceptance.sh`) runs sensors
serially and is reserved for CI / headless callers. Both paths emit
the same per-sensor YAML schema, so downstream consumers see no
difference.

**Cycle-budget caveat.** When per-sensor timeout overrides push
`max(timeout_i)` beyond the ralph-loop cycle budget, the loop will
hit a hard bound before the cycle finishes. Document each long
override in the Acceptance Contract and verify the resulting cycle
budget against `hooks/check-hard-bounds.sh`.

**Inferential-sensor failure policy.** When a judge agent reports a
non-zero exit, `/yoke:implement` logs the failure to
`$(wm_runtime_dir)/.judge-verdicts/cycle-<N>/.failures.log`, treats
the criterion's verdict as `skip` for the cycle, and surfaces it in
the cycle status block. When the same sensor fails on two
consecutive cycles, the skill invokes
`lib/ralph-loop/escalate.sh --reason sensor-failure --sensor <id>`
and pauses the loop.

### Calibration drift management
Inferential sensors degrade as the underlying model changes. They carry:
- `calibrated_against: <model id>`
- `calibrated_at: <date>`
- `known_false_positives: <count or rate>`
- `known_false_negatives: <count or rate>`

Major model upgrades trigger recalibration (rippability principle). Drift
above a threshold triggers Orchestrator-mediated review of the sensor.

## Rules
- Every BDD scenario in the Acceptance Contract maps to at least one sensor (computational or inferential).
- Computational sensors are preferred over inferential ones. Promote inferential to computational whenever a deterministic encoding becomes possible.
- Sensor output is **machine-structured**, not prose. Plain-text-only output is a sensor bug.
- A failing sensor without a correction instruction or a canonical-memory reference fails the sensor's own quality check — it cannot be merged into the Contract.
- Inferential sensors carry calibration metadata. Without it, they cannot be used in a binding Contract.
- Sensors run inside the ralph loop (every cycle), not only at the merge boundary.

## Examples from this codebase
> Repository is empty. Expected sensor output shape:

```json
{
  "sensor": "structural:contract/payments-api.json",
  "status": "fail",
  "violations": [
    {
      "rule": "response-schema:RefundConfirmation.amount.currency",
      "location": "src/api/refund.py:142",
      "expected": "string (ISO-4217)",
      "actual": "number",
      "correction": "serialize amount.currency as ISO-4217 string before returning",
      "reference": "policies/api/iso-4217-currency-codes.md"
    }
  ]
}
```

```json
{
  "sensor": "inferential:semantic-judge/payment-reversal",
  "status": "fail",
  "calibrated_against": "claude-opus-4-7",
  "calibrated_at": "2026-04-22",
  "violations": [
    {
      "criterion": "error message includes actionable next step",
      "location": "src/api/refund.py:198",
      "evidence": "current message: 'Refund failed.' — no next step suggested",
      "correction": "include retry guidance per docs/error-voice.md",
      "reference": "conventions/error-voice.md#actionable-next-step"
    }
  ]
}
```

<!-- vibeflow:auto:end -->

## Anti-patterns
- Sensors that emit only `pass` / `fail` with no structured detail — agents cannot consume them.
- Reusing inferential sensors across unrelated scopes — calibration drift, both false positives and false negatives.
- Running sensors only at merge time — defeats shift-feedback-left, makes Phase 4 slow and expensive.
- Letting inferential sensors live without calibration metadata — invisible obsolescence the moment the model changes.
- Treating sensor verbosity as noise — the verbosity is the contract; silencing it removes the back-pressure mechanism.
- A failing sensor that the Validator ignores ("flaky") — either the sensor is wrong (fix it) or the implementation is wrong (fix it). There is no third option.

## Implementation Mapping

From `yoke-implementation-plan.md` (2026-04-24) — concrete artifacts:

- **Discovery** — `lib/sensors/discover-from-claude-md.sh` parses the host project's `CLAUDE.md` for marked sections (`## Testing`, `## Linting`, `## Build`, etc.) and emits a structured (yaml/json) list of available sensors. Fallback: the Validator asks the user directly.
- **Convention for `CLAUDE.md`** — host projects expose sensors by maintaining named sections that Yoke can parse. Documented in `docs/canonical-memory-setup.md` with a worked example.
- **Execution** — `lib/sensors/run-sensors.sh` and `hooks/verify-acceptance.sh` execute discovered sensors and emit structured output per the format in this pattern.
- **Calibration metadata** — inferential-sensor calibration lives in `templates/canonical-entry-frontmatter.yaml` (`model_calibrated_against`, `last_validated`) and is enforced during `/yoke:canonize`.
- **Sprint-3 limitation** — only "shell command" sensors are supported (e.g. `npm test`, `pytest`). Richer sensor types (structural fixtures, semantic judges with rubrics) ship in later sprints.
