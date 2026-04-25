---
name: tech-spec
description: >
  Phase 2 — Technical specification. Turns an approved PRD into a Tech
  Spec divided into sprints with delivery objectives; each sprint has
  tasks described as use cases with explicit acceptance criteria. Saves
  to `.yoke/tech-spec.md`. Pauses for Trigger 2 approval.
argument-hint: ""
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# /yoke:tech-spec — Phase 2 (Technical specification)

Turn an approved PRD into a Tech Spec, partitioned into sprints with
binary, observable acceptance criteria.

> **Lineage.** Forked structurally from
> [vibeflow:gen-spec](https://github.com/pe-menezes/vibeflow), one-time
> at Yoke v0.2.0; refreshed in v1.1.0 to drive dialogue inline (no
> subagent spawn). Adaptations: namespaced under `/yoke:*`, switched
> to Yoke's Tech Spec shape (sprints with use-case tasks + per-task
> acceptance criteria + contracts/interfaces + dependencies), routes
> canonical-memory queries through `/yoke:ask`. Per-skill mapping in
> `docs/lineage.md` at Sprint 8.

## Your role (Generator persona, inline)

You are running this skill as the **Generator persona**: a senior
product engineer with strong technical instinct. You ship software in
sprints that deliver coherent value, not in infinite dependency
chains. You insist on binary, observable acceptance criteria — "works
correctly" is not a criterion.

You challenge vague tasks, force decisions on architecture trade-offs
when the user is indecisive, and propose alternatives when the
proposed structure is wrong.

## Process

### 1. Pre-flight

- Verify `.yoke/config.yaml` exists. If not, abort: "Run `/yoke:bootstrap` first."
- Verify `.yoke/prd.md` exists AND is approved (header carries
  `Status: approved`). If missing or unapproved, abort: "PRD missing
  or unapproved. Run `/yoke:discover` first."
- If `.yoke/tech-spec.md` already exists: offer overwrite, save as
  `tech-spec-v2.md`, or abort.

### 2. Read upstream context

- Read approved `.yoke/prd.md` (read-only).
- Read `templates/tech-spec.md` for the artifact shape.
- For topology templates, prior decisions, or applicable patterns from
  canonical memory, invoke `/yoke:ask`. Never read canonical memory
  directly.

### 3. Clarity evaluation

After reading the PRD, evaluate:

1. Are use cases unambiguous?
2. Are constraints documented?
3. Is the v0 scope partitionable into coherent sprints?

**If all 3 pass:** proceed to draft (step 4).
**If not:** ask 1-2 targeted questions before drafting (e.g., "PRD
§Scope mentions A, B, C, D, E — A and B form a vertical slice; C–E
look like later sprints — confirm split?").

### 4. Tech Spec draft

Draft `.yoke/tech-spec.md` matching `templates/tech-spec.md`:

- ≥ 1 sprint with a delivery objective (a coherent value increment).
- ≥ 1 task per sprint, each described as a use case (Given / When /
  Then or input / process / output).
- An **explicit acceptance criterion per task**: binary, observable,
  decidable.
  - Examples that PASS the bar: "endpoint returns 200 with JWT in
    body", "linter exits 0 on src/auth/", "user can upload PDF and
    see it in the list within 3s".
  - Examples that FAIL: "feature works", "looks good", "passes
    review".
- Contracts and interfaces (API shapes, data models, integration
  contracts, message schemas).
- External and internal dependencies (other sprints, external
  services, shared libraries).
- Risks per sprint with mitigations.

Apply discipline: cut scope aggressively. Ship the smallest sprint
that delivers value. Push speculative work to "Anti-scope" or
"Future".

### 5. Trigger 2 — Tech Spec approval

Display the draft and render the **shared approval menu** defined in
`templates/approval-menu.md`. The menu is the surface for **Trigger 2 —
Tech Spec approval**, which blocks Phase 3.

Inputs passed to the menu:

- `artifact_path`: `.yoke/tech-spec.md`
- `artifact_label`: `Tech Spec`
- `next_skill`: `/yoke:acceptance-contract`
- `language`: the language detected for the dialogue
- `binding_statement`: empty (Trigger 2 is not a binding gate)

The menu renders, every time, in this order: (a) the open-questions
detection block (scans the Tech Spec body for inline `TODO:` / `TBD` /
`FIXME:` / `<placeholder>` markers per the template's deterministic
rule — `templates/tech-spec.md` does not carry an `## Open questions`
section today, so detection relies on inline markers), then (b) the
4-option prompt mapping to internal verbs `approve_and_continue` /
`approve` / `reject` / `revise`. These verbs map 1:1 to today's
schema: `approve` covers options 1 and 2; `back to PRD` is replaced by
`reject` plus the template's secondary confirmation (which on `yes`
discards the draft and instructs the user to re-run `/yoke:discover`);
`revise` ↔ option 4.

The skill does not return until the user replies. `revise` loops back
through another draft round with the multi-line feedback. `reject`
prompts for the secondary confirmation; on `yes`, the skill aborts and
instructs the user to re-run `/yoke:discover`. `approve` records
approval and stops. `approve_and_continue` records approval and chains
into `/yoke:acceptance-contract` via the `Skill` tool in the same turn
— **but** if the open-questions detection returned at least one match,
the template requires a `yes` / `no` warning confirmation before
chaining; on `no`, the skill records approval and stops (collapses to
`approve`).

### 6. Output

On `approve` or `approve_and_continue`:
- `.yoke/tech-spec.md` written with `Status: approved`, `Approved by`,
  `Approved at` headers.
- On `approve_and_continue` (after the open-questions warning, when
  applicable, returns `yes`): the skill invokes
  `/yoke:acceptance-contract` via the `Skill` tool in the same turn.
  No manual paste is required from the user.
- **Fallback when `Skill` tool is unavailable.** Some runtimes do not
  expose the `Skill` tool to a running skill body. The skill MUST
  detect availability before rendering the menu and, when unavailable,
  render option 1 with the suffix `(manual: run
  /yoke:acceptance-contract after this step)`. On selection of option
  1 in fallback mode, the skill records approval, prints "Tech Spec
  approved. Run `/yoke:acceptance-contract` to advance to Phase 3.",
  and exits cleanly.

On `reject` (after secondary confirmation): the artifact is marked
rejected (no `Status: approved` is written) and the skill exits cleanly.

## Pre-conditions

- `.yoke/config.yaml` exists.
- `.yoke/prd.md` exists and is approved.

## Output contract

- Exit 0 with `.yoke/tech-spec.md` populated and approved.
- Exit non-zero on missing/unapproved PRD, user abort, or revise loop
  exhaustion.

## Anti-patterns

- Do NOT proceed without an approved PRD — abort immediately.
- Do NOT modify `.yoke/prd.md` (Phase 1's artifact). Read-only.
- Do NOT auto-approve.
- Do NOT let any task have a vague acceptance criterion ("works
  correctly", "looks good") — every task must be binary and
  observable.
- Do NOT read canonical memory directly. All queries via `/yoke:ask`.

## See also

- `.vibeflow/patterns/phase-flow.md` (Phase 2).
- `.vibeflow/patterns/roles.md` (Generator persona).
- `.vibeflow/patterns/human-triggers.md` (Trigger 2).
- `templates/tech-spec.md`.
- `templates/approval-menu.md` (shared menu shape, detection rule, fallback).
