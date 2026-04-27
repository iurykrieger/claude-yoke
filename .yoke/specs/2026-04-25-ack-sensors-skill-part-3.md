# Spec: Inferential `semantic-judge` subagent (Part 3 of 4)

> Generated via /vibeflow:gen-spec on 2026-04-25 from `.vibeflow/prds/ack-sensors-skill.md`

## Dependencies

- `.vibeflow/specs/ack-sensors-skill-part-1.md` — catalog/readiness
  skill must exist; this part registers the inferential template into
  the catalog.
- `.vibeflow/specs/ack-sensors-skill-part-2.md` — Validator must already
  parallel-spawn computational sensors; this part adds the inferential
  spawn path on top.

## Objective

Introduce one inferential-sensor template (`semantic-judge`) and one
runtime subagent (`agents/semantic-judge.md`) so the Validator can
spawn LLM-backed semantic judges in parallel via the `Agent` tool,
making the abstract two-class sensor model from `patterns/sensors.md`
operational end-to-end.

## Context

`patterns/sensors.md` describes computational + inferential sensors as
the two-class contract Yoke promises, but v0.3.0 supports only
shell-command sensors. With Part 2 in place, the parallel-spawn
machinery is live for computational sensors via background Bash. This
part adds the inferential leg via `Agent`, exercising both classes
end-to-end and shipping the first concrete inferential template the
catalog can register.

## Definition of Done

1. New `lib/sensors/templates/semantic-judge.md` ships with mandatory
   calibration frontmatter: `calibrated_against` (model id),
   `calibrated_at` (ISO date), `known_false_positives` (number or
   rate), `known_false_negatives` (number or rate),
   `criterion_scope` (what kinds of criteria this template can judge).
   File is a self-contained template with a scope-binding prompt
   skeleton.
2. New `agents/semantic-judge.md` runtime subagent: spawned per
   inferential sensor by the Validator via
   `Agent(subagent_type: yoke:semantic-judge)`. Receives only:
   the Acceptance Contract criterion text, the diff under review,
   and the calibration block. Emits the same structured JSON verdict
   shape as computational sensors (`criterion / status / location /
   fix_instruction / sensor / evidence`).
3. Validator (`agents/validator.md`) updated to spawn inferential
   sensors via `Agent` alongside computational sensors via
   background Bash. `Monitor` aggregates events from both classes
   into a unified verdict stream. The any-fail-wins aggregation
   from Part 2 applies across both classes uniformly.
4. **Per-sensor hard timeout for inferential: 120s default.**
   Per-sensor override via Acceptance Contract bullet under a new
   `### Inferential` subsection (additive — does not change the
   `### Computational` syntax). Timeout produces `status: "skip"`,
   `reason: "timeout: 120s"`, `exit_code: 124`.
5. **Calibration drift writes to working memory only.** The
   semantic-judge subagent appends per-host calibration drift
   metrics (false-positive / false-negative observations) to
   `.yoke/sensors/<sensor-name>.md`. **No canonical-memory writes**
   from this skill — promotion to canonical happens via the
   existing `/yoke:preserve` path under Model C.
6. **Quality gate (subagent context isolation).** `agents/semantic-judge.md`
   "Allowed tools" is `Read` only — no `Write`, no `Bash`, no
   `Edit`. The subagent cannot touch host code, cannot read
   `.yoke/progress.md`, cannot read `.yoke/query-trace.md`. Only
   the per-spawn input it receives. Asserted by reading the
   subagent file's frontmatter in the smoke test.
7. **Quality gate (verdict shape parity).** `tests/smoke/ack-sensors-inferential.test.sh`
   asserts that the inferential verdict JSON is byte-shape-identical
   to the computational verdict JSON (same keys, same nesting). Any
   downstream consumer (Orchestrator escalation, contracts.md) sees
   no difference between the two classes.

## Scope

- New `lib/sensors/templates/semantic-judge.md`:
  - YAML frontmatter (calibration metadata).
  - Markdown body: scope-binding prompt skeleton with `{{criterion}}`,
    `{{diff}}`, `{{calibration_block}}` placeholders.
  - Inline documentation of which criterion types it can judge
    (semantic alignment with Tech Spec, error-message voice,
    README-vs-API consistency — calibration scope examples).
- New `agents/semantic-judge.md`:
  - Frontmatter: `name: semantic-judge`, `description`, `tools: Read`.
  - Body: persona (terse, structured-output-only), behaviors
    (Always: emit verdict in JSON; Never: write files, read other
    .yoke files, fabricate fix instructions without evidence).
  - Memory scope: `task` — but stricter than Validator: only the
    spawn-time inputs.
- Modify `agents/validator.md`:
  - Add `Agent` to "Allowed tools".
  - Extend "Sensor execution protocol" (added in Part 2) with the
    inferential branch: for each sensor with `class: inferential`,
    spawn via `Agent(subagent_type: yoke:semantic-judge, ...)`
    instead of `Bash(run_in_background=true)`.
  - Document the unified `Monitor` aggregation across classes.
- New `tests/smoke/ack-sensors-inferential.test.sh`:
  - Fixture Acceptance Contract with one computational + one
    inferential sensor on the same criterion.
  - Asserts verdict shape parity, calibration-drift write to
    `.yoke/sensors/`, no canonical-memory writes (proven by
    git-status check on the canonical substrate fixture remaining
    clean), 120s timeout default applied.

## Anti-scope

- **No** additional inferential templates beyond `semantic-judge`.
  Rubric-based judges, diff-coherence judges, behavior-equivalence
  judges — explicit follow-ups, not this PR.
- **No** automatic calibration recalibration on model upgrades.
  Recalibration is a manual `/yoke:preserve` flow per the
  rippability principle in `patterns/sensors.md`.
- **No** fan-out: one inferential sensor → one judge subagent. No
  ensemble voting, no n-of-m quorum.
- **No** changes to canonical-memory write protocol. Calibration
  drift writes are working-memory-only; promotion is a separate
  human-driven `/yoke:preserve` action.
- **No** dynamic prompt rewriting based on prior verdicts. Each
  judge spawn is independent; cross-cycle learning happens via
  the calibration drift file, consumed in future cycles via the
  template's frontmatter — not via prompt mutation.
- **No** modification of the catalog mode in `/yoke:ack-sensors`
  to enumerate `lib/sensors/templates/`. That listing-extension
  belongs to a follow-up; this part only registers the template
  on disk.

## Technical Decisions

### One subagent type per inferential class
`yoke:semantic-judge` is a single, reusable subagent that takes the
template + criterion + diff as input. We do not generate a new
subagent file per inferential sensor. Reason: subagent files are
prompt scaffolding; sensor-specific behavior lives in the
**template** (which is the calibration-bound artifact). The same
subagent loads different templates depending on the sensor.

**Trade-off:** the subagent prompt must be generic enough to host
many templates. Mitigated by making the subagent body short and
delegating all judgment criteria to the loaded template.

### `Read`-only tools for the judge
Adversarial separation per `patterns/roles.md` is non-negotiable.
The judge cannot patch code, cannot write `progress.md`, cannot
read `query-trace.md`. It receives a closed set of inputs and
returns a verdict. This means the judge cannot validate against
canonical-memory policies directly — that's the Orchestrator's job.

**Trade-off:** the judge is unaware of broader project context.
But that's the point — semantic judgment must be reproducible
from the criterion alone, otherwise the calibration metadata
is meaningless.

### Calibration drift in working memory, not canonical
Per the resolved PRD question 4 (Option B). Working-memory drift
files are task-scoped — they accumulate per-host signal that the
human reviews during termination canonization and proposes
upstream via `/yoke:preserve`. This keeps Model C governance
intact: no automatic doctrine writes from a stochastic judge.

### Verdict shape parity with computational sensors
The judge must emit the exact same JSON shape (`criterion /
status / location / fix_instruction / sensor / evidence`).
`location` for inferential verdicts is the file/line range in the
diff that triggered the judgment; `fix_instruction` is the
satisfaction criterion (since deterministic fixes aren't always
known). Documented in the template.

### Inferential timeouts default to 120s (vs. 60s computational)
Per the resolved PRD question 1. Inferential judges include LLM
roundtrip latency, so the same budget is too tight. Per-sensor
override via the Contract.

### `### Inferential` subsection in the Contract is additive
The current Contract has only `### Computational` under
`## Sensors`. Part 3 introduces `### Inferential` as a sibling
subsection with the same bullet syntax. Hooks parsing
`### Computational` are unaffected.

## Applicable Patterns

- **`patterns/sensors.md`** — calibration metadata mandatory for
  inferential sensors. The template ships with full frontmatter.
  This part is the first concrete instance of the inferential
  class; future templates follow the same shape.
- **`patterns/roles.md`** — "runtime subagents do not share
  context" rule applies to `semantic-judge`: it gets only its
  spawn inputs, no working-memory access beyond the calibration
  drift file (write-only).
- **`patterns/ralph-loop.md`** — concurrent batch principle is
  preserved: judge subagents are spawned in the same Monitor-
  aggregated wave as computational sensors, not in a separate
  pass. Update the pattern's "concurrent agentic batch" to note
  that the Validator now spawns *additional* per-sensor
  Agent calls inside its own scope (nested, not sequential).
- **Conventions: "Blueprints wrapping agentic nodes"** — each
  judge is a contained agentic node: clear input, clear output,
  no side effects beyond the calibration drift file.
- **Conventions: "Minimalist canonical memory with mandatory
  traceability"** — calibration drift stays out of canonical
  until promoted, preserving the inversion default.

## Risks

| Risk | Likelihood | Impact | Mitigation |
| :--- | :--- | :--- | :--- |
| `Agent`-spawned subagents have unbounded latency under load, breaking the 120s timeout assumption | medium | high | Validator wraps the `Agent` call in a deadline (Bash subshell) and treats no-event-by-deadline as `status: "skip"`, `reason: "timeout"`. Smoke test asserts a sleep-fixture template times out cleanly |
| Calibration drift file accumulates indefinitely per task | low | medium | Working-memory files are per-task; they reset with each new task's `.yoke/`. Document this lifecycle in `patterns/sensors.md` |
| Judge produces a `pass` verdict without evidence (LLM hallucinates) | medium | high | Smoke test asserts every `pass` verdict has a non-empty `evidence` field. The template prompt requires evidence per the "back-pressure" rule. False-pass rate tracked in calibration drift |
| Adding `Agent` to Validator's tool list is misused (Validator spawns generic subagents instead of judges) | low | high | The "Allowed tools" change is paired with a hard rule in `agents/validator.md`: `Agent` may be used **only** with `subagent_type: yoke:semantic-judge`. Other subagent types are forbidden. Review-time enforcement |
| Judge's per-host calibration drift never gets promoted, so doctrine never improves | medium | medium | This is a process risk, not a code risk — but document the promotion path in `patterns/sensors.md` and surface drift summaries in `/yoke:status` (separate task, Sprint-7 candidate) |
| Same-criterion any-fail-wins makes the Validator overly conservative when a flaky judge contradicts a passing computational sensor | medium | medium | Documented in `patterns/sensors.md`: "Either the judge is wrong (recalibrate) or the implementation is wrong (fix). There is no third option." Calibration drift surfaces flaky judges |
