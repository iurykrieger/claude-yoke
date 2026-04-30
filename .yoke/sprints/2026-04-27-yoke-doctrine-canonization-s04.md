---
task_id: 2026-04-27-yoke-doctrine-canonization-s04
sprint: 4
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-yoke-doctrine-canonization.md#sprint-4
Migrated-from: [.yoke/tasks/2026-04-27-yoke-doctrine-canonization-s04-t01.md, .yoke/tasks/2026-04-27-yoke-doctrine-canonization-s04-t02.md, .yoke/tasks/2026-04-27-yoke-doctrine-canonization-s04-t03.md, .yoke/tasks/2026-04-27-yoke-doctrine-canonization-s04-t04.md]
---

# Sprint 04: Framework cutover

## Sprint objective

Every framework file (`skills/`, `agents/`, `hooks/`, `lib/`, `templates/`) is rewritten to drop `.vibeflow/` references in favor of `/yoke:ask` invocations and working-memory paths; `CLAUDE.md` directs future agents at canonical memory and working memory.

## Sprint DoD

- 2026-04-27-yoke-doctrine-canonization-s04-t01: `grep -rcF '.vibeflow/' skills/ | awk -F: '{s+=$2} END {print s}'` returns 0 AND a Python YAML-frontmatter parser run over every `skills/*/SKILL.md` exits 0 for every file.
- 2026-04-27-yoke-doctrine-canonization-s04-t02: `grep -rcF '.vibeflow/' agents/ | awk -F: '{s+=$2} END {print s}'` returns 0 AND a heading-presence check (`grep -lE '^## (Persona|Discipline|Behaviors|See also)$' agents/*.md | wc -l`) returns the expected count for the four required headings × three agent files.
- 2026-04-27-yoke-doctrine-canonization-s04-t03: `grep -rcF '.vibeflow/' hooks/ lib/ templates/ | awk -F: '{s+=$2} END {print s}'` returns 0 AND `find hooks/ lib/ -name '*.sh' -exec bash -n {} \; 2>&1 | wc -l` returns 0 (no syntax errors).
- 2026-04-27-yoke-doctrine-canonization-s04-t04: Every match of `grep -nF '.vibeflow/' CLAUDE.md` falls within the line range of the `## Migration history` section (deterministic check via `awk` extracting the section's start/end line numbers and comparing to grep's match line numbers).

## Tasks

### Task 2026-04-27-yoke-doctrine-canonization-s04-t01

**Story:**

`skills/` is the heaviest concentration of `.vibeflow/` references in
the framework — every skill body cites pattern docs, decisions, or
specs. The s01-t04 cutover proved the rewrite path on one file; this
task applies the same pattern to every remaining skill.

**Technical implementation:**

- Read `.yoke/runtime/vibeflow-inventory.txt` and filter to entries under `skills/`. Subtract the file already cut over in s01-t04.
- For each file in the filtered list:
  - Apply the rewrite-pattern key committed in s01-t04's Validation section. Doctrine references rewrite to `/yoke:ask` invocation phrases; project-history references rewrite to `.yoke/specs/<slug>.md` or `.yoke/prds/<slug>.md` paths (using slugs from sprint 3's migration); index references rewrite to project-entity invocations.
  - Preserve all surrounding prose verbatim.
- For skills containing a "See also" section that lists `.vibeflow/patterns/*.md` files, replace each line with the corresponding `concepts/yoke-pattern-*.md` invocation pattern.
- For skills containing TEMPLATES with embedded `.vibeflow/patterns/memory-model.md` reference (the task seed template references it in its comment block), update `templates/task.md` here too — that's a skill-adjacent template and falls in scope.
- Run the framework-surface grep after each batch of ~5 files to confirm references are dropping. After all skill files are cut over, the grep count for `skills/` should be 0.

**Validation:**

- `grep -rcF '.vibeflow/' skills/` returns 0 (sum of per-file counts).
- For every skill that was rewritten, the YAML frontmatter (top of file) parses as valid YAML — the frontmatter is the part Claude Code reads to register the skill, so a parse failure breaks the plugin.
- For every skill, the file's directory still matches the skill's `name` field (e.g., `skills/discover/SKILL.md` still has `name: yoke:discover`).
- A spot-check on three randomly-sampled rewritten files reads as natural prose with no orphaned phrases or broken sentences.

**Acceptance criterion:**

`grep -rcF '.vibeflow/' skills/ | awk -F: '{s+=$2} END {print s}'` returns 0 AND a Python YAML-frontmatter parser run over every `skills/*/SKILL.md` exits 0 for every file.

### Task 2026-04-27-yoke-doctrine-canonization-s04-t02

**Story:**

The three runtime subagents (`generator.md`, `validator.md`,
`orchestrator.md`) each carry a "See also" section and inline
references to pattern docs and decisions. Their persona/discipline
sections also cite specific `.vibeflow/` paths. Every reference must
become a `/yoke:ask` invocation so the runtime subagents query
canonical memory exactly like the spec-phase skills.

**Technical implementation:**

- Read `.yoke/runtime/vibeflow-inventory.txt` and filter to entries under `agents/`.
- For each agent file:
  - Apply the same rewrite-pattern key from s01-t04 / s04-t01.
  - Subagents are read by the harness per-task at runtime; their structure (frontmatter + body sections) must remain intact. Verify the rewrite preserves: the `name:` and `description:` frontmatter, the `## Persona` heading, the `## Discipline` block, the `## Behaviors` block, and the closing `## See also` section.
  - For the `## See also` section, replace each `.vibeflow/patterns/*.md` line with a `/yoke:ask "describe the X pattern (concepts/yoke-pattern-X)"` invocation phrase.
- Generator and Validator subagent files reference `.yoke/runtime/progress.md` and other working-memory paths — those are NOT `.vibeflow/` references and stay untouched.

**Validation:**

- `grep -rcF '.vibeflow/' agents/` returns 0.
- Each agent file's frontmatter still has `name:` and `description:`; the runtime loader can register the subagents.
- Each agent file still has the four required sections (`## Persona`, `## Discipline`, `## Behaviors`, `## See also`) — no headings dropped during rewrite.

**Acceptance criterion:**

`grep -rcF '.vibeflow/' agents/ | awk -F: '{s+=$2} END {print s}'` returns 0 AND a heading-presence check (`grep -lE '^## (Persona|Discipline|Behaviors|See also)$' agents/*.md | wc -l`) returns the expected count for the four required headings × three agent files.

### Task 2026-04-27-yoke-doctrine-canonization-s04-t03

**Story:**

Hooks are bash scripts; libs are bash helpers; templates are
artifact-shape definitions. References to `.vibeflow/` here are
typically in comments (rationale citations) or in template prose
that ends up in user-facing artifacts. This task closes out the
last three framework directories so the framework-surface grep
returns 0 across the board before sprint 5's sensor lands.

**Technical implementation:**

- Read `.yoke/runtime/vibeflow-inventory.txt` and filter to entries under `hooks/`, `lib/`, and `templates/`. Process the three directories independently — they have different rewrite shapes:
  - **`hooks/*.sh` and `lib/**/*.sh`:** comments referencing `.vibeflow/patterns/*` rewrite to short citations of the canonical-memory entity name (e.g., `# see concepts/yoke-pattern-sensors for the rationale`). Avoid phrasing that implies a runtime query — bash hooks don't query canonical memory.
  - **`templates/*.md`:** template prose that ends up in user artifacts must rewrite cleanly. Specifically `templates/task.md`'s comment block currently references `.vibeflow/patterns/memory-model.md` — replace with `concepts/yoke-pattern-memory-model` (a path users / agents can `/yoke:ask` for if needed).
  - **`templates/approval-menu.md`:** has multiple `.vibeflow/patterns/human-triggers.md` references. Replace with `concepts/yoke-pattern-human-triggers`.
  - **`templates/spec.md`:** any `.vibeflow/patterns/*.md` cites in prose rewrite the same way.
- Process files alphabetically within each directory to keep the diff reviewable.

**Validation:**

- `grep -rcF '.vibeflow/' hooks/ lib/ templates/` returns 0 (sum across all matches).
- For `hooks/*.sh` files, `bash -n <file>` passes (syntax check) for every rewritten script.
- For `lib/**/*.sh` files, the same syntax check passes.
- For `templates/*.md`, no template's structural skeleton changed: heading levels, code-block fences, and frontmatter delimiters are unchanged from pre-rewrite.

**Acceptance criterion:**

`grep -rcF '.vibeflow/' hooks/ lib/ templates/ | awk -F: '{s+=$2} END {print s}'` returns 0 AND `find hooks/ lib/ -name '*.sh' -exec bash -n {} \; 2>&1 | wc -l` returns 0 (no syntax errors).

### Task 2026-04-27-yoke-doctrine-canonization-s04-t04

**Story:**

The repo's `CLAUDE.md` is the entry-point any future Claude Code
session reads at startup. Today it contains explicit references like
`Read .vibeflow/index.md for project state` and `Pattern docs in
.vibeflow/patterns/`. After this task, `CLAUDE.md` redirects every
such read to canonical memory or working-memory archives, completing
the cutover from Yoke's coding-agent-runtime perspective.

**Technical implementation:**

- Edit `./CLAUDE.md` (the project's, not the user's global). Targets:
  - `## Where things live` section: replace the `.vibeflow/` line with: `.yoke/` (working memory: prds, specs, tasks, acceptance-contracts, contracts) plus a one-liner pointing at `/yoke:ask` for doctrine (patterns, decisions, conventions, audits live in canonical memory).
  - `## Working on this repo` numbered list: rewrite each of the four bullets that cite `.vibeflow/index.md`, `.vibeflow/conventions.md`, `.vibeflow/patterns/`, and `.vibeflow/decisions.md` to instead reference `/yoke:ask` queries or `projects/claude-yoke.md` (the project entity).
  - `## Sprint discipline` section: replace `.vibeflow/specs/` with `.yoke/specs/`.
  - `## Testing` section: leave `.vibeflow/decisions.md` reference replaced with the `/yoke:ask` form.
- The `## What Yoke is` section and below — manifesto-style reference — does NOT need rewrites if it cites `yoke.md` or the manifesto rather than `.vibeflow/`. Verify by grepping the section.
- Add a brief `## Migration history` section at the bottom (≤6 lines) noting that `.vibeflow/` was retired by the 2026-04-27 doctrine canonization PRD; this is the only deliberate retention of a `.vibeflow/` token in `CLAUDE.md`.

**Validation:**

- `grep -F '.vibeflow/' CLAUDE.md` returns matches only inside the `## Migration history` section. A bash check enumerates every match's line number and asserts each one falls within the line range of that section.
- `CLAUDE.md` still parses as valid Markdown (no broken heading hierarchy, no orphan code fences).
- A spot-read of `## Where things live` and `## Working on this repo` confirms the rewrites read naturally and instruct future agents to query canonical memory through `/yoke:ask`.

**Acceptance criterion:**

Every match of `grep -nF '.vibeflow/' CLAUDE.md` falls within the line range of the `## Migration history` section (deterministic check via `awk` extracting the section's start/end line numbers and comparing to grep's match line numbers).

## Functional acceptance criteria

- (criterion IDs to be resolved from .yoke/acceptance-contracts/2026-04-27-yoke-doctrine-canonization.md when that AC artifact migrates to the new shape; left empty for now since the doctrine task already shipped)

## Sensors

- (post-shipped sprint; sensors recorded in audit reports)
