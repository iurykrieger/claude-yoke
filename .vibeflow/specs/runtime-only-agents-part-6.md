# Spec: runtime-only-agents — Part 6 (smoke tests)

> Generated via /vibeflow:gen-spec on 2026-04-25 from
> `.vibeflow/prds/runtime-only-agents.md`. Part 6 of 6.

## Objective

Update existing sprint smoke tests (`tests/smoke/sprint-{2..5}.test.sh`)
to assert the new agent / skill topology — no Task spawns in
spec-phase skills, 3 concurrent Task calls per `/yoke:implement`
cycle, and automatic canonization at loop termination.

## Context

The existing smoke tests assert v1.0.0 behavior — spec-phase subagent
spawning, sequential cycle agent spawning, and Phase-5 explicit
`/yoke:canonize` invocation. After Parts 1–5 land, those assertions
are outdated and the suite would fail. Sprint 1 (bootstrap) and
sprints 6–8 (hard bounds, drift sense, CI gate) are not affected by
this refactor.

## Definition of Done

1. `tests/smoke/sprint-2.test.sh` asserts that `/yoke:discover` and
   `/yoke:tech-spec` produce their respective artifacts without
   invoking the Task tool — verifiable either by inspecting
   `allowed-tools` in the SKILL.md files or by asserting absence of
   Task-call traces in the test transcript.
2. `tests/smoke/sprint-3.test.sh` asserts that
   `/yoke:acceptance-contract` produces its artifact without
   invoking the Task tool, and that sensor discovery
   (`lib/sensors/discover-from-claude-md.sh`) still fires.
3. `tests/smoke/sprint-4.test.sh` asserts that `/yoke:implement`
   issues exactly 3 concurrent Task calls per cycle (against a
   fixture acceptance contract with at least 1 BDD scenario), and
   that all existing ralph-loop assertions (sensor execution,
   contradiction check, Trigger-4 escalation simulation) still
   pass.
4. `tests/smoke/sprint-5.test.sh` asserts that the Orchestrator's
   canonize phase fires automatically at `/yoke:implement` loop
   termination (no separate `/yoke:canonize` invocation needed),
   and that canonical-memory writes route through a test substrate
   or `--dry-run` mode. Existing `/yoke:canonize` escape-hatch
   tests still pass.
5. All four updated tests complete within the existing
   `timeout 600` external guard and exit 0 on green.
6. **Craftsmanship gate** — each test's external `timeout 600`
   guard is preserved (per the *Smoke test per sprint* convention
   in `.vibeflow/conventions.md`); each test's failure paths emit
   structured diagnostics (no silent skips, no generic "test
   failed" messages); sprint-1 and sprints 6–8 are not touched.

## Scope

- Update `tests/smoke/sprint-2.test.sh` for the no-Task-spawn
  assertions on `/yoke:discover` and `/yoke:tech-spec`. Add
  positive assertions that artifacts (`prd.md`, `tech-spec.md`)
  are produced and carry `Status: approved`.
- Update `tests/smoke/sprint-3.test.sh` for the no-Task-spawn
  assertion on `/yoke:acceptance-contract`. Preserve existing
  sensor-discovery and Trigger-3 ratification assertions.
- Update `tests/smoke/sprint-4.test.sh` for the
  3-concurrent-Task assertion in `/yoke:implement`. Keep all
  existing ralph-loop assertions.
- Update `tests/smoke/sprint-5.test.sh` for the
  auto-canonize-at-termination assertion. Keep existing
  `/yoke:canonize` escape-hatch tests intact.

## Anti-scope

- New test files — assertions are added to existing per-sprint
  test files, not new ones. The 1-test-per-sprint layout is
  preserved.
- `tests/smoke/sprint-1.test.sh` (bootstrap) — untouched.
- `tests/smoke/sprint-6.test.sh` (hard bounds) — untouched; hard
  bounds remain a Sprint-6 concern, unaffected by topology refactor.
- `tests/smoke/sprint-7.test.sh` (drift sense) — untouched.
- `tests/smoke/sprint-8.test.sh` (CI gate) — untouched; the gate
  itself continues to run as-is.
- CI workflow files (`.github/workflows/*`) — no changes.
- Test fixtures under `tests/fixtures/` (if present) — only update
  if they encode the old topology; document any updates in the
  implementation notes.

## Technical Decisions

- **Assertions go in existing per-sprint test files.** Maintains
  the 1-test-per-sprint layout. The new behavior is tested by the
  sprint that owns the relevant capability:
  - Sprint 2 owns `/yoke:discover`, `/yoke:tech-spec`.
  - Sprint 3 owns `/yoke:acceptance-contract`.
  - Sprint 4 owns `/yoke:implement` (runtime).
  - Sprint 5 owns `/yoke:canonize` and canonical-memory writes.
- **3-concurrent-Task assertion strategy: prefer observable
  side effects.** Counting Task tool-use blocks in a single
  assistant message via transcript parsing is brittle. Prefer
  asserting 3 distinct subagent contributions per cycle in
  `.yoke/progress.md` and `.yoke/contracts.md` (each subagent
  leaves identifiable per-cycle entries). The exact mechanism is
  the implementer's choice — DoD only requires the assertion
  fires correctly.
- **Canonize-at-termination assertion uses `--dry-run`.** Avoid
  polluting any canonical-memory repo. Assert that the
  propose-write payload was generated and its impact class is
  classified.
- **No new external timeouts.** Reuse the existing
  `timeout 600 ...` external wrapper; do not add per-sub-test
  timeouts.

## Applicable Patterns

- `.vibeflow/patterns/ralph-loop.md` (post-rewrite, Part 4) —
  semantics being tested.
- `.vibeflow/patterns/sensors.md` — structured-output
  expectations preserved.
- `.vibeflow/patterns/human-triggers.md` — Trigger-4 escalation
  schema (Sprint 4 test).

## Risks

- **R-F1 — Counting concurrent Task calls is transcript-format
  dependent and brittle.** Mitigation: prefer asserting observable
  side effects in `.yoke/*.md` files (3 distinct per-cycle
  contributions) over transcript parsing.
- **R-F2 — Auto-canonize assertion depends on a test
  canonical-memory substrate.** Mitigation: use `--dry-run`
  mode (already supported per the Orchestrator subagent's
  contract); assert dry-run payload generation and impact-class
  classification.
- **R-F3 — Test fixtures may encode the old topology.**
  Mitigation: grep `tests/fixtures/` for "Implementation Agent",
  "Validation Agent", "spec-phase Generator", etc.; update any
  hits.
- **R-F4 — Sprint-5 test may rely on a separate
  `/yoke:canonize` invocation in v1.0.** Mitigation: refactor
  the test to (a) exercise the auto-canonize path via
  `/yoke:implement` exit, AND (b) keep the explicit
  `/yoke:canonize` escape-hatch test as a separate scenario.

## Dependencies

- `.vibeflow/specs/runtime-only-agents-part-1.md`
- `.vibeflow/specs/runtime-only-agents-part-2.md`
- `.vibeflow/specs/runtime-only-agents-part-3.md`
