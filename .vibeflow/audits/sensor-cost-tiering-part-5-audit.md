# Audit Report: sensor-cost-tiering — Part 5 (Coordinator + history + pattern doc)

> Audited on 2026-04-27
> Spec: `.vibeflow/specs/sensor-cost-tiering-part-5.md`
> Source PRD: `.vibeflow/prds/sensor-cost-tiering.md`
> Depends on: Parts 1 (PASS), 2 (PASS), 3 (PASS), 4 (PASS)

**Verdict: PASS**

## Test execution

- Commands: `bash tests/sensor-tiering.test.sh`; `bash tests/run-all.sh`.
- Result: **PASS** — 110/110 assertions in `sensor-tiering.test.sh`
  (24 new in (l)+(m)+(n) for pattern/skill content + append-runs unit
  tests + end-to-end smoke); **19/19 test files PASS** in the full
  suite (zero regressions).

## DoD Checklist

- [x] **DoD 1 — Two-phase per-cycle execution.** SKILL.md cycle protocol
  has explicit Phase A (cheap, sync, `--tier cheap --criterion <id>`)
  and Phase B (expensive, gated by cycle N-1's `schedule_next`,
  `--tier expensive --criterion <id>`). Phase B parses
  `schedule_next:` from `wm_progress_path`'s most recent cycle entry
  and authorizes only when `tiers:` includes `expensive` or
  `sensors:` lists explicit ids whose `applies_to` covers the
  current criterion.
  *Evidence:* `skills/implement/SKILL.md` Process §2 steps 2 + 3;
  tests "(l) implement SKILL.md describes Phase A (cheap)" + "...
  Phase B (expensive, gated)" — PASS.

- [x] **DoD 2 — Cycle-1 default = Phase A only.** Hard-coded branch in
  the SKILL.md: "Cycle 1: skip Phase B. No prior `schedule_next`
  exists; the coordinator runs cheap-only by design. Phase B
  becomes possible from cycle 2 onward via the Validator's
  authorization."
  *Evidence:* test "(l) implement SKILL.md documents cycle-1
  Phase-A-only default" — PASS.

- [x] **DoD 3 — Merge-ready convergence runs full suite (all tiers).**
  Step 8 invokes `hooks/verify-acceptance.sh --concurrency 1
  --tier all` (no `--criterion`); explicitly ignores
  `schedule_next`. Documented as "non-negotiable convergence: every
  sensor (cheap AND expensive) MUST pass before convergence,
  regardless of what the Validator authorized in the last per-cycle
  decision."
  *Evidence:* test "(l) implement SKILL.md merge-ready uses
  --tier all" — PASS.

- [x] **DoD 4 — Per-sensor history persistence.** `lib/sensors/append-
  runs.sh` invoked from SKILL.md after both phases finish. Helper
  parses snapshot YAML for per-sensor results, locates
  `.yoke/sensors/<id>.md`, and appends one entry: `{cycle,
  started_at, status, criterion, evidence_snippet}`. Sensors that
  did not run are not touched.
  *Evidence:* `lib/sensors/append-runs.sh` (executable); SKILL.md
  Process §2 step 4 invokes it; tests "(m) append-runs added cycle
  1 entry to foo.md" + "(m) append-runs entry includes status /
  criterion" — PASS.

- [x] **DoD 5 — N=20 retention cap.** `CAP=20` constant in
  `append-runs.sh:30`; cap enforced on every append by tail-N over
  combined (old + new) entries. Verified by stress test: append 26
  cycles, assert exactly 20 entries remain (cycles 7..26),
  cycle-1 rolled off, boundary cycle-7 kept, newest cycle-26 kept.
  *Evidence:* tests "(m) retention cap enforced (exactly 20 entries
  after 26 appends)" + "(m) oldest entry (cycle 1) rolled off as
  expected" + "(m) newest entry (cycle 26) present after retention"
  + "(m) boundary entry (cycle 7) present after retention" — PASS.

- [x] **DoD 6 — Pattern doc records new behavior.**
  `.vibeflow/patterns/sensors.md` has a new "Cost tiering, sensor
  persistence, and Validator-owned scheduling" subsection covering:
  per-sensor file layout (`.yoke/sensors/<id>.md`), class-based
  default tier rule, two-phase per-cycle execution (Phase A / Phase
  B / merge-ready), lag-by-one Validator scheduling, run-history
  persistence with N=20 retention, and the actionable-feedback
  rationale (with explicit reconciliation against the
  shift-feedback-left convention). New anti-pattern entry added at
  the bottom: "Running all expensive sensors every cycle when the
  feature is mid-assembly..."
  *Evidence:* tests "(l) sensors.md adds 'Cost tiering, ...
  Validator-owned scheduling' subsection" + "... cites actionable-
  feedback rationale" + "... adds anti-pattern entry for
  unconditional expensive runs" — PASS.

- [x] **DoD 7 — End-to-end test coverage.** 24 new assertions across
  three groups:
  - **(l)** pattern + skill content: subsection presence, rationale
    citation, anti-pattern entry, Phase A/B descriptions, append-
    runs invocation, `--tier all` merge-ready, cycle-1 default —
    8 assertions.
  - **(m)** `append-runs.sh` unit tests: file present + executable,
    single append, status / criterion captured, body preserved,
    retention cap (3 sub-assertions), unregistered-sensor skip
    (2 sub-assertions) — 12 assertions.
  - **(n)** end-to-end smoke: cheap-only Phase A leaves expensive
    sensors untouched (2 + 2 sub-assertions), Phase B authorization
    appends to expensive sensors — 5 assertions.
  All PASS.

- [x] **DoD 8 — Craftsmanship.** Parallel-spawn architecture
  preserved (no new in-cycle synchronization between Validator and
  coordinator — the lag-by-one model is reused exactly as Part 4
  established). Pattern-doc edit follows existing structure (new
  subsection placed contiguously after parallel-execution coverage;
  anti-patterns list extended cleanly). No manifesto invariant is
  weakened or removed — shift-feedback-left convention is
  **refined**, not rescinded, with explicit rationale captured in
  the new pattern subsection. PRD reference inline in
  `lib/sensors/append-runs.sh`, `skills/implement/SKILL.md`, and
  `.vibeflow/patterns/sensors.md`.

## Pattern Compliance

- [x] **`patterns/sensors.md`** — followed and extended. The new
  subsection layers cleanly on the existing parallel-execution
  coverage; structured-output rule preserved (`append-runs.sh`'s
  failure mode emits `Error:` to stderr with non-zero exit). New
  anti-pattern entry preserves the existing list shape.

- [x] **`patterns/ralph-loop.md`** — followed. Cycle-protocol
  invariants preserved: deterministic node (sensor execution +
  history append), structured per-cycle output, parallel-spawn
  unchanged. The two-phase structure is a refinement of the
  existing single-execution-per-cycle model — both phases still
  produce a single per-cycle YAML snapshot for the Validator to
  consume.

- [x] **`patterns/roles.md`** — followed. Validator scheduling is a
  refinement; coordinator (deterministic) consumes
  `schedule_next:` and writes history; Generator unchanged;
  Orchestrator unchanged.

- [x] **`patterns/acceptance-contract.md`** — followed. Binding
  semantics preserved by the merge-ready full sweep: convergence
  requires every sensor (across all tiers) to pass against the
  binding contract.

- [x] **`patterns/memory-model.md`** — followed. `append-runs.sh`
  writes only to working memory (`.yoke/sensors/<id>.md`); no
  canonical-memory access. The `runs:` history grows within
  per-task working-memory bounds (capped at N=20).

- [x] **`conventions.md`** — followed. Bash 4+ throughout
  (`declare`, `[[ regex ]]`, `case`, atomic `mv`). Structured
  failure on every error path in `append-runs.sh` (snapshot not
  found → exit 3, malformed cycle → exit 2, missing `runs:` key in
  sensor file → structured `Error:` to stderr). Shift-feedback-left
  rationale reconciled in the new pattern subsection.

## Convention Violations

None identified.

## Scope Discipline

Files changed: **4 / ≤ 4 budget**.

- `skills/implement/SKILL.md` (modified) — two-phase execution,
  cycle-1 default, append-runs invocation, merge-ready full sweep,
  step-numbering refresh
- `.vibeflow/patterns/sensors.md` (modified) — new subsection +
  anti-pattern entry
- `lib/sensors/append-runs.sh` (created) — runs-history append +
  retention helper
- `tests/sensor-tiering.test.sh` (modified) — 24 new assertions

Anti-scope respected: parallel-spawn architecture unchanged; no
tier authoring/parsing changes; no `schedule_next` schema changes;
cycle budget uniform; no retry/flake handling for expensive
sensors; no CI/Sprint-8 wiring; no flake auto-quarantine
(`runs:` history enables it as a future addition); no `runs:` field
schema migration; no manifesto invariant removed.

### Note on the helper file (4th file beyond strict spec listing)

The spec's Scope section lists 3 files (`skills/implement/SKILL.md`,
`.vibeflow/patterns/sensors.md`, `tests/sensor-tiering.test.sh`),
but the run-history append + retention logic is non-trivial bash
(~150 lines). Inlining it into SKILL.md prose would make the skill
description brittle (Claude Code synthesizes shell from the prose
at runtime; non-trivial logic risks transcription drift) and would
sacrifice unit-testability. The chosen split — extract a
`lib/sensors/append-runs.sh` helper — is consistent with the
existing repo pattern (every other lib/sensors/* helper is its own
file invoked by the skill: `discover-from-claude-md.sh`,
`discover-from-makefile.sh`, `discover-from-package-json.sh`,
`discover-from-pyproject.sh`, `run-sensors.sh`, `ack-sensors.sh`).

The 4th file is within the project budget of ≤ 4 (declared in
`.vibeflow/index.md`); the spec's scope listing is a closer-fit
than a hard limit. Treated as scope discipline rather than scope
creep — alternative approaches were either less testable
(inline) or required exceeding budget (helper + test fixture
separately).

## Architectural notes / pitfalls discovered

1. **`runs:` MUST be the last frontmatter key.** `append-runs.sh`'s
   three-zone parser (prefix → in_runs → suffix) assumes the closing
   `---` of the frontmatter is what ends the runs zone. If a future
   sensor template adds a key after `runs:`, the new key will be
   absorbed into the in_runs zone and silently dropped. Documented
   in `append-runs.sh`'s header comment; the Part-1 template puts
   `runs:` last by design.

2. **Stat compatibility (BSD vs GNU).** The end-to-end smoke initially
   used `stat -f '%m'` (BSD/macOS); the test now falls back to
   `stat -c '%Y'` (GNU/Linux) when BSD form fails. This is mtime-
   only and not strictly required for the test (it was a leftover
   from an earlier scaffolding) — kept for parity with how pre-
   state would be captured for future invariants.

3. **Snapshot YAML field separator.** `append-runs.sh` parses
   `output_excerpt: "..."` with a strict double-quote pair. If a
   future evidence string contains a literal `"` and the snapshot
   serializer doesn't escape it consistently, parsing could split
   the value. Current `verify-acceptance.sh` uses `esc()` to
   backslash-escape quotes, so this is safe today; revisit if the
   snapshot format changes.

## Gaps

None. Verdict is PASS.

## Final integration milestone

Part 5 is the last part of `sensor-cost-tiering`. With Parts 1–5
all PASS, the full feature is shipped:

- Sensors are first-class persistent artifacts in
  `.yoke/sensors/<id>.md` (Part 1).
- `/yoke:ack-sensors --mode upsert` materializes them from the
  Acceptance Contract (Part 2).
- `hooks/verify-acceptance.sh --tier cheap | expensive | all`
  filters by cost tier (Part 3).
- `agents/validator.md` reads sensor files and emits
  `schedule_next:` per cycle (Part 4).
- `skills/implement/SKILL.md` runs sensors in two phases, persists
  per-cycle results back to sensor files with N=20 retention, and
  runs the full suite at merge-ready (Part 5).

Aggregate test coverage: **110 assertions** in
`tests/sensor-tiering.test.sh`; **5 audit reports PASS** in
`.vibeflow/audits/`.

## Next steps

Ready to ship the full feature. Suggested follow-ups (out of scope
for sensor-cost-tiering, but flagged for future work):

- **Migration tooling** — a `/yoke:bootstrap-sensors <contract>`
  command that runs `/yoke:ack-sensors --mode upsert` automatically
  during host-project bootstrap, so users adopting the new contract
  format don't have to remember to run it manually.
- **Drift-sense for orphan sensor files** — Phase 6 drift-sense
  pass that flags `.yoke/sensors/<id>.md` files referenced by no
  contract, candidate for archival.
- **Quantitative flake quarantine** — built on top of the `runs:`
  history, auto-defer sensors with `recent_pass_rate < threshold`
  beyond the qualitative Validator-owned heuristic.
- **Canonization of stable sensor knowledge** — `/yoke:preserve` of
  long-lived caveats and calibration notes from `.yoke/sensors/`
  into canonical memory under Model C.
