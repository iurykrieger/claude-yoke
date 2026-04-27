# Spec: Yoke v1 — Sprint 7 — Phase 6 drift sensing

> Generated via /vibeflow:gen-spec on 2026-04-24
> PRD: `.vibeflow/prds/yoke-v1.md`
> Plugin version target: 0.7.0

## Objective

Ship continuous drift sensing across the codebase, the canonical
memory, and historical traces. `/yoke:drift-sense` runs manually or via
a scheduled GitHub Actions workflow, producing structured findings
that feed Orchestrator deprecation propositions through Model C.

## Context

Phase 6 makes Yoke a living system rather than a per-task framework
(manifesto §8.6). Per the PRD's recommendation, GitHub Actions is the
chosen scheduling surface. Local cron and daemon backends are
documented as future fallbacks but not implemented in v1.0.

## Definition of Done

1. `/yoke:drift-sense --target codebase` runs a configured tool
   (default: language-appropriate dead-code detector discovered from
   the host `CLAUDE.md`) and returns structured findings per
   `patterns/sensors.md`.
2. `/yoke:drift-sense --target canonical-memory` detects items not
   consulted for > N days, items calibrated against a different model
   than the current one, and items with `contradicts_with` referring to
   present items.
3. `/yoke:drift-sense --target traces` analyzes historical
   `.yoke/contracts.md` and `.yoke/query-trace.md` for patterns that
   recurred but never reached canonization.
4. `.github/workflows/yoke-drift-sense.yml` runs daily; output becomes a
   GitHub issue (or PR) in the project repo. Workflow is idempotent and
   safe to interrupt.
5. `docs/scheduling-strategy.md` records the GitHub Actions decision and
   notes the local-cron / daemon fallbacks, including the credentials
   walkthrough for Actions.
6. `tests/smoke/sprint-7.test.sh` injects a synthetic stale
   canonical-memory item and synthetic dead code; both are detected.
7. **Craftsmanship gate:** false-positive rate < 20 % on the
   synthetic-injection test; findings are structured (not loose prose);
   no `conventions.md` Don'ts violated.

## Scope

- Real `skills/drift-sense/SKILL.md` — three modes
  (`codebase` / `canonical-memory` / `traces`).
- `lib/canonical-memory/staleness-check.sh`.
- Trace-analyzer script (placement TBD — `lib/canonical-memory/` or
  dedicated `lib/drift/`).
- `.github/workflows/yoke-drift-sense.yml`.
- `docs/scheduling-strategy.md` — decision, walkthrough, fallback notes
  (PRD Open Question 6).
- `tests/smoke/sprint-7.test.sh` with synthetic injections.

## Anti-scope

- Local cron / daemon backends — documented as fallback only, not
  implemented.
- Adversarial canonical-memory audit — out of v1.0 (planned extension
  §17).
- Production-signal observation (logs, SLOs, post-deploy) — out of v1.0.
- ML-based pattern detection — heuristic only.
- Auto-merging of drift-sense propositions — they go through Model C
  like any other; deprecation propositions are typically medium-impact.

## Technical Decisions

- **Codebase mode delegates** to language-appropriate detectors
  discovered from `CLAUDE.md` (extends Sprint-3 sensor discovery).
  Trade-off: relies on the host project to declare a dead-code tool;
  fallback is a clear "no detector configured" message.
- **Canonical-memory mode reads frontmatter directly.** No LLM judgment
  for staleness — pure metadata math. Trade-off: misses semantic
  obsolescence; rippability heuristics handle most cases.
- **Trace mode analyzes only completed tasks.** Working memory of
  open tasks is excluded — they are still in flight. Completed = merged
  to main of the host project (configurable).
- **Workflow output as GitHub issue, not PR.** Trade-off: issues are
  cheaper to ignore (low-friction noise channel) vs. PRs imply intent;
  drift-sense findings are signals, not actions.
- **Drift-sense propositions go through Model C.** Deprecation
  propositions are typically medium-impact (veto window). Trade-off:
  slows deprecation but matches the rest of the governance shape.

## Applicable Patterns

- `phase-flow.md` — Phase 6 (out-of-lifecycle).
- `model-c-governance.md` — deprecation propositions follow the same
  PR / impact path as new entries.
- `sensors.md` — structured findings; calibration metadata for any
  inferential checks.
- `memory-model.md` — frontmatter metadata is the staleness source of
  truth.

No new patterns introduced.

## Risks

- **False positives.** DoD #7 caps them at < 20 % on the synthetic
  test. **Mitigation:** if exceeded, tighten heuristics before declaring
  done; document known false-positive shapes in
  `docs/scheduling-strategy.md`.
- **GitHub Actions credentials UX.** First-time setup is multi-step.
  **Mitigation:** explicit walkthrough in docs; one external reviewer
  tests the setup before DoD.
- **PRD Open Question 6 — non-GitHub fallback.** Documented but not
  implemented. Some users will need it. **Mitigation:** flag explicitly
  in docs; v1.1 work.
- **Risk of drowning the issue tracker.** Daily runs producing noisy
  findings may train users to ignore them. **Mitigation:** rate-limit
  the workflow (only open new issues if findings changed since the last
  run); spec adds this as part of DoD #4 idempotency.

## Dependencies

- `.vibeflow/specs/yoke-v1-sprint-6.md`
