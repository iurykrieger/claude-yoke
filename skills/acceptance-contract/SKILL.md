---
name: acceptance-contract
description: >
  Phase 3 — Acceptance Contract. Produces a binding artifact with BDD
  scenarios for every Tech-Spec task, validation fixtures, measurable
  functional requirements, applicable policies, and the sensors that
  will run during Phase 4. Saves to
  `.yoke/acceptance-contracts/<slug>.md`, where <slug> comes from
  `.yoke/.current`. Pauses for Trigger-3 ratification with the binding
  statement printed verbatim.
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

- Source `lib/working-memory/paths.sh`. All paths below resolve through `wm_*_path`.
- Verify `.yoke/config.yaml` exists. If not, abort: "Run
  `/yoke:bootstrap` first."
- Resolve the active task: `slug="$(wm_active_slug)"`. If `.yoke/.current` is missing, surface the helper's "no active task" error and instruct the user to run `/yoke:discover`.
- Verify `wm_prd_path "$slug"` exists AND is approved. Abort otherwise:
  "PRD missing or unapproved at <path>. Run `/yoke:discover` first."
- Verify `wm_tech_spec_path "$slug"` exists AND is approved. Abort
  otherwise: "Tech Spec missing or unapproved at <path>. Run
  `/yoke:tech-spec` first."
- If `wm_acceptance_contract_path "$slug"` already exists: offer overwrite (replace in place — same path) or abort. No `-v2.md` shadowing — the per-task slug already provides versioning across tasks.

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

- Read the approved PRD at `wm_prd_path "$slug"` (read-only).
- Read the approved Tech Spec at `wm_tech_spec_path "$slug"` (read-only).
- Read `templates/acceptance-contract.md` for artifact shape.
- For applicable regulatory policies (PCI-DSS, LGPD, HIPAA, etc.) and
  prior sensor calibrations: invoke `/yoke:ask`. Never read canonical
  memory directly.

### 4. Acceptance Contract draft

Ensure `.yoke/acceptance-contracts/` exists (`mkdir -p`). Draft the
Acceptance Contract at `wm_acceptance_contract_path "$slug"` (i.e.,
`.yoke/acceptance-contracts/<slug>.md`) matching
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

Display the draft and print the binding statement verbatim, then ask
the explicit Trigger-3 prompt:

> **Trigger 3 — Acceptance Contract ratification (BINDING).**
> Approving this contract operationally defines "done" as "passes
> every criterion below". Changes during runtime require a fresh
> ratification round. Decision required: `ratify` / `revise <feedback>`
> / `back to Tech Spec`.

The skill does not return until the user responds explicitly.
`back to Tech Spec` aborts the skill and instructs the user to re-run
`/yoke:tech-spec`.

### 6. Output

On `ratify`:
- `wm_acceptance_contract_path "$slug"` written with
  `Status: ratified`, `Ratified by`, `Ratified at` headers.
- Print: "Acceptance Contract ratified. Run `/yoke:implement` to
  advance to Phase 4."

## Pre-conditions

- `.yoke/config.yaml` exists.
- `.yoke/.current` exists and points at a valid slug.
- `.yoke/prds/<slug>.md` exists and is approved.
- `.yoke/tech-specs/<slug>.md` exists and is approved.

## Output contract

- Exit 0 with `.yoke/acceptance-contracts/<slug>.md` populated and ratified.
- Exit non-zero on missing `.current`, missing/unapproved upstream artifacts, sensor
  discovery failure with no fallback answer from the user, or user
  abort.

## Anti-patterns

- Do NOT proceed without an approved PRD AND an approved Tech Spec.
- Do NOT modify the PRD or Tech Spec (Phase 1/2 artifacts). Read-only.
- Do NOT write to any flat path. All paths go through `lib/working-memory/paths.sh`.
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
- `lib/sensors/discover-from-claude-md.sh`.
- `hooks/verify-acceptance.sh`.
