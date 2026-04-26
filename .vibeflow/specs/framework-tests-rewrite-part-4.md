# Spec: Framework tests rewrite — Part 4 (runtime tests)

> Generated via /vibeflow:gen-spec on 2026-04-25 from
> .vibeflow/prds/framework-tests-rewrite.md

## Objective

Add concept-shaped tests for `/yoke:bootstrap`, sensor discovery +
acceptance verification, and ralph-loop hard bounds.

## Context

Bootstrap behavior is partially asserted in
`tests/smoke/sprint-1.test.sh`-style files; sensor discovery and
ralph-loop hard bounds are scattered across `sprint-{6,7,8}` smokes.
This part collapses them into three concept files.

Patterns governing this part:
- `patterns/sensors.md` — structured-output requirement;
  shift-feedback-left.
- `patterns/ralph-loop.md` — hard bounds (N cycles / timeout /
  budget); Trigger 4 escalation.
- `conventions.md` Don'ts — "ralph loops without hard bounds";
  "generic sensor output".

## Definition of Done

1. `tests/bootstrap.test.sh` simulates `/yoke:bootstrap`'s file
   effects in a `mktemp -d` clean repo (with `git init` + minimal
   `git config`). It asserts: (a) `.yoke/config.yaml`,
   `.yoke/.gitignore` (content exactly `.current\nruntime/`) are
   created; (b) the host repo's git working tree shows the new
   `.yoke/` files but no auto-commit was made; (c)
   `skills/bootstrap/SKILL.md` declares the canonical-memory
   registration step (refs `registry.sh add` or equivalent) and the
   no-pollute-host-repo invariant.
2. `tests/acceptance-and-sensors.test.sh` runs
   `lib/sensors/discover-from-claude-md.sh` against
   `examples/greenfield-payment-service/CLAUDE.md` and asserts ≥2
   sensors with `category: testing` are emitted; runs
   `hooks/verify-acceptance.sh` against
   `examples/greenfield-payment-service/.yoke/acceptance-contract.md`
   and asserts the hook produces structured output (not generic
   `tests failed`) and an exit code consistent with its declared
   contract.
3. `tests/ralph-loop-bounds.test.sh` asserts: (a)
   `hooks/check-hard-bounds.sh` is executable; (b) given a synthetic
   `.yoke/runtime/` state in `mktemp -d` with cycle count exceeding
   the bound, the hook exits non-zero; (c) the exit-output contains
   structured "bound reached" identification (sensor format, not
   generic); (d) `lib/ralph-loop/escalate.sh` exists and references
   Trigger 4.
4. `bash tests/bootstrap.test.sh`,
   `bash tests/acceptance-and-sensors.test.sh`,
   `bash tests/ralph-loop-bounds.test.sh` each exit 0 against HEAD.
5. **Craftsmanship gate.**
   `grep -EIn 'sprint-[0-9]|Sprint [0-9]|Part [0-9]|v[0-9]+\.[0-9]+'
   tests/bootstrap.test.sh tests/acceptance-and-sensors.test.sh
   tests/ralph-loop-bounds.test.sh` returns nothing.
6. All three files pass `bash -n` and (if available) `shellcheck`.

## Scope

- Create `tests/bootstrap.test.sh`.
- Create `tests/acceptance-and-sensors.test.sh`.
- Create `tests/ralph-loop-bounds.test.sh`.
- Each sources `tests/lib/harness.sh` and calls `harness::summary`.
- Each isolates with `mktemp -d` + `trap` cleanup.

## Anti-scope

- **No actual ralph-loop execution.** Implementation/Validation
  subagents are not invoked.
- **No new fixture files.** Reuse `examples/greenfield-payment-service/`
  as the fixture for sensor + acceptance-contract checks.
- **No real progressive-disclosure query** against canonical memory.
- **No CI changes** (Part 6).

## Technical Decisions

- **Reuse `examples/greenfield-payment-service/` as fixture.** Keeps
  file count at 3 (under budget). Couples Part 4 to Part 5's example
  invariants — acceptable, since Part 5 owns the example's shape and
  any change there is deliberate.
- **`bootstrap.test.sh` simulates skill side-effects, not the skill
  itself.** Skills are markdown; their executable surface is the
  `lib/canonical-memory/registry.sh add` and `lib/working-memory/paths.sh`
  helpers. The test exercises those directly with `git init` +
  inputs that the SKILL prose specifies.
- **`hooks/check-hard-bounds.sh` interface is inspected at write
  time.** The hook's input contract (env vars, flags, file paths)
  drives the test; first action of the implementer is to read the
  hook to lock in the contract.
- **Structured-output assertion is regex-based.** Look for
  `category:|sensor:|location:|fix_instruction:` (sensor schema
  fields) — generic strings like "tests failed" should NOT appear.

## Applicable Patterns

- `patterns/sensors.md` — structured-output schema fields.
- `patterns/ralph-loop.md` — hard bounds and Trigger 4 escalation.
- `patterns/plugin-structure.md` — `hooks/` and `lib/sensors/`
  locations.
- `conventions.md` Don'ts — "ralph loops without configured hard
  bounds (N cycles, timeout, budget)"; "generic sensor output".

## Risks

- **Coupling to `examples/greenfield-payment-service/`.** If that
  example's `CLAUDE.md` loses testing sensors, Part 4 fails alongside
  Part 5. Acceptable: the example is itself a framework invariant.
- **`hooks/check-hard-bounds.sh` interface assumption.** This spec
  assumes the hook reads cycle state from a known location. The
  implementer reads the hook source first and pins to its actual
  interface; this part flags the assumption rather than guessing
  it.
- **`verify-acceptance.sh` may exit non-zero on a contract that
  declares unmet criteria.** The example's contract is `Status:
  ratified`. If the hook treats unmet criteria at fixture time as a
  failure rather than a structured report, the test must invoke it
  in a "report-only" mode. Implementer inspects the hook to choose
  the right invocation.

## Dependencies

- `.vibeflow/specs/framework-tests-rewrite-part-1.md`
