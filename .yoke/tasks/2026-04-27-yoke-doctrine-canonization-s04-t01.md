---
task_id: 2026-04-27-yoke-doctrine-canonization-s04-t01
sprint: 4
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s04-t01 — Rewrite every `.vibeflow/` reference under `skills/` to a `/yoke:ask` invocation or a working-memory path.

## Story

`skills/` is the heaviest concentration of `.vibeflow/` references in
the framework — every skill body cites pattern docs, decisions, or
specs. The s01-t04 cutover proved the rewrite path on one file; this
task applies the same pattern to every remaining skill.

## Technical implementation

- Read `.yoke/runtime/vibeflow-inventory.txt` and filter to entries under `skills/`. Subtract the file already cut over in s01-t04.
- For each file in the filtered list:
  - Apply the rewrite-pattern key committed in s01-t04's Validation section. Doctrine references rewrite to `/yoke:ask` invocation phrases; project-history references rewrite to `.yoke/specs/<slug>.md` or `.yoke/prds/<slug>.md` paths (using slugs from sprint 3's migration); index references rewrite to project-entity invocations.
  - Preserve all surrounding prose verbatim.
- For skills containing a "See also" section that lists `.vibeflow/patterns/*.md` files, replace each line with the corresponding `concepts/yoke-pattern-*.md` invocation pattern.
- For skills containing TEMPLATES with embedded `.vibeflow/patterns/memory-model.md` reference (the task seed template references it in its comment block), update `templates/task.md` here too — that's a skill-adjacent template and falls in scope.
- Run the framework-surface grep after each batch of ~5 files to confirm references are dropping. After all skill files are cut over, the grep count for `skills/` should be 0.

## Validation

- `grep -rcF '.vibeflow/' skills/` returns 0 (sum of per-file counts).
- For every skill that was rewritten, the YAML frontmatter (top of file) parses as valid YAML — the frontmatter is the part Claude Code reads to register the skill, so a parse failure breaks the plugin.
- For every skill, the file's directory still matches the skill's `name` field (e.g., `skills/discover/SKILL.md` still has `name: yoke:discover`).
- A spot-check on three randomly-sampled rewritten files reads as natural prose with no orphaned phrases or broken sentences.

## Acceptance criterion

`grep -rcF '.vibeflow/' skills/ | awk -F: '{s+=$2} END {print s}'` returns 0 AND a Python YAML-frontmatter parser run over every `skills/*/SKILL.md` exits 0 for every file.
