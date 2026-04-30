# Sprint 03 of 03: Yoke Runtime Perf Quick Wins

> Migrated from: # Spec: Yoke Runtime Perf Quick Wins — Part 3: Tiered Model Pinning


> Generated via /vibeflow:gen-spec on 2026-04-25 from
> `.vibeflow/prds/yoke-runtime-perf-quickwins.md`.

## Objective

Pin the Validator and the Orchestrator's per-cycle modes (consult +
monitor) to **Sonnet 4.6**; keep the Generator and the Orchestrator's
canonize mode on the current top-tier model. Quality preserved on the
roles that demand it (code generation, governance writes); cost +
latency cut on roles whose output is structured-deterministic (verdict
JSON, retrieval over canonical memory).

## Context

The PRD's Round-1 challenge resolved this: quality is king on the
implementation side; the Validator and Orchestrator's per-cycle work is
structurally bounded (JSON schema + retrieval) and tolerates a smaller
model. Sonnet 4.6 was chosen explicitly. This part is about giving Yoke
a **per-role model-selection mechanism** and pinning the right roles.

Currently no `agents/*.md` carries a `model:` field — runtime subagents
inherit the user's session model. Two viable mechanisms:

- **Frontmatter `model:` per subagent.** Cleanest if Claude Code's
  plugin format supports it on subagents (analogous to `tools:`).
  Pinning lives next to the persona that owns the model choice.
- **Coordinator-side per-Task argument.** `skills/implement/SKILL.md`
  passes `model: <id>` when issuing each Task call. Always works; more
  central; surfaces the model choice in the cycle protocol explicitly.

The **canonize mode complicates frontmatter pinning** — the same
Orchestrator file runs both per-cycle (Sonnet 4.6) and at termination
(top-tier). A single frontmatter `model:` cannot express "depends on
mode". So even if frontmatter pinning works for the Validator, the
Orchestrator likely needs coordinator-side per-call pinning. v0 ships
the coordinator-side mechanism uniformly to keep the model surface
unified, with frontmatter as a future simplification once Claude Code's
support is confirmed.

## Definition of Done

1. **Per-role model selection mechanism in place.**
   `skills/implement/SKILL.md` resolves an explicit `model: <id>` for
   each Task call when spawning Generator, Validator, and Orchestrator.
   Resolution order: `.yoke/config.yaml` → built-in defaults. The
   resolved model is logged to `.yoke/query-traces/<slug>.md` (or the
   cycle's progress entry, whichever is closer to the call site)
   so traces show provenance.
2. **Validator pinned to Sonnet 4.6.**
   Default for `runtime.models.validator` is `claude-sonnet-4-6`
   (configurable). The Validator's Task call in
   `skills/implement/SKILL.md` step 2 resolves to this value unless
   the host project overrides it.
3. **Orchestrator pinned by mode.**
   `runtime.models.orchestrator.consult` and
   `runtime.models.orchestrator.monitor` default to
   `claude-sonnet-4-6`; `runtime.models.orchestrator.canonize`
   defaults to the current top-tier model (resolved from
   `runtime.models.default` if not set explicitly). Per-cycle Task
   calls and the termination canonize call use the matching value.
4. **`templates/yoke-config.yaml` exposes the overrides.**
   The template includes a commented `runtime.models:` block with all
   three (validator, orchestrator.consult/monitor/canonize) keys, plus
   a `runtime.models.default` for the Generator and any future role.
   `/yoke:bootstrap` copies it into host projects so users can
   override per-project.
5. **Validator-quality regression is zero.**
   `tests/smoke/perf-quickwins-part-3.test.sh` runs the Validator on a
   fixed set of pre-recorded sensor-snapshots (under
   `tests/fixtures/perf-quickwins-part-3/snapshots/`) and asserts that
   the Validator's per-criterion JSON verdicts (status, sensor,
   location) match a reference verdict file modulo timing-related
   fields. If Sonnet 4.6 produces a divergent verdict on the fixture
   set, the test fails and v0 falls back to top-tier for the
   Validator while keeping Orchestrator-consult/monitor on Sonnet 4.6
   (smaller win, no regression).
6. **Craftsmanship gate.**
   `agents/orchestrator.md` retains its sole-canonical-memory-writer
   contract per `patterns/roles.md`; canonize-mode write authority is
   not relaxed by the model swap (Model C governance preserved per
   `patterns/model-c-governance.md`); no `conventions.md` Don't
   violated; no new manifesto invariant introduced.

## Scope

In scope:

- `skills/implement/SKILL.md` — read `runtime.models.*` from
  `.yoke/config.yaml` at preflight; pass `model: <id>` to each Task
  call (per-cycle Generator + Validator + Orchestrator-consult/monitor;
  termination Orchestrator-canonize).
- `agents/validator.md` — add a comment in the persona section noting
  the model is coordinator-pinned (no frontmatter change in v0; see
  Technical Decisions).
- `agents/orchestrator.md` — add a comment in the mode-declaration
  section noting that consult/monitor and canonize may run on
  different models, both coordinator-pinned.
- `templates/yoke-config.yaml` — add `runtime.models:` block with
  documented defaults and override examples.
- `tests/smoke/perf-quickwins-part-3.test.sh` — new fixture-driven
  smoke test exercising the fixture snapshots + reference verdicts;
  wraps in `timeout 600`.

Optional (in scope only if straightforward in implementation):

- A small helper in `lib/runtime/` (e.g., `lib/runtime/agent-config.sh`)
  that the coordinator sources to resolve model defaults. Counts as one
  file; total stays at 5 (within budget).

## Anti-scope

- **Not** lowering the Generator model. Quality is king
  (PRD constraint A).
- **Not** lowering the Orchestrator's canonize-mode model. Governance
  writes are not where you optimize for cost.
- **Not** adding new model-fallback logic (e.g., "if Sonnet 4.6 fails,
  retry on top-tier"). If the model is unreachable, the Task call
  fails and the existing escalation path handles it.
- **Not** changing the per-cycle protocol shape — still 3 concurrent
  Task calls, same disjoint inputs, same per-agent file-ownership
  contracts.
- **Not** introducing per-task model overrides (only per-project via
  `.yoke/config.yaml`). Per-task pinning is a v0.1 candidate if
  needed.
- **Not** touching frontmatter `model:` on subagent files in v0. If
  Claude Code adds first-class support, fold it in v0.1.
- **Not** changing Validator/Orchestrator authorities, write
  contracts, or memory scopes.

## Technical Decisions

### Coordinator-side pinning over frontmatter pinning

Two reasons: (a) the Orchestrator file is the same agent invoked in
three modes, and a single `model:` frontmatter cannot express
mode-conditional pinning; (b) coordinator-side pinning is universally
supported regardless of plugin-frontmatter capability, removing a
runtime risk. Trade-off: the model choice lives one level removed
from the agent persona; we mitigate by adding a comment in each
agent's persona section pointing at `templates/yoke-config.yaml`.

### Mode-keyed config for the Orchestrator

`runtime.models.orchestrator.canonize` is a separate key from
`.consult` / `.monitor` because the two governance regimes don't
share a model rationale (per-cycle retrieval vs. write authority).
Treating them as one key would invite future drift.

### Defaults are conservative

Defaults pin only Validator + Orchestrator-consult/monitor to
Sonnet 4.6. Generator + Orchestrator-canonize fall back to
`runtime.models.default`, which itself defaults to absent —
inheriting the user's session model, preserving today's behavior
for the roles where quality is king.

### Smoke-test reference verdicts

The smoke test relies on a small fixture set
(`tests/fixtures/perf-quickwins-part-3/snapshots/*.yaml` +
`tests/fixtures/perf-quickwins-part-3/expected-verdicts.json`).
Building the fixture once with the current top-tier Validator and
asserting Sonnet 4.6 reproduces the same verdicts on the same
snapshots is the cheapest regression gate. If a future model upgrade
shifts both, the fixture is regenerated alongside the calibration
(`patterns/sensors.md` rippability principle applies).

### Logging the resolved model

Every Task spawn logs `[task-spawn] role=<r> model=<m>` either to
`.yoke/query-traces/<slug>.md` or to the cycle's `progress.md`
header. This is cheap traceability that pays for itself the first
time an operator wonders why a cycle behaved oddly after a config
edit.

### Mechanism cleanup deferred to v0.1

If Claude Code's plugin format supports per-subagent `model:`
frontmatter and per-mode pinning becomes possible (e.g., via
mode-passed parameters), simplify in a v0.1 follow-up. v0 ships the
universal coordinator-side path.

## Applicable Patterns

- `patterns/roles.md` — Validator and Orchestrator role contracts
  unchanged. Memory scopes, write authorities, and per-mode
  responsibilities preserved verbatim.
- `patterns/model-c-governance.md` — canonize-mode write protocol
  preserved (impact classification + git-native PRs + per-class PR
  behavior); the model running canonize stays top-tier so governance
  judgment is not downgraded.
- `patterns/ralph-loop.md` — per-cycle subagent batch shape unchanged;
  termination canonize call shape unchanged. Only the resolved
  `model:` value passed to each Task call differs.
- `conventions.md` (Cross-cutting → "Periodic re-test (rippability)")
  — model swaps are an explicit rippability moment; the smoke test's
  fixture-vs-reference comparison is the rippability check for this
  swap.

No new pattern.

## Risks

- **R1: Sonnet 4.6 produces lower-quality verdicts.**
  *What can go wrong:* on edge-case sensor outputs, Sonnet emits a
  malformed verdict JSON, mis-classifies a sensor failure, or misses
  a divergence the Validator should flag — silent quality erosion.
  *Mitigation:* DoD-5's fixture-vs-reference test gates merge. If
  it fails, fall back to top-tier for the Validator and capture
  the partial win from Orchestrator-consult/monitor only. Future
  audits compare Validator divergence rates pre/post — if the rate
  drifts, recalibrate or revert.
- **R2: Coordinator-side pinning isn't actually supported.**
  *What can go wrong:* the Task tool used by `/yoke:implement`
  doesn't accept a `model:` parameter in the deployed Claude Code
  version, and pinning silently no-ops. All agents continue running
  on the user's session model; the win evaporates without warning.
  *Mitigation:* the resolved-model logging (Technical Decisions →
  "Logging the resolved model") doubles as a verification gate. The
  smoke test additionally asserts the logged model matches the
  configured value. If the assertion fails, escalate to the
  open-question path (frontmatter `model:` per subagent if
  supported, else surface as a Yoke runtime requirement).
- **R3: Model identifiers drift over Claude Code releases.**
  *What can go wrong:* `claude-sonnet-4-6` becomes obsolete or
  renamed; the config silently fails or routes to a fallback the
  operator didn't choose.
  *Mitigation:* `templates/yoke-config.yaml` documents the model
  identifier alongside its capability rationale (e.g., "Sonnet-class
  for structured-JSON judgment"). On model upgrade, re-run the
  smoke test (rippability), update the default, and document in
  `.vibeflow/decisions.md`.
- **R4: Per-mode Orchestrator pinning leaks via canonize-call
  miswiring.**
  *What can go wrong:* the termination canonize call accidentally
  uses the consult-mode model (Sonnet) — write decisions made on a
  smaller model violates the constraint that canonize stays
  top-tier.
  *Mitigation:* `skills/implement/SKILL.md` step 3 (termination
  handoff) explicitly resolves
  `runtime.models.orchestrator.canonize` (not `.consult`); the
  smoke test for Part 3 includes a tiny "fake termination" assertion
  that the canonize-call's logged model matches the configured
  canonize value. The model identifier mismatch fails the test.

## Dependencies

None. This part is independently implementable. Sequence is a
preference, not a requirement: Part 1 is the highest-leverage win
and the easiest to measure, so most teams will land it first; Part
3 is the most mechanical and has the cleanest gate; Part 2 is the
most behavioral and is best landed last when fixture data exists
to evaluate cycle-count delta.
