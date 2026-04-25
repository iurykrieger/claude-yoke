---
name: tech-spec
description: >
  Phase 2 — Technical specification. Turns an approved PRD into a Tech
  Spec divided into sprints with delivery objectives; each sprint has
  tasks described as use cases with explicit acceptance criteria. Saves
  to `.yoke/tech-specs/<slug>.md`, where <slug> comes from
  `.yoke/.current`. Pauses for Trigger 2 approval.
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

- Source `lib/working-memory/paths.sh`. All paths below resolve through `wm_*_path`.
- Verify `.yoke/config.yaml` exists. If not, abort: "Run `/yoke:bootstrap` first."
- Resolve the active task: `slug="$(wm_active_slug)"`. If `.yoke/.current` is missing, the helper aborts with "no active task" — surface that and instruct the user to run `/yoke:discover`.
- Verify `wm_prd_path "$slug"` exists AND is approved (header carries
  `Status: approved`). If missing or unapproved, abort: "PRD missing
  or unapproved at <path>. Run `/yoke:discover` first."
- If `wm_tech_spec_path "$slug"` already exists: offer overwrite (replace in place — same path) or abort. No `tech-spec-v2.md` shadowing — the per-task slug already provides versioning across tasks.

### 2. Read upstream context

- Read the approved PRD at `wm_prd_path "$slug"` (read-only).
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

Ensure `.yoke/tech-specs/` exists (`mkdir -p "$(dirname "$(wm_tech_spec_path "$slug")")"`). Draft the spec at `wm_tech_spec_path "$slug"` (i.e., `.yoke/tech-specs/<slug>.md`) matching `templates/tech-spec.md`:

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

Display the draft and ask the explicit Trigger-2 prompt:

> **Trigger 2 — Tech Spec approval.** This blocks Phase 3. Decision
> required: `approve` / `revise <feedback>` / `back to PRD`.

`back to PRD` aborts the skill and instructs the user to re-run
`/yoke:discover` (which would create a *new* task with a new slug;
the current task stays archived as PRD-only). The skill does not
return until the user responds explicitly.

### 6. Output

On `approve`:
- `wm_tech_spec_path "$slug"` written with `Status: approved`,
  `Approved by`, `Approved at` headers.
- Print: "Tech Spec approved. Run `/yoke:acceptance-contract` to
  advance to Phase 3."

## Pre-conditions

- `.yoke/config.yaml` exists.
- `.yoke/.current` exists and points at a valid slug.
- `.yoke/prds/<slug>.md` exists and is approved.

## Output contract

- Exit 0 with `.yoke/tech-specs/<slug>.md` populated and approved.
- Exit non-zero on missing `.current`, missing/unapproved PRD, user abort, or revise loop
  exhaustion.

## Anti-patterns

- Do NOT proceed without an approved PRD — abort immediately.
- Do NOT modify the PRD (`.yoke/prds/<slug>.md` is Phase 1's artifact). Read-only.
- Do NOT write to any flat path. All paths go through `lib/working-memory/paths.sh`.
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
