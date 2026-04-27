---
task_id: 2026-04-27-yoke-doctrine-canonization-s04-t03
sprint: 4
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s04-t03 — Rewrite every `.vibeflow/` reference under `hooks/`, `lib/`, and `templates/` similarly.

## Story

Hooks are bash scripts; libs are bash helpers; templates are
artifact-shape definitions. References to `.vibeflow/` here are
typically in comments (rationale citations) or in template prose
that ends up in user-facing artifacts. This task closes out the
last three framework directories so the framework-surface grep
returns 0 across the board before sprint 5's sensor lands.

## Technical implementation

- Read `.yoke/runtime/vibeflow-inventory.txt` and filter to entries under `hooks/`, `lib/`, and `templates/`. Process the three directories independently — they have different rewrite shapes:
  - **`hooks/*.sh` and `lib/**/*.sh`:** comments referencing `.vibeflow/patterns/*` rewrite to short citations of the canonical-memory entity name (e.g., `# see concepts/yoke-pattern-sensors for the rationale`). Avoid phrasing that implies a runtime query — bash hooks don't query canonical memory.
  - **`templates/*.md`:** template prose that ends up in user artifacts must rewrite cleanly. Specifically `templates/task.md`'s comment block currently references `.vibeflow/patterns/memory-model.md` — replace with `concepts/yoke-pattern-memory-model` (a path users / agents can `/yoke:ask` for if needed).
  - **`templates/approval-menu.md`:** has multiple `.vibeflow/patterns/human-triggers.md` references. Replace with `concepts/yoke-pattern-human-triggers`.
  - **`templates/spec.md`:** any `.vibeflow/patterns/*.md` cites in prose rewrite the same way.
- Process files alphabetically within each directory to keep the diff reviewable.

## Validation

- `grep -rcF '.vibeflow/' hooks/ lib/ templates/` returns 0 (sum across all matches).
- For `hooks/*.sh` files, `bash -n <file>` passes (syntax check) for every rewritten script.
- For `lib/**/*.sh` files, the same syntax check passes.
- For `templates/*.md`, no template's structural skeleton changed: heading levels, code-block fences, and frontmatter delimiters are unchanged from pre-rewrite.

## Acceptance criterion

`grep -rcF '.vibeflow/' hooks/ lib/ templates/ | awk -F: '{s+=$2} END {print s}'` returns 0 AND `find hooks/ lib/ -name '*.sh' -exec bash -n {} \; 2>&1 | wc -l` returns 0 (no syntax errors).
