# Audit Report: runtime-only-agents-part-2 (skill rewrites: spec phases + ask)

> Audited via /vibeflow:audit on 2026-04-25
> Spec: `.vibeflow/specs/runtime-only-agents-part-2.md`

**Verdict: PASS**

## DoD Checklist

- [x] **#1** — `skills/discover/SKILL.md`, `skills/tech-spec/SKILL.md`,
  `skills/acceptance-contract/SKILL.md` each have `allowed-tools`
  excluding `Task` and embed persona inline. Evidence:
  `allowed-tools: Read, Write, Edit, Grep, Glob, Bash` across all
  three; `grep -c "Spawn .agents/|Invoke the Generator subagent|
  Invoke the Validator subagent|via the Task tool"` = 0; persona
  blocks present (3 references in discover, 3 in tech-spec, 2 in
  acceptance-contract).
- [x] **#2** — Yoke-specific framework elements preserved. Evidence:
  Trigger-1 prompt verbatim in discover (`Trigger 1 — PRD approval`,
  2 hits); Trigger-2 in tech-spec (2 hits); Trigger-3 binding
  statement in acceptance-contract (1 hit, multi-line); `/yoke:ask`
  routing referenced 5x in discover, 3x in tech-spec, 3x in
  acceptance-contract; sensor discovery (`lib/sensors/
  discover-from-claude-md.sh`) preserved in
  acceptance-contract (2 hits).
- [x] **#3** — `skills/ask/SKILL.md` is a thin direct-call skill.
  Evidence: `allowed-tools: Bash, Read, Write` (no Task);
  `lib/canonical-memory/query.sh` and `.yoke/query-trace.md`
  referenced 9 times; lineage note retires "Orchestrator skill in
  mediator mode" concept.
- [x] **#4** — Structural shape mirrors Vibeflow's discover/gen-spec.
  Evidence: each skill retains Process / Pre-conditions / Output
  contract / Anti-patterns / See also sections (Vibeflow's standard
  shape) layered with Yoke-specific elements (Triggers, `.yoke/`
  paths, Acceptance Contract artifact).
- [x] **#5 (craftsmanship)** — Conventions Don'ts upheld:
  - "No direct canonical-memory reads outside `/yoke:ask`" — every
    spec-phase skill routes reads through `/yoke:ask`.
  - "Structured sensor output" — `acceptance-contract.md`'s "every
    scenario must be decidable by a fixture or sensor" rule
    preserved.
  - "Skills don't silently advance past unmet triggers" — each
    skill explicitly states "skill does not return until the user
    responds explicitly".
  - "Generator must challenge at least one point" — preserved in
    discover skill anti-patterns.

## Pattern Compliance

- [x] **`patterns/phase-flow.md`** — Phase 1, 2, 3 boundaries
  preserved with explicit gates; each skill aborts on
  missing/unapproved upstream artifact.
- [x] **`patterns/human-triggers.md`** — Trigger 1/2/3 schemas
  preserved verbatim with binding language.
- [x] **`patterns/acceptance-contract.md`** — BDD scenarios + fixtures
  + sensors + binding statement structure preserved in
  acceptance-contract skill.
- [x] **`patterns/sensors.md`** — sensor discovery + structured-output
  expectations preserved.
- [x] **`patterns/memory-model.md`** — `/yoke:ask` is the sole
  canonical-memory read surface from Phases 1–3.
- [x] **`patterns/roles.md`** — declared authorities consistent with
  the post-rewrite roles pattern.

## Convention Violations
None.

## Tests

`tests/smoke/sprint-2.test.sh` and `sprint-3.test.sh` (which include
Part 6's no-Task assertions for spec-phase skills) PASS in chained
regression via `tests/smoke/sprint-5.test.sh`.

## Gaps
None.

## Notes
- Risk R-B1 (inline persona bloat) — final skill files are within
  Vibeflow's lean style; persona blocks are rules + format only,
  no LinkedIn-style bios.
- Risk R-B2 (bypass-detection contract weakens without mediator
  subagent) — resolved by `/yoke:ask` writing its own trace; bypass
  detection still works via trace absence.
- Risk R-B3 (multi-round dialogue persona consistency) — Vibeflow's
  pattern is the reference; works because the skill prompt is
  re-read each turn.
