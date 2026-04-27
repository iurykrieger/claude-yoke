---
task_id: 2026-04-27-yoke-doctrine-canonization-s04-t04
sprint: 4
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s04-t04 — Update `CLAUDE.md` to direct readers at `/yoke:ask` for doctrine and `.yoke/specs/` / `.yoke/prds/` for project history.

## Story

The repo's `CLAUDE.md` is the entry-point any future Claude Code
session reads at startup. Today it contains explicit references like
`Read .vibeflow/index.md for project state` and `Pattern docs in
.vibeflow/patterns/`. After this task, `CLAUDE.md` redirects every
such read to canonical memory or working-memory archives, completing
the cutover from Yoke's coding-agent-runtime perspective.

## Technical implementation

- Edit `./CLAUDE.md` (the project's, not the user's global). Targets:
  - `## Where things live` section: replace the `.vibeflow/` line with: `.yoke/` (working memory: prds, specs, tasks, acceptance-contracts, contracts) plus a one-liner pointing at `/yoke:ask` for doctrine (patterns, decisions, conventions, audits live in canonical memory).
  - `## Working on this repo` numbered list: rewrite each of the four bullets that cite `.vibeflow/index.md`, `.vibeflow/conventions.md`, `.vibeflow/patterns/`, and `.vibeflow/decisions.md` to instead reference `/yoke:ask` queries or `projects/claude-yoke.md` (the project entity).
  - `## Sprint discipline` section: replace `.vibeflow/specs/` with `.yoke/specs/`.
  - `## Testing` section: leave `.vibeflow/decisions.md` reference replaced with the `/yoke:ask` form.
- The `## What Yoke is` section and below — manifesto-style reference — does NOT need rewrites if it cites `yoke.md` or the manifesto rather than `.vibeflow/`. Verify by grepping the section.
- Add a brief `## Migration history` section at the bottom (≤6 lines) noting that `.vibeflow/` was retired by the 2026-04-27 doctrine canonization PRD; this is the only deliberate retention of a `.vibeflow/` token in `CLAUDE.md`.

## Validation

- `grep -F '.vibeflow/' CLAUDE.md` returns matches only inside the `## Migration history` section. A bash check enumerates every match's line number and asserts each one falls within the line range of that section.
- `CLAUDE.md` still parses as valid Markdown (no broken heading hierarchy, no orphan code fences).
- A spot-read of `## Where things live` and `## Working on this repo` confirms the rewrites read naturally and instruct future agents to query canonical memory through `/yoke:ask`.

## Acceptance criterion

Every match of `grep -nF '.vibeflow/' CLAUDE.md` falls within the line range of the `## Migration history` section (deterministic check via `awk` extracting the section's start/end line numbers and comparing to grep's match line numbers).
