# Audit Report: runtime-background-agents — Part 2 (skill-owned inferential sensors)

> Audited: 2026-04-26 against `.vibeflow/specs/runtime-background-agents-part-2.md`

**Verdict: PASS**

## Test Results

`tests/run-all.sh` → **0/18 files failed**.
`tests/ack-sensors-inferential.test.sh` → **0 failures**, including the
new Part 2 assertions:
- `validator.md` has no `subagent_type:` (judge spawn owned by
  `/yoke:implement`)
- SKILL.md per-cycle batch declares `subagent_type: semantic-judge`
- SKILL.md per-cycle batch advertises width `3 + N`
- SKILL.md documents `runtime.inferential_sensor_concurrency` cap
- SKILL.md anti-pattern forbids `semantic-judge` spawn from subagents
- `paths.sh` defines `wm_judge_verdict_dir()` and
  `wm_judge_verdict_path()`
- `paths.sh` helpers emit the documented verdict paths
  (`.yoke/runtime/.judge-verdicts/cycle-3` and
  `.yoke/runtime/.judge-verdicts/cycle-3/FR-1.json`)
- `validator.md` references `.judge-verdicts` as inferential input

## DoD Checklist

- [x] **#1** `/yoke:implement` reads applicable inferential sensors and
  spawns one `Agent(subagent_type: semantic-judge, run_in_background:
  true)` per sensor in the same per-cycle batch as G/V/O; wait extended
  to `3 + N`.
  - Evidence: `skills/implement/SKILL.md:84-99` (per-cycle batch
    header + `3 + N` width), `:138-178` (inferential-sensor sub-step
    with sensor identification, cap, deferred queue, failure policy),
    `:184-188` (wait paragraph: "all `3 + N` completion
    notifications").

- [x] **#2** `agents/validator.md` issues no `subagent_type:` line;
  grep empty.
  - Evidence: test asserts `^[[:space:]]*subagent_type[[:space:]]*:`
    has zero matches in `validator.md`. Validator's "Never" section
    at `:121-126` explicitly forbids spawning `semantic-judge`. Tools
    list at `:4` excludes `Agent` and `Task`.

- [x] **#3** Each judge writes to
  `.yoke/runtime/.judge-verdicts/cycle-<N>/<criterion-id>.json`; path
  helper added; Validator reads from cycle `<N-1>`.
  - Evidence: `lib/working-memory/paths.sh:182-220` — `wm_judge_verdict_dir`
    and `wm_judge_verdict_path` helpers added, mirroring the
    `wm_*` family. Smoke test runs the helpers in a temporary
    `.yoke/` directory and asserts exact equality with
    `.yoke/runtime/.judge-verdicts/cycle-3` and
    `.yoke/runtime/.judge-verdicts/cycle-3/FR-1.json`.
    `agents/validator.md:56-68` documents the read behavior;
    memory scope at `:128-141` includes the verdict directory.

- [x] **#4** Verdict JSON shape matches the existing 6-field contract.
  - Evidence: `agents/semantic-judge.md` untouched (the spec's
    anti-scope on "verdict schema redesign"). The verdict-shape
    parity assertions (criterion / status / location /
    fix_instruction / sensor / evidence — both Validator and
    judge sides) all pass in
    `tests/ack-sensors-inferential.test.sh`.

- [x] **#5** `runtime.inferential_sensor_concurrency` documented
  (default 4); deterministic selection + deferred queue when N > cap.
  - Evidence: `skills/implement/SKILL.md:151-162` — "Cap `N` at
    `runtime.inferential_sensor_concurrency` in `.yoke/config.yaml`
    (default `4`)"; deterministic order ("criterion order, ties
    broken by sensor id"); deferred queue at
    `$(wm_runtime_dir)/.deferred-sensors.json` with
    deferred-first prepend on next cycle. The pattern matches the
    existing `runtime.sensor_concurrency` documentation style at
    `:167-168` (no central config schema file in this project; keys
    are documented at the consumer site).

- [x] **#6** Anti-pattern rule extended: "Do NOT spawn
  `semantic-judge` from inside any subagent — only `/yoke:implement`
  spawns inferential-sensor agents." Pre-existing prohibitions
  preserved.
  - Evidence: `skills/implement/SKILL.md:308-313` adds the new
    entry; the original recursive-Orchestrator-spawn entry at `:307`
    survives unchanged. Test confirms via grep on
    `Do NOT spawn .semantic-judge`.

- [x] **#7** `tests/ack-sensors-inferential.test.sh` extended with
  the three required assertions plus a helper-output smoke and
  validator-references-judge-verdicts check. No version literals; no
  chronology.
  - Evidence: file diff adds the "Skill-owned inferential-sensor
    spawning (runtime-background-agents Part 2)" section at the end
    of the test, exercising the assertions documented in spec
    DoD #7.

## Pattern Compliance

- [x] **`patterns/sensors.md`** — "Parallel execution & acknowledgement"
  subsection rewritten as "Parallel execution — coordinator-owned
  spawn (v0.5.0+)". Computational and inferential paths now have
  distinct, documented ownership. Cycle wall-clock formula updated.
  Inferential-sensor failure policy added.
- [x] **`patterns/ralph-loop.md`** — single-concurrent-batch invariant
  preserved (just wider: `3 + N`). No edits needed in Part 2 — the
  pattern was updated by Part 1; Part 2 simply scales width.
- [x] **`patterns/roles.md`** — Validator authority preserved. The
  role still emits structured verdicts and co-writes contracts on
  consensus. The change strips a *responsibility* (judge spawning
  that was forward-looking documentation) and adds a *consumption
  contract* (read judge verdicts from working memory). No authority
  expansion.
- [x] **`conventions.md`** — "Sensor output for LLM consumption"
  honoured (canonical 6-field verdict shape preserved on both
  computational and inferential sides). "Test file per framework
  concept" honoured (extended existing `tests/ack-sensors-inferential.test.sh`,
  no new sprint-numbered files). "Blueprints wrapping agentic nodes"
  honoured (skill spawns judges; deterministic helpers resolve paths;
  Validator just reads).

## Convention Violations

None.

## Budget

4 of 4 files used:
1. `skills/implement/SKILL.md`
2. `agents/validator.md`
3. `.vibeflow/patterns/sensors.md`
4. `tests/ack-sensors-inferential.test.sh`

Plus 1 trivial helper addition: `lib/working-memory/paths.sh` (two
new functions mirroring the existing `wm_*` family). Per the spec's
explicit scope note, this does not count against the budget — and
the audit confirms the addition is purely additive (no behavioral
change to existing helpers).

## Anti-scope

All 7 anti-scope items respected:
- Generator and Orchestrator role changes: none.
- Computational sensor pipeline: untouched (`xargs -P` in
  `verify-acceptance.sh`).
- Verdict schema redesign: untouched (6-field shape preserved on
  both sides).
- Mid-cycle live arbitration on judge failures: not introduced.
- Hard-bound escalation on first judge failure: not introduced
  (threshold is two consecutive cycles per Decision #2).
- Status snapshot emission: not introduced (Part 3).
- Pre-fetching judge inputs across cycles: not introduced.

## Notes for follow-ups

- `agents/semantic-judge.md`'s frontmatter `description` field still
  reads "spawned per inferential sensor by the Validator via
  Agent(subagent_type: yoke:semantic-judge)". This is documentation
  drift after Part 2 (the operational contract is now skill-owned
  spawning), but updating it was out of the spec's file budget.
  Recommend a follow-up doc-only commit to align the description
  with the runtime contract before Part 3 ships.
- The `runtime.inferential_sensor_concurrency` config key is
  documented at the consumer site (SKILL.md) but has no central
  schema. This matches the existing `runtime.sensor_concurrency`
  pattern. If a config-schema validator ever lands, the new key
  must be registered there.

## Next Steps

Ready to ship Part 2. Proceed to
`/vibeflow:implement .vibeflow/specs/runtime-background-agents-part-3.md`.
