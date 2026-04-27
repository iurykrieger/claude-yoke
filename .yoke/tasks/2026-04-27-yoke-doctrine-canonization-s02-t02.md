---
task_id: 2026-04-27-yoke-doctrine-canonization-s02-t02
sprint: 2
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s02-t02 — Split `.vibeflow/decisions.md` into one `concepts/yoke-decision-*.md` entity per decision with supersession backlinks preserved.

## Story

`decisions.md` is one file with N decisions, each starting `### YYYY-MM-DD —`.
Splitting them into individual entities makes each decision queryable
via `/yoke:ask`, surfaces supersession history as a graph (`supersedes`
/ `superseded_by`), and unblocks `/yoke:drift-sense` from having a
real corpus. Without the split, decisions stay un-rippable: no
ratification frontmatter, no per-decision traceability, no decay
signal.

## Technical implementation

- Parse `.vibeflow/decisions.md` deterministically: split on `^### ([0-9]{4}-[0-9]{2}-[0-9]{2}) — (.+)$` headings. Each match anchors one decision spanning to the next heading. Pure bash + awk.
- For each decision, derive a slug: `yoke-decision-<YYYY-MM-DD>-<kebab-slug>` where the kebab-slug is the heading text after the date, lowercased, hyphenated, truncated to fit `wm_validate_slug`-compatible total length when used elsewhere.
- For each decision, write `<iury-brain-checkout>/concepts/yoke-decision-<YYYY-MM-DD>-<kebab-slug>.md`. Frontmatter: `kind: decision`, `tags: [yoke-framework]`, `ratified: <YYYY-MM-DD>` (the heading date verbatim), `last_validated: 2026-04-27`, `status: active | superseded | deprecated`, `project: claude-yoke`, plus `supersedes:` / `superseded_by:` arrays of entity filenames where applicable.
- Detect supersession by scanning each decision's body for the literal phrase `supersedes` or `superseded by` followed by a date — the deterministic regex is `(supersed(es|ed by) ")?([0-9]{4}-[0-9]{2}-[0-9]{2})`. Backlinks are bidirectional: A supersedes B means B's frontmatter gains `superseded_by: [A's filename]` and B's `status` flips to `superseded`.
- Body: Decision text, Context paragraph, and Discarded alternatives — preserved verbatim from the source decision block.
- Open ONE Model C PR carrying every new decision file plus the appended bullets in `projects/claude-yoke.md`'s `## Doctrine entities` section. PR title: `yoke: migrate decisions.md to <N> concept entities`.

## Validation

- Count of `<iury-brain-checkout>/concepts/yoke-decision-*.md` files equals the count of `^### [0-9]{4}-[0-9]{2}-[0-9]{2} —` matches in `.vibeflow/decisions.md` (modulo the slice migrated in s01-t03, which already exists).
- Bidirectional supersession check: every entity with `superseded_by: [X]` in its frontmatter has X existing as a file AND X's `supersedes` array contains the first entity's filename. A bash check enumerates pairs and asserts symmetry.
- Sample `/yoke:ask` round-trip on the most-recent decision returns a hit citing the new entity.
- Sample `/yoke:ask` round-trip on the most-superseded decision (the one with the most ancestors) returns a hit AND the response surfaces the `superseded_by` chain.

## Acceptance criterion

`ls <iury-brain-checkout>/concepts/yoke-decision-*.md | wc -l` equals `grep -c '^### [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} —' .vibeflow/decisions.md` AND a bash symmetry check of `supersedes` / `superseded_by` frontmatter pairs across all migrated decision entities exits 0 (every relationship is bidirectional and both endpoints exist).
