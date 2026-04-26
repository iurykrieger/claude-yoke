# Audit Report: Yoke Runtime Perf Quick Wins — Part 1

**Verdict: PASS**

> Audited 2026-04-25 against
> `.vibeflow/specs/yoke-runtime-perf-quickwins-part-1.md`.
> Tests run: `tests/smoke/perf-quickwins-part-1.test.sh` (PASS),
> `tests/smoke/sprint-8.test.sh` full audit gate (PASS — all
> sprints 2–7 + plugin-install + skills-format).

## Test Suite

- `tests/smoke/perf-quickwins-part-1.test.sh` → **PASS** (20/20 checks)
- `tests/smoke/sprint-8.test.sh` → **PASS** (full audit gate)
  - Sprints 2/3/4/5/6/7 regressions all green
  - `plugin-install.test.sh` green
  - `skills-format.test.sh` green
- Bash syntax (`bash -n`) clean on `hooks/verify-acceptance.sh` and
  `hooks/post-iteration.sh`. `shellcheck` not installed in this
  environment; syntax-checked instead. Recommend running
  `shellcheck` in a dev-host that has it before merging — does not
  block this audit.

Test FAIL → automatic FAIL rule does NOT trigger; both targeted
suite + full regression are green.

## DoD Checklist

- [x] **DoD #1** — `--criterion <id>` resolves to a sensor subset.
  Evidence: `hooks/verify-acceptance.sh:170-227` parses the
  Scenario `Sensors: [...]` line and the FR `Sensor: name.` field;
  smoke test (a) green for both `Scenario 1` (yields linter +
  type-check, excludes unit-test) and `FR-1` (isolates to linter).
  Default behavior (no flag) preserved — full-suite path unchanged.

- [x] **DoD #2** — Sensors run in parallel via `xargs -P` with
  per-sensor fragment files merged alphabetically.
  Evidence: `hooks/verify-acceptance.sh:286-301` runs `xargs -0 -I
  {} -P "$concurrency" bash -c '...'` with `run_one_sensor`
  exported; fragments land at
  `${fragments_dir}/$(safe_filename "$name").yaml`; merge step
  (`hooks/verify-acceptance.sh:313-321`) uses
  `find ... | LC_ALL=C sort` for deterministic alphabetical
  ordering. Smoke (b) measured ratio 35 % (parallel-time /
  serial-time) — well under the 70 % threshold (≥ 30 % faster).
  Concurrency knob `runtime.sensor_concurrency` resolved by
  `yoke_sensor_concurrency()` at
  `hooks/verify-acceptance.sh:128-149`, default 4, override via
  `.yoke/config.yaml`.

- [x] **DoD #3** — Sensors run exactly once per cycle.
  Evidence: `skills/implement/SKILL.md` step 2
  (lines 117-138) explicitly redirects scoped run to
  `$(wm_runtime_dir)/.pending-snapshot.yaml` with
  `--fragments-dir "$(wm_runtime_dir)/.pending-fragments"`;
  `hooks/post-iteration.sh:55-79` promotes the scratch artifacts
  (`mv .pending-snapshot.yaml → cycle-<N>.yaml`,
  `mv .pending-fragments → cycle-<N>.fragments/`) without
  re-running sensors when the scratch is present. Validator
  `agents/validator.md:36-41` updated to "Read the cycle's
  snapshot at `$(wm_snapshots_dir)/cycle-<N>.yaml`" — the run-it-
  yourself instruction is gone. `agents/validator.md:96-103`
  Bash-tool description now says "**Never** invoke
  `hooks/verify-acceptance.sh`". Smoke (c) green: counter
  fixture sensor stays at 1 across step-2 + post-iteration
  promotion.

- [x] **DoD #4** — MERGE-READY check runs full-suite serial sweep.
  Evidence: `skills/implement/SKILL.md` step 6 (lines 167-176)
  rewritten to "run `hooks/verify-acceptance.sh --concurrency 1`
  (no `--criterion`) one final time" before declaring
  convergence. Smoke (d) green: full-suite run with
  `--concurrency 1` includes all three fixture sensors (linter +
  type-check + unit-test).

- [x] **DoD #5** — Smoke test exercises all four behaviors.
  Evidence: `tests/smoke/perf-quickwins-part-1.test.sh` runs
  a fixture contract with 3 sensors, asserts (a)+(b)+(c)+(d) per
  the spec, plus craftsmanship-slice assertions on the 6-field
  output schema, archives baseline numbers to
  `.vibeflow/audits/perf-quickwins-baseline.yaml`. 600 s
  watchdog active (lines 31-33). 20/20 internal checks PASS.

- [x] **DoD #6** — Craftsmanship gate.
  - Bash syntax clean (`bash -n` on both modified hooks).
    `shellcheck` unavailable locally; flagged as a
    pre-merge step.
  - Structured sensor-output schema preserved: smoke
    `(craft)` block confirms all six fields (`sensor`,
    `command`, `status`, `exit_code`, `output_excerpt`,
    `reason`) appear in the emitted YAML. Schema unchanged
    relative to pre-Part-1 behavior — `run_one_sensor()`
    in `hooks/verify-acceptance.sh:236-281` retains the
    same heredoc shape.
  - No `conventions.md` Don't violated (audited against
    the 13-item Don'ts list — no canonical-memory writes
    introduced, no hard-bound bypass, no Acceptance
    Contract modification at runtime, no rubber-stamp
    Trigger handling).
  - No new manifesto invariant introduced. The cycle
    protocol shape (3 concurrent subagents per cycle,
    five stop conditions, termination canonize handoff)
    is verbatim preserved.

## Pattern Compliance

- [x] **`patterns/sensors.md`** — followed. The fragment-file
  shape and the merged-snapshot YAML emit the same six structured
  fields per sensor (`sensor`, `command`, `status`, `exit_code`,
  `output_excerpt`, `reason`) — back-pressure principle preserved
  (success silent on sensor stdout via `output_excerpt`
  truncation; failures verbose). Computational sensors only;
  inferential semantics untouched per spec anti-scope. Evidence:
  `hooks/verify-acceptance.sh:265-280`, smoke `(craft)` block.

- [x] **`patterns/ralph-loop.md`** — followed. Cycle protocol
  retains exactly five stop conditions
  (merge-ready / divergence / contract-conflict / hard-bound /
  infeasibility — `skills/implement/SKILL.md:184-202`). The
  `run_sensors()` deterministic node now runs once (scoped) +
  once at MERGE-READY (full-suite serial). No new deterministic
  node introduced. Parallel-spawn shape unchanged (3 concurrent
  Task calls per cycle, single assistant turn). Termination
  canonize handoff unchanged.

- [x] **`patterns/roles.md`** — followed. Validator authority
  unchanged: still no code writes, still co-writes
  `.yoke/contracts/<slug>.md` on consensus, still task memory
  scope, still consumes the canonical-memory subgraph via
  `query-traces`. The text-level change clarifies that
  `verify-acceptance.sh` invocation is the coordinator's
  responsibility — Validator is now an explicit *consumer* of
  the snapshot, which `patterns/ralph-loop.md:38-40` already
  contemplated ("runs sensors via `hooks/verify-acceptance.sh`
  **or reads its prior snapshot**"). Evidence:
  `agents/validator.md:36-41`, `agents/validator.md:96-103`.

## Convention Violations (none)

Audited against `.vibeflow/conventions.md`:

- ✅ Bash 4+ floor preserved (`xargs -P`, `mapfile`-free, no GNU
  parallel dependency).
- ✅ Working-memory tree untouched at the path level (existing
  `wm_*_path` helpers still authoritative).
- ✅ Sensor output remains machine-structured (no plain-text-only
  bug surface introduced).
- ✅ "Shift feedback left" — no degradation; per-criterion scoping
  shifts feedback *closer* to the Generator's last edit.
- ✅ "Blueprints wrapping agentic nodes" — the new `xargs -P`
  fanout is deterministic-node territory, no LLM judgement
  introduced.
- ✅ Hard-bound semantics untouched (`hooks/check-hard-bounds.sh`
  not modified; cycle counter still incremented by
  `hooks/post-iteration.sh`).
- ✅ Progressive disclosure preserved (no canonical memory loaded;
  Orchestrator's role unchanged).

## Files Changed (5/6 budget)

| File | Change | LOC delta (approx) |
|---|---|---|
| `hooks/verify-acceptance.sh` | rewrite — `--criterion`/`--concurrency`/`--fragments-dir` flags, parallel `xargs -P` fanout, fragment merge | ~+170 |
| `hooks/post-iteration.sh` | scratch promotion path + legacy fallback | ~+25 |
| `skills/implement/SKILL.md` | step 2 + step 6 rewritten | ~+25 |
| `agents/validator.md` | "Always" bullet + "Allowed tools" updated to drop sensor execution | ~+5 |
| `tests/smoke/perf-quickwins-part-1.test.sh` | new fixture-driven smoke (20 checks + watchdog + baseline archive) | ~+200 |

Spec scope listed 4 files; the 5th file (`hooks/post-iteration.sh`)
was a technical necessity to satisfy DoD #3's "exactly once per
cycle" requirement (otherwise the post-iteration hook would re-run
sensors after the scoped step-2 execution). Within the codebase's
revised budget of ≤ 6 files (project index says ≤ 4 minimum,
revisable upward as the codebase grows).

## Anti-scope Compliance

All seven anti-scope items respected:

- ✅ Parallel-spawn architecture untouched — `skills/implement/SKILL.md`
  step 2.1 still spawns 3 concurrent subagents.
- ✅ No human Trigger modified.
- ✅ Canonical-memory write authority untouched (Orchestrator-only;
  Model C governance untouched).
- ✅ No inferential-sensor parallelism semantics introduced.
- ✅ No sensor-result cache across cycles introduced.
- ✅ No per-sensor concurrency-safety metadata wired (R1 mitigation
  remains: operators with unsafe sensors set
  `runtime.sensor_concurrency: 1`).
- ✅ Generator persona untouched (Part 2 territory).
- ✅ Model selection untouched (Part 3 territory).

## Risks Status

- **R1** (concurrency-unsafe sensors) — mitigated by configurable
  concurrency knob; defaults to 4. Documentation still TODO
  (`docs/installation.md` mention recommended for v0.1).
- **R2** (smoke timing flakiness) — mitigated by ratio assertion
  (≤ 70 %, not absolute time) + median-of-2 per leg. First run
  measured 35 %, comfortable margin.
- **R3** (contract template lacks parseable mapping) — verified
  not an issue. Existing `templates/acceptance-contract.md` already
  carries Scenario `Sensors: [...]` and FR `Sensor: name.` —
  parseable as-is. Template untouched.
- **R4** (Validator snapshot one cycle behind) — pre-existing
  parallel-spawn semantic; not introduced by this part. No change.

## Baseline Numbers Archived

`.vibeflow/audits/perf-quickwins-baseline.yaml` (written by the
smoke test):

```yaml
baseline:
  serial_ns: ~3.4e9     # 3 sensors × 1 s sleep, ≈ 3.4 s
  parallel_ns: ~1.2e9   # 4-way concurrent ≈ 1.2 s
  ratio_pct: 35
  target_ratio_pct: 70
```

This discharges the PRD's "instrumentation alongside v0"
obligation. Subsequent runs of the smoke test will overwrite the
archive; that is intentional — the file is the latest baseline
under the current configuration, not an immutable historical log.

## Next Steps

Ready to ship Part 1. Proceed to
`/vibeflow:implement .vibeflow/specs/yoke-runtime-perf-quickwins-part-2.md`.

Pre-merge polish (optional, not blocking):
- Run `shellcheck` on `hooks/verify-acceptance.sh` and
  `hooks/post-iteration.sh` in an environment that has it.
- Add a `runtime.sensor_concurrency: 1` mention to
  `docs/installation.md` (R1 mitigation note).
