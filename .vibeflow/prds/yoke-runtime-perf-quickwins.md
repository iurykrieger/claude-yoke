# PRD: Yoke Runtime Performance Quick Wins

> Generated via /vibeflow:discover on 2026-04-25

## Problem

`/yoke:implement` is taking ~1 hour to converge on simple features (≤ 4 files,
≤ 6 acceptance criteria). The cost is not in the parallel-spawn architecture
itself — it is in **per-cycle behavior**:

1. **Sensor execution is serial and unscoped.** Every cycle re-runs the full
   acceptance-contract sensor suite (whole E2E tests), with no parallelism and
   no scoping to the criterion the Generator targeted that cycle. Worse, the
   suite runs **twice per cycle**: once by the Validator
   (`agents/validator.md:38`) and again by the coordinator post-Generator
   (`skills/implement/SKILL.md:113-117`).
2. **The Generator is not behaving as a senior engineer.** It treats criteria
   one-at-a-time, even when failing criteria are clearly coupled (same file,
   same module, shared interface). It does not plan-first; it patches the
   surface symptom of the latest sensor failure and waits for the next cycle
   to discover what should have been obvious from reading all failing
   criteria together. This inflates cycle count.

The compound effect — full sensor suite × 2 × cycles, where cycles are
inflated by weak Generator planning — is what produces the 1-hour wall-clock
on tasks that should resolve in 10–15 minutes.

## Target Audience

Yoke users running `/yoke:implement` on real tasks. Initial validation:
the Yoke developer dogfooding the framework. Success here directly removes
friction for every downstream Yoke adopter.

## Proposed Solution

Three coordinated changes, all confined to Phase 4 runtime:

1. **Sensor scoping + parallelism + de-duplication.** `hooks/verify-acceptance.sh`
   gains a `--criterion <id>` flag for incremental cycles and runs independent
   sensors in parallel. The coordinator runs sensors **once** per cycle
   post-Generator; the Validator consumes the snapshot rather than re-running
   the suite. Full-suite serial sweep happens only on the MERGE-READY check.
2. **Stronger Generator engineer persona.** Rewrite `agents/generator.md`'s
   persona + behavior contract so that every cycle starts with: read **all**
   currently-failing criteria, group those that share files / modules /
   interfaces, plan the change set, name files + intended changes in
   `progress.md`, *then* edit. Allow batched implementation across coupled
   criteria within a single cycle when the planning step shows they share a
   change surface.
3. **Tiered models (quality preserved).** Generator stays on the current
   top-tier model (quality is king). Validator and Orchestrator (consult +
   monitor modes) drop to **Sonnet 4.6** — sufficient for structured-JSON
   verdicts over deterministic sensor output and for retrieval/filter work
   over canonical memory. Canonize-mode Orchestrator stays on the top tier
   (governance writes are not a place to compromise).

## Success Criteria

Measured on a representative simple feature (≤ 4 files, ≤ 6 criteria), via
instrumented baseline + post-change runs:

- **Wall-clock to MERGE-READY ≤ 15 min** (target ≥ 4× improvement over
  current ~1 h baseline).
- **Average cycles-to-MERGE-READY drops by ≥ 30 %** on the same feature
  size, attributable to Generator batching + sensor scoping.
- **Sensor execution time drops ≥ 50 %** within a cycle (parallelism +
  scoping + single-run; measured against the full-suite baseline).
- **Validator quality unchanged.** Re-run prior tasks against fixture
  snapshots; the structured JSON verdicts must match the pre-change runs
  modulo timing fields. Zero divergence-detection regressions.

## Scope v0

- `hooks/verify-acceptance.sh`:
  - Add `--criterion <id>` flag; default behavior unchanged (full suite).
  - Run sensors in parallel via `xargs -P` (bash 4+ floor; no GNU parallel
    dependency).
- `skills/implement/SKILL.md`:
  - Coordinator runs `verify-acceptance.sh --criterion <last-target>` once
    post-Generator, scoped to the criterion the Generator addressed.
  - Validator no longer runs sensors itself; consumes the snapshot at
    `$(wm_snapshots_dir)/cycle-<N>.yaml`.
  - Final MERGE-READY check runs full-suite serial sweep (no scoping) before
    declaring convergence.
- `agents/generator.md`:
  - Rewrite persona + "Always" section to require plan-first behavior
    every cycle: read all failing criteria, group coupled ones, name files
    + intent in `progress.md`, then edit.
  - Allow batched implementation across coupled criteria within a single
    cycle when planning shows shared change surface.
- `agents/validator.md`:
  - Replace "Run `hooks/verify-acceptance.sh` every cycle" with "Read the
    coordinator's snapshot at `$(wm_snapshots_dir)/cycle-<N>.yaml`".
- Per-agent model configuration:
  - Validator and Orchestrator (consult / monitor) pinned to Sonnet 4.6.
  - Generator unchanged.
  - Mechanism resolved in Phase 2 (frontmatter `model:` if Claude Code
    supports it on subagents; otherwise Task-tool argument from the
    coordinator).
- Tests:
  - Smoke test under `tests/smoke/` exercising `--criterion` scoping and
    parallel sensor execution.
  - Baseline + post-change wall-clock run on one representative simple
    feature (instrumented; numbers archived in
    `.vibeflow/audits/`).

## Anti-scope

Explicitly **not** in v0:

- No change to the parallel-spawn architecture (3 subagents concurrent per
  cycle stays).
- No change to any human Trigger (1, 2, 3, 4, 5).
- No change to canonical-memory write authority or Model C governance.
- No changes to spec-phase skills (`/yoke:discover`, `/yoke:tech-spec`,
  `/yoke:acceptance-contract`).
- No Generator model downgrade. Quality is king.
- No on-demand-Orchestrator-consult gating (deferred — orthogonal cut,
  worth measuring v0 first).
- No "stagnation early-exit" heuristic (deferred — depends on v0 data
  before we can calibrate).
- No pre-flight "binding-constraints digest" to shrink subagent context
  reads (deferred — measure first whether context size is actually a
  bottleneck post-v0).
- No new manifesto invariants; no removal of existing invariants.

## Technical Context

Reference points in this repo:

- Cycle protocol: `skills/implement/SKILL.md:56-143`.
- Subagent contracts: `agents/generator.md`, `agents/validator.md`,
  `agents/orchestrator.md`.
- Sensor entry-point: `hooks/verify-acceptance.sh` (parallelism + scoping
  added here).
- Snapshot path helper: `wm_snapshots_dir` from
  `lib/working-memory/paths.sh`.
- Persisted progress: `.yoke/runtime/progress.md` (Generator's plan
  section reuses the existing schema in `templates/progress.md` —
  add a `plan:` block, do not invent a new artifact).

Manifesto invariants this PRD respects (verified):

- Binding spec — Acceptance Contract still defines "done"; sensor scoping
  is a runtime optimization, not a contract change.
- Adversarial loop with hard bounds — unchanged.
- Sprint contracts ⊂ Acceptance Contract — unchanged.
- Governed canonical memory — unchanged (Orchestrator canonize stays
  top-tier model).
- Progressive disclosure — Generator's plan-first batching aligns with
  it (read what is needed, not all upstream every cycle).
- Structured sensor output — preserved; scoping does not change schema.

## Open Questions

- **Per-agent model pinning mechanism.** Does Claude Code's plugin format
  support a `model:` field in subagent frontmatter (parallel to `tools:`)?
  If yes, set it there. If no, the coordinator must pass `model:` as a
  parameter to the Task tool when spawning Validator and Orchestrator.
  Decide before Phase 2 implementation.
- **Sensor → criterion mapping.** Audit `templates/acceptance-contract.md`
  and the current `verify-acceptance.sh` parsing: is the declared mapping
  already a clean criterion → sensor(s) lookup that `--criterion <id>`
  can resolve, or does the contract format need a small extension to make
  the mapping explicit?
- **Coupling heuristic for Generator batching.** Initial proposal: criteria
  touching overlapping file sets in the same Tech Spec task are "coupled"
  and may be batched. Validate against a real task before locking it in.
- **Baseline measurement.** "1 hour" is an observation, not an
  instrumented baseline. Run one representative simple feature with
  per-cycle / per-sensor / per-subagent timing logged before changing any
  code, so we can attribute the win post-change. Land instrumentation
  alongside v0; archive numbers in `.vibeflow/audits/`.
- **Validator model swap regression risk.** Sonnet 4.6 should be sufficient
  for structured-JSON verdicts, but confirm via the Validator-quality
  fixture re-run (success criterion 4) before declaring v0 done. If a
  regression appears, fall back to top-tier model and capture the savings
  from sensor scoping + de-duplication alone.
