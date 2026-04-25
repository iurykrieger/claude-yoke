# Spec: runtime-only-agents — Part 5 (manifesto, diagram, version, CHANGELOG)

> Generated via /vibeflow:gen-spec on 2026-04-25 from
> `.vibeflow/prds/runtime-only-agents.md`. Part 5 of 6.

## Objective

Update `yoke.md` (manifesto), `docs/architecture.md` (architecture
diagram), `.claude-plugin/plugin.json` (version bump), and
`CHANGELOG.md` to reflect v1.1.0 — the runtime-only-agents refactor.

## Context

The manifesto is the design source of truth; sections referencing the
5-subagent topology and the canonization phase need surgical edits.
The architecture diagram in `docs/architecture.md` is user-facing
documentation. The plugin version is bumped to 1.1.0 to reflect the
architectural refactor; `CHANGELOG.md` documents the clean break and
explicit non-migration stance.

## Definition of Done

1. `yoke.md` §10 (Model C) and §13 (architecture / role count)
   reflect: 3 runtime subagents (Generator, Validator, Orchestrator);
   skills-only spec phase (no spec-phase subagent instances); the
   *consult live, canonize on termination* canonization semantics.
2. A grep sweep over `yoke.md` for "Implementation Agent",
   "Validation Agent", "five subagents", "Five subagents",
   "spec-phase Generator", "spec-phase Validator" returns zero hits
   referencing them as live entities (only historical references in
   manifesto changelogs are acceptable, and only if explicitly
   marked historical).
3. `docs/architecture.md` shows the new topology — 3 runtime
   subagents spawned in parallel by `/yoke:implement`; spec phases
   driven by skills only (no Task spawns); `/yoke:ask` as a thin
   skill calling `query.sh` directly. If a Mermaid block exists, it
   is updated; if no Mermaid exists, one is added (no PNG).
4. `.claude-plugin/plugin.json` version is `1.1.0`.
5. `CHANGELOG.md` has a `## [1.1.0]` entry that lists, at minimum:
   the 3-subagent runtime topology; skills-only spec phases;
   `/yoke:ask` as a thin skill; `/yoke:canonize` repositioned as
   manual escape hatch; clean break with no migration.
6. **Craftsmanship gate** — manifesto remains internally consistent
   after the surgical edits (no contradictions between sections);
   `CHANGELOG.md` follows the existing convention used in the file
   (Keep-a-Changelog style or current Yoke style — match what is
   already present); markdown lint clean per
   `.vibeflow/conventions.md`.

## Scope

- Edit `yoke.md` §10 (Model C) to note that canonization writes are
  generated only at loop termination, not mid-loop; impact classes
  and per-class PR behavior unchanged.
- Edit `yoke.md` §13 (architecture) to reflect 3 runtime subagents,
  spec-phase skills-only, and the new role topology. Update any
  inline diagram in §13 to match.
- Sweep `yoke.md` for orphan references to deleted entities and
  remove or mark historical.
- Refresh `docs/architecture.md` — update Mermaid blocks in place;
  add a Mermaid block if none exists.
- Audit other `docs/*.md` files for orphan references to the old
  topology — update any that surface to users
  (`installation.md`, `quickstart.md`, `troubleshooting.md`,
  `canonical-memory-setup.md`, `scheduling-strategy.md`,
  `lineage.md`). Skip any that don't reference the topology.
- Bump `.claude-plugin/plugin.json` `"version"` field to `"1.1.0"`.
- Add a `## [1.1.0]` entry to `CHANGELOG.md` (at top, newest-first if
  that's the existing convention).
- Update `README.md` if it references the 5-subagent layout.

## Anti-scope

- Pattern docs and decisions — Part 4 (already landed).
- `agents/*` — Part 1.
- `skills/*` — Parts 2 and 3.
- Smoke tests — Part 6.
- No new docs files — only edits to existing ones.
- No marketplace JSON changes (`.claude-plugin/marketplace.json`)
  unless it explicitly references topology — audit during
  implementation; if no reference, skip.
- No tests run as part of this part — Part 6 owns test updates.

## Technical Decisions

- **Mermaid over PNG for diagrams.** Text-based diagrams diff
  cleanly in PRs and don't require image-editing tools. If
  `docs/architecture.md` already has a Mermaid block, edit it; if
  not, add one. Avoid PNG/SVG.
- **Surgical manifesto edits, not full rewrite.** The manifesto is
  long and most sections are unchanged. Edit only §10, §13, and any
  orphan references found by the grep sweep.
- **Newest-first CHANGELOG.** Match existing CHANGELOG convention;
  if newest-first, prepend `## [1.1.0]`; if oldest-first, append.
- **Clean-break wording in CHANGELOG.** State explicitly that
  v1.0 → v1.1 has no migration path because v1.0 has no active
  users. This sets the precedent for future major refactors before
  v2.

## Applicable Patterns

- `.vibeflow/patterns/plugin-structure.md` — version bump
  conventions; `.claude-plugin/plugin.json` schema.
- `.vibeflow/patterns/roles.md` (post-rewrite from Part 4) —
  authoritative source for §13 description.
- `.vibeflow/patterns/ralph-loop.md` (post-rewrite from Part 4) —
  reference for runtime topology in §13 and `architecture.md`.
- `.vibeflow/patterns/model-c-governance.md` — reference for §10
  edits.

## Risks

- **R-E1 — Manifesto sweep misses orphan references.** Mitigation:
  grep `yoke.md` for the patterns listed in DoD #2; confirm zero
  live hits; document any historical hits left in place.
- **R-E2 — Mermaid renders inconsistently across viewers.**
  Mitigation: use the simplest Mermaid features (flowchart TD/LR,
  no theming, no advanced syntax). Verify rendering in GitHub's
  Markdown preview before merging.
- **R-E3 — Other `docs/*.md` files harbor stale topology
  references.** Mitigation: grep `docs/` for the same patterns and
  update or skip explicitly.
- **R-E4 — `README.md` may be the user's first impression and may
  reference the 5-subagent layout.** Mitigation: README audit is in
  scope; update if needed.
- **R-E5 — CHANGELOG drift.** Mitigation: copy the shape from any
  prior version entry in the file; do not invent new fields.

## Dependencies

- `.vibeflow/specs/runtime-only-agents-part-1.md`
- `.vibeflow/specs/runtime-only-agents-part-2.md`
- `.vibeflow/specs/runtime-only-agents-part-3.md`
- `.vibeflow/specs/runtime-only-agents-part-4.md`
