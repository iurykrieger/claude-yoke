# Spec: Tech Spec Task Split — Cleanup Part 2 — Other spec-phase skills

> Generated via /vibeflow:gen-spec on 2026-04-25
> PRD: `.vibeflow/prds/tech-spec-task-split.md`
> Plugin version target: 0.7.0 (working-memory rev — final cleanup)

## Objective

Migrate the four other spec-phase skills (`/yoke:implement`,
`/yoke:bootstrap`, `/yoke:discover`, `/yoke:status`) off the
deprecated `wm_tech_spec_path` / `.yoke/tech-specs/<slug>.md`
references onto Part 1's `wm_spec_path` / `.yoke/specs/<slug>.md`
shape and (where the prose discusses iteration) the new
`.yoke/tasks/<slug>-s*-t*.md` archive.

## Context

These four skills carry references that range from runtime helper
calls (`/yoke:implement` actually calls `wm_tech_spec_path`) to
prose mentions in archive listings (`/yoke:bootstrap`,
`/yoke:status`) and task-isolation guidance (`/yoke:discover`).

`/yoke:tech-spec` and `/yoke:acceptance-contract` were migrated by
Parts 2 and 3 of the original PRD. Cleanup Parts 1 (runtime helper +
subagents) and 2 (this spec) are independent of each other; both
must merge before Cleanup Part 3 (alias removal in `paths.sh`).

## Definition of Done

1. `skills/implement/SKILL.md` — `wm_tech_spec_path` (lines 42 and
   69) replaced with `wm_spec_path`; `.yoke/tech-specs/<slug>.md`
   (line 200) replaced with `.yoke/specs/<slug>.md`. The skill's
   pre-condition list and read-authority documentation reflect the
   new layout.
2. `skills/bootstrap/SKILL.md` — `tech-specs/` mention at line 120
   replaced with `specs/` (and adjacent prose extended to mention
   the new `tasks/` archive). Rationale block describing per-category
   versioning preserved verbatim except for the archive list.
3. `skills/discover/SKILL.md` — `tech-specs/` mentions at lines 194
   and 244 replaced with `specs/` (and the "other task's archive
   files" guidance extended to include `tasks/<other>-s*-t*.md`).
   Task-isolation contract (no cross-task writes) preserved.
4. `skills/status/SKILL.md` — `tech-specs/<slug>.md` mention at
   line 62 replaced with `specs/<slug>.md`. The Phase-2 phase label
   in the status output (if present) updates to reflect the new
   archive name.
5. **Craftsmanship gate.** All four files preserve their existing
   frontmatter (`name`, `description`, `argument-hint`,
   `allowed-tools`); none add `Task` to `allowed-tools` (skill-only
   contract preserved per the 2026-04-25 runtime-only-agents
   decision); the Generator persona inline guidance (where
   applicable) stays put.
6. The full smoke suite still PASS after this part lands. In
   particular `tests/smoke/sprint-2.test.sh` (which checks
   `/yoke:discover` Trigger-1 binding prompt and the
   skill-archive list) and any sprint-N test that touches the
   migrated skills pass without modification.

## Scope

- `skills/implement/SKILL.md` (modify) — three references swapped.
- `skills/bootstrap/SKILL.md` (modify) — one rationale-block line
  swapped + adjacent prose.
- `skills/discover/SKILL.md` (modify) — two task-isolation
  references swapped.
- `skills/status/SKILL.md` (modify) — one phase-listing line
  swapped.

## Anti-scope

- No `lib/working-memory/paths.sh` changes — the alias removal is
  Cleanup Part 3.
- No runtime helper / subagent changes — those are Cleanup Part 1.
- No test changes (smoke tests touched only as regression net) —
  the two affected smoke tests migrate in Cleanup Part 3.
- No behavioral changes. No new fields, no new args, no new flags.
  Pure reference migration.
- No `wm_tech_spec_path` removal — alias must stay callable until
  Cleanup Part 3 lands; do not anticipate Part 3 here.

## Technical Decisions

- **Conservative-edit strategy.** Each migration is a literal
  string replacement plus surrounding prose adjustment where the
  paragraph mentions "and the other archive folders". Skills with
  per-category descriptions (especially `bootstrap` and
  `discover`) get one-line additions for the new `tasks/` category;
  no prose rewrites.
- **No skill semantics changes.** `/yoke:implement` does not change
  what it iterates (still tasks); only the path resolution shifts
  from a single tech-spec file to spec + tasks files. The
  description and process still call this artifact "the Tech Spec"
  in prose since that is the colloquial label.

## Applicable Patterns

- `.vibeflow/patterns/memory-model.md` — working-memory archive
  layout consumers; per-skill read-authority entries shift to the
  new categories.
- `.vibeflow/patterns/phase-flow.md` — Phase 2/3/4 boundaries
  unchanged; only the on-disk path consumed by Phase 4 changes.

No new pattern introduced.

## Risks

- **Adjacent prose drift.** Bootstrap and discover skills include
  rationale prose explaining why archives are versioned. Replacing
  `tech-specs/` with `specs/` mid-sentence can read awkwardly.
  **Mitigation:** include a one-line addition for the new `tasks/`
  category alongside the rename, so the prose remains coherent.
- **Sprint-2 smoke false negative on `/yoke:discover`.** Sprint-2
  smoke greps for specific markers in `discover/SKILL.md`; check
  the existing assertions don't depend on the literal string
  `tech-specs/`. **Mitigation:** run the full suite after each edit;
  fix any false negatives with the same option-B style spec
  softening if surfaced.

## Dependencies

None. (Cleanup Parts 1 and 2 are independent and can land in either
order; Part 3 depends on both.)
