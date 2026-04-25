---
name: discover
description: >
  Phase 1 — Discovery. Runs an interactive dialogue (1–5 rounds) to turn an
  idea into an approved PRD with product invariants, business context, known
  constraints, risks, and open questions. Saves to `.yoke/prd.md`. Pauses
  for explicit human approval (Trigger 1) before completing.
argument-hint: "<idea>"
allowed-tools: Read, Write, Edit, Grep, Glob, Task
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
- If `.yoke/prd.md` already exists: ask the user — overwrite, save as `prd-v2.md`, or abort.

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

### 4. Draft and review

The Generator drafts `.yoke/prd.md` per `templates/prd.md`. The skill
displays the draft to the user and asks the explicit Trigger-1 prompt:

> **Trigger 1 — PRD approval.** This blocks Phase 2. Decision required:
> `approve` / `revise <feedback>` / `restart`.

The skill does not return until the user responds explicitly. `revise`
loops back to the Generator for another iteration. `restart` discards the
draft and re-runs the dialogue.

### 5. Idempotency

If `.yoke/prd.md` already existed when the skill started:

- User chose "overwrite": replace `.yoke/prd.md` after approval.
- User chose "save as v2": write `.yoke/prd-v2.md`.
- User chose "abort": exit 0 without changes.

### 6. Output

On approve:

- `.yoke/prd.md` is written and approved (header carries `Status: approved`,
  `Approved by`, `Approved at`).
- Print: "PRD approved. Run `/yoke:tech-spec` to advance to Phase 2."

## Pre-conditions

- `.yoke/config.yaml` exists (run `/yoke:bootstrap` first).
- The user provides an idea via the `<idea>` argument or in the dialogue.

## Output contract

- Exit 0 with `.yoke/prd.md` populated and approved.
- Exit non-zero on missing `.yoke/`, user abort, or Generator failure.

## Anti-patterns

- Do NOT advance without explicit user approval.
- Do NOT skip the "ask at least one clarifying question" rule.
- Do NOT let the Generator read canonical memory directly — must go via `/yoke:ask`.
- Do NOT modify `.yoke/tech-spec.md` (Phase 2's artifact) or `.yoke/acceptance-contract.md` (Phase 3's).

## See also

- `.vibeflow/patterns/phase-flow.md` (Phase 1).
- `.vibeflow/patterns/roles.md` (Generator).
- `.vibeflow/patterns/human-triggers.md` (Trigger 1).
- `agents/generator.md`.
