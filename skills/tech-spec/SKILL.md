---
name: tech-spec
description: >
  Phase 2 — Technical specification. Turns an approved PRD into a Tech Spec
  divided into sprints with delivery objectives; each sprint has tasks
  described as use cases with explicit acceptance criteria. Saves to
  `.yoke/tech-spec.md`. Pauses for Trigger 2 approval.
argument-hint: ""
allowed-tools: Read, Write, Edit, Grep, Glob, Task
---

# /yoke:tech-spec — Phase 2 (Technical specification)

Turn an approved PRD into a Tech Spec.

> **Lineage.** Forked from
> [vibeflow:gen-spec](https://github.com/pe-menezes/vibeflow), one-time at
> the start of Yoke v0.2.0. Adaptations: namespaced under `/yoke:*`, switched
> to Yoke's Tech Spec shape (sprints with use-case tasks + per-task
> acceptance criteria + contracts/interfaces + dependencies), wires the
> Generator subagent as the LLM driver, routes canonical-memory queries
> through `/yoke:ask`. Per-skill mapping in `docs/lineage.md` at Sprint 8.

## Process

### 1. Pre-flight

- Verify `.yoke/config.yaml` exists. If not, abort with: "Run `/yoke:bootstrap` first."
- Verify `.yoke/prd.md` exists AND is approved (header carries `Status: approved`). If missing or unapproved, abort with: "PRD missing or unapproved. Run `/yoke:discover` first."
- If `.yoke/tech-spec.md` already exists: offer overwrite, save as `tech-spec-v2.md`, or abort.

### 2. Invoke the Generator subagent

Spawn `agents/generator.md` via the Task tool with:

- The approved `.yoke/prd.md`.
- A reference to `templates/tech-spec.md`.
- Instruction: "Generate a Tech Spec from this PRD. Split work into
  sprints. Each task is a use case with a binary, observable acceptance
  criterion. Consult canonical memory via `/yoke:ask` for relevant
  topology templates."

### 3. Drafting and consultation

The Generator may invoke `/yoke:ask` to find topology templates, prior
decisions, or applicable patterns from canonical memory. All queries are
mediated; the Generator never reads canonical memory directly.

The Generator drafts `.yoke/tech-spec.md` matching `templates/tech-spec.md`:

- ≥ 1 sprint with a delivery objective.
- ≥ 1 task per sprint, described as a use case.
- An explicit acceptance criterion per task (binary, observable).
- Contracts and interfaces (API shapes, data models, integration contracts).
- External and internal dependencies.

### 4. Review

The skill displays the draft and asks the explicit Trigger-2 prompt:

> **Trigger 2 — Tech Spec approval.** This blocks Phase 3. Decision required:
> `approve` / `revise <feedback>` / `back to PRD`.

`back to PRD` aborts the skill and instructs the user to re-run `/yoke:discover`.

### 5. Output

On approve:

- `.yoke/tech-spec.md` is written and approved.
- Print: "Tech Spec approved. Run `/yoke:acceptance-contract` to advance to Phase 3."

## Pre-conditions

- `.yoke/config.yaml` exists.
- `.yoke/prd.md` exists and is approved.

## Output contract

- Exit 0 with `.yoke/tech-spec.md` populated and approved.
- Exit non-zero on missing/unapproved PRD, user abort, or Generator failure.

## Anti-patterns

- Do NOT proceed without an approved PRD — abort immediately.
- Do NOT let the Generator modify `.yoke/prd.md` (Phase 1's artifact).
- Do NOT auto-approve.
- Do NOT let any task have a vague acceptance criterion ("works correctly", "looks good") — every task must be binary and observable.

## See also

- `.vibeflow/patterns/phase-flow.md` (Phase 2).
- `.vibeflow/patterns/roles.md` (Generator).
- `.vibeflow/patterns/human-triggers.md` (Trigger 2).
- `agents/generator.md`.
