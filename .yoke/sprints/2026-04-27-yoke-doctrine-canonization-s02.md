---
task_id: 2026-04-27-yoke-doctrine-canonization-s02
sprint: 2
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-yoke-doctrine-canonization.md#sprint-2
Migrated-from: [.yoke/tasks/2026-04-27-yoke-doctrine-canonization-s02-t01.md, .yoke/tasks/2026-04-27-yoke-doctrine-canonization-s02-t02.md, .yoke/tasks/2026-04-27-yoke-doctrine-canonization-s02-t03.md]
---

# Sprint 02: Canonical-memory bulk migration (doctrine)

## Sprint objective

Every doctrine artifact from `.vibeflow/` (the eight remaining patterns, every decision in `decisions.md`, the conventions doc, every audit) exists as a properly-frontmattered entity in `iurykrieger/brain`, retrievable via `/yoke:ask` round-trip.

## Sprint DoD

- 2026-04-27-yoke-doctrine-canonization-s02-t01: `ls <iury-brain-checkout>/concepts/yoke-pattern-*.md | wc -l` returns exactly 9 AND a script of eight `/yoke:ask` queries (committed in the Validation section) produces eight non-empty responses each containing the corresponding `concepts/yoke-pattern-<stem>.md` filename verbatim.
- 2026-04-27-yoke-doctrine-canonization-s02-t02: `ls <iury-brain-checkout>/concepts/yoke-decision-*.md | wc -l` equals `grep -c '^### [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} —' .vibeflow/decisions.md` AND a bash symmetry check of `supersedes` / `superseded_by` frontmatter pairs across all migrated decision entities exits 0 (every relationship is bidirectional and both endpoints exist).
- 2026-04-27-yoke-doctrine-canonization-s02-t03: `ls <iury-brain-checkout>/discussions/yoke-audit-*.md | wc -l` equals `ls .vibeflow/audits/*.md | wc -l` AND a sample `/yoke:ask` query about a specific audit returns a response citing the matching `discussions/yoke-audit-*.md` filename verbatim.

## Tasks

### Task 2026-04-27-yoke-doctrine-canonization-s02-t01

**Story:**

Sprint 1's slice migrated `roles.md` to prove the path. Eight patterns
remain: `acceptance-contract`, `human-triggers`, `memory-model`,
`model-c-governance`, `phase-flow`, `plugin-structure`, `ralph-loop`,
`sensors`. After this task, every framework pattern is queryable via
`/yoke:ask` — the precondition for sprint-4's bulk cutover under
`skills/` and `agents/`.

**Technical implementation:**

- Iterate the eight pattern files in alphabetical order. For each:
  - Source: `.vibeflow/patterns/<stem>.md`.
  - Destination: `<iury-brain-checkout>/concepts/yoke-pattern-<stem>.md`.
  - Frontmatter: `kind: pattern`, `tags: [yoke-framework]`, `ratified: <date>` (preserved from the pattern's own ratification or first commit), `last_validated: 2026-04-27`, `traceability: <link to motivating decision in concepts/yoke-decision-*>`, `status: active`, `project: claude-yoke`.
  - Body: pattern doc verbatim, with intra-doc references rewritten to point at the migrated entity names (e.g., a `[see roles.md](roles.md)` becomes `[see roles pattern](concepts/yoke-pattern-roles.md)`).
- Invoke `/yoke:teach` per file with the source path + target shape; the skill ingests, frontmatters, and writes. If `/yoke:teach` cannot accept eight invocations cleanly (rate-limit, batch-size cap), surface the error per the PRD's recursive-failure-of-dogfood signal — do not bypass the skill.
- After each migration, run a one-query `/yoke:ask` round-trip (e.g., for `yoke-pattern-sensors`: `/yoke:ask "describe Yoke's sensors pattern"`).
- Append all eight new entity paths to `projects/claude-yoke.md`'s `## Doctrine entities` section in a single Model C PR after all eight are written.

**Validation:**

- `ls <iury-brain-checkout>/concepts/yoke-pattern-*.md | wc -l` returns 9 (the slice from s01-t03 plus the eight added here).
- Each new entity's frontmatter passes the deterministic key check (every required key present, non-empty).
- Eight `/yoke:ask` round-trip queries — one per new pattern — return responses that cite the entity by filename and include a substring lifted from the entity body.
- The single Model C PR appending eight bullets to `projects/claude-yoke.md` is merged; checkout is sync'd.

**Acceptance criterion:**

`ls <iury-brain-checkout>/concepts/yoke-pattern-*.md | wc -l` returns exactly 9 AND a script of eight `/yoke:ask` queries (committed in the Validation section) produces eight non-empty responses each containing the corresponding `concepts/yoke-pattern-<stem>.md` filename verbatim.

### Task 2026-04-27-yoke-doctrine-canonization-s02-t02

**Story:**

`decisions.md` is one file with N decisions, each starting `### YYYY-MM-DD —`.
Splitting them into individual entities makes each decision queryable
via `/yoke:ask`, surfaces supersession history as a graph (`supersedes`
/ `superseded_by`), and unblocks `/yoke:drift-sense` from having a
real corpus. Without the split, decisions stay un-rippable: no
ratification frontmatter, no per-decision traceability, no decay
signal.

**Technical implementation:**

- Parse `.vibeflow/decisions.md` deterministically: split on `^### ([0-9]{4}-[0-9]{2}-[0-9]{2}) — (.+)$` headings. Each match anchors one decision spanning to the next heading. Pure bash + awk.
- For each decision, derive a slug: `yoke-decision-<YYYY-MM-DD>-<kebab-slug>` where the kebab-slug is the heading text after the date, lowercased, hyphenated, truncated to fit `wm_validate_slug`-compatible total length when used elsewhere.
- For each decision, write `<iury-brain-checkout>/concepts/yoke-decision-<YYYY-MM-DD>-<kebab-slug>.md`. Frontmatter: `kind: decision`, `tags: [yoke-framework]`, `ratified: <YYYY-MM-DD>` (the heading date verbatim), `last_validated: 2026-04-27`, `status: active | superseded | deprecated`, `project: claude-yoke`, plus `supersedes:` / `superseded_by:` arrays of entity filenames where applicable.
- Detect supersession by scanning each decision's body for the literal phrase `supersedes` or `superseded by` followed by a date — the deterministic regex is `(supersed(es|ed by) ")?([0-9]{4}-[0-9]{2}-[0-9]{2})`. Backlinks are bidirectional: A supersedes B means B's frontmatter gains `superseded_by: [A's filename]` and B's `status` flips to `superseded`.
- Body: Decision text, Context paragraph, and Discarded alternatives — preserved verbatim from the source decision block.
- Open ONE Model C PR carrying every new decision file plus the appended bullets in `projects/claude-yoke.md`'s `## Doctrine entities` section. PR title: `yoke: migrate decisions.md to <N> concept entities`.

**Validation:**

- Count of `<iury-brain-checkout>/concepts/yoke-decision-*.md` files equals the count of `^### [0-9]{4}-[0-9]{2}-[0-9]{2} —` matches in `.vibeflow/decisions.md` (modulo the slice migrated in s01-t03, which already exists).
- Bidirectional supersession check: every entity with `superseded_by: [X]` in its frontmatter has X existing as a file AND X's `supersedes` array contains the first entity's filename. A bash check enumerates pairs and asserts symmetry.
- Sample `/yoke:ask` round-trip on the most-recent decision returns a hit citing the new entity.
- Sample `/yoke:ask` round-trip on the most-superseded decision (the one with the most ancestors) returns a hit AND the response surfaces the `superseded_by` chain.

**Acceptance criterion:**

`ls <iury-brain-checkout>/concepts/yoke-decision-*.md | wc -l` equals `grep -c '^### [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} —' .vibeflow/decisions.md` AND a bash symmetry check of `supersedes` / `superseded_by` frontmatter pairs across all migrated decision entities exits 0 (every relationship is bidirectional and both endpoints exist).

### Task 2026-04-27-yoke-doctrine-canonization-s02-t03

**Story:**

Audits are after-action reports tied to specs. They become the
historical-trace input that `/yoke:drift-sense` consumes when scanning
for stale doctrine. `discussions/` is the right destination per the
PRD's Migration mapping: persistent learnings, not ephemeral notes.
Without this migration, drift-sense has no real corpus to scan.

**Technical implementation:**

- Iterate every file under `.vibeflow/audits/`. For each file:
  - Source: `.vibeflow/audits/<spec-stem>-audit.md` (or similar, depending on filename convention).
  - Destination: `<iury-brain-checkout>/discussions/yoke-audit-<spec-stem>-<YYYY-MM-DD>.md` where the date is the audit file's first-commit date.
  - Frontmatter: `kind: audit`, `tags: [yoke-framework]`, `audited_spec: <spec-stem>`, `audit_date: <YYYY-MM-DD>`, `last_validated: 2026-04-27`, `status: active`, `project: claude-yoke`.
  - Body: audit content verbatim.
- Invoke `/yoke:teach` per file with the source path + target shape. Batch-friendly (one ingestion per audit; ~50 invocations expected).
- The target shape (`kind: audit` plus the `audited_spec` field) may not be a recognized variant in the upstream `bedrock:teach` skill. If `/yoke:teach` rejects the shape, file the gap as a separate Yoke fix and use a one-shot direct write through the canonical-memory PR helper as a documented stop-gap. Do not silently fork `/yoke:teach`.
- After all writes, append entity paths to `projects/claude-yoke.md`'s `## Doctrine entities` section in a single Model C PR.

**Validation:**

- `ls <iury-brain-checkout>/discussions/yoke-audit-*.md | wc -l` equals `ls .vibeflow/audits/*.md | wc -l` (53 expected).
- Each migrated file's frontmatter passes the deterministic key check.
- Sample `/yoke:ask` round-trip: query for an audit by its audited spec name (e.g., `/yoke:ask "what was the outcome of the runtime-only-agents audit?"`) returns a hit citing the corresponding `discussions/yoke-audit-runtime-only-agents-*.md` entity.
- `projects/claude-yoke.md`'s `## Doctrine entities` section now contains the appended audit entries.

**Acceptance criterion:**

`ls <iury-brain-checkout>/discussions/yoke-audit-*.md | wc -l` equals `ls .vibeflow/audits/*.md | wc -l` AND a sample `/yoke:ask` query about a specific audit returns a response citing the matching `discussions/yoke-audit-*.md` filename verbatim.

## Functional acceptance criteria

- (criterion IDs to be resolved from .yoke/acceptance-contracts/2026-04-27-yoke-doctrine-canonization.md when that AC artifact migrates to the new shape; left empty for now since the doctrine task already shipped)

## Sensors

- (post-shipped sprint; sensors recorded in audit reports)
