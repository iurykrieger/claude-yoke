# PRD: Sensor Cost Tiering with Validator-Owned Scheduling

> Generated via /vibeflow:discover on 2026-04-27
> Updated 2026-04-27 — sensors promoted to first-class persistent
> artifacts in `.yoke/sensors/<id>.md`.

## Problem

During autonomous `/yoke:implement` runs, expensive sensors (Playwright
e2e, long-running inferential judges) burn ~60–120 s **every cycle** on
tests that cannot pass until the feature is fully assembled. The
Generator cannot act on the failure — the e2e isn't reporting a bug,
it's reporting incompleteness. The output is wallpaper, not feedback.

A second, related problem: sensor metadata today lives inline inside
`acceptance-contract.md` and has no place to grow. There is no per-
sensor home for accumulated caveats, recent run results, calibration
notes, or "this sensor flakes when the test DB is cold" knowledge.
Without that home, the Validator cannot make informed scheduling
decisions — it has to re-derive everything from the latest sensor
output every cycle.

The right principle is **shift-left only when feedback is actionable**:

- A failing unit test mid-cycle is actionable: the Generator can fix it.
- A failing Playwright run three cycles before the page mounts is not
  actionable: it's a known-fail by construction.

The framework should encode this distinction as first-class sensor
state — declared once, refined over time — and let the Validator
decide per-cycle when to spend the expensive sensor budget using
that state.

## Target Audience

- **Primary**: Yoke users running `/yoke:implement` on features with
  non-trivial e2e or heavyweight inferential coverage.
- **Initial validation**: the Yoke developer dogfooding the framework
  on the `e2e-tests` worktree where this insight originated.

## Proposed Solution

Four coordinated changes, all confined to Phase 4 runtime + working
memory:

1. **Sensors as first-class persistent artifacts.** Each sensor lives
   in `.yoke/sensors/<sensor-id>.md` — a markdown file with YAML
   frontmatter (`command`, `class`, `tier`, `applies_to`, `runs:`
   history) and a body for caveats, calibration notes, and accumulated
   learnings. `/yoke:ack-sensors` gains an **upsert mode** that
   creates / updates these files from the Acceptance Contract's sensor
   declarations. The Acceptance Contract references sensors by ID
   (`sensor: <id>`); the per-sensor file is the source of truth for
   command + tier + class + history.

2. **Cost tier on the sensor.** `tier: cheap | expensive` lives in the
   sensor file's frontmatter. The default is **derived from the
   sensor's class** (`computational` → `cheap`; `inferential` →
   `expensive`). Authors override per sensor — the explicit field
   always wins. Heavy computational sensors (Playwright, browser
   automation) require an explicit `tier: expensive` annotation.

3. **Validator-owned scheduling per cycle.** The Validator's per-cycle
   verdict gains a `schedule_next` block naming the sensors (or tier
   shorthands) the coordinator should run **next** cycle. The
   Validator reads `.yoke/sensors/<id>.md` files when deciding —
   caveats, recent runs, and known flake history feed the decision.
   Default policy: `tier:cheap` always; `tier:expensive` when (a)
   cheap-tier was green this cycle for the targeted criterion(s),
   (b) the Validator explicitly authorizes (e.g. diff touches
   expensive-relevant surface, or the sensor has been green for two
   prior cycles), or (c) merge-ready.

4. **Two-phase per-cycle execution + result persistence.** Within a
   cycle:
   - **Phase A** (after Generator diff) — cheap sensors fire
     synchronously via `hooks/verify-acceptance.sh --tier cheap`.
   - **Phase B** (cycle boundary, gated) — expensive sensors fire only
     when authorized by the previous cycle's `schedule_next`
     (lag-by-one — same model used for inferential judges per
     `patterns/sensors.md:90`).
   - **After both phases**, the coordinator appends the cycle's per-
     sensor results to each sensor file's `runs:` history. This is
     the durable record the Validator reads next cycle.

The **merge-ready convergence check always runs the full sensor suite
across all tiers** — non-negotiable. The binding contract is satisfied
only when every sensor passes.

## Success Criteria

Measured on a representative feature with at least one expensive
sensor (e.g. a Playwright suite covering the e2e-tests worktree):

- **Cycle wall-clock drops ≥ 40 %** on cycles where Phase B is gated
  off (instrumented baseline + post-change runs, archived in
  `.vibeflow/audits/`).
- **Expensive-sensor cycles run ≤ 30 %** of total cycles on a feature
  with at least one declared `expensive` sensor — gating actually
  defers most runs.
- **Zero false-positive convergence.** Merge-ready full sweep catches
  every failure that gated cycles skipped; no run declared done while
  any expensive sensor fails or remains unrun.
- **Sensor-file persistence verified.** After a multi-cycle run,
  `.yoke/sensors/<id>.md` files exist for every contract-declared
  sensor; their `runs:` history records the cycles run, results, and
  durations.
- **Validator uses sensor history.** On a fixture run where a sensor
  has flaked in `runs:` history, the Validator's `schedule_next`
  reasoning explicitly cites the flake — observable in
  `progress.md` / `contracts.md`.
- **Validator scheduling correctness on calibration fixtures.** When
  cheap is red, no expensive authorized; when cheap green and diff
  touches expensive-relevant surface, expensive authorized.

## Scope v0

### Working-memory layout

- `.yoke/sensors/` directory introduced via a new `wm_sensors_dir`
  helper in `lib/working-memory/paths.sh`.
- `templates/sensor.md` (new) — per-sensor template:
  ```
  ---
  id: <sensor-id>
  command: <shell command>
  class: computational | inferential
  tier: cheap | expensive   # optional; defaults from class
  applies_to: [<criterion-id>...]
  runs: []                  # populated by the coordinator
  ---
  # <human-readable name>

  ## Caveats
  <known flakes, environmental dependencies, calibration notes>
  ```

### Acceptance Contract by reference

- `templates/acceptance-contract.md`: sensor declarations become
  references (`sensor: <id>`) rather than inline blocks. Tier and
  command no longer appear in the contract — they live in the
  sensor file.

### `/yoke:ack-sensors` upsert mode

- `lib/sensors/ack-sensors.sh` extended with an upsert path:
  - **catalog mode** (existing): list available sensors.
  - **readiness mode** (existing): verify every contract-referenced
    sensor has a file at `.yoke/sensors/<id>.md` and the file is
    well-formed.
  - **upsert mode** (new): create / update `.yoke/sensors/<id>.md`
    files from contract references. Class-based default applied
    when sensor file is created without explicit tier. Author
    edits to existing sensor files are preserved (do not clobber
    caveats, calibration notes, runs history).

### Tier-aware execution

- `hooks/verify-acceptance.sh` gains `--tier cheap | expensive | all`
  (orthogonal to the existing `--criterion <id>`). Reads sensor
  files to resolve tier per sensor; runs only the matching subset.
  Default (no flag): all sensors — backward compat.

### Validator scheduling

- `agents/validator.md`:
  - Reads `.yoke/sensors/<id>.md` files when emitting
    `schedule_next` — caveats and `runs:` history feed the decision.
  - Emits `schedule_next: { sensors: [...], tiers: [...], reason:
    "..." }` in every cycle verdict.
  - Default rule: cheap always; expensive when prior-cycle cheap
    green for targeted criterion OR Validator-authorized OR merge-
    ready.
  - Cycle-1 heuristic: with no prior `schedule_next`, the
    coordinator runs cheap only; the Validator's first verdict may
    use Tech-Spec signals + cycle diff to authorize expensive
    starting cycle 2.
- `templates/progress.md` and `templates/contracts.md` persist
  `schedule_next` per cycle.

### Coordinator two-phase + history persistence

- `skills/implement/SKILL.md`:
  - Two-phase per-cycle execution: Phase A (cheap) synchronous via
    the hook; Phase B (expensive) gated by cycle N-1's
    `schedule_next`.
  - After both phases, append the cycle's per-sensor result to each
    sensor file's `runs:` history (timestamp, status, duration,
    cycle number, criterion targeted).
  - Cycle-1 default: Phase A only.
  - Merge-ready convergence: full sweep, regardless of
    `schedule_next`.

### Pattern documentation

- `.vibeflow/patterns/sensors.md`: new subsection covering the
  `.yoke/sensors/` layout, class-based tier default, two-phase
  execution, lag-by-one Validator scheduling, run-history
  persistence, and the actionable-feedback rationale (with explicit
  reconciliation against shift-feedback-left).

### Tests

- `tests/sensor-tiering.test.sh` covering:
  - Sensor-file format and class-based default.
  - `ack-sensors.sh` upsert preserves author edits.
  - Contract-by-ID references parse correctly.
  - `verify-acceptance.sh --tier` filters by tier read from sensor
    files.
  - Validator verdict format includes `schedule_next` with required
    fields, and the reasoning cites sensor history when present.
  - End-to-end smoke: 3-cycle run with one cheap + one expensive
    sensor, asserting Phase B gating + run-history persistence +
    merge-ready full sweep.

## Anti-scope

Explicitly **not** in v0:

- **No automatic tier inference from runtime, naming, or duration.**
  Class-based default only. Author override always wins.
- **No third tier** (`merge-ready-only`, `nightly`).
- **No per-criterion tier overrides.** Tier is a property of the
  sensor file, not of the (criterion, sensor) pair.
- **No in-cycle scheduling.** Validator decides via lag-by-one.
- **No canonization of sensor knowledge to canonical memory.** Sensor
  files live in working memory only. Promotion to canonical memory
  via `/yoke:preserve` is out of scope; revisit after observing
  what accumulates in `.yoke/sensors/` over real runs.
- **No sensor-file schema versioning.** Premature.
- **No automatic flake detection / quarantine.** The `runs:` history
  enables it as a future addition; v0 only persists data.
- **No retry policy changes.**
- **No CI workflow wiring.** Sprint-8 CI integration is separate.
- **No tier-aware budget accounting.** Cycle budget stays uniform.
- **No removal or weakening of any manifesto invariant.** Shift-
  feedback-left is **refined**, not rescinded — cheap sensors still
  run every cycle; only expensive sensors are gated, with explicit
  rationale.
- **No changes to canonical-memory governance, Model C, or any human
  Trigger.**

## Technical Context

This PRD layers on top of `yoke-runtime-perf-quickwins.md`:

- That PRD: scope sensors by criterion, run them once per cycle
  (de-dup), full-suite serial sweep at merge-ready.
- This PRD: among the criterion-scoped sensors, gate the expensive
  ones via Validator-owned scheduling — and persist sensor knowledge
  + history as first-class artifacts so the Validator's decision is
  informed.

Both PRDs touch `hooks/verify-acceptance.sh`, `agents/validator.md`,
`skills/implement/SKILL.md`. Sequencing matters — implement
`yoke-runtime-perf-quickwins` first or in parallel; this PRD assumes
its `--criterion` flag, snapshot-based Validator, and once-per-cycle
sensor execution model.

Manifesto invariants verified compatible:

- **Shift feedback left** (`patterns/sensors.md:136`,
  `conventions.md:18-22`) — preserved with refinement: cheap sensors
  still run inside the loop every cycle. Expensive sensors are gated
  precisely because their pre-convergence failures are not actionable
  feedback. The new sensors-pattern subsection records this rationale
  explicitly.
- **Structured sensor output** — unchanged. Tier and history are
  metadata; the per-cycle output schema is untouched.
- **Hard bounds** — unchanged. Cycle budget covers Phase A + Phase B
  when both run.
- **Binding spec** — unchanged. Acceptance Contract still defines
  done; tier and per-sensor file are execution metadata, not a
  binding-scope change. Merge-ready full sweep guarantees binding
  semantics.
- **Sprint contracts ⊂ Acceptance Contract** — unchanged.
- **Adversarial loop** — Validator's scheduling is a refinement of
  its judgment role.
- **Working memory is per-task and short-lived** — `.yoke/sensors/`
  fits the working-memory tier definition. Promotion of stable
  sensor knowledge to canonical memory is a separate, later concern.

Reference points in this repo:

- Sensor declaration site (today): `templates/acceptance-contract.md`.
- Sensor parser: `lib/sensors/ack-sensors.sh`.
- Sensor execution entry: `hooks/verify-acceptance.sh`.
- Validator persona: `agents/validator.md`.
- Coordinator cycle protocol: `skills/implement/SKILL.md`.
- Working-memory paths helper: `lib/working-memory/paths.sh`.
- Inferential-judge lag-by-one model: `patterns/sensors.md:74-119`.
- Sensors pattern doc to extend: `.vibeflow/patterns/sensors.md`.

## Open Questions

- **`schedule_next` schema and audit visibility.** Locked shape:
  `{ sensors: [<id>...], tiers: [cheap|expensive], reason: "..." }`.
  Decide in Tech Spec whether `reason` is a free-form string or a
  structured citation list referencing sensor IDs + run-history
  entries. Pragmatic v0: free-form string with the requirement to
  cite at least one signal source.
- **Interaction with `runtime.inferential_sensor_concurrency`.**
  When expensive includes inferential, the existing concurrency cap
  + deferred-sensors queue (`patterns/sensors.md:80-86`) still
  apply. Verify precedence: tier gating happens **before** the
  concurrency cap.
- **`runs:` history retention.** Unbounded growth bloats sensor
  files. Tech Spec must specify a cap (proposal: keep last N=20
  cycles; older entries roll off). Pruning is a coordinator
  responsibility on append.
- **`ack-sensors.sh` upsert idempotency under concurrent edits.**
  If a human edits `caveats` while a cycle is appending `runs:`,
  ensure the upsert merges rather than overwrites. Tech Spec must
  specify the merge strategy (preserve frontmatter fields the human
  edited, append-only to `runs:`).
- **Sensor-file deletion semantics.** When a sensor is removed from
  the contract, does its `.yoke/sensors/<id>.md` file get deleted,
  archived, or left in place? Pragmatic v0: leave in place (no
  destructive deletion); annotate as orphan in a future drift-sense
  pass.

## Resolved decisions

Locked in during discovery on 2026-04-27:

- **Inferential-sensor default tier = `expensive`.** Median
  inferential runtime exceeds the cheap-feedback threshold.
- **Cycle 1 default = cheap only.** No prior `schedule_next` exists;
  Validator's first verdict authorizes expensive starting cycle 2,
  judging by the type of work being implemented (Tech-Spec signals
  + cycle diff).
- **Class-based default for unannotated sensors.** Parser fills in
  the implied tier when the sensor file omits `tier:`. Authors
  override via explicit `tier:`. No runtime / name / duration
  inference.
- **Sensors as first-class persistent artifacts** in
  `.yoke/sensors/<id>.md`. Source of truth for command, class, tier,
  caveats, and runs history. Acceptance Contract references by ID.
- **Working-memory placement.** `.yoke/sensors/` lives in working
  memory (per host project), not canonical memory. Cross-run
  learning happens within a project; canonization to canonical
  memory is out of scope.
