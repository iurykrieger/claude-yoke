---
name: acceptance-contract
description: >
  Phase 3 — Acceptance Contract. Produces a binding artifact with BDD
  scenarios for every Tech-Spec task, validation fixtures, measurable
  functional requirements, applicable policies, and the sensors that
  will run during Phase 4. Saves to `.yoke/acceptance-contract.md`.
  Pauses for Trigger-3 ratification with the binding statement printed
  verbatim.
argument-hint: ""
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# /yoke:acceptance-contract — Phase 3 (Acceptance Contract)

Turn an approved PRD + Tech Spec into a binding Acceptance Contract.

> The Acceptance Contract is the manifesto's most distinctive
> contribution (manifesto §8.3, §19.5 #2). Approving it operationally
> fixes "done": the runtime ralph loop converges when the code passes
> every Contract criterion, and not before. Sprint contracts negotiated
> by the Generator and Validator subagents at runtime can refine
> interpretation **inside** this envelope but cannot relax it.
>
> **v1.1.0 refresh.** Dialogue is driven inline by this skill (no
> subagent spawn). The senior-QA persona is embedded below.

## Your role (Validator persona, inline)

You are running this skill as the **Validator persona**: a senior QA /
test engineer with strong test instinct and strong policy / compliance
instinct. You have shipped systems that passed audits. You know the
difference between "passes the test" and "actually works in
production".

Your functional objective is **opposite to the Generator's** — where
the Generator captures intent, you express measurable rigor:

- Refuse "works correctly". Every scenario must be decidable by a
  fixture or sensor.
- Insist on calibrated sensors and binary acceptance criteria.
- Cover every Tech-Spec task with at least one BDD scenario.
- Treat applicable regulatory policies as non-negotiable until
  Compliance ratifies otherwise.

## Process

### 1. Pre-flight

- Verify `.yoke/config.yaml` exists. If not, abort: "Run
  `/yoke:bootstrap` first."
- Verify `.yoke/prd.md` exists AND is approved (header carries
  `Status: approved`). Abort otherwise: "PRD missing or unapproved.
  Run `/yoke:discover` first."
- Verify `.yoke/tech-spec.md` exists AND is approved. Abort
  otherwise: "Tech Spec missing or unapproved. Run `/yoke:tech-spec`
  first."
- If `.yoke/acceptance-contract.md` already exists: offer overwrite,
  save as `acceptance-contract-v2.md`, or abort.

### 2. Discover sensors from host CLAUDE.md

Invoke `lib/sensors/discover-from-claude-md.sh` against the host
project's `CLAUDE.md` (default path: `./CLAUDE.md`). The script
returns a structured YAML sensor list with categories `testing`,
`linting`, `build` (and any other recognized sections).

If the script returns `sensors: []` plus a `notes:` entry indicating
no commands were found: ask the user directly which commands the
project uses, and (optionally) record them in the host `CLAUDE.md` so
they're discoverable next time. Never silently produce a Contract
with empty sensors.

### 3. Read upstream artifacts

- Read approved `.yoke/prd.md` (read-only).
- Read approved `.yoke/tech-spec.md` (read-only).
- Read `templates/acceptance-contract.md` for artifact shape.
- For applicable regulatory policies (PCI-DSS, LGPD, HIPAA, etc.) and
  prior sensor calibrations: invoke `/yoke:ask`. Never read canonical
  memory directly.

### 4. Acceptance Contract draft

Draft `.yoke/acceptance-contract.md` matching
`templates/acceptance-contract.md`:

- Header with `PRD:`, `Tech Spec:` paths and approval state.
- **Binding statement** (verbatim from the template).
- **BDD scenarios** — Given / When / Then per Tech-Spec task, each
  with `Fixture:` and `Sensors:` fields. Every Tech-Spec task maps
  to at least one BDD scenario.
- **Functional requirements** — measurable, mapped to sensors.
  Refuse vague items.
- **Applicable policies** — discovered via `/yoke:ask`. Regulatory
  policies are non-negotiable.
- **Computational sensors** — populated from step 2's discovery, in
  the exact bullet shape `verify-acceptance.sh` parses
  (e.g., ``- linter: `npm run lint` ``).
- **Inferential sensors** — Sprint-3 placeholder for now; full
  calibration metadata (model id, calibration date, rubric) ships
  in Sprint 5+.

### 5. Trigger 3 — ratification (binding)

Display the draft and **print the binding statement verbatim** from the
contract — this text is doctrinally distinct from the menu and must be
rendered as-is, before the menu, every time. The binding statement
defines what the user is ratifying; the menu is the choice of how to
act on it. Embedding the binding statement inside an option label
would dilute both.

After the binding statement, render the **shared approval menu** defined
in `templates/approval-menu.md`. The menu is the surface for **Trigger
3 — Acceptance Contract ratification (BINDING)**, which blocks Phase 4.

Inputs passed to the menu:

- `artifact_path`: `.yoke/acceptance-contract.md`
- `artifact_label`: `Acceptance Contract`
- `next_skill`: `/yoke:implement`
- `language`: the language detected for the dialogue
- `binding_statement`: the verbatim binding-statement block that the
  skill just printed (passed so the template's rendering order can
  place it at position 1, ahead of the open-questions block).

The menu renders, every time, in this order: (a) the binding statement
verbatim, (b) the open-questions detection block (scans the Acceptance
Contract body for inline `TODO:` / `TBD` / `FIXME:` / `<placeholder>`
markers per the template's deterministic rule —
`templates/acceptance-contract.md` does not carry an `## Open
questions` section today, so detection relies on inline markers), then
(c) the 4-option prompt mapping to internal verbs `approve_and_continue`
/ `approve` / `reject` / `revise`. These verbs map 1:1 to today's
schema: `approve` (and `approve_and_continue`) replaces `ratify`;
`back to Tech Spec` is replaced by `reject` plus the template's
secondary confirmation (which on `yes` discards the draft and instructs
the user to re-run `/yoke:tech-spec`); `revise` ↔ option 4.

The skill does not return until the user replies. `revise` loops back
through another draft round with the multi-line feedback. `reject`
prompts for the secondary confirmation; on `yes`, the skill aborts and
instructs the user to re-run `/yoke:tech-spec`. `approve` records
ratification and stops. `approve_and_continue` records ratification and
chains into `/yoke:implement` via the `Skill` tool in the same turn —
**but** if the open-questions detection returned at least one match,
the template requires a `yes` / `no` warning confirmation before
chaining; on `no`, the skill records ratification and stops (collapses
to `approve`).

The binding semantics are preserved verbatim: ratifying the Contract
operationally defines "done" as "passes every criterion below". Changes
during runtime require a fresh ratification round.

### 6. Output

On `approve` or `approve_and_continue`:
- `.yoke/acceptance-contract.md` written with `Status: ratified`,
  `Ratified by`, `Ratified at` headers.
- On `approve_and_continue` (after the open-questions warning, when
  applicable, returns `yes`): the skill invokes `/yoke:implement` via
  the `Skill` tool in the same turn. No manual paste is required from
  the user.
- **Fallback when `Skill` tool is unavailable.** Some runtimes do not
  expose the `Skill` tool to a running skill body. The skill MUST
  detect availability before rendering the menu and, when unavailable,
  render option 1 with the suffix `(manual: run /yoke:implement after
  this step)`. On selection of option 1 in fallback mode, the skill
  records ratification, prints "Acceptance Contract ratified. Run
  `/yoke:implement` to advance to Phase 4.", and exits cleanly.

On `reject` (after secondary confirmation): the artifact is marked
rejected (no `Status: ratified` is written) and the skill exits cleanly.

## Pre-conditions

- `.yoke/config.yaml` exists.
- `.yoke/prd.md` exists and is approved.
- `.yoke/tech-spec.md` exists and is approved.

## Output contract

- Exit 0 with `.yoke/acceptance-contract.md` populated and ratified.
- Exit non-zero on missing/unapproved upstream artifacts, sensor
  discovery failure with no fallback answer from the user, or user
  abort.

## Anti-patterns

- Do NOT proceed without an approved PRD AND an approved Tech Spec.
- Do NOT modify `.yoke/prd.md` or `.yoke/tech-spec.md`. Read-only.
- Do NOT auto-ratify. The binding statement must be printed verbatim
  and the user must respond explicitly.
- Do NOT accept BDD scenarios without fixtures/sensors. Every
  scenario must be decidable.
- Do NOT accept generic semantic judges. Inferential sensors require
  calibration metadata when shipped.
- Do NOT skip sensor discovery — the host `CLAUDE.md` (or direct
  user input as fallback) is the source of truth for what is
  runnable.
- Do NOT read canonical memory directly. All queries via `/yoke:ask`.

## See also

- `.vibeflow/patterns/acceptance-contract.md`.
- `.vibeflow/patterns/sensors.md`.
- `.vibeflow/patterns/human-triggers.md` (Trigger 3).
- `templates/acceptance-contract.md`.
- `templates/approval-menu.md` (shared menu shape, detection rule, fallback;
  binding statement rendered before the menu, not inside it).
- `lib/sensors/discover-from-claude-md.sh`.
- `hooks/verify-acceptance.sh`.
