# Sprint 03 of 06: `/yoke:ask` source-agnostic

> Migrated from: # Spec: `/yoke:ask` source-agnostic — Part 3 / Test suite alignment


> Generated via /vibeflow:gen-spec on 2026-04-25
> PRD: `.vibeflow/prds/ask-source-agnostic-read.md`

## Objective

Update the four smoke tests that assert query-trace behavior so they
reflect the no-trace, source-agnostic contract introduced in Parts 1–2.

## Context

Four smoke tests currently encode the trace contract:

- `tests/smoke/sprint-2.test.sh` — asserts `/yoke:ask` writes to
  `.yoke/query-traces/<slug>.md`, references `wm_query_trace_path`,
  declares no-clone, declares no-fabrication, caps at 15.
- `tests/smoke/sprint-5.test.sh` — asserts the YAML trace shape (mode,
  entities_read, capped, invoker fields).
- `tests/smoke/folder-isolation.test.sh` — asserts the per-category
  folder layout including `query-traces/`, plus a migration check for
  the singular `query-trace.md`.
- `tests/smoke/ask-no-clone.test.sh` — asserts the no-clone invariant
  under the (now-removed) trace-emitting flow.

After Parts 1–2, assertions about (a)–(c) become false; (d)'s no-clone
property must be preserved with revised assertion code. This part
realigns each test in place.

## Definition of Done

1. `tests/smoke/sprint-2.test.sh` — assertions about trace writing,
   `wm_query_trace_path`, and `.yoke/query-traces/<slug>.md` are removed.
   Replacement assertions cover: skill is callable without `.yoke/.current`;
   skill references `lib/canonical-memory/resolve-memory.sh`; allowed-tools
   excludes `Task`; declares no-clone; declares no-fabrication; caps at 15.
2. `tests/smoke/sprint-5.test.sh` — assertions about the YAML trace shape
   (`mode: ask`, `entities_read`, `capped`, `invoker`) are removed. Any
   assertion that overlaps with sprint-2 is deleted (no duplicate); any
   remaining assertion is consistent with Part 1.
3. `tests/smoke/folder-isolation.test.sh` — the per-category folder
   layout assertion lists only `prds`, `tech-specs`,
   `acceptance-contracts`, `contracts`. The migration check for the
   singular `query-trace.md` is removed (the singular file did not
   survive past v0.6.0; the plural directory will not exist). Any
   `wm_query_trace_path` invocation is deleted.
4. `tests/smoke/ask-no-clone.test.sh` — the no-clone invariant assertion
   is preserved; any setup or assertion that depended on the old trace
   flow is updated so the test still exercises the no-clone property
   under the new skill shape.
5. All four smoke tests pass under
   `timeout 600 bash tests/smoke/<file>.test.sh` against a clean test
   repo created by the harness each test already uses.
6. **No surviving reference** in any test file under `tests/` to
   `query-trace.md`, `query-traces/`, or `wm_query_trace_path`.
7. **Vacuous-green assertions are forbidden** — every replaced assertion
   tests a real new property or is deleted; no `grep -q '<string that
   does not exist>'` no-ops.

## Scope

- Edit `tests/smoke/sprint-2.test.sh`.
- Edit `tests/smoke/sprint-5.test.sh`.
- Edit `tests/smoke/folder-isolation.test.sh`.
- Edit `tests/smoke/ask-no-clone.test.sh`.

## Anti-scope

- Adding new test files. Coverage for the source-agnostic-call path is
  added inside `sprint-2.test.sh` (where `/yoke:ask` shape is asserted),
  not in a new file.
- Wiring `tests/` into CI (Sprint 8).
- Changes to the smoke-test harness, the `timeout 600` discipline, or
  the test-repo bootstrap helpers.
- Changes to `tests/smoke/sprint-1.test.sh`, `sprint-3.test.sh`,
  `sprint-4.test.sh`, or `teach-ingest.test.sh`. Pre-edit verification:
  none of these reference query-trace; if grep finds a hit, fold it
  into this part's scope.

## Technical Decisions

1. **Update in place vs replace.** Edit each test file in place rather
   than rewriting from scratch. Trade-off: heavier review than a clean
   rewrite. Justification: preserves the rest of each test's coverage
   and isolates the diff to trace-related assertions.
2. **Failure window.** Tests are guaranteed to be inconsistent with the
   skill between merging Part 1 and merging Part 3. Implementation
   sequence must land Parts 1, 2, 3 close together; ideally as a single
   PR series with a held merge until Part 3 is reviewed.
3. **No bypass-detection assertion.** Bypass discipline is declarative
   in v0 (Part 2). There is nothing automated to assert. A future spec
   that adds a sensor will own its own assertion.
4. **Migration assertion removal.** `folder-isolation.test.sh` currently
   asserts that the singular `.yoke/query-trace.md` migration is
   complete. Both the singular and plural forms cease to be live; the
   migration check goes with them.

## Applicable Patterns

- `.vibeflow/patterns/sensors.md` — structured output convention; "every
  sprint adds `tests/smoke/sprint-N.test.sh`" discipline.
- `.vibeflow/patterns/plugin-structure.md` — tests/ layout.

## Risks

- **R1 / Vacuous-green assertion.** A removed assertion is replaced with
  a `grep` for a string that doesn't exist anyway. Mitigation: DoD #7
  forbids it; reviewer scans every replaced assertion.
- **R2 / Removed assertion takes a real safety property with it.**
  Mitigation: enumerate every removed assertion in the PR description;
  reviewer maps each removal to either Part 1's DoD #4 invariants
  (preserved) or the trace contract (intentionally removed).
- **R3 / Test fails on macOS bash 3.** Mitigation: `.vibeflow/conventions.md`
  pins bash 4+; ensure tests use bash 4 features only where the existing
  tests already do.
- **R4 / `timeout 600` bound is exceeded by the new flow.** Mitigation:
  the new flow does fewer disk writes than the old; runtime should
  shrink, not grow. If it grows unexpectedly, profile before relaxing
  the bound.

## Dependencies

- `.vibeflow/specs/ask-source-agnostic-read-part-1.md`
- `.vibeflow/specs/ask-source-agnostic-read-part-2.md`
