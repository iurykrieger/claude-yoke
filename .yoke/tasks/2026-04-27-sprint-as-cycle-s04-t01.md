---
task_id: 2026-04-27-sprint-as-cycle-s04-t01
sprint: 4
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-4
---

# Task 2026-04-27-sprint-as-cycle-s04-t01 — Concatenate this spec's own task files (`.yoke/tasks/2026-04-27-sprint-as-cycle-s<NN>-t<MM>.md`) into 4 sprint files at `.yoke/sprints/2026-04-27-sprint-as-cycle-s<NN>.md`, with `Migrated-from:` frontmatter preserving the original paths.

## Story

This is the closing migration: this spec's own 23 task files (4 + 5 + 8 + 6 spread across the 4 sprints) get concatenated into 4 sprint files in the new shape, completing the on-disk shape switch. Until this task runs, the spec carries dual artifacts (per-task files for the running ralph loop + sprint files for everything else). After this task runs, only sprint files remain. This is also the last point at which the running `/yoke:implement` reads from `.yoke/tasks/` — by the time the cycle returns from this task, the working set has migrated.

## Technical implementation

- Pre-flight: extend the backup from sprint 2 t01 to also archive THIS spec's task files. Copy every `.yoke/tasks/2026-04-27-sprint-as-cycle-s*-t*.md` to `.yoke/.legacy-archive/2026-04-27-pre-migration/tasks/own-spec/`, append paths + sha256 sums to MANIFEST.txt.
- Group the 23 source files by sprint (parsing `s<NN>` from filenames):
  - `s01`: 4 files (`-s01-t01.md` through `-s01-t04.md`)
  - `s02`: 5 files (`-s02-t01.md` through `-s02-t05.md`)
  - `s03`: 8 files (`-s03-t01.md` through `-s03-t08.md`)
  - `s04`: 6 files (`-s04-t01.md` through `-s04-t06.md`)
- For each sprint group:
  - Compose target file `.yoke/sprints/2026-04-27-sprint-as-cycle-s<NN>.md` (must not exist; abort with conflict message otherwise).
  - Frontmatter: `task_id: 2026-04-27-sprint-as-cycle-s<NN>`, `sprint: <N>`, `slug: 2026-04-27-sprint-as-cycle`, `status: approved` (lifted from the source task files which become approved at Trigger 2 of this current run), `created_at: <iso8601 of first task>`, `model: claude-opus-4-7[1m]`, `traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-<N>`, `Migrated-from: [<23-original-paths>]`.
  - Body header: `# Sprint <NN>: <name lifted from spec>`.
  - Append `## Sprint objective` lifted from the spec's `**Delivery objective:**` line for that sprint.
  - Append `## Sprint DoD` synthesized from each source task's Acceptance criterion (one bullet per task).
  - Append `## Tasks` — one `### Task <task_id>` subsection per source task, with the four inline labels lifted verbatim from the source task's body sections.
  - Append `## Functional acceptance criteria` placeholder bullet (criterion IDs filled by Phase 3 / `/yoke:acceptance-contract` when this slug's AC is authored).
  - Append `## Sensors` — list any sensor IDs explicitly referenced across the source tasks' Validation sections.
- After composing the 4 sprint files, `git rm` each of the 23 source task files in one git commit.
- Final commit message: `chore(working-memory): self-migrate sprint-as-cycle task files (closing migration)`.

## Validation

- Count smoke: `find .yoke/sprints -name '2026-04-27-sprint-as-cycle-s*.md' -type f | wc -l` returns `4`.
- Source-removal smoke: `find .yoke/tasks -name '2026-04-27-sprint-as-cycle-s*-t*.md' -type f | wc -l` returns `0`.
- Frontmatter smoke: each of the 4 sprint files has `Migrated-from: [...]` listing the original 23 paths in aggregate (4 + 5 + 8 + 6 = 23 across the four files).
- Body-content smoke: each `### Task <id>` subsection contains the four inline labels.
- Verbatim smoke: pick one source task body from `.yoke/.legacy-archive/2026-04-27-pre-migration/tasks/own-spec/`, locate its `## Story` body, and confirm that exact text appears under the corresponding `### Task <id>` in the migrated sprint file.

## Acceptance criterion

`find .yoke/sprints -name '2026-04-27-sprint-as-cycle-s*.md' -type f | wc -l` returns `4`, AND `find .yoke/tasks -name '2026-04-27-sprint-as-cycle-s*-t*.md' -type f | wc -l` returns `0`.
