# Sprint 01 of 06: Bedrock canonical-memory port

> Migrated from: # Spec: Bedrock canonical-memory port — Part 1: Foundation


> Generated via /vibeflow:gen-spec on 2026-04-25
> Source PRD: `.vibeflow/prds/bedrock-canonical-memory-port.md`

## Objective

Ship the substrate every later part depends on: a plugin-level memory
registry with deterministic resolution, plus the 8-entity content model
(templates + semantic definitions) extended with Yoke's mandatory
rippability frontmatter.

## Context

Today, canonical memory is a single repo cloned on every read into
`~/.cache/yoke/canonical/<slug>/`. There is no entity model, no
registry, and no per-memory configuration. Bedrock 1.2.1 has all three
solved for vaults; this part ports the mechanics, keeps the manifesto's
mandatory frontmatter on top, and produces no user-facing skills yet —
just the substrate Parts 2–6 build on.

## Definition of Done

1. `<plugin_dir>/memories.json` is created and managed via
   `lib/canonical-memory/registry.sh`, exposing `init`, `list`, `add`,
   `remove`, `set-default` operations against the
   `{name, path, url, default}` schema.
2. `lib/canonical-memory/resolve-memory.sh` resolves the active memory
   through the chain `--memory <name>` flag → CWD detection
   (longest-prefix match) → registry default → error with the registry
   listing. The resolver is sourceable; callers consume
   `$YOKE_MEMORY_PATH`.
3. The 8 bedrock entity types ship as templates under
   `templates/canonical/{type}/_template.md` (actor, person, team,
   concept, topic, discussion, project, fleeting). Every template
   carries the bedrock fields **plus** the Yoke rippability fields:
   `ratified_at`, `model_calibrated_against`, `last_validated`,
   `traceability`, `impact_level`.
4. The 8 entity semantic definitions ship under `entities/{type}.md`,
   copied from bedrock 1.2.1 with kebab-case namespace renames
   (`/bedrock:*` → `/yoke:*`, vault → memory). Update rules
   (merge-only on people/teams/concepts/topics) explicitly forbid
   deleting any of the five Yoke rippability fields.
5. `templates/yoke-memory-config.json` documents the per-memory config
   schema: `language`, `git.strategy`
   (`commit-push` | `commit-push-pr` | `commit-only`),
   `query.max_subgraph_calls`.
6. `lib/canonical-memory/scaffold-memory.sh` initializes a fresh memory
   repo: `git init`, creates the 8 entity directories, copies all
   templates, writes `.yoke-memory/config.json` from the schema. Used
   by Part 2's `/yoke:memory add <empty-path>`.
7. **Quality gate:** `docs/lineage.md` carries a new section
   attributing the bedrock-derived templates and entity definitions to
   bedrock 1.2.1, per Implementation Plan Conventions ("Lineage is
   documented honestly"). No `.vibeflow/conventions.md` Don'ts are
   violated — the foundation does not read canonical memory by clone,
   does not expose any agent to the full memory, and does not bypass
   the Orchestrator's write authority.

## Scope

- Registry library + `<plugin_dir>/memories.json` schema.
- Memory resolution library (3-step chain).
- 8 entity templates (copy from bedrock + rippability extension).
- 8 entity semantic definitions (copy + namespace rename).
- Per-memory config schema document.
- Scaffold helper for fresh memory creation.
- Lineage entry in `docs/lineage.md`.

## Anti-scope

- No skills wired here. `/yoke:memory`, `/yoke:bootstrap` migration,
  `/yoke:ask` refactor, `/yoke:preserve`, `/yoke:teach`,
  `/yoke:compress`, `/yoke:status` extension all live in Parts 2–6.
- No graphify integration; no `code` 9th entity type.
- No deletion of the existing `lib/canonical-memory/query.sh` or
  `propose-write.sh` — they continue to work until their consumers
  retire in later parts.
- No Model C wiring (Part 4).
- No removal of `lib/canonical-memory/canonization-criteria.sh` — it
  survives untouched and becomes the Model C classifier in Part 4.

## Technical Decisions

- **Registry at `<plugin_dir>/memories.json`, not XDG.** Bedrock parity
  per PRD resolution. Caveat documented: lost on plugin reinstall;
  recovery is `/yoke:memory add` per memory.
- **Rippability frontmatter is additive.** Each bedrock template gets
  the 5 mandatory Yoke fields appended to the existing YAML. Nothing
  bedrock-defined is removed — preserves bedrock's merge-only
  semantics for people/teams/concepts/topics. The Yoke fields join
  the "never delete" list explicitly.
- **Templates and entity-defs split by purpose.** Templates →
  `templates/canonical/{type}/_template.md` (used by `/yoke:preserve`
  for new-entity creation). Definitions → `entities/{type}.md` at the
  plugin root (used by `/yoke:ask` and `/yoke:preserve` for
  classification). Mirrors bedrock's `<base_dir>/../../entities/`
  layout.
- **Resolution lib is sourced, not exec-ed.** The 3-step chain is a
  bash function returning `$YOKE_MEMORY_PATH` to the caller. Avoids
  process boundary noise and matches the existing
  `lib/working-memory/paths.sh` pattern.
- **Schema for `memories.json`** mirrors bedrock's `vaults.json`:
  ```json
  { "memories": [
      { "name": "main", "path": "/abs/path", "url": "...", "default": true }
  ] }
  ```
  Names are kebab-case, lowercase, unique. Exactly one default.

## Applicable Patterns

- `.vibeflow/patterns/memory-model.md` — the new infrastructure must
  not contradict the two-tier model (working vs canonical). It
  strengthens canonical-memory mechanics; the working-memory side
  stays untouched.
- `.vibeflow/patterns/plugin-structure.md` — new directories follow
  the existing layout convention (`templates/`,
  `lib/canonical-memory/`, `entities/` at plugin root).
- **New pattern emerging — "Registered local checkout."** Don't
  document it as its own pattern doc here; Part 4 owns the
  `memory-model.md` rewrite and folds it in.

## Risks

- **R-1.1 — Plugin reinstall loses registry.** Bedrock has the same
  caveat. *Mitigation:* document recovery in
  `docs/canonical-memory-setup.md` (Part 2 owns that doc); registry
  lib emits a clear error from `list` when the file is missing,
  pointing at `/yoke:memory add`.
- **R-1.2 — Bedrock template drift.** Templates copied verbatim could
  silently diverge from bedrock upstream. *Mitigation:* lineage entry
  pins source version (`bedrock 1.2.1`); future bedrock upgrades are
  explicit decisions, never implicit syncs (Implementation Plan
  Conventions: "Do not pin Yoke to a specific upstream version… those
  skills evolve internally").
- **R-1.3 — Rippability fields silently deleted on update.** Bedrock's
  update semantics are merge-only for people/teams/concepts/topics,
  but actors are merge-and-modify. The 5 Yoke fields must survive
  every update class. *Mitigation:* explicit "never delete" rule
  added to each `entities/{type}.md` after the namespace rename;
  Part 4 enforces in `/yoke:preserve` Phase 4.

## File budget

This part exceeds the project's suggested budget of ≤4 files per task.
The overage is data, not code: 8 entity templates + 8 entity definitions
are bulk markdown copied from bedrock 1.2.1 with mechanical renames.
The "minimum; revise upward as the codebase grows" wording in
`.vibeflow/index.md` covers this case. Library code (registry,
resolution, scaffold) stays under 4 files.

## Dependencies

None — this is the foundation.
