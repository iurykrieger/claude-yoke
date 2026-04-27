---
task_id: 2026-04-27-yoke-doctrine-canonization-s01-t02
sprint: 1
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s01-t02 — Create `projects/claude-yoke.md` and `actors/yoke.md` in the canonical-memory vault.

## Story

The vault needs a project entity and an actor entity to hold backlinks
from every doctrine entity created in subsequent sprints. Without
these scaffolds, doctrine entities have no backlink target, and
`/yoke:ask` queries scoped to the Yoke project return zero results.
The two entities are the foundation every later sprint depends on.

## Technical implementation

- Locate the registered checkout via `bash lib/canonical-memory/registry.sh path-of iury-brain` (returns `/Users/iury.krieger/Workspace/iurykrieger/iury-brain`).
- Write `projects/claude-yoke.md` in the checkout. Frontmatter: `kind: project`, `tags: [yoke-framework]`, `status: active`, `repository: https://github.com/iurykrieger/yoke`, `version: 1.1.0`, `created: 2026-04-27`, `last_validated: 2026-04-27`. Body sections: a Status section (current sprint, deployment target), an Architecture section (link to the manifesto entity once migrated, summary of the three-runtime-subagent shape), and an empty `## Doctrine entities` section that subsequent migration tasks append to.
- Write `actors/yoke.md` similarly. Frontmatter: `kind: actor`, `tags: [yoke-framework]`, `status: active`, `project: claude-yoke`, `kind_detail: framework`, `created: 2026-04-27`, `last_validated: 2026-04-27`. Body: a Persona section (Yoke as a development framework with three runtime subagents), a Capabilities section, and a Backlinks section listing the role concepts (`yoke-pattern-roles` referenced once it is migrated).
- Open a canonical-memory PR via `/yoke:preserve` carrying both files. Model C classification: medium-impact (vault scaffolding); auto-merge after veto window.
- Update Yoke's local `iury-brain` checkout: `git pull` the merged PR before sprint-1 task 3 begins ingesting doctrine entities.

## Validation

- Both files exist at `<checkout>/projects/claude-yoke.md` and `<checkout>/actors/yoke.md`.
- Every required frontmatter key is present and non-empty (deterministic key check via a yaml-frontmatter parser, no LLM judgment).
- `/yoke:ask "what is the claude-yoke project?"` returns a hit citing `projects/claude-yoke.md` with at least one body excerpt visible in the response.
- `/yoke:ask "describe the yoke actor"` returns a hit citing `actors/yoke.md`.
- The PR opened via `/yoke:preserve` is merged into `iurykrieger/brain` (URL captured in this task's `traceability` frontmatter field at completion).

## Acceptance criterion

Both `<iury-brain-checkout>/projects/claude-yoke.md` and `<iury-brain-checkout>/actors/yoke.md` exist with all required frontmatter keys present, AND both `/yoke:ask` sample queries above return entity hits whose responses contain the new file paths verbatim.
