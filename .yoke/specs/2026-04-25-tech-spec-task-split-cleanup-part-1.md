# Spec: Tech Spec Task Split — Cleanup Part 1 — Runtime helper + subagents

> Generated via /vibeflow:gen-spec on 2026-04-25
> PRD: `.vibeflow/prds/tech-spec-task-split.md`
> Plugin version target: 0.7.0 (working-memory rev — final cleanup)

## Objective

Migrate the runtime ralph-loop helper and the three runtime subagent
prompt files off the deprecated `wm_tech_spec_path` /
`.yoke/tech-specs/<slug>.md` references onto Part 1's
`wm_spec_path` / `.yoke/specs/<slug>.md` shape.

## Context

Part 1 of `tech-spec-task-split` retained `wm_tech_spec_path` as a
deprecated soft alias and listed every consumer call site in the
DEPRECATED block at `lib/working-memory/paths.sh:99-115`. Parts 2
and 3 migrated `skills/tech-spec/SKILL.md` and
`skills/acceptance-contract/SKILL.md` respectively.

This cleanup part migrates the runtime layer:
`lib/ralph-loop/orchestrate.sh` (Phase 4 helper that pre-flights the
spec into Generator subagent context) and the three runtime
subagent prompts (`agents/generator.md`,
`agents/validator.md`, `agents/orchestrator.md`) that reference the
spec path in their persona prompts.

Cleanup Parts 1, 2, and 3 are sequenced: this part and Part 2
(other spec-phase skills) are independent of each other. Part 3
removes the alias from `paths.sh` and is therefore strictly
dependent on Parts 1 and 2.

## Definition of Done

1. `lib/ralph-loop/orchestrate.sh:68` no longer calls
   `wm_tech_spec_path`. The replacement uses `wm_spec_path "$slug"`,
   maintaining the existing variable name (`tech`) for source-diff
   minimality OR renaming to `spec` if the surrounding code is
   already idiomatic — pick whichever requires no behavioral change.
2. `agents/generator.md` no longer references `wm_tech_spec_path`,
   `.yoke/tech-specs/<slug>.md`, or `tech-specs/`. Persona prompt
   reads from `.yoke/specs/<slug>.md` and (where the description
   talks about iterating tasks) `.yoke/tasks/<slug>-s*-t*.md` per
   the new layout introduced by Parts 2/3.
3. `agents/validator.md` no longer references `wm_tech_spec_path`,
   `.yoke/tech-specs/<slug>.md`, or `tech-specs/`. Persona prompt
   reads from `.yoke/specs/<slug>.md` plus `.yoke/tasks/<slug>-s*-t*.md`.
4. `agents/orchestrator.md` no longer references
   `wm_tech_spec_path`, `.yoke/tech-specs/<slug>.md`, or
   `tech-specs/`. Both the consult-mode read list and the canonize
   write-restriction list reference the new `specs/` and `tasks/`
   archive shape.
5. **Craftsmanship gate.** All four files conform to
   `.vibeflow/conventions.md`; bash files target bash 4+ and remain
   syntactically valid; subagent files preserve their existing
   frontmatter and persona shape; the 2026-04-25 runtime-only-agents
   decision (three subagents only — Generator, Validator,
   Orchestrator) is honored.
6. `tests/smoke/sprint-2.test.sh` (and every smoke test that does
   not assert against the legacy `tech-specs` content shape) still
   PASS after this part lands. Smoke tests that assert literally
   against the legacy content shape (`sprint-4.test.sh:54-58` —
   `Never modify.*prds.*tech-specs.*acceptance-contracts` regex —
   plus the `sprint-5/6/7/8` cascading regression checks that
   verify Sprint-4 still passes) will FAIL in the in-flight state
   and are migrated by Cleanup Part 3. This is the expected
   stacked-merge state — mitigated the same way the original PRD's
   Risk #1 was, and tracked under
   `.vibeflow/decisions.md` 2026-04-25 entry "wm_tech_spec_path
   retained as deprecated soft alias". The deprecated alias
   remains in place (Part 3 territory) so cross-cutting consumers
   stay green; only assertions that bake the literal token
   `tech-specs` into a regex regress until Part 3 lands.

## Scope

- `lib/ralph-loop/orchestrate.sh` (modify) — single line at :68
  swapped from `wm_tech_spec_path` to `wm_spec_path`. No other
  behavioral changes.
- `agents/generator.md` (modify) — references at lines 15, 55, 79,
  97 swapped to the new layout. Persona shape preserved.
- `agents/validator.md` (modify) — references at lines 69, 88
  swapped to the new layout.
- `agents/orchestrator.md` (modify) — references at lines 148, 159
  swapped to the new layout.

## Anti-scope

- No `lib/working-memory/paths.sh` changes — the alias removal is
  Cleanup Part 3.
- No spec-phase skill changes — those are Cleanup Part 2.
- No test changes (smoke tests touched only as regression net,
  not modified) — `folder-isolation.test.sh` and `sprint-4.test.sh`
  migrate in Cleanup Part 3.
- No new behavior, no new fields, no schema changes — pure
  reference migration.
- No changes to the runtime subagent functional contract (Generator
  iterates tasks; Validator runs sensors; Orchestrator coordinates +
  canonizes) — only the spec-path references change.

## Technical Decisions

- **Source-diff minimality.** Where the existing code uses a local
  variable `tech` to hold the spec path, keep the variable name; the
  semantic referent shifts (now points at `.yoke/specs/<slug>.md`
  instead of `.yoke/tech-specs/<slug>.md`) but the surrounding logic
  doesn't care. Trade-off: variable name `tech` is now slightly
  stale wrt the new shape. Win: minimal diff, no cascading rename.
- **Subagent prompt updates preserve persona language.** The agent
  files refer to "the Tech Spec" in prose — that *human-facing*
  label stays (the artifact is colloquially still "the tech spec"
  even though the file lives at `.yoke/specs/`). Only the *path
  string* and the *helper name* change.
- **No path-helper inlining.** The orchestrate.sh script keeps
  sourcing `paths.sh` and calling helpers; do not inline path
  construction.

## Applicable Patterns

- `.vibeflow/patterns/memory-model.md` — working-memory archive
  layout (consumers reading the spec follow the per-file
  read-authority table).
- `.vibeflow/patterns/roles.md` — runtime subagent definitions
  (read-authority for spec / task files unchanged in semantics).
- `.vibeflow/patterns/ralph-loop.md` — Phase 4 runtime, Generator
  iterates over the spec.

No new pattern introduced.

## Risks

- **Stale variable names** in `orchestrate.sh` (`tech` no longer
  semantically tracks `tech-specs/`). **Mitigation:** documented as
  a Technical Decision; rename can ride along with a future Phase 4
  refactor.
- **Subagent prompt drift** if persona prose was load-bearing on
  the legacy path string. **Mitigation:** the references are pure
  read-authority statements ("Generator reads `.yoke/tech-specs/<slug>.md`")
  — direct path replacement preserves semantics. Prompt-diff against
  the pre-cleanup version is the regression check.

## Dependencies

None. (Cleanup Parts 1 and 2 are independent and can land in either
order; Part 3 depends on both.)
