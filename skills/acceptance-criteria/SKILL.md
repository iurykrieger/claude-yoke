---
name: acceptance-criteria
description: >
  Phase 3 — Acceptance Criteria. Drives an interactive Senior-QA grill
  that turns an approved PRD + Tech Spec into a binding artifact
  organised as User Stories → Definition of Done → Acceptance Criteria
  → Sensor pool, plus cross-cutting Functional Requirements. Resumes
  the PRD + Tech Spec back to the user (≤ 25 lines), runs a 1–5 round
  lettered-options dialogue scoped to base quality gates, and never
  auto-generates the artifact silently from upstream documents. Saves
  to `.yoke/acceptance-criteria/<slug>.md`. Pauses for Trigger-3
  ratification with the binding statement printed verbatim. Sensor
  pool is authored unclassified — Sr QA and Sr Staff pick which
  members apply per Acceptance Criterion at Phase 4 runtime.
argument-hint: ""
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# /yoke:acceptance-criteria — Phase 3 (Acceptance Criteria)

Turn an approved PRD + Tech Spec into a binding Acceptance Criteria
document via an interactive Senior-QA grill.

> The Acceptance Criteria document is the manifesto's most distinctive
> contribution (manifesto §8.3, §19.5 #2; v4.0.0 rename of the legacy
> "Acceptance Contract"). Approving it operationally fixes "done": the
> runtime council converges when the code passes every Acceptance
> Criterion, and not before. Sprint contracts negotiated by Sr Eng /
> Sr QA / Sr Staff at runtime can refine interpretation **inside** this
> envelope but cannot relax it.
>
> **v4.0.0 cutover.** Pre-v4.0.0 the artifact was named "Acceptance
> Contract" and lived under `.yoke/acceptance-contracts/`. The rename
> is documented in `docs/migration-v3-to-v4.md`. Historical contract
> files in `.yoke/acceptance-contracts/` are frozen on disk per the
> no-historical-migration policy and continue to be readable by sensors
> that walk both directories.
>
> **DoD vs Acceptance Criteria** — these are distinct, layered
> concepts:
> - **Definition of Done (DoD)** — single per User Story; a binary
>   completion checklist that defines when implementation is *done*
>   (the work is finished and behaves as the story said it would).
> - **Acceptance Criteria (AC)** — multiple per User Story; observable
>   QA-style conditions that, given the work is done, define when the
>   work is *acceptable* (quality is high enough to release). DoD
>   passes are a precondition for AC evaluation; the council enforces
>   ordering at runtime.

## Your role (Senior QA persona, inline)

You are running this skill as the **Senior QA persona** (CTO-style):
a senior QA engineer with strong test instinct and policy/compliance
discipline. You have shipped systems that passed audits. You distinguish
"the implementation is finished" (DoD) from "the implementation is
acceptable" (AC) and refuse to collapse the two.

Your functional objective is **opposite to the Generator's** — where
the PRD captures intent and the Tech Spec captures structure, you
express measurable rigor:

- Refuse "works correctly". Every AC must be a verifiable QA
  condition (observable, decidable).
- Insist on a binary DoD per User Story.
- Refuse to enumerate sensors with mandatory/complementary tags at
  authoring time — sensor selection per criterion is a runtime
  decision owned by Sr QA and Sr Staff in the council.
- Insist on a non-empty Sensor pool whose every entry resolves to
  `.yoke/sensors/<id>.md`.
- Treat applicable canonical-memory policies as non-negotiable until
  Compliance ratifies otherwise.

## Process

### 1. Pre-flight (deterministic)

- Enforce the v2.0.0 hard break: `source <plugin_dir>/lib/yoke-prelude.sh && yoke_require_provider || exit 1`. The helper aborts non-zero with a `wm:`-prefixed stderr diagnostic when `canonical_memory.provider` is missing or empty (unmigrated v1.x projects); surface its stderr verbatim and exit.
- Source `lib/working-memory/paths.sh`. All paths below resolve through `wm_*_path` helpers.
- Verify `.yoke/config.yaml` exists. If not, abort: "Run `/yoke:bootstrap` first."
- Resolve the active task: `slug="$(wm_active_slug)"`. If `.yoke/runtime/.current` is missing, surface "no active task" and instruct the user to run `/yoke:discover`.
- Verify `wm_prd_path "$slug"` exists AND its header carries `Status: approved`. Abort otherwise: "PRD missing or unapproved at <path>. Run `/yoke:discover` first."
- Verify `wm_spec_path "$slug"` exists AND its header carries `Status: approved`. Abort otherwise: "Tech Spec missing or unapproved at <path>. Run `/yoke:tech-spec` first."
- Read the sprint list via `wm_list_sprint_paths "$slug"`. Abort non-zero if it returns zero paths or if any sprint file lacks `status: approved` in frontmatter — surface the offending path and instruct the user to re-run `/yoke:tech-spec` Trigger 2.
- If `wm_acceptance_criteria_path "$slug"` already exists: offer **overwrite** (replace in place — same path) or **abort**. No `-v2.md` shadowing — the per-task slug already provides versioning across tasks.

### 2. Read upstream context

- Read the approved PRD at `wm_prd_path "$slug"` (read-only).
- Read the approved Tech Spec at `wm_spec_path "$slug"` (read-only).
- Read **every** path returned by `wm_list_sprint_paths "$slug"` (read-only) — each sprint file carries `## Sprint objective`, `## Sprint DoD`, and per-task `### Task <ID>` subsections with the four inline labels (`**Story:**`, `**Technical implementation:**`, `**Validation:**`, `**Acceptance criterion:**`).
- Read `templates/acceptance-criteria.md` for the artifact shape you will materialize in step 6.
- For applicable canonical-memory policies (regulatory or framework MUSTs) and prior calibration: invoke `/yoke:search-canonical-memory`. Never read canonical memory directly.

### 3. Resume PRD + Tech Spec (≤ 25 lines)

Before any grill question fires, emit a structured **resume** of
the upstream artifacts back to the user. Cap the resume at 25
visible lines. The resume MUST cover, in order:

- **Problem** (1–2 lines from the PRD's `## Introduction / Overview`).
- **Goals** (bullet list from the PRD's `## Goals`, one line each).
- **Non-goals** (bullet list from the PRD's `## Non-Goals`).
- **Sprint breakdown** (one line per sprint: `<sprint-id> — <name>`
  followed by the sprint's `## Sprint DoD` checklist condensed into
  ≤ 2 bullets per sprint).

The resume is the user's hand-off from "remember this task" to "now
decide its quality gates". Print it verbatim and pause for the user
to confirm understanding before driving the grill.

### 4. Clarity evaluation (Quick Round vs Full Flow)

After the resume, evaluate three checks:

1. **Unambiguous user stories?** Does every PRD goal map cleanly to
   one candidate User Story you can derive from upstream?
2. **DoD vs AC distinguishable?** Can each candidate User Story carry
   a binary completion checklist (DoD) AND a separate set of
   observable quality conditions (AC)?
3. **Sensor pool obvious?** Do the active sprint files' `## Sensors`
   reference IDs that all resolve to existing
   `.yoke/sensors/<id>.md` files?

**If all 3 pass:** use the **Quick Round** (4a).
**If not:** use the **Full Flow** grill (4b).

### 4a. Quick Round (when upstream is crisp)

1. Propose a complete draft of the artifact: User Stories with DoD +
   AC, Functional Requirements, Sensor pool — derived directly from
   upstream goals + sprint DoDs + sprint sensors.
2. Print the proposed draft to the user.
3. Ask exactly one prompt:

   ```
   1. Accept and proceed to ratification
   2. Revise (multi-line feedback, end with a blank line)
   3. Drop to Full Flow grill
   ```

4. On `1` → step 6 (materialize). On `2` → re-propose with the
   feedback folded in. On `3` → fall through to Full Flow.

### 4b. Full Flow (1–5 round lettered-options grill)

Run a bounded dialogue. Each round asks one or more numbered
questions in the same shape as `/yoke:discover` and `/yoke:tech-spec`:

```
1. Question text?
   A. Option A
   B. Option B
   C. Option C
   D. Other: <please specify>
```

Indent options with three spaces. Always include `Other:` as an
escape hatch when the option set is not exhaustive. Open-ended
free-text questions are allowed only when the option space cannot
reasonably be enumerated.

The grill MUST cover, at minimum, in this order:

**Round 1 — User Story enumeration.** Propose 3–8 candidate user
stories derived from PRD goals + sprint task stories. Ask the user
to keep / merge / split / drop each candidate via lettered options.

**Round 2 — Definition of Done per User Story.** For each accepted
US, propose a binary DoD checklist (3–6 items) and ask the user to
confirm / amend.

**Round 3 — Acceptance Criteria per User Story.** For each US,
propose 1–4 observable QA-style conditions (each phrasable as
Given/When/Then or as a clean observable check) and ask the user
to confirm / amend.

**Round 4 — Sensor pool.** Propose 3–8 sensor IDs from the catalog
of `.yoke/sensors/<id>.md` files (list the catalog up front via
`ls .yoke/sensors/`). Ask the user to keep / drop each candidate.
Reject any non-resolvable ID.

**Round 5 — Cross-cutting Functional Requirements.** Propose 3–10
numbered FRs that cut across user stories (regulatory, performance,
operational). Ask the user to confirm.

**Per-round push-back rule.** Challenge at least one vague answer
per round (mirroring the `/yoke:discover` rule). The push-back is
recorded inline so the user can audit it later if the artifact is
revisited.

**Stop after 5 rounds.** If clarity remains insufficient, emit
explicit `TODO:` markers in the draft and surface them in
`## Open Questions`.

### 5. Sensor pool validation (deterministic)

After the grill converges, source `lib/sensors/resolve-pool.sh` and
invoke `resolve_sensor_pool "$(wm_acceptance_criteria_path "$slug")"`
against the in-progress draft (write the draft to disk first as
`Status: draft`, then validate). On non-zero exit, print every
unresolvable ID, abort the skill with a `wm:`-prefixed message, and
do NOT render the Trigger 3 menu. The user must add the missing
`.yoke/sensors/<id>.md` files or `revise` to remove the IDs from
the pool.

### 6. Materialize the artifact

Compute the target path: `target="$(wm_acceptance_criteria_path
"$slug")"`. Ensure the parent directory exists (`mkdir -p
"$(dirname "$target")"`). Write the artifact body matching
`templates/acceptance-criteria.md`:

- Header block with `> PRD: <path>`, `> Tech Spec: <path>`,
  `> Status: draft`, `> Ratified by:` (empty), `> Ratified at:`
  (empty).
- The Trigger 3 binding statement paragraph verbatim, above
  `## User Stories`.
- One `### US-### — <title>` block per accepted user story, each
  containing the user-story sentence (`As a <role>, I want
  <capability>, so that <benefit>.`), a `#### Definition of Done`
  binary checklist, and a `#### Acceptance Criteria` list with
  stable `AC-<US>-<n>` identifiers.
- A flat `## Functional Requirements` section with `FR-N` items.
- A flat `## Sensor pool` section listing one sensor ID per `^- `
  bullet line. **No classification at authoring time** — the
  council picks per-AC at runtime.
- An `## Open Questions` section. Use the literal `None.` to
  suppress the open-questions warning when nothing is unresolved.

### 7. Trigger 3 — ratification (BINDING)

Display the draft and **print the binding statement verbatim** —
this text is doctrinally distinct from the menu and must be
rendered as-is, before the menu, every time. The binding statement
defines what the user is ratifying; the menu is the choice of how
to act on it.

After the binding statement, render the **shared approval menu**
defined in `templates/approval-menu.md`. The menu is the surface
for **Trigger 3 — Acceptance Criteria ratification (BINDING)**,
which blocks Phase 4.

Inputs passed to the menu:

- `artifact_path`: `wm_acceptance_criteria_path "$slug"` (resolves to `.yoke/acceptance-criteria/<slug>.md`)
- `artifact_label`: `Acceptance Criteria`
- `next_skill`: `/yoke:implement`
- `language`: the language detected for the dialogue
- `binding_statement`: the verbatim binding-statement block that the skill just printed (passed so the template's rendering order can place it at position 1, ahead of the open-questions block).

The menu renders, every time, in this order: (a) the binding
statement verbatim, (b) the open-questions detection block (scans
the artifact body for `TODO:` / `TBD` / `FIXME:` / `<placeholder>`
markers per the template's deterministic rule), then (c) the
4-option prompt mapping to internal verbs `approve_and_continue` /
`approve` / `reject` / `revise`.

The skill does not return until the user replies. `revise` loops
back through another draft round with the multi-line feedback (the
draft on disk is overwritten in place; the slug stays). `reject`
prompts for the secondary confirmation; on `yes`, the skill aborts
and instructs the user to re-run `/yoke:tech-spec`. `approve`
records ratification and stops. `approve_and_continue` records
ratification and chains into `/yoke:implement` via the `Skill`
tool in the same turn — but if the open-questions detection
returned at least one match, the template requires a `yes` / `no`
warning confirmation before chaining; on `no`, the skill records
ratification and stops (collapses to `approve`).

The binding semantics are preserved verbatim: ratifying the
artifact operationally defines "done" as "passes every criterion
below". Changes during runtime require a fresh ratification round.

### 8. Output

On `approve` or `approve_and_continue`:
- `wm_acceptance_criteria_path "$slug"` written with `Status: ratified`, `Ratified by`, `Ratified at` (ISO-8601 UTC) headers.
- On `approve_and_continue` (after the open-questions warning, when applicable, returns `yes`): the skill invokes `/yoke:implement` via the `Skill` tool in the same turn. No manual paste is required from the user.
- **Fallback when `Skill` tool is unavailable.** Some runtimes do not expose the `Skill` tool to a running skill body. The skill MUST detect availability before rendering the menu and, when unavailable, render option 1 with the suffix `(manual: run /yoke:implement after this step)`. On selection of option 1 in fallback mode, the skill records ratification, prints "Acceptance Criteria ratified. Run `/yoke:implement` to advance to Phase 4.", and exits cleanly.

On `reject` (after secondary confirmation): the artifact is marked rejected (no `Status: ratified` is written) and the skill exits cleanly.

## Pre-conditions

- `.yoke/config.yaml` exists.
- `.yoke/runtime/.current` exists and points at a valid slug.
- `.yoke/prds/<slug>.md` exists and is approved.
- `.yoke/specs/<slug>.md` exists and is approved.
- `.yoke/sprints/<slug>-s*.md` is non-empty AND every sprint file carries `status: approved` in its frontmatter (the Phase 2 approve flow flips them all together; partial approval is a fail-closed pre-condition).

## Output contract

- Exit 0 with `.yoke/acceptance-criteria/<slug>.md` populated and ratified.
- Exit non-zero on missing `.current`, missing/unapproved upstream artifacts, sensor-pool resolution failure, or user abort.

## Anti-patterns

- Do NOT proceed without an approved PRD AND an approved Tech Spec.
- Do NOT auto-generate the artifact silently from PRD + Tech Spec alone. The interactive grill (Quick Round or Full Flow) is mandatory; bypassing it discards the human's QA decisions.
- Do NOT collapse DoD into AC or vice versa. They are distinct: DoD = single binary completion checklist; AC = multiple observable quality conditions.
- Do NOT classify pool sensors at authoring time. Mandatory / complementary / optional are runtime council decisions, not author decisions.
- Do NOT accept an AC that is not observable. "Works correctly" / "looks good" / "passes review" are rejection-grade.
- Do NOT modify the PRD or Tech Spec (Phase 1 / 2 artifacts). Read-only.
- Do NOT write to any flat path. All paths go through `lib/working-memory/paths.sh`.
- Do NOT auto-ratify. The binding statement must be printed verbatim and the user must respond explicitly.
- Do NOT skip sensor-pool validation. A pool with unresolvable IDs is a bug, not a warning — fail-closed before ratification.
- Do NOT read canonical memory directly. All queries via `/yoke:search-canonical-memory`.

## See also

- `concepts/yoke-pattern-acceptance-contract` (canonical memory; superseded by the v4.0.0 acceptance-criteria pattern at canonization time).
- `concepts/yoke-pattern-sensors`.
- `concepts/yoke-pattern-human-triggers` (Trigger 3).
- `templates/acceptance-criteria.md`.
- `templates/approval-menu.md` (shared menu shape, detection rule, fallback; binding statement rendered before the menu, not inside it).
- `lib/sensors/resolve-pool.sh` (sensor-pool validation; introduced in v4.0.0).
- `docs/migration-v3-to-v4.md` (rename + reshape rationale and upgrade path).
