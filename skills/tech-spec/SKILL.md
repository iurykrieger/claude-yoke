---
name: tech-spec
description: >
  Phase 2 — Technical specification (design doc). Turns an approved PRD
  into a single-file design doc at `.yoke/specs/<slug>.md` carrying the
  twelve canonical H2 sections (Context and Scope; Goals and Non-Goals;
  System Context; Architecture; Stack and Dependencies; APIs and Data
  Model; Non-Functional Requirements; Alternatives Considered;
  Trade-offs; Cross-cutting Concerns; Technical Use Cases; Open
  Questions). Negotiates stack via host-project auto-detection plus a
  curated market menu by feature category, queries canonical memory
  for applicable architectural patterns first and falls back to
  `WebSearch` only when fewer than the configured threshold of pattern
  entities is returned. Phase 2 NEVER writes any sprint file and NEVER
  emits a `### Task <ID>` anchor — sprint partition + task breakdown
  are owned by Phase 3 (`/yoke:acceptance-criteria`). Pauses for
  Trigger 2 approval, which marks only the spec.
argument-hint: ""
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# /yoke:tech-spec — Phase 2 (Technical specification — design doc)

Turn an approved PRD into a single-file architectural design doc — the
spec **is** the architectural decision record (Nygard / MADR shape:
context, decision, alternatives, consequences encoded across the
twelve H2 sections). Phase 2 produces no sprint files and no task
anchors; sprint partition lives in Phase 3.

> **Lineage.** v0.2.0 forked structurally from
> [vibeflow:gen-spec](https://github.com/pe-menezes/vibeflow); v1.1.0
> drove dialogue inline (no subagent spawn); the `tech-spec-task-split`
> rollout (Part 2) and the `sprint-as-cycle` rollout grew a 3-stage
> blueprint that emitted sprint files. Per the
> 2026-05-03-tech-spec-as-design-doc PRD + Spec, the 3-stage blueprint
> is retired: stages 2 (sprint-file scaffolder) and 3 (LLM-per-sprint
> fill) move to `/yoke:acceptance-criteria`. This skill is now a
> single LLM stage wrapping a deterministic post-draft self-check.
> Per-skill mapping in `docs/lineage.md`.

## Your role (Senior Engineer persona, inline)

You are running this skill as the **Senior Engineer persona** (CTO-
style): a technical lead who has shipped systems in real production.
You translate product intent into architecture you can defend. You
force framework / library choices to be named with explicit
trade-offs, you refuse adjective-only NFRs, and you insist on
quantitative targets — "performant" is not a non-functional
requirement.

You produce a design doc that reads as an architectural decision
record. You do not partition delivery into sprints (Phase 3 does
that). You do not emit task anchors (Phase 3 does that). You force
every alternative considered to carry a trade-off, a reason for
rejection, and a source — canonical-memory wikilink, WebSearch URL
that actually appeared in this session, or `internal experience`.

## The blueprint (single LLM stage + deterministic post-draft self-check)

This skill is a **blueprint wrapping agentic nodes** per
`concepts/yoke-conventions`:

1. **Stage 1 — LLM (dialogue + draft).** You (Senior Engineer
   persona) run four dialogue rounds (stack, architecture, NFRs,
   use-cases) and then draft `.yoke/specs/<slug>.md` end-to-end in a
   single `Write` call.
2. **Stage 2 — bash (deterministic post-draft self-check).** A
   sequence of `grep`s validates the twelve H2 sections in order, the
   quantitative-NFR regex, the `### Alt:` triple-shape, the US-###
   lift, the absence of `### Task` anchors, and the absence of
   sprint files. Any failure aborts the skill non-zero with a
   `wm:`-prefixed message naming the offending location.

Phase 2 produces exactly one file (`.yoke/specs/<slug>.md`) and zero
files under `.yoke/sprints/`. This is enforced both by the dialogue
discipline (no sprint round) and by the post-draft self-check
(filesystem assertion). Cite `concepts/yoke-pattern-phase-flow` —
Phase 2 still produces tech-spec.md as the binding artifact; sprint
files are downstream Phase-3 outputs and do not change the phase-flow
shape.

## Process

### 1. Pre-flight

- Enforce the v2.0.0 hard break: `source <plugin_dir>/lib/yoke-prelude.sh && yoke_require_provider || exit 1`. The helper aborts non-zero with a stderr diagnostic when `canonical_memory.provider` is missing or empty (unmigrated v1.x projects); surface its stderr verbatim and exit.
- Source `<plugin_dir>/lib/working-memory/paths.sh`. All paths below
  resolve through `wm_*` helpers.
- Source `<plugin_dir>/lib/config-overrides.sh`. `yoke_get_override`
  is consumed in step 5 (architecture round) to read the
  canonical-pattern threshold.
- Verify `.yoke/config.yaml` exists. If not, abort: "Run
  `/yoke:bootstrap` first."
- Resolve the active task: `slug="$(wm_active_slug)"`. If
  `.yoke/runtime/.current` is missing, the helper aborts with "no
  active task" — surface that and instruct the user to run
  `/yoke:discover`.
- Verify `wm_prd_path "$slug"` exists AND is approved (header carries
  `Status: approved`). If missing or unapproved, abort: "PRD missing
  or unapproved at <path>. Run `/yoke:discover` first."
- If `wm_spec_path "$slug"` already exists: offer **overwrite**
  (delete + rewrite — see step 9) or **abort**. No `-v2.md`
  shadowing. **Never** check or touch `wm_list_sprint_paths "$slug"`
  here — Phase 2 has nothing to do with sprint files; if any exist,
  they belong to a prior Phase 3 run on this slug.

### 2. Read upstream context

- Read the approved PRD at `wm_prd_path "$slug"` (read-only).
- Read `<plugin_dir>/templates/spec.md` for the twelve-section
  design-doc shape (this skill writes that shape; deviations break the
  post-draft self-check).
- For applicable architectural patterns from canonical memory, invoke
  `/yoke:search-canonical-memory` (see step 5). Never read canonical
  memory directly.

### 3. Stack auto-detection (host-project signal)

Read the following manifest files via the `Read` tool when present
(skip absent files; never use `cat`):

- `package.json` → Node.js / TypeScript family
- `go.mod` → Go family
- `Cargo.toml` → Rust family
- `requirements.txt` → Python family (pip)
- `pyproject.toml` → Python family (modern)
- `pom.xml` → Java / JVM family
- `Gemfile` → Ruby family

Capture the detected stack signature for the dialogue's default
offer in step 4. When **two or more** manifest types are detected
(polyglot repo), do NOT auto-pick — the dialogue round in step 4 must
list every detected stack as a candidate and force the user to reply.

### 4. Round 1 — stack negotiation

Render a curated stack menu **by feature category** with 3-5 lettered
options + an `Other:` escape. The category itself is inferred from
the PRD's Goals / User Stories (web-api / web-ui / cli / library /
data-pipeline). The menu shape is:

```
Stack — pick the family that matches this work (auto-detected default
in **bold**):

1A. **<auto-detected default — e.g. bash 4+ / shell helpers>**
1B. <market-default option for the inferred category>
1C. <market-default option>
1D. <market-default option>
1E. Other: <your free-text>
```

Print the auto-detected default in **bold** when exactly one manifest
type was detected; print every detected stack as a candidate (1A,
1B, …) when ≥ 2 manifests were detected (no auto-pick on polyglot
repos). The `Other:` escape captures stacks the curated menu does not
list. Wait for a single response. Capture the choice; record it for
the spec's `## Stack and Dependencies` section.

### 5. Round 2 — architecture (canonical-memory first, WebSearch as fallback)

Lift the feature's domain phrase from the PRD's Introduction /
Overview (one-line scope statement). Invoke
`/yoke:search-canonical-memory` via the `Skill` tool with a
domain-scoped query: `"applicable architectural patterns for
<domain phrase>"`. Count the **pattern-typed entities** in the
response (entries whose entity type is `pattern` —
`concepts/yoke-pattern-*`).

Resolve the threshold:

```
threshold="$(yoke_get_override overrides.tech_spec.canonical_pattern_threshold 3)"
```

If `pattern_count >= threshold`, **skip** WebSearch. Surface the
canonical-memory pattern entities to the user with their trade-offs
and capture the chosen pattern. Cite the chosen wikilink in the
spec's `## Alternatives Considered` `Source:` lines.

Otherwise (pattern_count < threshold), load `WebSearch` via
`ToolSearch` (`select:WebSearch`) — `WebSearch` is a deferred tool
and is not preloaded in this runtime. Run a single targeted query:
`"<domain phrase> architecture pattern"` (or a closely-scoped variant
informed by the PRD). Surface the top 2-3 industry results to the
user with explicit trade-offs and capture the chosen pattern. Cite
the consulted URLs verbatim in the spec's `## Alternatives Considered`
`Source:` lines — fabricated URLs fail the post-draft self-check.

### 6. Round 3 — Non-Functional Requirements (quantitative only)

Prompt the user for quantitative NFRs the system must satisfy:
latency, availability, throughput, consistency, token cost, disk
footprint. Each NFR captured in the dialogue MUST carry a numeric
target with a unit (e.g., `p95 < 200ms`, `≥ 99.9%`, `≥ 50 rps`,
`≤ 2000 tokens per cycle`). Adjective-only answers ("performant",
"secure", "reliable" without numbers) are **challenged inline** —
ask the user to convert the adjective into a measurable target. Do
not proceed until every captured NFR matches the post-draft regex
`\d+(\.\d+)?\s*(ms|s|%|rps|qps|req/s|MB|GB|TB|users)` (case-insensitive).

### 7. Round 4 — Technical Use Cases (PRD US-### lift)

Walk **every** PRD `US-###` in PRD order. For each, prompt the user
for: components involved, contracts used, NFRs applied, edge cases.
Allow the user to defer a US-### only with an explicit `Deferred:
<reason>` answer; record the deferral so step 8's draft surfaces it
in `## Open Questions`. Silently skipping a US-ID is a hard error
(the post-draft self-check catches it; do not let the dialogue allow
silent drops).

### 8. Stage 1 — Draft the design doc

Ensure `.yoke/specs/` exists (`mkdir -p "$(dirname "$(wm_spec_path
"$slug")")"`). Draft `.yoke/specs/<slug>.md` end-to-end in a single
`Write` call matching `templates/spec.md`'s twelve H2 sections in
fixed order:

1. `## Context and Scope`
2. `## Goals and Non-Goals`
3. `## System Context`
4. `## Architecture`
5. `## Stack and Dependencies`
6. `## APIs and Data Model`
7. `## Non-Functional Requirements`
8. `## Alternatives Considered`
9. `## Trade-offs`
10. `## Cross-cutting Concerns`
11. `## Technical Use Cases`
12. `## Open Questions`

Section-by-section discipline:

- **Context and Scope** — concrete; name the files and modules. The
  scope statement says what changes and what does not.
- **Goals and Non-Goals** — measurable goals; non-goals defend
  against scope creep.
- **System Context** — actors, components, data flows. ASCII /
  mermaid diagram welcome.
- **Architecture** — name the chosen pattern (canonical-memory
  wikilink or industry name from WebSearch). Spell out the invariants
  the architecture guarantees.
- **Stack and Dependencies** — exactly the choice from round 1.
  External libraries with version constraints. Internal prior work
  (canonical-memory pattern wikilinks, prior specs).
- **APIs and Data Model** — schemas, endpoints, message formats.
  Name contracts the Acceptance Contract will exercise.
- **Non-Functional Requirements** — bullet list. Every bullet
  matches the quantitative-target regex.
- **Alternatives Considered** — one `### Alt: <name>` subsection
  per rejected approach, with the three labels (`**Trade-off vs.
  chosen:**`, `**Reason for rejection:**`, `**Source:**`). Source =
  canonical-memory wikilink, WebSearch URL surfaced this session, or
  `internal experience`.
- **Trade-offs** — what the chosen approach itself gives up.
- **Cross-cutting Concerns** — observability, security, error
  handling, i18n / a11y when applicable.
- **Technical Use Cases** — one `### US-### — <title>` subsection
  per PRD US-ID, in PRD order, with the four labels (`**Components
  involved:**`, `**Contracts used:**`, `**NFRs applied:**`, `**Edge
  cases:**`). Deferred entries: `Deferred: <reason>` with the
  deferral surfaced in `## Open Questions`.
- **Open Questions** — anything the spec does not yet resolve;
  deferred US-### entries surface here verbatim.

The spec carries **no `## Sprints` section** and **no `### Task <ID>`
anchors**. Sprint partition + task breakdown are Phase 3's
responsibility.

### 9. Stage 2 — Deterministic post-draft self-check

After the `Write` call, run the following bash checks against
`spec="$(wm_spec_path "$slug")"`:

1. **Twelve-H2 in order.** `grep -nE '^## '` lists exactly twelve
   lines whose headings match the documented order. Failure: abort
   with `wm: tech-spec self-check: spec at $spec must carry the
   twelve H2 sections in the documented order; got: <ordered list
   from grep>`.
2. **Quantitative NFR.** Every bullet line under `## Non-Functional
   Requirements` (a region scanned via `awk '/^## Non-Functional
   Requirements$/,/^## /'`) matches the regex
   `\d+(\.\d+)?\s*(ms|s|%|rps|qps|req/s|MB|GB|TB|users)`
   (case-insensitive). Failure: abort with `wm: tech-spec self-check:
   adjective-only NFR rejected at line <N>: <line text>`.
3. **`### Alt:` triple-shape.** For each `### Alt: <name>`
   subsection in `## Alternatives Considered`, the three labels
   `**Trade-off vs. chosen:**`, `**Reason for rejection:**`, and
   `**Source:**` MUST all appear within the subsection body before
   the next `### `, `## `, or end-of-file. Failure: abort with `wm:
   tech-spec self-check: Alternative '<name>' missing label
   '<label>'`.
4. **US-### lift.** For each `US-###` ID present in the approved
   PRD's body, the spec MUST contain either a heading
   `### US-### — <title>` under `## Technical Use Cases` or a line
   `Deferred: <reason>` referencing the US-### plus a matching entry
   under `## Open Questions`. Failure: abort with `wm: tech-spec
   self-check: PRD US-### '<id>' silently dropped (no subsection,
   no deferral)`.
5. **No task anchors.** `grep -cE '^### Task ' "$spec"` returns `0`.
   Failure: abort with `wm: tech-spec self-check: spec body contains
   '### Task ' anchor at line <N> — sprint partition and task
   breakdown are Phase 3's responsibility`.
6. **No sprint files.** `find .yoke/sprints -name "${slug}-s*.md" |
   wc -l` returns `0`. Failure: abort with `wm: tech-spec
   self-check: sprint files exist for '$slug' under .yoke/sprints/
   — Phase 2 must not write there`. (If sprint files are present
   from a prior Phase 3 run on the same slug, the user should pick
   `revise` at Trigger 3 to wipe them, not at Trigger 2; surface
   the conflict explicitly.)

WebSearch source verification: when WebSearch fired in step 5, every
`Source:` line in `## Alternatives Considered` that is not a
canonical-memory wikilink and is not the literal string `internal
experience` MUST match a URL that actually appeared in the WebSearch
tool result of this session. Implementation: capture the URLs from
the WebSearch result into a runtime list, then `grep -F` each
non-wikilink, non-internal-experience `Source:` URL against that
list. Failure: abort with `wm: tech-spec self-check: Source URL
'<url>' was not returned by any WebSearch call this session`.

Any failure aborts the skill non-zero. Do NOT proceed to Trigger 2.

### 10. Trigger 2 — Spec approval

Display the drafted spec, then render the **shared approval menu**
defined in `templates/approval-menu.md`. The menu is the surface for
**Trigger 2 — Tech Spec approval**, which blocks Phase 3.

Inputs passed to the menu:

- `artifact_path`: `wm_spec_path "$slug"` (resolves to
  `.yoke/specs/<slug>.md`).
- `artifact_label`: `Tech Spec`. The menu template's Tech-Spec-only
  summary block adapts to the new shape: instead of a per-sprint
  summary, the block lists the twelve H2 sections present in the
  spec with a one-line summary per section (lifted from each
  section's first non-empty line).
- `next_skill`: `/yoke:acceptance-criteria`.
- `language`: the language detected for the dialogue.
- `binding_statement`: empty (Trigger 2 is not a binding gate;
  Trigger 3 carries the binding statement).
- `section_summary`: ordered list of the twelve H2 sections present
  in the spec, one entry per section: `<section name> — <one-line
  summary>`.

The menu renders, every time, in this order: (a) the
twelve-section summary block (Tech-Spec-only), (b) the open-questions
detection block (scans the spec body for inline `TODO:` / `TBD` /
`FIXME:` / `<placeholder>` markers), then (c) the 4-option prompt
mapping to internal verbs `approve_and_continue` / `approve` /
`reject` / `revise`.

The skill does not return until the user replies. `revise` loops
back through stages 1-2 (see step 11). `reject` is the **back to
PRD** escape — it prompts for the secondary confirmation; on `yes`,
the skill aborts and instructs the user to re-run `/yoke:discover`
(which creates a *new* task with a new slug). `approve` records
approval and stops. `approve_and_continue` records approval and
chains into `/yoke:acceptance-criteria` via the `Skill` tool in the
same turn — but if the open-questions detection returned at least
one match, the template requires a `yes` / `no` warning confirmation
before chaining; on `no`, the skill records approval and stops
(collapses to `approve`).

### 11. `revise` — delete + rewrite

When the user picks `revise`:

1. Print a loud `wm:`-prefixed warning naming the spec path that
   will be deleted plus the captured feedback.
2. Delete `.yoke/specs/<slug>.md`. Use plain `rm` on the path; do
   NOT use `rm -rf` on directories. **Do NOT touch
   `.yoke/sprints/`** — Phase 2 has no business deleting Phase 3
   artifacts. Sprint files (if present from a prior Phase 3 run)
   remain on disk; the user picks `revise` at Trigger 3 to wipe
   them.
3. Re-run stages 1-2 from scratch with the captured feedback as
   additional context for the dialogue.
4. Re-render the Trigger 2 menu.

Hand-edits to the spec are NOT preserved across `revise`. The
warning makes this explicit.

## Recording approval

On `approve` or `approve_and_continue`:

- Write `Status: approved`, `Approved by`, `Approved at` headers to
  `wm_spec_path "$slug"` (after the `Status:` line in the spec body).

This is a single-file flip — no sprint files exist at Phase 2, so the
v1.x atomic-multi-file flow does not apply. `Status: approved` on the
spec is the **complete** Trigger 2 gate.

## Output

On `approve` or `approve_and_continue`:

- `wm_spec_path "$slug"` written with `Status: approved`,
  `Approved by`, `Approved at` headers.
- `find .yoke/sprints -name "${slug}-s*.md" | wc -l` returns `0` —
  Phase 2 wrote no sprint files.
- `grep -cE '^### Task ' "$(wm_spec_path "$slug")"` returns `0` —
  Phase 2 emitted no task anchors.
- On `approve_and_continue` (after the open-questions warning, when
  applicable, returns `yes`): the skill invokes
  `/yoke:acceptance-criteria` via the `Skill` tool in the same turn.
  No manual paste is required from the user.
- **Fallback when `Skill` tool is unavailable.** Some runtimes do
  not expose the `Skill` tool to a running skill body. The skill
  MUST detect availability before rendering the menu and, when
  unavailable, render option 1 with the suffix `(manual: run
  /yoke:acceptance-criteria after this step)`. On selection of
  option 1 in fallback mode, the skill records approval, prints
  "Tech Spec approved. Run `/yoke:acceptance-criteria` to advance to
  Phase 3.", and exits cleanly.

On `reject` (after secondary confirmation): the spec is marked
rejected (no `Status: approved` written) and the skill exits cleanly.

## Pre-conditions

- `.yoke/config.yaml` exists.
- `.yoke/runtime/.current` exists and points at a valid slug.
- `.yoke/prds/<slug>.md` exists and is approved.

## Output contract

- Exit 0 with `.yoke/specs/<slug>.md` populated and approved AND zero
  files under `.yoke/sprints/<slug>-s*.md` (Phase 2 never writes
  there) AND zero `### Task <ID>` anchors in the spec body.
- Exit non-zero on missing `.current`, missing/unapproved PRD,
  post-draft self-check failure, partial approval write failure,
  user abort, or revise-loop exhaustion.

## Anti-patterns

- Do NOT proceed without an approved PRD — abort immediately.
- Do NOT modify the PRD (`.yoke/prds/<slug>.md` is Phase 1's
  artifact). Read-only.
- Do NOT write to any flat path. All paths go through
  `lib/working-memory/paths.sh`.
- Do NOT invoke the sprint-file scaffolder
  (`lib/working-memory/scaffold-*.sh`) from this skill — sprint
  scaffolding belongs to Phase 3 (`/yoke:acceptance-criteria`).
- Do NOT emit any `### Task <ID>` anchor in the spec body. The
  post-draft self-check rejects them.
- Do NOT write any file under `.yoke/sprints/`. The post-draft
  self-check rejects sprint-file side effects.
- Do NOT auto-approve.
- Do NOT let any NFR be adjective-only ("performant", "secure",
  "reliable" without numbers). Challenge inline; the post-draft
  self-check rejects them.
- Do NOT let any `### Alt:` subsection skip a label. The
  post-draft self-check rejects them.
- Do NOT silently drop a PRD `US-###`. The post-draft self-check
  rejects silent drops; explicit `Deferred: <reason>` is the only
  acceptable path, and the deferral surfaces in `## Open Questions`.
- Do NOT cite a `Source:` URL that did not appear in this session's
  WebSearch results. Fabricated URLs fail the self-check.
- Do NOT load `WebSearch` always-on. Gate on the canonical-pattern
  threshold (`overrides.tech_spec.canonical_pattern_threshold`,
  default 3).
- Do NOT read canonical memory directly. All queries via
  `/yoke:search-canonical-memory`.
- Do NOT preserve hand edits across `revise` — delete + rewrite is
  the contract.

## See also

- `concepts/yoke-pattern-phase-flow` (Phase 2; the spec is the
  binding artifact, sprint files are Phase-3 outputs).
- `concepts/yoke-pattern-roles` (Senior Engineer / Generator
  persona inline).
- `concepts/yoke-pattern-human-triggers` (Trigger 2; shared-menu rule).
- `concepts/yoke-pattern-memory-model` (working-memory archive layout).
- `concepts/yoke-pattern-plugin-structure` (lib/ placement for
  `lib/config-overrides.sh`).
- `concepts/yoke-conventions` ("blueprints wrapping agentic nodes",
  "progressive disclosure").
- `templates/spec.md` (twelve-section design-doc shape; placeholder
  body shape for NFR / Alt / US-### sections).
- `templates/approval-menu.md` (shared menu shape, detection rule,
  fallback, Tech-Spec-only twelve-section summary block).
- `lib/config-overrides.sh` (`yoke_get_override`).
- `lib/yoke-prelude.sh` (`yoke_require_provider`).
