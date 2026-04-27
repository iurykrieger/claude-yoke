---
task_id: 2026-04-27-yoke-doctrine-canonization-s04-t02
sprint: 4
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s04-t02 — Rewrite every `.vibeflow/` reference under `agents/` similarly.

## Story

The three runtime subagents (`generator.md`, `validator.md`,
`orchestrator.md`) each carry a "See also" section and inline
references to pattern docs and decisions. Their persona/discipline
sections also cite specific `.vibeflow/` paths. Every reference must
become a `/yoke:ask` invocation so the runtime subagents query
canonical memory exactly like the spec-phase skills.

## Technical implementation

- Read `.yoke/runtime/vibeflow-inventory.txt` and filter to entries under `agents/`.
- For each agent file:
  - Apply the same rewrite-pattern key from s01-t04 / s04-t01.
  - Subagents are read by the harness per-task at runtime; their structure (frontmatter + body sections) must remain intact. Verify the rewrite preserves: the `name:` and `description:` frontmatter, the `## Persona` heading, the `## Discipline` block, the `## Behaviors` block, and the closing `## See also` section.
  - For the `## See also` section, replace each `.vibeflow/patterns/*.md` line with a `/yoke:ask "describe the X pattern (concepts/yoke-pattern-X)"` invocation phrase.
- Generator and Validator subagent files reference `.yoke/runtime/progress.md` and other working-memory paths — those are NOT `.vibeflow/` references and stay untouched.

## Validation

- `grep -rcF '.vibeflow/' agents/` returns 0.
- Each agent file's frontmatter still has `name:` and `description:`; the runtime loader can register the subagents.
- Each agent file still has the four required sections (`## Persona`, `## Discipline`, `## Behaviors`, `## See also`) — no headings dropped during rewrite.

## Acceptance criterion

`grep -rcF '.vibeflow/' agents/ | awk -F: '{s+=$2} END {print s}'` returns 0 AND a heading-presence check (`grep -lE '^## (Persona|Discipline|Behaviors|See also)$' agents/*.md | wc -l`) returns the expected count for the four required headings × three agent files.
