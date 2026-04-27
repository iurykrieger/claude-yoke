# Spec: Move `.yoke/.current` into `.yoke/runtime/` — Part 2 (doc alignment)

> Generated via /vibeflow:gen-spec on 2026-04-27. Pure prose alignment
> across five skill SKILL.md files; ships after Part 1 lands.

## Dependencies

- `.vibeflow/specs/current-into-runtime-part-1.md` — must be
  implemented and audited PASS before Part 2 begins. Part 1
  changes the actual path; Part 2 just updates docs to match.

## Objective

Replace every prose reference to `.yoke/.current` with
`.yoke/runtime/.current` across the five skill SKILL.md files that
mention the active-task pointer, so docs stay accurate to the code
that landed in Part 1.

## Context

After Part 1 lands, `.current` lives at `.yoke/runtime/.current`,
but five skill SKILL.md files still say `.yoke/.current` in their
prose:

- `skills/discover/SKILL.md` — 4 references (`grep` 2026-04-27).
- `skills/status/SKILL.md` — 2 references.
- `skills/tech-spec/SKILL.md` — 2 references.
- `skills/acceptance-contract/SKILL.md` — 3 references.
- `skills/implement/SKILL.md` — 3 references.

Each is in user-facing prose: pre-conditions sections, "what this
skill writes" headers, error messages embedded in command examples.
Stale prose misleads users (`/yoke:status` won't find `.yoke/.current`
on a freshly-cleaned project) and conflicts with the canonical layout
doc in `lib/working-memory/paths.sh`.

The change is doc-only — no code path is exercised, no test
fixture is touched. Tests already pass after Part 1; Part 2 is
about user-facing accuracy.

## Definition of Done

1. `skills/discover/SKILL.md` has zero occurrences of the literal
   `.yoke/.current`; every reference reads `.yoke/runtime/.current`.
2. `skills/status/SKILL.md` has zero occurrences of `.yoke/.current`.
3. `skills/tech-spec/SKILL.md` has zero occurrences of `.yoke/.current`.
4. `skills/acceptance-contract/SKILL.md` has zero occurrences of
   `.yoke/.current`.
5. `skills/implement/SKILL.md` has zero occurrences of `.yoke/.current`.
6. **(craftsmanship)** A repo-wide grep
   `grep -rn '\.yoke/\.current' .` returns only matches inside
   `.vibeflow/audits/`, `.vibeflow/decisions.md`, or `.vibeflow/specs/`
   (historical references in audit/decision/spec records, which
   are immutable history and should NOT be edited). Zero matches
   in `lib/`, `hooks/`, `skills/`, `agents/`, `tests/`, `templates/`,
   `docs/`, or other live surfaces.

## Scope

- `skills/discover/SKILL.md` — replace each of the 4 prose
  references found at lines 7, 146, 194, 205, 232 (line numbers
  approximate; use grep at implement time). Pre-condition lists,
  "writes" sections, "continue active task" branch description.
- `skills/status/SKILL.md` — replace at lines ~52 and ~206.
- `skills/tech-spec/SKILL.md` — replace at lines ~84 and ~325.
- `skills/acceptance-contract/SKILL.md` — replace at lines ~9, ~54,
  ~214.
- `skills/implement/SKILL.md` — replace at lines ~38, ~51, ~355.

Each replacement is `.yoke/.current` → `.yoke/runtime/.current`. No
restructuring, no rewording, no examples added.

## Anti-scope

- **No edits outside the five skill SKILL.md files.** All other
  occurrences (`lib/`, `hooks/`, `tests/`, `templates/`,
  `skills/bootstrap/SKILL.md`) were handled in Part 1.
- **No prose reflow / restructuring.** Find-and-replace only.
- **No edits to historical records** (`.vibeflow/audits/*`,
  `.vibeflow/decisions.md`, `.vibeflow/specs/*`). Those are
  immutable audit trails.
- **No new examples or callouts** about the new path.
- **No README / docs/ updates.** Those mention `.yoke/` at a higher
  level; the `.yoke/.current` literal does not appear in them per
  the gen-spec grep.

## Technical Decisions

### 1. Find-and-replace, not rewrite

The five files have established voice and structure. A pure literal
substitution preserves the surrounding sentences and section flow.
Rewriting would introduce review surface for no gain.

### 2. Skip historical records

`.vibeflow/audits/`, `.vibeflow/decisions.md`, `.vibeflow/specs/*`,
and `.vibeflow/prds/*` mention `.yoke/.current` in records that
were accurate at the time they were written. Mutating them
rewrites history. Future audit/decision/spec records will use the
new path naturally.

### 3. Verification by grep, not by re-running smoke

Part 2 ships no executable behavior. The DoD #6 craftsmanship
gate is "grep returns zero hits in live surfaces" — that is the
verification. No smoke needed.

## Applicable Patterns

- **`patterns/plugin-structure.md`** — repo layout discipline.
  Doc-prose accuracy follows the same hygiene as the layout-doc
  comment block updated in Part 1.
- **conventions.md "Lineage is documented honestly"** — accurate
  references to working-memory paths are part of honest
  documentation.

## Risks

- **R1 — Hidden references in code blocks within SKILL.md.** The
  five files contain code-fenced examples that may use
  `.yoke/.current`. Replacement should also touch code-fenced
  literals (those are user-facing instructions). Mitigation: the
  grep used in DoD #6 is content-agnostic; it catches both prose
  and code-fenced occurrences.
- **R2 — Replacement breaks markdown formatting.** Unlikely — the
  literal is a path, surrounded by backticks in every observed
  occurrence. Mitigation: visual scan of each touched line during
  implement.
- **R3 — Drift between Part 1 ship and Part 2 ship.** If Part 2
  doesn't ship promptly after Part 1, users hit doc/code drift.
  Mitigation: ship Parts 1 and 2 in adjacent PRs (sequenced by the
  Dependencies field above).

## Files touched (≤ 5)

1. `skills/discover/SKILL.md`
2. `skills/status/SKILL.md`
3. `skills/tech-spec/SKILL.md`
4. `skills/acceptance-contract/SKILL.md`
5. `skills/implement/SKILL.md`
