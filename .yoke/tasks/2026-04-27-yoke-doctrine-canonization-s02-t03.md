---
task_id: 2026-04-27-yoke-doctrine-canonization-s02-t03
sprint: 2
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s02-t03 — Migrate every `.vibeflow/audits/*.md` into `discussions/yoke-audit-*.md` with `kind: audit` frontmatter.

## Story

Audits are after-action reports tied to specs. They become the
historical-trace input that `/yoke:drift-sense` consumes when scanning
for stale doctrine. `discussions/` is the right destination per the
PRD's Migration mapping: persistent learnings, not ephemeral notes.
Without this migration, drift-sense has no real corpus to scan.

## Technical implementation

- Iterate every file under `.vibeflow/audits/`. For each file:
  - Source: `.vibeflow/audits/<spec-stem>-audit.md` (or similar, depending on filename convention).
  - Destination: `<iury-brain-checkout>/discussions/yoke-audit-<spec-stem>-<YYYY-MM-DD>.md` where the date is the audit file's first-commit date.
  - Frontmatter: `kind: audit`, `tags: [yoke-framework]`, `audited_spec: <spec-stem>`, `audit_date: <YYYY-MM-DD>`, `last_validated: 2026-04-27`, `status: active`, `project: claude-yoke`.
  - Body: audit content verbatim.
- Invoke `/yoke:teach` per file with the source path + target shape. Batch-friendly (one ingestion per audit; ~50 invocations expected).
- The target shape (`kind: audit` plus the `audited_spec` field) may not be a recognized variant in the upstream `bedrock:teach` skill. If `/yoke:teach` rejects the shape, file the gap as a separate Yoke fix and use a one-shot direct write through the canonical-memory PR helper as a documented stop-gap. Do not silently fork `/yoke:teach`.
- After all writes, append entity paths to `projects/claude-yoke.md`'s `## Doctrine entities` section in a single Model C PR.

## Validation

- `ls <iury-brain-checkout>/discussions/yoke-audit-*.md | wc -l` equals `ls .vibeflow/audits/*.md | wc -l` (53 expected).
- Each migrated file's frontmatter passes the deterministic key check.
- Sample `/yoke:ask` round-trip: query for an audit by its audited spec name (e.g., `/yoke:ask "what was the outcome of the runtime-only-agents audit?"`) returns a hit citing the corresponding `discussions/yoke-audit-runtime-only-agents-*.md` entity.
- `projects/claude-yoke.md`'s `## Doctrine entities` section now contains the appended audit entries.

## Acceptance criterion

`ls <iury-brain-checkout>/discussions/yoke-audit-*.md | wc -l` equals `ls .vibeflow/audits/*.md | wc -l` AND a sample `/yoke:ask` query about a specific audit returns a response citing the matching `discussions/yoke-audit-*.md` filename verbatim.
