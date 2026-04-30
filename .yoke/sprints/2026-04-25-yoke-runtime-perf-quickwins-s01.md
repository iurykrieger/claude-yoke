# Sprint 01 of 03: Yoke Runtime Perf Quick Wins

> Migrated from: # Spec: Yoke Runtime Perf Quick Wins — Part 1: Sensor Scoping + Parallelism + De-duplication


> Generated via /vibeflow:gen-spec on 2026-04-25 from
> `.vibeflow/prds/yoke-runtime-perf-quickwins.md`.

## Objective

Make every Phase 4 cycle run sensors **once**, **scoped** to the criterion the
Generator targeted, and **in parallel** — instead of running the full
acceptance-contract sensor suite serially **twice per cycle** (Validator +
coordinator).

## Context

Reading `skills/implement/SKILL.md:113-117` and `agents/validator.md:38`
together, the current cycle runs `hooks/verify-acceptance.sh` twice per
cycle and always against the full suite. On a simple feature with 4–6
acceptance criteria, this dominates wall-clock — every cycle re-runs every
sensor (lints, type checks, unit tests, structural tests) regardless of
which criterion the Generator just changed. The pattern docs already
permit a snapshot-consumption model: `patterns/ralph-loop.md:38-40` says
the Validator "runs sensors via `hooks/verify-acceptance.sh` (or reads
its prior snapshot)" and `patterns/roles.md:54-55` lists "Reads: sensor
output from `verify-acceptance.sh`" as Validator's input — both already
contemplate the snapshot path. This part operationalizes it.

Sensor scoping is also implicit-already: `patterns/sensors.md` rule "Every
BDD scenario in the Acceptance Contract maps to at least one sensor"
means the contract format must already carry per-criterion sensor
identity. We'll surface the mapping explicitly so the coordinator can
slice it.

## Definition of Done

1. **`--criterion <id>` resolves to a sensor subset.**
   `hooks/verify-acceptance.sh --criterion <id>` reads the active
   `wm_acceptance_contract_path` and runs **only** the sensors mapped to
   `<id>`. Default behavior (no flag) preserves the full-suite run for
   backward compatibility.
2. **Sensors run in parallel.**
   Sensor execution within `hooks/verify-acceptance.sh` is parallelized
   via `xargs -P "$(yoke_sensor_concurrency)"` (default `4`,
   overrideable via `.yoke/config.yaml`'s `runtime.sensor_concurrency`).
   Per-sensor stdout/stderr lands in dedicated fragment files under
   `$(wm_snapshots_dir)/cycle-<N>.fragments/` and is merged into the
   single `cycle-<N>.yaml` snapshot deterministically (alphabetical
   sensor-id order). No interleaved output corrupts the snapshot.
3. **Sensors run exactly once per cycle.**
   `skills/implement/SKILL.md` step 2 invokes `verify-acceptance.sh
   --criterion <last-targeted-criterion>` exactly once per cycle,
   post-Generator. `agents/validator.md` is updated so its "Always"
   section reads the snapshot at `$(wm_snapshots_dir)/cycle-<N>.yaml`
   instead of running `verify-acceptance.sh` itself.
4. **MERGE-READY check runs full-suite serial sweep.**
   The stop-check in `skills/implement/SKILL.md` step 6 runs
   `verify-acceptance.sh` (no `--criterion`) serially before declaring
   convergence. Scoped/parallel mode never decides MERGE-READY.
5. **Smoke test exercises all four behaviors.**
   `tests/smoke/perf-quickwins-part-1.test.sh` runs against a fixture
   acceptance contract with ≥ 3 sensors and asserts: (a) `--criterion`
   filters correctly, (b) parallel execution beats serial wall-clock by
   ≥ 30 % on the fixture, (c) the cycle invokes sensors exactly once
   (assert via an execution counter file written by a stub sensor),
   (d) MERGE-READY runs full suite. Smoke test wraps in `timeout 600`
   per `conventions.md`.
6. **Craftsmanship gate.**
   All bash changes pass `shellcheck` (where installed); the structured
   sensor-output contract from `patterns/sensors.md` is preserved
   (every emitted entry retains `sensor`, `command`, `status`,
   `exit_code`, `output_excerpt`, `reason`); no `conventions.md` Don't
   is violated; no new manifesto invariant is introduced.

## Scope

In scope:

- `hooks/verify-acceptance.sh` — add `--criterion <id>` flag; parse
  per-criterion sensor mapping from the active contract; parallelize
  via `xargs -P`; emit fragment files + deterministic merger.
- `skills/implement/SKILL.md` — coordinator invokes `verify-acceptance.sh
  --criterion <id>` exactly once per cycle (step 2); MERGE-READY check
  (step 6) runs full-suite serial.
- `agents/validator.md` — replace "Run `hooks/verify-acceptance.sh` every
  cycle" instruction with "Read the cycle's snapshot at
  `$(wm_snapshots_dir)/cycle-<N>.yaml`". Memory scope unchanged.
- `tests/smoke/perf-quickwins-part-1.test.sh` — new smoke test (4
  assertions above + `timeout 600` wrap).

The acceptance-contract template is **read-only** for this part — the
sensor-mapping format must already be parseable from the existing
template. If it is not, that is surfaced under Risks (R3 below) and
addressed by extending `templates/acceptance-contract.md` minimally
inside this part (counts as a 5th file; still within budget).

## Anti-scope

- **Not** changing the parallel-spawn architecture. Generator + Validator
  + Orchestrator stay concurrent per cycle.
- **Not** changing any human Trigger.
- **Not** changing canonical-memory write authority.
- **Not** introducing inferential-sensor parallelism semantics. Inferential
  sensors stay sequential within their declared scope.
- **Not** introducing a sensor-result cache across cycles. Every cycle
  produces a fresh snapshot (caching is orthogonal and out of scope).
- **Not** wiring per-sensor concurrency-safety metadata. v0 assumes
  sensors declared in the contract are concurrency-safe; unsafe sensors
  are documented as a Phase-2 risk (see R1) and worked around with
  `runtime.sensor_concurrency: 1` per task.
- **Not** changing Generator persona (Part 2's territory).
- **Not** changing model selection (Part 3's territory).

## Technical Decisions

### `xargs -P` over GNU parallel

Bash 4+ is the floor (`conventions.md` "Bash scripts target bash 4+").
GNU `parallel` is not assumed available. `xargs -P "$N"` ships with
POSIX userland, handles SIGTERM cleanly, and is sufficient for the
sensor-fanout use case. Trade-off: loses GNU parallel's per-job
result-collation; we compensate with per-sensor fragment files merged
in alphabetical order.

### Per-sensor fragment files

Concurrent writes to a shared `cycle-<N>.yaml` would race. Each parallel
sensor writes its own
`$(wm_snapshots_dir)/cycle-<N>.fragments/<sensor-id>.yaml`; a final
deterministic step concatenates them (sorted by sensor-id) into
`cycle-<N>.yaml`. This preserves snapshot reproducibility and makes
fragment-level debugging trivial. Trade-off: an extra directory per
cycle. Acceptable; cleaned up by `hooks/post-iteration.sh`'s existing
snapshot retention (or queued for cleanup if that hook does not yet
prune fragments — small follow-up if so).

### Validator switches to snapshot consumption

Pattern texts already permit it (see Context). The functional change in
`agents/validator.md` is text-only: replace one bullet under "Always",
update memory scope to clarify "snapshot, not execution". Adversariality
is preserved — Validator still judges cycle-N's diff against the
freshest sensor output, just via the coordinator's single execution.

### Backward-compatible scoping

`--criterion` is opt-in. Hosts whose contracts predate explicit
sensor-mapping continue to work via the unscoped default. Coordinator
upgrades the call (passing `--criterion`) only when the contract
declares a parseable mapping; otherwise it falls back to full-suite per
cycle (a slow but correct behavior).

### Concurrency knob lives in `.yoke/config.yaml`

New key: `runtime.sensor_concurrency` (default `4`). Operators with
slow CI / shared resources / known-unsafe sensors set it to `1` to
serialize. Coordinator reads it via `lib/working-memory/paths.sh`
(or a new `lib/runtime/config.sh` if needed — defer the helper-vs-inline
decision to implementation).

### Baseline measurement folded into the smoke test

Smoke test records cycle-time and sensor-time deltas to
`.vibeflow/audits/perf-quickwins-baseline.yaml`. No separate
instrumentation effort required; the test is the measurement. This
discharges the PRD's "instrumentation alongside v0" obligation.

## Applicable Patterns

- `patterns/sensors.md` — structured-output contract preserved across
  the fragment → snapshot merge; concurrency-safety convention noted in
  R1.
- `patterns/ralph-loop.md` — cycle protocol still has the same five
  stop conditions; only the sensor-execution placement and shape change.
  No new deterministic node is introduced — the existing `run_sensors()`
  node simply gets faster + scoped.
- `patterns/roles.md` — Validator authority unchanged (still no code
  writes, still co-writes `contracts.md` on consensus). The text-level
  change clarifies that `verify-acceptance.sh` invocation is the
  coordinator's responsibility, with the Validator as consumer.

No new pattern is introduced.

## Risks

- **R1: Concurrency-unsafe sensors silently corrupt cycles.**
  *What can go wrong:* a host project's sensor mutates a shared
  resource (a single test database, a fixed network port, a shared
  filesystem path) and parallel execution races, producing flaky
  PASS/FAIL signals.
  *Mitigation:* `runtime.sensor_concurrency: 1` documented as the
  fallback in `docs/installation.md` (or wherever Yoke runtime
  configuration is documented); examples/greenfield-payment-service
  documents the convention "one sensor → one DB schema / port /
  workdir" so concurrency is safe by default. v0.1 may add explicit
  per-sensor `concurrent: false` metadata if R1 fires in practice.
- **R2: Smoke-test timing assertions are flaky on shared CI.**
  *What can go wrong:* CI noise makes the "parallel ≥ 30 % faster than
  serial" assertion fail intermittently.
  *Mitigation:* assert wall-clock ratios (parallel-time / serial-time
  ≤ 0.7), not absolute times; run each leg twice and take the median;
  surface the actual numbers in test output for human review.
- **R3: Acceptance-contract template lacks parseable sensor mapping.**
  *What can go wrong:* the existing `templates/acceptance-contract.md`
  doesn't expose criterion → sensor-id mapping in a machine-parseable
  shape; `--criterion` cannot resolve cleanly.
  *Mitigation:* audit the template before coding; if a minimal
  extension is needed (e.g., a `sensors:` array per criterion already
  hinted at in `patterns/sensors.md`'s mapping rule), include it in
  this part's file budget. If extension would be invasive, fall back
  to full-suite-per-cycle and ship parallelism-only as v0; carry
  scoping into a v0.1 follow-up.
- **R4: Validator's snapshot is stale relative to its judgment turn.**
  *What can go wrong:* in the parallel batch, Validator reads a
  cycle-N-1 snapshot while Generator concurrently changes code that
  cycle-N's snapshot will reflect — the verdict is one cycle behind.
  *Mitigation:* this is the existing parallel-spawn semantic, not new
  to this part; `patterns/ralph-loop.md` already documents
  per-agent-input freshness. No change. Coordinator's post-Generator
  single execution captures cycle-N state for cycle-N+1's Validator,
  preserving the existing freshness semantics.

## Dependencies

None. This part is independently implementable.
