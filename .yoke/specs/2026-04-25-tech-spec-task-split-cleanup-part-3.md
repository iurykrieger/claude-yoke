# Spec: Tech Spec Task Split — Cleanup Part 3 — Tests + alias removal + pattern doc

> Generated via /vibeflow:gen-spec on 2026-04-25
> PRD: `.vibeflow/prds/tech-spec-task-split.md`
> Plugin version target: 0.7.0 (working-memory rev — final cleanup)

## Objective

Migrate the two smoke tests still calling `wm_tech_spec_path` /
hard-coded `.yoke/tech-specs/` paths, **remove** the deprecated
alias and `tech-specs` archive category from
`lib/working-memory/paths.sh`, and update
`.vibeflow/patterns/memory-model.md`'s Implementation Mapping to
reflect the new on-disk layout.

This is the **load-bearing closing step** of the
`tech-spec-task-split` PRD: after this part lands, the PRD's
"no backward-compat shim" anti-scope is met in full.

## Context

Cleanup Parts 1 and 2 migrate every code consumer off the
deprecated `wm_tech_spec_path` alias. This part does the cleanup
proper: removes the alias from `paths.sh`, removes the `tech-specs`
category from `WM_ARCHIVE_CATEGORIES`, migrates the two smoke
tests that still hard-code the legacy paths, and updates the
pattern doc that documents the on-disk archive shape.

The user-facing migration path for any host project still on
`.yoke/tech-specs/<slug>.md` is `lib/working-memory/migrate-tech-specs.sh`
(landed in Part 3 of the original PRD). After Cleanup Part 3, host
projects with un-migrated `.yoke/tech-specs/` archives will see
`/yoke:tech-spec`, `/yoke:acceptance-contract`, and `/yoke:implement`
abort with the standard "missing/unapproved" error and the
migration helper as the recovery path.

## Definition of Done

1. `lib/working-memory/paths.sh` no longer defines
   `wm_tech_spec_path`; the DEPRECATED block is removed; the
   `tech-specs` entry is removed from `WM_ARCHIVE_CATEGORIES`
   (resulting tuple: `(prds specs tasks acceptance-contracts
   contracts query-traces)`); the `tech-specs/<slug>.md` line in
   the layout doc-comment block is removed; the
   `wm_tech_spec_path` mention in the usage example block is
   removed.
2. `tests/smoke/folder-isolation.test.sh` no longer calls
   `wm_tech_spec_path` (line 101, 102) and no longer references
   `.yoke/tech-specs/` (line 139). Replacement uses `wm_spec_path`
   plus the `.yoke/specs/<slug>.md` path. The test's
   allowed-locations and folder-isolation assertions still cover
   the spec archive (now `specs/` instead of `tech-specs/`).
3. `tests/smoke/sprint-4.test.sh` no longer references the
   `tech-specs` directory in the regression check (line 56) or in
   the synthetic-task-fixture mkdir (line 170) or in the synthetic
   tech-spec write (line 175). The fixture writes to
   `$tmpdir/.yoke/specs/$SLUG.md` instead, with shape-equivalent
   contents. The "Never modify..." regex assertion accommodates
   the new archive list.
4. `.vibeflow/patterns/memory-model.md` "Implementation Mapping"
   section enumerates `.yoke/specs/<slug>.md` and
   `.yoke/tasks/<slug>-s*-t*.md` as working-memory categories;
   `.yoke/tech-specs/<slug>.md` is removed from the layout
   description. The "Working memory — canonical files" table in
   the same doc reflects the spec + per-task split.
5. **Craftsmanship gate.** `bash -n` clean for `paths.sh`,
   `folder-isolation.test.sh`, `sprint-4.test.sh`. The idempotent
   re-source guard in `paths.sh` is preserved. The pattern doc
   stays internally consistent (cross-references to other patterns
   still resolve; no broken links). No file in the repository
   contains `wm_tech_spec_path` after this part lands —
   `grep -r wm_tech_spec_path` returns empty.
6. The full smoke suite (13/13 tests) PASS after this part lands.
   The PRD's "no backward-compat shim" anti-scope is verified by a
   grep assertion in `sprint-2.test.sh`.

## Scope

- `lib/working-memory/paths.sh` (modify) — remove the deprecated
  alias function, the DEPRECATED block comment, the `tech-specs`
  category entry, the layout doc-comment line, the usage-example
  reference. Net change: ~25 lines removed, no additions.
- `tests/smoke/folder-isolation.test.sh` (modify) — swap
  `wm_tech_spec_path` → `wm_spec_path`, swap `.yoke/tech-specs/`
  → `.yoke/specs/` in the allowed-locations regex.
- `tests/smoke/sprint-4.test.sh` (modify) — swap directory
  fixture paths, update the regression-check regex.
- `.vibeflow/patterns/memory-model.md` (modify) — Implementation
  Mapping section + Working-memory canonical-files table updated
  to the new layout.

## Anti-scope

- No skill changes — Parts 2/3 of the original PRD + Cleanup
  Parts 1 and 2 own those.
- No new behavior, no new fields. Pure removal + reference
  migration.
- No deletion of `.yoke/tech-specs/` directories that may exist in
  host projects — the cleanup is plugin-side; users with stale
  archives keep them and use `migrate-tech-specs.sh`. Do NOT add
  any host-side cleanup logic.
- No deletion of `lib/working-memory/migrate-tech-specs.sh` — the
  helper remains useful as long as any host project might still
  carry legacy archives. Removing it is out of scope for this PRD.
- No reformatting of `paths.sh` beyond the removed lines.
  Surrounding code stays put.

## Technical Decisions

- **Hard removal, not soft deprecation.** This part is exactly the
  removal pass that the option-B decision in 2026-04-25
  ("wm_tech_spec_path retained as deprecated soft alias") promised.
  Cleanup Parts 1 and 2 must merge first — verified by Anti-scope
  and by Dependencies below.
- **Pattern-doc updates ride along here, not in Parts 1/2.** The
  pattern doc references the layout abstractly; updating it before
  the alias is removed would create a doc/code mismatch. Updating
  it after is the safer order.
- **Smoke-test migration is mechanical.** No new assertions added;
  existing assertions retargeted at the new paths. A
  grep-for-`wm_tech_spec_path` regression-net assertion lands in
  `sprint-2.test.sh` to lock the no-backward-compat invariant.

## Applicable Patterns

- `.vibeflow/patterns/memory-model.md` — working-memory archive
  layout. This part *updates* the pattern doc itself to reflect the
  new layout.

No new pattern introduced.

## Risks

- **Smoke-test brittleness on the regex update.** `sprint-4.test.sh`
  uses a single regex check (line 56) that asserts the
  "Never modify..." restriction across multiple categories.
  Replacing `tech-specs` with `specs` in the regex while the
  subagent files still mention either label (or both during the
  transient state) could miss matches. **Mitigation:** Cleanup
  Part 1 lands first, ensuring `agents/*.md` use the new layout;
  only then does the regex flip cleanly.
- **Stale references in `.vibeflow/`.** The pattern doc may have
  cross-references in code-mapping tables to functions that no
  longer exist. **Mitigation:** grep for `wm_tech_spec_path` in
  `.vibeflow/` after the doc edit; surface any remaining hits
  before declaring DoD #5 met.
- **Host projects with legacy archives.** Users still on
  `.yoke/tech-specs/` will see their next `/yoke:tech-spec` run
  fail (skill aborts on missing approved spec at the new path).
  This is the **intended behavior**; the migration helper is the
  recovery path. The CHANGELOG entry for v0.7.0 must call this
  out explicitly. (CHANGELOG update is out of scope for this part
  — owner: release commit.)

## Dependencies

- `.vibeflow/specs/tech-spec-task-split-cleanup-part-1.md` — must
  merge first (runtime subagents + ralph-loop must be on the new
  layout before the alias is removed).
- `.vibeflow/specs/tech-spec-task-split-cleanup-part-2.md` — must
  merge first (the four other spec-phase skills must be on the new
  layout before the alias is removed).
