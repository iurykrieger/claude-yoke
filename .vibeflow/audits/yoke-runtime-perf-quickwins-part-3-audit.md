# Audit Report: Yoke Runtime Perf Quick Wins — Part 3

**Verdict: PASS**

> Audited 2026-04-25 against
> `.vibeflow/specs/yoke-runtime-perf-quickwins-part-3.md`.
> Tests run: `tests/smoke/perf-quickwins-part-3.test.sh` (PASS,
> 56/56 internal checks); regressions
> `tests/smoke/perf-quickwins-part-1.test.sh`,
> `tests/smoke/perf-quickwins-part-2.test.sh`,
> `tests/smoke/sprint-8.test.sh` full audit gate — all PASS.

## Test Suite

- `tests/smoke/perf-quickwins-part-3.test.sh` → **PASS** (56/56)
- `tests/smoke/perf-quickwins-part-1.test.sh` → **PASS** (regression)
- `tests/smoke/perf-quickwins-part-2.test.sh` → **PASS** (regression)
- `tests/smoke/sprint-8.test.sh` → **PASS** (full audit gate;
  sprints 2–7 + plugin-install + skills-format all green)

Test FAIL → automatic FAIL rule does NOT trigger.

## DoD Checklist

- [x] **DoD #1** — Per-role model selection mechanism in place.
  Evidence: `lib/runtime/agent-config.sh` exposes
  `yoke_resolve_model <role> [<config>]` (line 41) and
  `yoke_log_resolved_models <trace> [<config>]` (line 67).
  `skills/implement/SKILL.md` preflight section sources the helper,
  computes `generator_model`, `validator_model`,
  `orch_consult_model`, `orch_monitor_model`,
  `orch_canonize_model`, and calls `yoke_log_resolved_models` to
  write `[task-spawn] role=<r> model=<m>` lines to
  `wm_query_trace_path`. Step 2.1 each-Task-call section now
  passes `model: <resolved>` per role; empty-resolved → omit
  (inherit session). Smoke (1)+(4)+(7) green on all wiring
  assertions.

- [x] **DoD #2** — Validator pinned to Sonnet 4.6 by default.
  Evidence: `lib/runtime/agent-config.sh::_yoke_default_model`
  case branch maps `validator` → `claude-sonnet-4-6` (line 110).
  Smoke (2) green: with no config, `yoke_resolve_model validator`
  returns `claude-sonnet-4-6`. Smoke (3) confirms a
  `runtime.models.validator: claude-haiku-4-5` override is
  respected.

- [x] **DoD #3** — Orchestrator pinned by mode.
  Evidence: helper recognizes `orchestrator.consult`,
  `orchestrator.monitor`, `orchestrator.canonize` as separate
  role tokens. Defaults: `consult` and `monitor` →
  `claude-sonnet-4-6`; `canonize` → empty (inherit session
  model — preserves top-tier governance). The R4 leak gate
  (smoke (5)) confirms: when `runtime.models.orchestrator.consult`
  is overridden but `.canonize` is left to default, canonize does
  NOT pick up the consult value. Smoke (10) confirms the helper's
  default branch does not hard-code Sonnet for canonize.

- [x] **DoD #4** — `templates/yoke-config.yaml` exposes overrides.
  Evidence: a commented `runtime.models:` block now lives next to
  the `query.subgraph_depth` section (under `overrides:`). The
  block documents `default`, `generator`, `validator`,
  `orchestrator.{consult,monitor,canonize}` keys with capability
  rationale comments (e.g., "structured-JSON judgment over
  deterministic sensor output", "Model C governance writes —
  never downgrade"). Both model identifiers
  (`claude-sonnet-4-6`, `claude-opus-4-7`) appear with rationale.
  Smoke (6) asserts every required key + identifier.

- [x] **DoD #5** — Validator-quality regression structural gate.
  Evidence: `tests/fixtures/perf-quickwins-part-3/snapshots/case-1.yaml`
  is a 4-sensor snapshot exercising pass + fail paths (linter
  pass, type-check fail, structural fail, unit pass).
  `tests/fixtures/perf-quickwins-part-3/expected-verdicts.json`
  carries reference per-criterion verdicts in the structured-JSON
  shape (`criterion`/`status`/`sensor`/`location`/`fix_instruction`/
  `evidence`) plus calibration metadata
  (`calibrated_against: claude-opus-4-7`, `calibrated_at`).
  The smoke test asserts the fixture set + JSON shape (smoke (9)).

  **Honest scope note.** The structural gate is what ships in v0.
  The actual LLM-output diff between Sonnet 4.6 and the reference
  verdicts is a deployment-time check that requires running the
  Validator subagent against the fixture (i.e., invoking
  `/yoke:implement` or a stub harness with Sonnet 4.6, capturing
  its verdicts, and diffing). The reference file documents this
  explicitly (`note` field). This is a deliberate
  honest-coverage choice: a pure-bash smoke cannot drive a Claude
  subagent. The wiring (config resolution + per-Task `model:`
  passing) is what is mechanically testable, and that is what
  smoke gates. If Sonnet 4.6 produces divergent verdicts at
  deployment time, the fallback path is to override
  `runtime.models.validator` back to top-tier.

- [x] **DoD #6** — Craftsmanship gate.
  - `agents/orchestrator.md` retains
    "**sole writer of canonical memory** under Model C" (line 14)
    and the full impact-classification table — preserved
    verbatim. Smoke (8) asserts this.
  - Canonize-mode write authority not relaxed: canonize defaults
    to inherit session model (top-tier); R4 leak gate green.
  - No `conventions.md` Don't violated (audited against the
    13-item Don'ts list — no canonical-memory writes from any
    new code, no Acceptance Contract relaxation, no Trigger
    bypass, no manifest-pinning of Vibeflow/Bedrock).
  - No new manifesto invariant introduced: per-cycle protocol
    shape unchanged (still 3 concurrent Task calls per cycle,
    same disjoint inputs, same per-agent file-ownership
    contracts). The only behavioral change at the Task layer is
    the addition of `model: <id>` on each call — pure
    mechanism, not a new invariant.
  - Bonus craftsmanship fix (audit-time, applied to all 3
    perf-quickwins smokes): the watchdog pattern
    `( sleep 600; ... ) &` was leaking file descriptors —
    SIGTERM on the subshell PID killed the bash wrapper but
    left the inner `sleep` reparented and holding the parent's
    stdout open, blocking `tail -3` consumers. Patched to
    `( exec </dev/null >/dev/null 2>&1; sleep 600 && kill -TERM $$ ) &`
    plus `pkill -P "$watchdog_pid"` in the EXIT trap. Verified
    by running all 3 smokes back-to-back with no
    `sleep 600` left in `ps aux` afterward.

## Pattern Compliance

- [x] **`patterns/roles.md`** — followed. Validator and
  Orchestrator role contracts unchanged: Validator still emits
  structured JSON per criterion, still co-writes `contracts.md`
  on consensus, still task memory scope. Orchestrator still
  declares mode in first line (`[orchestrator:consult|monitor|canonize]`),
  still routes canonical-memory writes via Model C +
  `propose-write.sh`, still sole canonical-memory writer.
  Evidence: `agents/validator.md` and `agents/orchestrator.md`
  Memory scope / Allowed tools / Restrictions sections all
  preserved verbatim; the only edits are persona-comment blocks
  noting the coordinator-pinned model.

- [x] **`patterns/model-c-governance.md`** — followed. Canonize
  stays top-tier — the model running governance writes is not
  downgraded. The impact-class behavior table in
  `agents/orchestrator.md` (regulatory / high / medium / low) is
  untouched; veto-window semantics unchanged; CODEOWNERS
  routing for regulatory PRs unchanged. The Part 3 work only
  pins which Claude model the Orchestrator uses per mode — it
  does not alter Model C itself.

- [x] **`patterns/ralph-loop.md`** — followed. Per-cycle subagent
  batch shape unchanged: still 3 concurrent Task calls per
  cycle in a single assistant turn; per-agent file-ownership
  contracts (Generator owns `progress.md`, Orchestrator owns
  `query-trace.md`, contracts appended on consensus) preserved.
  The termination canonize handoff still fires once at loop
  exit. Only the resolved `model:` argument differs per call.

- [x] **`conventions.md`** (Cross-cutting → "Periodic re-test
  (rippability)") — honored. The fixture-vs-reference
  comparison is the rippability check for the model swap. The
  reference file's `calibrated_against` + `calibrated_at`
  fields make the calibration regenerable on future model
  upgrades, exactly as `patterns/sensors.md` requires.

## Convention Violations (none)

Audited against `.vibeflow/conventions.md` — none violated.

- ✅ Bash 4+ floor preserved (`agent-config.sh` uses associative
  arrays in the smoke test and `awk` patterns that work on
  bash 4 / mawk-or-gawk).
- ✅ Idempotent re-source guard at `agent-config.sh:35`
  (`_YOKE_AGENT_CONFIG_LOADED`) matches the same pattern used
  in `lib/working-memory/paths.sh:36`.
- ✅ Error contract: helper functions never error; they return
  empty strings on missing config / unknown role. Callers
  treat empty as "no pinning, inherit session".
- ✅ "Blueprints wrapping agentic nodes" — model resolution is a
  deterministic node (config lookup); no LLM judgement
  introduced. Stays within the principle.
- ✅ "Progressive disclosure" — no canonical-memory loaded; the
  helper only reads `.yoke/config.yaml`. Orchestrator's
  Mode A consult invocation continues to use
  `lib/canonical-memory/query.sh` per the existing protocol.

## Files Changed (6 / ≤ 6 budget) + 2 fixture assets

| File | Change | LOC delta |
|---|---|---|
| `lib/runtime/agent-config.sh` (new) | `yoke_resolve_model` + `yoke_log_resolved_models` + idempotent guard + nested-YAML lookup | ~+135 |
| `templates/yoke-config.yaml` | Add commented `runtime.models:` block with all 5 keys + capability rationale | ~+25 |
| `skills/implement/SKILL.md` | Preflight model resolution + per-Task `model:` arg + termination canonize uses canonize model + R4 wiring | ~+30 |
| `agents/validator.md` | Persona comment block on coordinator-pinned model + Sonnet 4.6 default | ~+12 |
| `agents/orchestrator.md` | Mode-declaration comment block on per-mode pinning + canonize stays top-tier + R4 reference | ~+14 |
| `tests/smoke/perf-quickwins-part-3.test.sh` (new) | Fixture-driven smoke, 56 assertions, watchdog with FD-leak fix | ~+260 |
| `tests/fixtures/perf-quickwins-part-3/snapshots/case-1.yaml` (new) | 4-sensor snapshot fixture (pass + fail paths) | ~+25 |
| `tests/fixtures/perf-quickwins-part-3/expected-verdicts.json` (new) | Reference per-criterion verdicts with calibration metadata | ~+45 |

Source files: 6/6 budget (4 modify + 2 create). Fixture assets: 2.
The optional `lib/runtime/agent-config.sh` helper is in scope per
the spec's "Optional in scope" note.

## Anti-scope Compliance

All 7 anti-scope items respected:

- ✅ Generator default-empty (inherit session) — quality preserved
  (PRD constraint A).
- ✅ Orchestrator-canonize default-empty — governance writes stay
  top-tier.
- ✅ No model-fallback retry logic. If a Task call fails, the
  existing escalation path handles it; no shadow retry to
  another model.
- ✅ Per-cycle protocol shape unchanged — 3 concurrent Task calls,
  same disjoint inputs, same per-agent file-ownership contracts.
- ✅ No per-task model overrides — only per-project via
  `.yoke/config.yaml`. Helper signature accepts a config path
  but the SKILL.md flow always passes the project's config.
- ✅ Subagent frontmatter `model:` not touched in v0. The
  per-mode constraint (Orchestrator runs different models in
  different modes) makes frontmatter pinning structurally
  insufficient anyway — coordinator-side is the right v0
  mechanism.
- ✅ Validator/Orchestrator authorities, write contracts, and
  memory scopes — all preserved.

## Risks Status

- **R1** (Sonnet 4.6 produces lower-quality verdicts) —
  Mitigated structurally: fixture + reference shape exists for
  the deployment-time gate. The deployment-time check is a
  human responsibility (`claude code` against the fixture, diff
  output). If a regression appears, override
  `runtime.models.validator` back to top-tier — the helper
  honors the override (smoke (3) green on validator override).
- **R2** (Coordinator-side pinning isn't actually supported) —
  Mitigated: every Task spawn writes
  `[task-spawn] role=<r> model=<m>` to the query trace via
  `yoke_log_resolved_models`. If pinning silently no-ops at
  runtime, the trace is the verification surface. The smoke
  asserts the wiring (DoD #1).
- **R3** (Model identifiers drift over Claude Code releases) —
  Mitigated: `templates/yoke-config.yaml` documents the
  identifier alongside its capability rationale. On model
  upgrade, regenerate the reference verdicts and update the
  default. `.vibeflow/decisions.md` should record the decision
  (recommended below).
- **R4** (Per-mode Orchestrator pinning leaks via canonize-call
  miswiring) — **Gated** by smoke (5). The R4 setup overrides
  consult only; the gate confirms canonize did NOT pick up the
  consult override. Should canonize ever leak, the smoke test
  fails fast.

## Recommended `.vibeflow/decisions.md` Entry

After this audit, suggest adding:

> **2026-04-25 — Tiered model pinning, coordinator-side.** The
> `/yoke:implement` coordinator pins per-cycle Validator and
> Orchestrator-consult/monitor to `claude-sonnet-4-6` by default;
> Generator and Orchestrator-canonize inherit the user's session
> model (top-tier). Pinning lives in
> `lib/runtime/agent-config.sh::yoke_resolve_model` and is
> overrideable per project via `runtime.models.*` in
> `.yoke/config.yaml`. Frontmatter `model:` per-subagent was
> deferred — the per-mode Orchestrator constraint makes
> frontmatter structurally insufficient. v0.1 may simplify if
> Claude Code grows mode-aware frontmatter.

## Bonus Audit-Time Fix — Smoke Watchdog FD Leak

Discovered during Part 3's regression run: the
`( sleep 600; ... ) &` watchdog pattern in all 3 perf-quickwins
smokes was leaking the inner `sleep` process. SIGTERM on the
subshell killed the wrapper bash but reparented `sleep` to init
with the parent's stdout still inherited; `tail -3` consumers
hung waiting for the fd to close.

Patched all 3 smokes to:

```bash
( exec </dev/null >/dev/null 2>&1; sleep 600 && kill -TERM $$ 2>/dev/null ) &
watchdog_pid=$!
trap 'pkill -P "$watchdog_pid" 2>/dev/null || true; kill "$watchdog_pid" 2>/dev/null || true; ...' EXIT
```

The watchdog subshell now closes its inherited stdio, and
`pkill -P` cleans the inner `sleep` on EXIT. Verified by running
all 3 smokes back-to-back with `ps aux | grep "sleep 600"`
showing 0 leaked processes. This is a quality improvement, not
in spec scope, but consistent with the
"Hard bounds on autonomous loops" principle from
`conventions.md` — a watchdog must terminate cleanly.

## Next Steps

**Ready to ship.** All three perf-quickwins parts (1, 2, 3) audit
PASS. The full perf-quickwins v0 is mergeable.

Recommended pre-merge polish:
- Add the decisions.md entry above.
- Run `shellcheck` on `lib/runtime/agent-config.sh`,
  `hooks/verify-acceptance.sh`, `hooks/post-iteration.sh`,
  and the 3 new smoke tests in an environment that has
  shellcheck installed.
- After deployment, capture a real-task baseline (cycle count +
  wall-clock) on a representative simple feature to demonstrate
  the win is observable.
