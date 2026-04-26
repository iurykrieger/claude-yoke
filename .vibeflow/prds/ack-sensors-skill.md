# PRD: `/yoke:ack-sensors` skill + parallel sensor execution by the Validator

> Generated via /vibeflow:discover on 2026-04-25

## Problem

Today, sensor execution is collapsed inside the Validator subagent's
single hot path: `hooks/verify-acceptance.sh` is called once per cycle,
extracts every computational sensor declared in the Acceptance Contract,
and runs them serially in a `while` loop. This has three downstream pains:

1. **Cycle latency is dominated by the slowest sensor.** A 30s typecheck
   blocks a 2s lint, blocks a 5s structural test. The Validator can't
   emit a partial verdict until everything finishes, even when half the
   verdict is already decided.
2. **No catalog of what sensors are available.** The host project's
   sensors are discovered ad-hoc from `CLAUDE.md` at spec time
   (`lib/sensors/discover-from-claude-md.sh`) and then frozen into the
   Acceptance Contract by hand. There is no skill the human
   (Trigger 3) or the Validator (Phase 4 start) can invoke to enumerate
   *every* sensor that could be wired in — including inferential ones
   that don't exist yet because the runtime never had a place for them.
3. **Inferential sensors are paper-only.** `patterns/sensors.md`
   describes computational + inferential sensors as the two-class
   contract, but the v0.3.0 runtime supports only shell-command
   sensors. The reason is purely mechanical: a serial bash loop has no
   way to host an LLM-backed semantic judge. The architecture allows
   them; the implementation doesn't.

The combined symptom: Phase 4 cycles are slower than they need to be,
and the Validator is structurally prevented from doing the rigorous
semantic judging the manifesto promises.

## Target Audience

- **Primary:** the Validator runtime subagent
  (`agents/validator.md`), which today blocks on
  `hooks/verify-acceptance.sh` and will instead orchestrate parallel
  sensor execution.
- **Secondary:** humans authoring the Acceptance Contract during
  Trigger 3, who today guess which sensors to declare and will instead
  pick from a catalog produced by `/yoke:ack-sensors`.
- **Tertiary:** the `/yoke:acceptance-contract` skill, which can call
  `/yoke:ack-sensors` to surface available sensors when drafting the
  contract.

## Proposed Solution

Introduce a single new skill, **`/yoke:ack-sensors`**, that has two
operational modes:

- **Catalog mode** (`--mode catalog`, default) — scan the host project
  and emit a structured catalog of every sensor that *could* run:
  computational sensors discovered from `CLAUDE.md`, `package.json`
  scripts, `Makefile`, `pyproject.toml`, etc., plus inferential-sensor
  templates registered in `lib/sensors/templates/`. Output is YAML the
  Acceptance Contract author (or `/yoke:acceptance-contract` skill)
  can copy from.
- **Readiness mode** (`--mode readiness <contract-path>`) — invoked by
  the Validator at the start of every Phase 4 cycle. Resolves the
  active task's Acceptance Contract, checks that every declared sensor
  is reachable (binary on `$PATH`, fixture path exists, inferential
  template found and calibrated), and emits a runtime manifest the
  Validator uses to schedule parallel execution.

Refactor the **Validator subagent** to consume that manifest and
spawn sensors in parallel:

- **Computational sensors** spawn via `Bash(run_in_background=true)`,
  each as an independent shell job. The Validator uses the `Monitor`
  tool to stream completion events and assemble verdicts as each
  sensor finishes.
- **Inferential sensors** spawn via the `Agent` tool with a dedicated
  `subagent_type: yoke:semantic-judge` (one new agent file:
  `agents/semantic-judge.md`). Each judge gets its own
  Acceptance-Contract scope, calibration metadata, and emits the same
  structured JSON verdict shape as computational sensors.

`hooks/verify-acceptance.sh` is kept as the **synchronous fallback**
for CI and headless callers — it stays compatible with today's
contract format and emits the same YAML output.

Ship one inferential-sensor template (`semantic-judge`) as part of
this work so the parallel-spawn machinery exercises both classes
end-to-end. Additional inferential templates (rubric-based judge,
diff-coherence judge, etc.) are explicit follow-ups.

## Success Criteria

A single `/yoke:implement` cycle on `examples/greenfield-payment-service/`
satisfies all of the following, observable from `.yoke/runtime/progress.md`
and the Validator's verdict log:

1. **Catalog visible.** Running `/yoke:ack-sensors` (no args) on a
   fresh host project emits a YAML catalog with at least one
   computational sensor (discovered from `CLAUDE.md`) and one
   inferential-sensor template (from `lib/sensors/templates/`). Empty
   discovery still returns valid YAML with a `notes:` block.
2. **Readiness gates the cycle.**
   `/yoke:ack-sensors --mode readiness` exits non-zero when an
   Acceptance Contract declares a sensor whose binary is missing or
   whose inferential template is uncalibrated, and the Validator
   surfaces the failure as a structured verdict with
   `status: "skip"` + `reason`.
3. **Parallel execution measurable.** With three computational
   sensors of mixed duration (2s / 5s / 30s) plus one inferential
   sensor (~10s), wall-clock cycle time is within 1.3× the slowest
   sensor — proving real parallelism, not serial dressing.
4. **Verdict shape unchanged.** Every sensor (computational or
   inferential) emits the existing structured JSON verdict
   (`criterion / status / location / fix_instruction / sensor /
   evidence`). Downstream consumers (`.yoke/contracts/<slug>.md`,
   Orchestrator escalation) need zero changes to interpret it.
5. **Backwards-compatible fallback.** Calling
   `hooks/verify-acceptance.sh` directly (no Validator) still works
   for CI / headless use, runs sensors serially, and emits the
   current YAML schema.

## Scope v0

1. New skill `skills/ack-sensors/SKILL.md` with two modes (catalog,
   readiness).
2. Catalog discovery extended beyond `CLAUDE.md`: also parse
   `package.json` `scripts`, `Makefile` targets, `pyproject.toml`
   `[tool.*]` sections (best-effort, additive — `CLAUDE.md` remains
   authoritative).
3. New `lib/sensors/templates/` directory with one inferential
   template: `semantic-judge.md` (calibration metadata + scope-binding
   prompt skeleton).
4. New runtime subagent `agents/semantic-judge.md` (Agent tool target,
   spawned per inferential sensor by the Validator).
5. Validator refactor (`agents/validator.md`): consume the readiness
   manifest, spawn computational sensors via background Bash, spawn
   inferential sensors via `Agent`, aggregate verdicts via `Monitor`,
   emit unchanged structured JSON.
6. `hooks/verify-acceptance.sh` retained as serial fallback; updated
   to delegate to `/yoke:ack-sensors --mode readiness` for sensor
   discovery (single source of truth) but keep its own serial
   execution path.
7. Pattern doc update: `patterns/sensors.md` gains a "Parallel
   execution & acknowledgement" subsection documenting the new
   topology.
8. Smoke test: `tests/smoke/ack-sensors.test.sh` covering catalog
   mode, readiness mode (success + missing-binary failure), and
   parallel-execution wall-clock assertion.

## Anti-scope

- **No** new sensor *types* beyond the one inferential template
  (`semantic-judge`). Rubric-based judges, diff-coherence judges,
  cross-file structural fixtures, etc. — explicit follow-ups, not
  this PR.
- **No** changes to the Acceptance Contract format. Sensors are still
  declared under `## Sensors > ### Computational` and a new
  `### Inferential` subsection (additive only).
- **No** Validator code-write authority. Validator still only
  judges; it never patches host code to satisfy a sensor.
- **No** caching layer for sensor results across cycles. Every cycle
  re-runs every sensor. (Caching is an interesting follow-up but
  introduces invalidation logic that doesn't belong in v0.)
- **No** dynamic sensor registration at runtime. The catalog is a
  read-only snapshot per invocation.
- **No** changes to canonical-memory write authority. Calibration
  metadata for the new `semantic-judge` template ships in
  `templates/canonical-entry-frontmatter.yaml` and is canonized via
  the existing `/yoke:preserve` path.
- **No** dogfooding of `/yoke:ack-sensors` inside Yoke's own build —
  Yoke v1.0 is built without running Yoke on itself
  (`.vibeflow/decisions.md`).

## Technical Context

Anchored in what already exists in this repo:

- `lib/sensors/discover-from-claude-md.sh` is the existing
  `CLAUDE.md` parser. `/yoke:ack-sensors` will *call* it (don't
  reimplement) and union its output with new discoverers for
  `package.json`, `Makefile`, `pyproject.toml`. Each discoverer is
  its own bash script under `lib/sensors/discover-*.sh` (mirrors the
  existing naming).
- `hooks/verify-acceptance.sh` already extracts sensors from the
  Acceptance Contract's `## Sensors > ### Computational` block. The
  refactor must keep this hook backwards-compatible for CI; the new
  parallel path is invoked by the Validator subagent, not the hook.
- `agents/validator.md` currently lists `Bash` in its allowed tools
  but does not yet use `run_in_background`. The refactor adds usage
  of `Bash(run_in_background=true)`, `Monitor`, and `Agent`
  (specifically `subagent_type: yoke:semantic-judge`) to the
  Validator's tool list — and updates the "Allowed tools" section in
  the agent file accordingly.
- `patterns/sensors.md` already documents the structured-output
  back-pressure principle and calibration metadata. The new code
  must preserve both: structured JSON verdicts only; calibration
  frontmatter required for every inferential template.
- `templates/canonical-entry-frontmatter.yaml` is where
  `model_calibrated_against` and `last_validated` live for
  inferential sensors — the new `semantic-judge` template uses this
  shape unchanged.
- Sprint discipline: this work fits inside the Sprint-7
  "background agents" theme (`.vibeflow/specs/yoke-v1-sprint-7.md`,
  if present), not the Sprint-3 sensor-bootstrap theme. Confirm
  sprint placement in gen-spec.

Constraints to respect:

- **Bash 4+** (macOS users via Homebrew) — standard for this repo.
- **No infinite loops** — every parallel sensor must have a hard
  timeout (per-sensor, defaulted via the Acceptance Contract's
  `timeout_seconds:` field on the sensor declaration). **Per-class
  defaults: 60s for computational, 120s for inferential.** Per-sensor
  overrides in the Contract win. Aligns with the "ralph loop with
  hard bounds" invariant.
- **Verdict aggregation: any-fail-wins.** When multiple sensors map
  to the same Acceptance Contract criterion, the Validator's combined
  verdict is `fail` if any sensor reports `fail` — independent of how
  many other sensors `pass`. This preserves the back-pressure
  principle from `patterns/sensors.md` (verbosity is the contract).
- **Catalog output is deterministic.** `/yoke:ack-sensors --mode
  catalog` emits sensors sorted by `(category, source, command)` so
  the YAML is diff-stable across invocations and reviewable in PRs.
- **Calibration drift lives in working memory.** Per-host
  false-positive / false-negative rates for inferential sensors are
  written to `.yoke/sensors/<sensor-name>.md` (working memory, task
  scope). Canonical templates under `lib/sensors/templates/` carry
  *initial* calibration only; drift accumulates locally and is
  promoted to canonical memory via `/yoke:preserve` on the existing
  Model-C path — not by `/yoke:ack-sensors`.
- **Monitor-driven streaming.** The Validator listens via the
  `Monitor` tool to events emitted by backgrounded Bash sensors and
  by `Agent`-spawned `yoke:semantic-judge` subagents. The Validator
  assembles the verdict map incrementally as events arrive — it does
  not block until all sensors finish.
- **Adversarial separation** — the inferential `semantic-judge`
  subagent must not share context with the Generator. Its prompt
  receives only: the Acceptance Contract criterion, the diff under
  review, and the calibration block. No `progress.md`, no
  `query-trace.md` beyond what the criterion explicitly references.
- **Progressive disclosure** — `/yoke:ack-sensors` does not load
  canonical memory. Calibration metadata is bundled with the
  template file itself.

## Open Questions

None remain blocking.

Resolved during discovery (2026-04-25):

1. ~~Hard-timeout default~~ → **60s computational, 120s inferential**
   per-class defaults; per-sensor overrides via the Contract win.
2. ~~Verdict aggregation when sensors disagree~~ → **any-fail-wins**
   (back-pressure principle preserved).
3. ~~`Monitor`-tool semantics~~ → **Monitor streams events to the
   Validator**; Validator assembles verdicts incrementally. Reliability
   for ≥4 concurrent sensors stays as a Tech-Spec Risk to spike during
   implementation, not a blocker.
4. ~~Inferential-sensor calibration storage~~ → **Option B**:
   `.yoke/sensors/<sensor-name>.md` (working memory). Promotion to
   canonical memory happens via the existing `/yoke:preserve` path,
   not by `/yoke:ack-sensors`.
5. ~~Catalog stability~~ → **Yes, deterministic output** sorted by
   `(category, source, command)`.
