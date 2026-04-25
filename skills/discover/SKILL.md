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
displays the draft to the user and renders the **shared approval menu**
defined in `templates/approval-menu.md`. The menu is the surface for
**Trigger 1 — PRD approval**, which blocks Phase 2.

Inputs passed to the menu:

- `artifact_path`: `.yoke/prd.md`
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

The skill does not return until the user replies. `revise` loops back to
the Generator with the multi-line feedback. `reject` prompts for a
single secondary confirmation before discarding the draft. `approve`
records approval and stops. `approve_and_continue` records approval and
chains into `/yoke:tech-spec` via the `Skill` tool in the same turn —
**but** if the open-questions detection returned at least one match, the
template requires a `yes` / `no` warning confirmation before chaining;
on `no`, the skill records approval and stops (collapses to `approve`).

### 5. Idempotency

If `.yoke/prd.md` already existed when the skill started:

- User chose "overwrite": replace `.yoke/prd.md` after approval.
- User chose "save as v2": write `.yoke/prd-v2.md`.
- User chose "abort": exit 0 without changes.

### 6. Output

On `approve` or `approve_and_continue`:

- `.yoke/prd.md` is written and approved (header carries `Status: approved`,
  `Approved by`, `Approved at`).
- On `approve_and_continue` (after the open-questions warning, when
  applicable, returns `yes`): the skill invokes `/yoke:tech-spec` via the
  `Skill` tool in the same turn. No manual paste is required from the user.
- **Fallback when `Skill` tool is unavailable.** Some runtimes (older Claude
  Code versions, non-Claude harnesses) do not expose the `Skill` tool to a
  running skill body. The skill MUST detect availability before rendering
  the menu and, when unavailable, render option 1 with the suffix
  `(manual: run /yoke:tech-spec after this step)`. On selection of option
  1 in fallback mode, the skill records approval, prints
  "PRD approved. Run `/yoke:tech-spec` to advance to Phase 2.", and exits
  cleanly. This preserves today's behavior verbatim on degraded runtimes.

On `reject` (after secondary confirmation): the artifact is marked rejected
(no `Status: approved` is written) and the skill exits cleanly.

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
- `templates/approval-menu.md` (shared menu shape, detection rule, fallback).
- `agents/generator.md`.
