# Spec: Yoke v1 — Sprint 3 — Acceptance Contract (Phase 3)

> Generated via /vibeflow:gen-spec on 2026-04-24
> PRD: `.vibeflow/prds/yoke-v1.md`
> Plugin version target: 0.3.0

## Objective

Ship the binding Acceptance Contract artifact. The Validator subagent
exists; `/yoke:acceptance-contract` produces a ratified
`.yoke/acceptance-contract.md`; `verify-acceptance.sh` runs declared
sensors and emits structured pass/fail/skip output.

## Context

The Acceptance Contract is the manifesto's most distinctive
contribution — pre-runtime, binding, produced by an agent with an
adversarial objective vs the Generator (manifesto §8.3, §12). Sprint 3
ships the contract artifact and its verification mechanism, with
sensors discovered from the host project's `CLAUDE.md`. No runtime
loop yet — Sprint 4 spawns the agents that consume this contract.

## Definition of Done

1. `/yoke:acceptance-contract` (after PRD + Tech Spec approved) produces
   `.yoke/acceptance-contract.md` with one BDD scenario per Tech Spec
   task, fixtures referenced, FRs measurable, sensors listed, and an
   explicit binding statement.
2. The Validator subagent is distinct from the Generator — verifiable by
   prompt diff.
3. `lib/sensors/discover-from-claude-md.sh` extracts ≥3 sensor categories
   (testing / linting / build) from a representative host `CLAUDE.md`;
   falls back to asking the user when the file or the sections are absent.
4. `hooks/verify-acceptance.sh` consumes a well-formed Acceptance
   Contract and emits structured output (yaml/json) with status
   `pass` / `fail` / `skip` per criterion.
5. The skill aborts with a clear message if `.yoke/prd.md` or
   `.yoke/tech-spec.md` are missing or unapproved.
6. `tests/smoke/sprint-3.test.sh` extends the Sprint-2 smoke test with
   `/yoke:acceptance-contract`; produces a valid Contract;
   `verify-acceptance.sh` runs against it and emits structured output.
7. **Craftsmanship gate:** the Validator never modifies PRD or Tech
   Spec; sensors emit structured output (per `patterns/sensors.md`); no
   `conventions.md` Don'ts violated.

## Scope

- `agents/validator.md` — full subagent definition per `patterns/roles.md`
  (memory scope = `project`; reads PRD + Tech Spec; writes
  `.yoke/acceptance-contract.md` and (later) `.yoke/contracts.md`).
- Real `skills/acceptance-contract/SKILL.md`.
- `lib/sensors/discover-from-claude-md.sh` — parses host `CLAUDE.md` for
  marked sections and emits structured sensor list.
- `hooks/verify-acceptance.sh` — basic version, shell-command sensors only.
- `templates/acceptance-contract.md` — with binding-statement section.
- Convention doc: how to format `CLAUDE.md` so Yoke parses sensor
  sections, with worked example in `docs/canonical-memory-setup.md`.
- `tests/smoke/sprint-3.test.sh`.

## Anti-scope

- Inferential sensors with calibration metadata — Sprint 5+ (PRD Open
  Question 3).
- Structural fixtures and richer sensor types beyond shell commands —
  later sprints.
- Implementation Agent / runtime — Sprint 4.
- Smart policy lookup from canonical memory — basic `/yoke:ask` text
  grep is enough; smart lookup follows progressive disclosure in Sprint 6.
- Multi-language `CLAUDE.md` parsing — English only for v1.0.

## Technical Decisions

- **Sensor discovery via `CLAUDE.md`** with marked sections (`## Testing`,
  `## Linting`, `## Build`). Trade-off: heuristic and brittle. Mitigation:
  worked example in docs and explicit fallback to asking the user.
- **Validator pauses for Trigger 3** with the binding statement printed
  verbatim — the user must explicitly acknowledge they are ratifying a
  binding contract (per `patterns/human-triggers.md`).
- **`verify-acceptance.sh` v0** supports only "shell command" sensor
  type. Trade-off: limits expressiveness; richer types deferred.
- **`skip` vs `fail`:** sensors that cannot run (missing dependencies)
  report `skip`, not `fail` — preserves the agent's ability to act on
  real failures vs environment problems.

## Applicable Patterns

- `roles.md` — Validator definition.
- `acceptance-contract.md` — the artifact's required sections,
  generation contract, binding semantics.
- `sensors.md` — computational sensors; structured output requirement;
  inferential sensors deferred.
- `human-triggers.md` — Trigger 3 schema with binding statement.

No new patterns introduced.

## Risks

- **`CLAUDE.md` parsing brittleness.** Heuristic-based extraction can
  miss or misclassify sensors. **Mitigation:** worked example in docs;
  fallback to asking the user; structured-output validation in
  `verify-acceptance.sh` catches malformed sensor declarations.
- **Inferential calibration deferred to a later sprint.** Some valuable
  semantic checks won't be expressible until then. **Mitigation:** spec
  explicit that v0.3.0 ships shell-command sensors only; inferential
  via PRD Open Question 3.
- **Self-evaluation bias regression.** If Validator and Generator
  prompts share too much text, the adversarial separation collapses.
  **Mitigation:** prompt-diff DoD check; CI gate ships in Sprint 8.

## Dependencies

- `.vibeflow/specs/yoke-v1-sprint-2.md`
