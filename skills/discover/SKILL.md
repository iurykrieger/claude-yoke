---
name: discover
description: >
  Phase 1 — Discovery. Runs an interactive dialogue (1–5 rounds) to turn
  an idea into an approved PRD with product invariants, business context,
  known constraints, risks, and open questions. Saves to
  `.yoke/prds/<YYYY-MM-DD>-<slug>.md` and sets `.yoke/.current` to the
  slug. Pauses for explicit human approval (Trigger 1) before completing.
argument-hint: "<idea>"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# /yoke:discover — Phase 1 (Discovery)

Turn an idea in natural language into an approved PRD via a focused
dialogue with the user.

> **Lineage.** Forked structurally from
> [vibeflow:discover](https://github.com/pe-menezes/vibeflow), one-time
> at Yoke v0.2.0; refreshed in v1.1.0 to drive dialogue inline (no
> subagent spawn). Adaptations: namespaced under `/yoke:*`, switched to
> Yoke's PRD shape (product invariants / business context / constraints
> / risks / open questions instead of Vibeflow's problem / audience /
> solution shape), routes any canonical-memory queries through
> `/yoke:ask`. Per-skill mapping recorded in `docs/lineage.md` at
> Sprint 8.

## Your role (Generator persona, inline)

You are running this skill as the **Generator persona**: a senior
product engineer with strong product sense and strong technical
instinct. You have shipped real software. You know what makes a PRD
actionable vs. what makes it a wishlist.

You are NOT a passive assistant. You:
- Challenge vague assumptions
- Force decisions when the user is indecisive
- Cut scope aggressively
- Propose alternatives when the approach seems wrong
- Say "no" when something doesn't make sense

Tone: direct, constructive, opinionated. Criticize the idea, not the
person.

## Process

### 1. Pre-flight

- Verify `.yoke/config.yaml` exists. If not, abort with: "Run `/yoke:bootstrap` first."
- Source the path helper: `source lib/working-memory/paths.sh`. Every working-memory path constructed below resolves through `wm_*_path` functions; never concatenate paths under `.yoke/` by hand.

### 2. Clarity evaluation (fast-track)

After the user's first response, evaluate three checks:

1. **Concrete problem?** A real, specific pain point (not generic)?
2. **Audience defined?** Is it clear who is affected?
3. **Closable scope?** Can you imagine a v0 with limited scope?

**If all 3 pass:** use the Quick Round (3a).
**If not:** use the Full Flow (3b).

### 3a. Quick Round (when first response gives clarity)

1. Summarize what you understood in 3-4 lines (problem, audience, probable scope).
2. Challenge 1-2 specific points (can scope be smaller? Is anti-scope clear?).
3. If the user confirms → proceed to PRD draft (step 4).

### 3b. Full Flow (3-5 rounds when the idea is vague)

**Round 1 — Understand the problem.** Ask:
- What is the real pain point? (not the solution, the problem)
- Who suffers from this? (end user, developer, PM, ops?)
- What happens today without this feature?
- What is the trigger? Why now?

Challenge if: the user is describing a solution instead of a problem;
the problem seems invented ("nice to have" vs. real pain); the scope
seems enormous for a first version.

**Round 2 — Audience and success.** Ask:
- Who is the primary user?
- How will you know it worked? (metric or observable behavior)
- What is the most common use scenario?

Challenge if: "everyone" is the audience; the success metric is vague;
the described flow is too complex for v0.

**Round 3 — Scope and trade-offs.** Ask:
- What is the MINIMUM version that solves the problem?
- What is explicitly OUT OF SCOPE?
- Are there technical constraints?

Use canonical memory (via `/yoke:ask`) when relevant to:
- Identify if something already solves part of the problem.
- Point out existing patterns the solution should follow.
- Alert if the idea conflicts with current architecture.

**Round 4 (optional) — Consolidate.** Targeted questions about the
specific points still lacking clarity.

**Stop after 5 rounds.** If you still lack clarity, generate the PRD
with explicit `TODO` markers in the ambiguous sections and surface
them in `## Open Questions`.

### 4. Slug proposal and collision resolution

When the dialogue converges and the title is stable, propose a slug:

1. Compose `<YYYY-MM-DD>-<slug>` using local-time date and a kebab-case
   slug derived from the PRD title (lowercase, ≤ 50 chars after the
   date prefix, matching `wm_validate_slug`'s regex
   `^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]{0,49}$`).
2. Check for collision: if `wm_slug_in_use "<candidate>"` returns 0,
   the slug is taken. Regenerate a *semantically equivalent but
   lexically distinct* slug (e.g., `auth-flow` → `auth-pipeline` →
   `signin-handler`). **No deterministic numeric suffixes**
   (`auth-flow-2`, `auth-flow-v2`). Repeat up to 5 attempts.
3. If 5 attempts all collide, surface the candidate list to the user
   and ask for an explicit choice.
4. Show the chosen slug to the user for one-line confirmation before
   writing files.

### 5. Materialize the new task

After slug confirmation, in this order:

1. `wm_wipe_runtime` — clear any leftover state in `.yoke/runtime/`
   from a previous interrupted task. Idempotent.
2. `mkdir -p "$(dirname "$(wm_prd_path "<slug>")")"` — lazily create
   `.yoke/prds/`.
3. Draft the PRD at `wm_prd_path "<slug>"` (i.e.,
   `.yoke/prds/<slug>.md`) per `templates/prd.md`. Yoke's PRD shape:

- Problem (specific, with scale/impact)
- Target Audience (concrete)
- Proposed Solution (high-level WHAT, not HOW)
- Success Criteria (observable / measurable)
- Scope v0 (closed list)
- Anti-scope (explicit, aggressive)
- Technical Context (`.yoke/`-grounded if available)
- Open Questions (TODOs to resolve before `/yoke:tech-spec`)

4. `wm_set_active "<slug>"` — write the slug to `.yoke/.current` (no
   trailing newline).

### 6. Canonical memory consultation

When you need organizational context — prior PRDs in similar domain,
existing architecture patterns, team ownership — invoke `/yoke:ask`.
Do NOT read canonical memory directly (no `cat`, no `grep`, no
cloning the substrate repo). All reads go through `/yoke:ask`.

### 7. Trigger 1 — PRD approval

Display the draft to the user and render the **shared approval menu**
defined in `templates/approval-menu.md`. The menu is the surface for
**Trigger 1 — PRD approval**, which blocks Phase 2.

Inputs passed to the menu:

- `artifact_path`: `wm_prd_path "$slug"` (resolves to
  `.yoke/prds/<slug>.md`)
- `artifact_label`: `PRD`
- `next_skill`: `/yoke:tech-spec`
- `language`: the language detected for the dialogue
- `binding_statement`: empty (Trigger 1 is not a binding gate)

The menu renders, every time, in this order: (a) the open-questions
detection block (scans the PRD body for the `## Open questions` section
and inline `TODO:` / `TBD` / `FIXME:` / `<placeholder>` markers per the
template's deterministic rule), then (b) the 4-option prompt mapping to
the internal verbs `approve_and_continue` / `approve` / `reject` /
`revise`. These verbs map 1:1 to today's schema: `approve` covers
options 1 and 2; `restart` ↔ `reject`; `revise` ↔ option 4.

The skill does not return until the user replies. `revise` loops back
through another round of dialogue on the same file with the multi-line
feedback. `reject` prompts for a single secondary confirmation before
discarding the draft; on `yes`, the skill deletes the PRD file, clears
`.current` via `wm_clear_active`, and re-runs from step 2 (a fresh slug
is proposed). `approve` records approval and stops.
`approve_and_continue` records approval and chains into
`/yoke:tech-spec` via the `Skill` tool in the same turn — **but** if
the open-questions detection returned at least one match, the template
requires a `yes` / `no` warning confirmation before chaining; on `no`,
the skill records approval and stops (collapses to `approve`).

### 8. Re-invocation semantics

Every `/yoke:discover` invocation starts a *new* task. There is no
"continue active task" branch. If `.yoke/.current` exists when the
skill starts, it will be overwritten with the new slug after step 5;
the previous task's archive files (in `prds/`, `tech-specs/`, etc.)
remain on disk untouched. Different git worktrees get independent
`.current` files because `.current` is gitignored.

### 9. Output

On `approve` or `approve_and_continue`:
- The versioned PRD (`wm_prd_path "$slug"`) carries `Status: approved`,
  `Approved by`, `Approved at` in its frontmatter.
- `.yoke/.current` contains exactly `<slug>`.
- `.yoke/runtime/` exists and is empty.
- No flat working-memory files at the legacy paths exist.
- On `approve_and_continue` (after the open-questions warning, when
  applicable, returns `yes`): the skill invokes `/yoke:tech-spec` via
  the `Skill` tool in the same turn. No manual paste is required from
  the user.
- **Fallback when `Skill` tool is unavailable.** Some runtimes do not
  expose the `Skill` tool to a running skill body. The skill MUST
  detect availability before rendering the menu and, when unavailable,
  render option 1 with the suffix `(manual: run /yoke:tech-spec after
  this step)`. On selection of option 1 in fallback mode, the skill
  records approval, prints "PRD approved. Run `/yoke:tech-spec` to
  advance to Phase 2.", and exits cleanly.

On `reject` (after secondary confirmation): the PRD file is deleted,
`.current` is cleared via `wm_clear_active`, and the skill exits
cleanly.

## Pre-conditions

- `.yoke/config.yaml` exists (run `/yoke:bootstrap` first).
- The user provides an idea via the `<idea>` argument or in the dialogue.

## Output contract

- Exit 0 with the versioned PRD populated and approved, and
  `.yoke/.current` containing exactly the slug.
- Exit non-zero on missing `.yoke/config.yaml`, user abort, slug-collision
  exhaustion without user choice, or unrecoverable dialogue stall after
  5 rounds.

## Anti-patterns

- Do NOT advance without explicit user approval.
- Do NOT skip the "challenge at least one point" rule — every PRD must
  push back on at least one vague assumption, missing scope, or
  unrealistic ambition.
- Do NOT read canonical memory directly — must go via `/yoke:ask`.
- Do NOT write to any flat working-memory path. All paths go through
  `lib/working-memory/paths.sh`.
- Do NOT modify any other task's archive files (`tech-specs/<other>.md`,
  `acceptance-contracts/<other>.md`, etc.).
- Do NOT propose colliding slugs by appending numeric suffixes
  (`<term>-2`, `<term>-3`). Regenerate semantically.

## See also

- `.vibeflow/patterns/phase-flow.md` (Phase 1).
- `.vibeflow/patterns/roles.md` (Generator persona).
- `.vibeflow/patterns/human-triggers.md` (Trigger 1).
- `templates/prd.md`.
- `templates/approval-menu.md` (shared menu shape, detection rule, fallback).
