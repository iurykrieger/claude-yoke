# Audit Report: ask-source-agnostic-read-part-3

**Verdict: PASS**

> Auditor: /vibeflow:audit (autonomous run, 2026-04-25)
> Spec: `.vibeflow/specs/ask-source-agnostic-read-part-3.md`
> PRD: `.vibeflow/prds/ask-source-agnostic-read.md`
> Dependencies: ask-source-agnostic-read-part-1 (PASS), ask-source-agnostic-read-part-2 (PASS)

## Test execution

| Test | Result |
| :--- | :--- |
| `tests/smoke/sprint-2.test.sh` | PASS |
| `tests/smoke/sprint-5.test.sh` | PASS |
| `tests/smoke/folder-isolation.test.sh` | PASS |
| `tests/smoke/ask-no-clone.test.sh` | PASS |
| `tests/smoke/sprint-3.test.sh` (regression) | PASS |
| `tests/smoke/sprint-4.test.sh` (regression) | PASS |
| `tests/smoke/sprint-6.test.sh` (regression) | PASS |
| `tests/smoke/sprint-7.test.sh` (regression) | PASS |
| `tests/smoke/sprint-8.test.sh` (regression) | PASS |
| `tests/smoke/memory-migration.test.sh` (regression) | PASS |
| `tests/smoke/preserve-model-c.test.sh` (regression) | PASS |
| `tests/smoke/status-readonly.test.sh` (regression) | PASS |
| `tests/smoke/teach-ingest.test.sh` (regression) | PASS |

**13/13 smoke tests PASS.** This is the first time the suite has been
fully green since the trace-removal effort began; Parts 1+2 left the
suite intentionally inconsistent until this part landed.

## DoD Checklist

- [x] **DoD-1** — `tests/smoke/sprint-2.test.sh`: trace-write assertion
      removed; replacement assertions cover skill callable without
      `.yoke/.current` (negative-pattern grep + positive
      "source-agnostic" phrase grep), allowed-tools excludes both
      `Task` and `Write`, references `resolve-memory.sh`, declares
      no-clone, declares no-fabrication, caps at 15.
      *Evidence:* `tests/smoke/sprint-2.test.sh` checks 8 (lines
      105-138) reads as the new shape; existing checks at lines 7, 9
      preserved unchanged.
- [x] **DoD-2** — `tests/smoke/sprint-5.test.sh`: assertions about the
      YAML trace shape (`mode: ask`, `entities_read`, `capped`,
      `invoker`) and the `query-traces` reference removed; only
      `resolve-memory.sh` is asserted. No duplicate of sprint-2's
      source-agnostic check (deletion preferred per spec).
      *Evidence:* `tests/smoke/sprint-5.test.sh` check 5 (lines 86-95)
      and check 13 (lines 239-244) reflect the new shape.
- [x] **DoD-3** — `tests/smoke/folder-isolation.test.sh`: per-category
      folder layout asserts only `prds`, `tech-specs`,
      `acceptance-contracts`, `contracts`. The migration check for the
      singular `query-trace.md` is replaced with a sweep that
      enforces no live query-trace references in `skills/`, `lib/`, or
      `hooks/` (exclusion regex skips lines marked retired). Any
      `wm_query_trace_path` invocation is deleted; the simulated flow
      no longer writes a trace; the forbidden-flat list no longer
      includes `.yoke/query-trace.md`.
      *Evidence:* `tests/smoke/folder-isolation.test.sh` lines 43-72
      (flat-path scan + sweep), 90-126 (simulated flow), 132-157
      (case statement + forbidden list).
- [x] **DoD-4** — `tests/smoke/ask-no-clone.test.sh`: untouched. On
      inspection the test had no trace coupling — it exercises the
      Part 1 resolution lib end-to-end and asserts (a) reflog stable
      across two resolutions, (b) `resolve-memory.sh` has no
      `clone/pull/fetch`, (c) SKILL.md declares the no-clone
      invariant, (d) `query.sh` is gone. All four assertions still
      hold under the new skill shape.
      *Evidence:* `bash tests/smoke/ask-no-clone.test.sh` reports
      `All Part 3 no-clone scenarios PASS`.
- [x] **DoD-5** — All four smoke tests pass. Confirmed by direct
      execution above.
- [x] **DoD-6** — No surviving *live* reference to `query-trace.md`,
      `query-traces/`, or `wm_query_trace_path` in any test. Surviving
      occurrences are all (i) docstrings explaining what was retired
      or (ii) negative-assertion patterns asserting the contract has
      not returned. The strict reading of "no test references" is
      relaxed to "no surviving reference as a live mechanism" per the
      spec body's intent ("the migration check for the singular
      `query-trace.md` is removed (the singular file did not survive
      past v0.6.0; the plural directory will not exist)").
      *Evidence:* `grep -RnE 'query-trace|wm_query_trace_path'
      tests/smoke/` returns 11 hits, every one of which is a comment,
      docstring, or err-branch of a negative-assertion guard.
- [x] **DoD-7** — Vacuous-green assertions absent. Each replaced
      assertion tests a real property:
      - "allowed-tools excludes Write" — would fail if Write returns.
      - "source-agnostic phrase present" — would fail if the SKILL.md
        regresses to require an active task.
      - "no live query-trace references in skills/lib/hooks" — would
        fail if any caller re-introduces the path.
      - sprint-5 trace-shape assertions deleted outright (no
        replacement that would always green).

## Pattern Compliance

- [x] **`.vibeflow/patterns/sensors.md`** — followed.
      Each new test assertion has clear pass/err messages and tests a
      named property. The "structured output" convention applies to
      runtime sensors but the test convention here mirrors it
      (`pass "<rule>"` / `err "<violation>"`).
- [x] **`.vibeflow/patterns/plugin-structure.md`** — followed.
      `tests/smoke/` layout preserved; no new directory introduced; no
      new test files created (DoD anti-scope).

## Convention Compliance

- [x] `.vibeflow/conventions.md` Implementation Plan Conventions —
      "Smoke test per sprint": preserved; `bash 4+` target preserved;
      external `timeout 600` discipline preserved (`ask-no-clone`
      already wraps itself; sprint-2/5/folder-isolation are
      pre-Sprint-6 and don't run ralph loops).

## Anti-scope discipline

| Anti-scope item | Status |
| :--- | :--- |
| Adding new test files | RESPECTED — no new files in `tests/smoke/` |
| Wiring `tests/` into CI (Sprint 8) | RESPECTED — no CI changes |
| Smoke-test harness or `timeout 600` discipline | RESPECTED — preserved |
| `tests/smoke/sprint-3.test.sh`, `sprint-4.test.sh`, `teach-ingest.test.sh` | RESPECTED — untouched; regressions PASS |

## Risks (from spec)

- **R1 / Vacuous-green assertion** — DID NOT HAPPEN. Each replaced
  assertion is verified as testing a real property.
- **R2 / Removed assertion takes a real safety property with it** —
  DID NOT HAPPEN. Each removed assertion was about the trace contract
  itself; preserved invariants (15-cap, no-clone, no-fabrication,
  resolve-memory.sh, allowed-tools-excludes-Task) still asserted by
  sprint-2 plus a new "Write excluded" check.
- **R3 / Test fails on macOS bash 3** — N/A (project targets bash 4+;
  the suite was already passing under bash 4 prior to this PR).
- **R4 / `timeout 600` exceeded** — DID NOT HAPPEN. Suite runs in
  seconds. The new flow does fewer disk writes than the old.

## Notable item: budget over-run

The spec's scope listed 4 test files; this implementation modified 3
test files (ask-no-clone needed no edit) plus 2 additional **skill**
files:

- `skills/implement/SKILL.md` — removed the
  `wm_query_trace_path "$slug"` initialization step from the cycle-0
  setup. The function had been deleted in Part 1; this line would
  have failed at runtime as soon as Part 1 shipped.
- `skills/drift-sense/SKILL.md` — three trace references rewritten:
  (a) staleness-source falls back to `last_validated` only; (b)
  `--target traces` mode now scans contracts only; (c) traces-mode
  pre-condition no longer mentions the retired `.yoke/query-traces/<slug>.md`.

These two files were Part 1 stragglers — Part 1's R1 mitigation
required a grep across `skills/` to catch every caller of the deleted
helper, but the Part 1 audit missed these two. They were caught by
folder-isolation.test.sh's new "no live query-trace references" sweep.
Patching them was necessary to make DoD-5 (tests pass) achievable;
without the patches the suite would have stayed red.

Files modified: 5 / spec scope 4. Treating as a Part 1 corrigendum
embedded in Part 3 rather than re-opening Part 1's audit. The two
skill files have a minimal-scope edit each (one removed line in
implement; three rewritten lines + 1 deprecation note in drift-sense)
and the broader behavioral implication (drift-sense `--target traces`
mode loses query-trace as an input source) is acknowledged in inline
comments.

This over-run is **PASS-compatible** under the audit skill's rules —
the rule that triggers automatic FAIL is "tests fail", not "budget
exceeded by 1". The architect (spec author) is hereby informed; if
this should have been a Part 1 amendment with a separate audit, that
is a process call rather than a code call.

## Gaps

None. All 7 DoD checks satisfied; all 13 smoke tests pass; anti-scope
respected; pattern compliance preserved.

## Notes for downstream parts

- Part 4 (doctrine update) must update `.vibeflow/conventions.md`,
  `.vibeflow/patterns/memory-model.md`, and
  `.vibeflow/patterns/roles.md` to reflect the runtime + skill +
  test contracts now established by Parts 1-3.
- Part 5 (CLAUDE.md + docs) must update the working-memory layout
  and any `query-trace.md` mentions in user-facing docs.
- Part 6 (changelog + trailing docs) must record the contract change
  end-to-end, including the Part 1 corrigendum to `skills/implement`
  and `skills/drift-sense`.

## Next step

Ready to ship Part 3. Proceed to Part 4: `.vibeflow/` doctrine update.
