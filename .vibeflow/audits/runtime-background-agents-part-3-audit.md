# Audit Report: runtime-background-agents — Part 3 (cycle status snapshots)

> Audited: 2026-04-26 against `.vibeflow/specs/runtime-background-agents-part-3.md`

**Verdict: PASS**

## Test Results

`tests/run-all.sh` → **0/18 files failed**.
`tests/ralph-loop-bounds.test.sh` → **23/23 PASS**, including the new
(f)-section asserting:
- helper exists and is executable
- SKILL.md invokes it exactly once per cycle (count = 1 inside the
  cycle-loop body, awk range "For each cycle" → "Termination handoff")
- helper output template references all 11 required field labels:
  `Cycle `, `- Generator:`, `- Validator:`, `- Orchestrator:`,
  `- judge:`, `Sensors:`, `computational`, `inferential`, `Bounds:`,
  `cycles`, `elapsed`
- integration smoke: helper exits 0 against synthetic state and
  emits a structured block matching the spec format (cycle 3, judge
  done/failed differentiation via `.failures.log`, sensor counts
  1/1/0 + 1/1/0, bounds line 3/8 cycles)

## DoD Checklist

- [x] **#1** `lib/ralph-loop/status-snapshot.sh` exists; accepts
  `<runtime-dir>` as `$1`; emits markdown to stdout; structured
  stderr on missing inputs.
  - Evidence: file present + executable, header docs the contract
    (`status-snapshot.sh:1-41`). Argument check at `:54-58` exits 2
    with usage text on missing arg. Runtime-dir existence check at
    `:62-72` exits 3 with structured `reason:` / `location:` /
    `correction:` block per `conventions.md` "Sensor output for LLM
    consumption". Smoke confirms exit 3 + structured stderr against
    `/nonexistent/dir/here`.

- [x] **#2** `/yoke:implement` invokes the helper exactly once per
  cycle, after `post-iteration.sh` and `check-hard-bounds.sh`,
  before next cycle's batch.
  - Evidence: `skills/implement/SKILL.md:249-261` adds step 7 with
    explicit ordering: "after step 4 (`post-iteration.sh`) and step
    5 (`check-hard-bounds.sh`) have completed and step 6 chose to
    continue". Test asserts `grep -cE 'lib/ralph-loop/status-snapshot\.sh'`
    inside the cycle body equals 1. `hooks/pre-implementation.sh`
    now records `.loop-start` idempotently so elapsed time can be
    computed.

- [x] **#3** Status block contains all required fields.
  - Evidence: helper output template emits, in order, the cycle
    title (`### Cycle <N> · <elapsed>s`), per-agent state lines for
    Generator/Validator/Orchestrator + dynamic `judge:<id>: <state>`
    lines from the verdict directory, one `Sensors:` line with both
    computational and inferential `pass/fail/skip` triplets, and one
    `Bounds:` line with `cycles/cycles_max` + `elapsed/timeout`.
    Test asserts every required label is referenced; integration
    smoke confirms the actual rendered block.

- [x] **#4** No mid-cycle / per-notification emission.
  - Evidence: `skills/implement/SKILL.md:255-258` step 7 prose:
    "Do **not** emit between step 1 and step 6 — the
    per-notification / mid-cycle window must remain silent." Plus
    new anti-pattern at `:316-321`: "Do NOT emit user-visible status
    mid-cycle". The cycle-body grep counting `1` invocation also
    means there is no second emission inside the cycle.

- [x] **#5** Helper is bash 4+ and emits a fixed structured format.
  - Evidence: `set -euo pipefail` at `:42`; idiomatic `[[ ... =~ ]]`
    regex tests; `declare -a` for arrays; `printf` for all output;
    `local` for function-scoped vars; `2>/dev/null || true` guard
    for reads; no backticks; quoted variables throughout. Output
    sections are emitted in the spec order (title → agent states →
    sensor counts → bounds) and one fact per line via discrete
    `printf` calls.
  - Caveat: `shellcheck-clean` cannot be formally verified locally
    — `shellcheck` is not installed on this host. Manual review of
    the patterns above gives high confidence the script is
    shellcheck-friendly. Recommend running `shellcheck` in CI when
    Sprint 8's CI workflow lands; if any warnings surface, address
    them in a follow-up commit.

- [x] **#6** `tests/ralph-loop-bounds.test.sh` extended with the
  three required assertions (helper exists+executable; SKILL.md
  invokes once; required labels present) plus an integration smoke
  test. All 23 checks pass; no version literals; no chronology.
  - Evidence: file diff adds the (f)-section. Required labels
    enumerated as a bash array driving a grep loop, so a missing
    label fails one specific assertion (not the whole section).

## Pattern Compliance

- [x] **`patterns/ralph-loop.md`** — Deterministic-nodes list (added
  in Part 1) accommodates the new step 7 implicitly: status snapshot
  is just another deterministic node in the blueprint. No edits
  needed in Part 3 because Part 1 already documented the
  deterministic-nodes class.
- [x] **`conventions.md`** — "Back-pressure: success is silent,
  failures are verbose" is acknowledged and bounded: the status
  snapshot is the single sanctioned exception, gated to one block
  per cycle, fixed format. The helper's stderr error format
  ("`reason:` / `location:` / `correction:`") follows the
  "Sensor output for LLM consumption" rule directly.
- [x] **`patterns/sensors.md`** — Status-block fidelity matches the
  inferential-sensor data model from Part 2: judges enumerate by
  verdict-file basename (criterion id today), failures attribute
  via `.failures.log` written by `/yoke:implement`. No conflict
  with the spawn ownership rule.

## Convention Violations

None observed.

## Budget

4 of 4 files used:
1. `lib/ralph-loop/status-snapshot.sh` (created)
2. `skills/implement/SKILL.md` (modified — step 7 + new anti-pattern)
3. `hooks/pre-implementation.sh` (modified — loop-start ts)
4. `tests/ralph-loop-bounds.test.sh` (modified — (f)-section)

`hooks/verify-acceptance.sh` was scoped as optional in the spec; the
existing `cycle-<N>.yaml` schema already exposes per-sensor `status:`
lines, so no change was needed.

## Anti-scope

All 7 items respected:
- per-notification status emission: not introduced (anti-pattern
  in SKILL.md guards it).
- mid-cycle / live progress: not introduced.
- TUI / spinner: not introduced (plain markdown).
- termination status duplicate: not introduced (helper does not
  fire on MERGE-READY).
- hard-bound abort duplicate: not introduced (helper does not
  fire on escalation paths; `escalate.sh` owns Trigger-4 packet).
- partial signals (e.g. "Generator targeted criterion auth-3"):
  not introduced.
- snapshot format negotiation with downstream tooling: not
  introduced (fixed format, no `--version` flag, no consumer API).

## Notes for follow-ups

- **shellcheck verification deferred.** Local environment lacks
  `shellcheck`. Sprint 8's CI workflow (per `index.md` §134) is the
  natural place to add a `shellcheck lib/**/*.sh hooks/**/*.sh`
  step; if any warnings surface against the new helper, address
  them then.
- **Part 2 verdict-path collision.** When two inferential sensors
  apply to the same criterion, the verdict path
  `wm_judge_verdict_path "$slug" "$cycle" "$criterion-id"` collides
  (basename keyed by criterion only). Part 3's status block
  surfaces only one `judge:<criterion>` line in that case. This is
  a known Part 2 limitation — the project's `Any-fail-wins
  aggregation` rule (`patterns/sensors.md`) supports multiple
  sensors per criterion, but the path schema does not. Recommend a
  follow-up spec to extend the verdict-path key from `<criterion>`
  to `<criterion>--<sensor>` before any production task with
  multiple inferential sensors per criterion lands.
- **`.task-spawn-log` semantics unchanged.** The Part 3 helper
  reads completion state from the verdict directory + failures log
  rather than the spawn log. The spawn log continues to record
  resolved-model provenance only.

## Next Steps

Ready to ship Part 3. All three parts of the multi-part spec are
now implemented and audited:

| Part | Status | Audit |
|------|--------|-------|
| Part 1 (background spawning) | shipped | PASS |
| Part 2 (skill-owned inferential sensors) | shipped | PASS |
| Part 3 (cycle status snapshots) | shipped | PASS |

The work originally framed in the PRD (background-agent spawning +
status visibility) is fully delivered.
