---
task_id: 2026-04-27-sprint-as-cycle-s02-t04
sprint: 2
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-2
---

# Task 2026-04-27-sprint-as-cycle-s02-t04 — Concatenate the 16 `2026-04-27-yoke-doctrine-canonization-s<NN>-t<MM>.md` task files into 5 sprint files at `.yoke/sprints/2026-04-27-yoke-doctrine-canonization-s<NN>.md`, each task body becoming a `### Task <ID>` subsection inside the sprint file, with frontmatter `Migrated-from: [<original-path-1>, ...]`.

## Story

The 2026-04-27 doctrine-canonization run shipped on the per-task-file shape and produced 16 task files (sprint 1: 4, sprint 2: 3, sprint 3: 2, sprint 4: 4, sprint 5: 3). Under the new shape, each sprint is one file with tasks as `### Task <ID>` subsections. This task collapses the 16 task files into 5 sprint files retroactively, preserving every task body verbatim and recording the migration in `Migrated-from:` frontmatter for audit. After this task, `.yoke/tasks/` carries only THIS spec's own task files (the 23 `2026-04-27-sprint-as-cycle-s*-t*.md` ones, which migrate in sprint 4).

## Technical implementation

- Group source files by sprint. The 16 source files form 5 groups by `s<NN>` prefix:
  - `s01`: 4 files (`-s01-t01.md` through `-s01-t04.md`)
  - `s02`: 3 files (`-s02-t01.md` through `-s02-t03.md`)
  - `s03`: 2 files (`-s03-t01.md` through `-s03-t02.md`)
  - `s04`: 4 files (`-s04-t01.md` through `-s04-t04.md`)
  - `s05`: 3 files (`-s05-t01.md` through `-s05-t03.md`)
- For each sprint group `s<NN>`:
  - Compose the target file at `.yoke/sprints/2026-04-27-yoke-doctrine-canonization-s<NN>.md` (must not exist; abort if it does).
  - Frontmatter: lift fields from the FIRST task file in the group (`task_id` becomes `2026-04-27-yoke-doctrine-canonization-s<NN>`, `sprint: <N>`, `slug: 2026-04-27-yoke-doctrine-canonization`, `status: approved` — preserved from the original since the doctrine task already shipped, `created_at: <iso8601 from first task>`, `model: claude-opus-4-7[1m]`, `traceability: .yoke/specs/2026-04-27-yoke-doctrine-canonization.md#sprint-<N>`). Add `Migrated-from: [.yoke/tasks/2026-04-27-yoke-doctrine-canonization-s<NN>-t01.md, ..., -t<NN-last>.md]` listing every source path in the group.
  - Body header: `# Sprint <NN>: <sprint name>` lifted from the corresponding `### Sprint <N> — <name>` heading in `.yoke/specs/2026-04-27-yoke-doctrine-canonization.md`.
  - Append `## Sprint objective` lifted from the spec's `**Delivery objective:**` line for the sprint.
  - Append `## Sprint DoD` — synthesize from the spec's delivery objective + each task's binary criterion (one bullet per task's Acceptance criterion).
  - Append `## Tasks` — for each source task file, append a `### Task <task_id>` subsection containing the four inline labels: `**Story:** <Story body>`, `**Technical implementation:** <Technical implementation body>`, `**Validation:** <Validation body>`, `**Acceptance criterion:** <Acceptance criterion body>`. Lift verbatim — do NOT rewrite or summarize.
  - Append `## Functional acceptance criteria` — placeholder bullet `- (criterion IDs to be resolved from .yoke/acceptance-contracts/2026-04-27-yoke-doctrine-canonization.md when that AC artifact migrates to the new shape; left empty for now since the doctrine task already shipped)`.
  - Append `## Sensors` — list the sensors used by the sprint (synthesized from the spec's Validation section, or left empty with a `(post-shipped sprint; sensors recorded in audit reports)` annotation).
- After composing the 5 sprint files, `git rm` each of the 16 source task files (one git rm command).
- Commit the change in one git commit with message `chore(working-memory): concatenate doctrine-canonization tasks into 5 sprint files`. (Third commit of sprint 2.)

## Validation

- Count smoke: `find .yoke/sprints -name '2026-04-27-yoke-doctrine-canonization-s*.md' -type f | wc -l` returns `5`.
- Source-removal smoke: `find .yoke/tasks -name '2026-04-27-yoke-doctrine-canonization-s*-t*.md' -type f | wc -l` returns `0`.
- Frontmatter smoke: each of the 5 sprint files has `Migrated-from: [...]` listing the original task file paths in its frontmatter.
- Body-content smoke: each `### Task <id>` subsection contains the four inline labels (`**Story:**`, `**Technical implementation:**`, `**Validation:**`, `**Acceptance criterion:**`).
- Verbatim smoke: pick `2026-04-27-yoke-doctrine-canonization-s01-t01.md` from `.yoke/.legacy-archive/2026-04-27-pre-migration/tasks/`, locate the `## Story` body, and confirm that exact text appears under `### Task 2026-04-27-yoke-doctrine-canonization-s01-t01` in the migrated `s01.md` sprint file.
- Sensor smoke: `bash lib/sensors/legacy-parts-zero-residual.sh` against `.yoke/tasks/` only emits violations for the remaining 23 `2026-04-27-sprint-as-cycle-s*-t*.md` files (THIS spec's own tasks; sprint 4 migrates them).

## Acceptance criterion

`find .yoke/sprints -name '2026-04-27-yoke-doctrine-canonization-s*.md' -type f | wc -l` returns `5`, AND `find .yoke/tasks -name '2026-04-27-yoke-doctrine-canonization-s*-t*.md' -type f | wc -l` returns `0`, AND `grep -l "^Migrated-from:" .yoke/sprints/2026-04-27-yoke-doctrine-canonization-s*.md | wc -l` returns `5`.
