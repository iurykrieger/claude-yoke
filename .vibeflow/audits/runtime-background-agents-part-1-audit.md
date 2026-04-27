# Audit Report: runtime-background-agents — Part 1 (background spawning)

> Audited: 2026-04-26 against `.vibeflow/specs/runtime-background-agents-part-1.md`

**Verdict: PASS**

## Test Results

`tests/run-all.sh` → **0/18 files failed**.
`tests/ralph-loop-bounds.test.sh` → **PASS (8 checks)**, including the
new (e)-section asserting:
- per-cycle batch declares `run_in_background: true`
- canonize handoff stays foreground (no `run_in_background:true` token)

## DoD Checklist

- [x] **#1** Per-cycle three-Task batch uses `run_in_background: true`;
  foreground spawning removed; no dual-mode toggle.
  - Evidence: `skills/implement/SKILL.md:84` ("3 background Task
    calls"), `:87-88` ("Each Task call sets `run_in_background: true`").
    No conditional/dual-mode language anywhere in §2.

- [x] **#2** Skill explicitly waits for all three completion
  notifications before `hooks/verify-acceptance.sh` runs.
  - Evidence: `skills/implement/SKILL.md:149-158` — new paragraph
    immediately after the per-agent input list, immediately before
    step 2 (sensor execution): "wait for all three completion
    notifications before advancing to step 2"; "every step below in
    this cycle assumes all three Task calls have returned".

- [x] **#3** Per-role model resolution preserved.
  - Evidence: `skills/implement/SKILL.md:89-99` carries the
    `$generator_model` / `$validator_model` / `$orch_consult_model`
    table verbatim plus the "when empty, omit" rule.
    `lib/runtime/agent-config.sh::yoke_resolve_model …` and the
    `yoke_log_resolved_models` log at preflight remain referenced
    (`SKILL.md:62-78`, unchanged).

- [x] **#4** Canonize handoff stays foreground.
  - Evidence: `skills/implement/SKILL.md:216-220` — "This call is
    **foreground** — background spawning applies only to the
    per-cycle batch in step 1". Test (e)'s third assertion confirms
    no `run_in_background: true` token in the awk-extracted canonize
    section.

- [x] **#5** `patterns/ralph-loop.md` updated:
  - Section heading "(per cycle, single assistant turn, background)"
    at line 30.
  - Body at lines 31-38 explicitly states `run_in_background: true` +
    notification-based wait, no polling.
  - Deterministic-nodes list adds the wait at lines 57-59.
  - Blueprint pseudocode at lines 179-184 uses
    `parallel_spawn(run_in_background=True)` + `wait_for_completions`.
  - Termination handoff comment at line 195 says "single foreground
    Orchestrator call".
  - Rules section at lines 162-165 adds the new per-cycle background
    rule.
  - Anti-patterns at lines 209-210 add foreground-batch and polling
    prohibitions.
  - Implementation mapping at lines 222-227 and 239-243 updated.

- [x] **#6** Anti-pattern list in `SKILL.md` extended; originals
  intact.
  - Evidence: `skills/implement/SKILL.md:294-303` adds two new
    entries: (a) "Do NOT spawn the per-cycle batch in foreground …
    The termination canonization handoff (step 3) is the **only**
    Task call in the loop that runs foreground"; (b) "Do NOT poll,
    sleep, or otherwise probe for completion state during the wait".
    Pre-existing entries (sequential spawn, share-context,
    mid-loop preserve, skip verify-acceptance, relax contract,
    timeout-pre-Sprint-6, recursive Orchestrator spawn) all still
    present.

- [x] **#7** `tests/ralph-loop-bounds.test.sh` extended with present-
  tense assertions in the (e)-section:
  - `(e) skills/implement/SKILL.md present` — file existence.
  - `(e) per-cycle batch declares run_in_background: true` — awk
    range from "Concurrent subagent batch" to "Sensor execution",
    grep for `run_in_background:[[:space:]]*true`.
  - `(e) canonize handoff stays foreground (no
    run_in_background:true)` — awk range from "Termination handoff"
    to "Termination paths", asserts the regex does NOT match.
  - No version literals; no chronology; assertions are present-tense.

## Pattern Compliance

- [x] **`patterns/ralph-loop.md`** — Updated to be consistent with the
  new spawning model. The "Concurrent agentic batch" subsection,
  Rules list, Anti-patterns, blueprint pseudocode, and Implementation
  Mapping all converge on background-per-cycle / foreground-canonize.
- [x] **`patterns/roles.md`** — Role boundaries preserved. The change
  is purely about *how* the skill spawns subagents, not *which*
  subagent owns *which* responsibility. Generator/Validator/
  Orchestrator authorities unchanged.
- [x] **`conventions.md`** — "Blueprints wrapping agentic nodes"
  honoured: the wait between batch dispatch and sensor execution is
  classified as a deterministic node in both `SKILL.md` and
  `ralph-loop.md`. "Test file per framework concept" honoured: the
  new assertions extend the existing `tests/ralph-loop-bounds.test.sh`
  rather than creating a new sprint-numbered file. No version
  literals.

## Convention Violations

None.

## Budget

3 of 4 files used. `lib/ralph-loop/orchestrate.sh` was scoped as
optional and did not need to change — the wait step inlines cleanly
in `SKILL.md` prose.

## Anti-scope

All 7 anti-scope items respected:
- inferential-sensor spawning untouched (Part 2).
- status snapshots not added (Part 3).
- `agents/validator.md` untouched.
- canonize handoff stays foreground.
- per-cycle batch width still 3.
- no polling / sleep loops introduced.
- no new canonical-memory reads or writes.

## Next Steps

Ready to ship Part 1. Proceed to
`/vibeflow:implement .vibeflow/specs/runtime-background-agents-part-2.md`.
