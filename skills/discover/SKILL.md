---
name: discover
description: >
  Phase 1 — Discovery. Runs an interactive dialogue (1–5 rounds) to turn an
  idea into an approved PRD with product invariants, business context, known
  constraints, risks, and open questions. Saves to
  `.yoke/prds/<YYYY-MM-DD>-<slug>.md` and sets `.yoke/.current` to the slug.
  Pauses for explicit human approval (Trigger 1) before completing.
argument-hint: "<idea>"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /yoke:discover — Phase 1 (Discovery)

Turn an idea in natural language into an approved PRD.

> **Lineage.** This skill is forked from
> [vibeflow:discover](https://github.com/pe-menezes/vibeflow), one-time at
> the start of Yoke v0.2.0. Adaptations: namespaced under `/yoke:*`, switched
> to Yoke's PRD shape (product invariants / business context / constraints /
> risks / open questions instead of Vibeflow's problem / audience / solution
> shape), wires the Generator subagent as the LLM driver, routes any
> canonical-memory queries through `/yoke:ask`. Per-skill mapping recorded
> in `docs/lineage.md` at Sprint 8.

## Process

### 1. Pre-flight

- Verify `.yoke/config.yaml` exists. If not, abort with: "Run `/yoke:bootstrap` first."
- Source the path helper: `source lib/working-memory/paths.sh`. Every path constructed below goes through `wm_*_path` functions; never concatenate paths under `.yoke/` by hand.

### 2. Invoke the Generator subagent

Spawn `agents/generator.md` via the Task tool with:

- The idea text the user provided.
- A reference to `templates/prd.md` for the output shape.
- Instruction: "Run a discovery dialogue with the user. Ask clarifying
  questions. Cut scope aggressively. Challenge vague assumptions. Produce
  a draft PRD."

### 3. Dialogue

The Generator runs the dialogue. Per its persona, it must ask at least one
clarifying question before drafting. Allowed tools include `/yoke:ask` for
canonical-memory consultation (mediated). The Generator never reads
canonical memory directly.

If the user's first response gives full clarity, the Generator may
fast-track to a 2-round dialogue (summarize understanding + 1–2 challenges
+ generate PRD). Otherwise the Generator runs the full 3–5 round flow.

### 4. Slug proposal and collision resolution

When the Generator is ready to write the PRD draft (after the dialogue
converges on a title), it proposes a slug:

1. Compose `<YYYY-MM-DD>-<slug>` using local-time date and a kebab-case
   slug derived from the PRD title (lowercase, ≤ 50 chars after the date
   prefix, matching `wm_validate_slug`'s regex).
2. Check for collision: if `wm_slug_in_use "<candidate>"` returns 0, the
   slug is taken. Ask the Generator to regenerate a *semantically
   equivalent but lexically distinct* slug (e.g., `auth-flow` →
   `auth-pipeline` → `signin-handler`). No deterministic numeric
   suffixes. Repeat up to 5 attempts.
3. If 5 attempts all collide, surface the candidate list to the user and
   ask for an explicit choice.
4. Show the chosen slug to the user for one-line confirmation before
   writing files.

See the "Slug collision protocol" block in `agents/generator.md` for the
agent-side contract.

### 5. Materialize the new task

After slug confirmation:

1. `wm_wipe_runtime` — clear any leftover state in `.yoke/runtime/` from
   a previous interrupted task. Idempotent.
2. `mkdir -p "$(dirname "$(wm_prd_path "<slug>")")"` — lazily create
   `.yoke/prds/`.
3. The Generator writes the PRD draft to `wm_prd_path "<slug>"` (the
   versioned PRD file).
4. `wm_set_active "<slug>"` — write the slug to `.yoke/.current` (no
   trailing newline).

### 6. Draft and review

The skill displays the draft to the user and asks the explicit Trigger-1 prompt:

> **Trigger 1 — PRD approval.** This blocks Phase 2. Decision required:
> `approve` / `revise <feedback>` / `restart`.

The skill does not return until the user responds explicitly. `revise`
loops back to the Generator for another iteration on the same file.
`restart` discards the draft (delete the PRD file, clear `.current`) and
re-runs the dialogue from Step 2 — a fresh slug is proposed.

### 7. Approval

On approve:

- The versioned PRD file (`wm_prd_path`) carries `Status: approved`,
  `Approved by`, `Approved at` in its frontmatter.
- `.yoke/.current` contains exactly `<slug>`.
- `.yoke/runtime/` exists and is empty.
- No flat working-memory files like the legacy singular PRD path exist.
- Print: "PRD approved. Run `/yoke:tech-spec` to advance to Phase 2."

### 8. Re-invocation semantics

Every `/yoke:discover` invocation starts a *new* task. There is no
"continue active task" branch. If `.yoke/.current` exists when the skill
starts, it will be overwritten with the new slug after Step 5; the
previous task's archive files (in `prds/`, `tech-specs/`, etc.) remain
on disk untouched. Different git worktrees get independent `.current`
files because `.current` is gitignored.

## Pre-conditions

- `.yoke/config.yaml` exists (run `/yoke:bootstrap` first).
- The user provides an idea via the `<idea>` argument or in the dialogue.

## Output contract

- Exit 0 with the versioned PRD populated and approved, and `.yoke/.current` containing exactly `<slug>`.
- Exit non-zero on missing `.yoke/config.yaml`, user abort, slug-collision exhaustion without user choice, or Generator failure.

## Anti-patterns

- Do NOT advance without explicit user approval.
- Do NOT skip the "ask at least one clarifying question" rule.
- Do NOT let the Generator read canonical memory directly — must go via `/yoke:ask`.
- Do NOT write to any flat working-memory path. All paths go through `lib/working-memory/paths.sh`.
- Do NOT modify any other task's archive files (`tech-specs/<other>.md`, `acceptance-contracts/<other>.md`, etc.).
- Do NOT propose colliding slugs by appending numeric suffixes (`<term>-2`, `<term>-3`). Regenerate semantically.

## See also

- `.vibeflow/patterns/phase-flow.md` (Phase 1).
- `.vibeflow/patterns/roles.md` (Generator).
- `.vibeflow/patterns/human-triggers.md` (Trigger 1).
- `agents/generator.md`.
