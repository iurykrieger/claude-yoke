# Spec: Approval menu — mechanism + first gate (Trigger 1)

> Generated via /vibeflow:gen-spec on 2026-04-25 from `.vibeflow/prds/plan-options.md`.
> Part 1 of 2. Establishes the shared menu shape and the chained-skill
> mechanism on `/yoke:discover` (Trigger 1) only. Triggers 2 and 3 are in
> Part 2.

## Objective

Replace the trailing free-text "Run `/yoke:tech-spec` to advance" instruction
in `/yoke:discover` with a structured 4-option menu, and define the shared
menu shape that Triggers 2 and 3 will adopt in Part 2.

## Context

Today `/yoke:discover` (`skills/discover/SKILL.md` line 79) ends with a
printed line instructing the user to run `/yoke:tech-spec` manually. The
existing trigger schema (`approve` / `revise <feedback>` / `restart`) is
correct in intent but not surfaced as discrete options at the end of the
skill — it lives only in skill documentation.

This part establishes the menu shape (a template referenced by skills) and
proves the chained-skill mechanism on the lowest-risk gate. Triggers 4 and
5 are explicitly out of scope for the entire feature, per the PRD and per
`patterns/human-triggers.md` ("coalescing triggers is an anti-pattern" —
distinct decision spaces and surfaces).

Sprint placement note: the SKILL.md files already exist (they are LLM-driven
prose); the body that drives the dialogue is functionally a placeholder per
`CLAUDE.md`. The change in this spec is a markdown edit to the trigger-1
prompt section and is implementable today — independent of when the
discover dialogue itself is fully implemented in `agents/generator.md`.

## Definition of Done

1. `templates/approval-menu.md` exists and defines exactly 4 options with
   stable internal verbs: `approve_and_continue`, `approve`, `reject`,
   `revise`. Each verb maps 1:1 to one of today's existing schema words
   (`approve` covers options 1 and 2; `restart` ↔ `reject`; `revise` ↔
   option 4). Option 4 supports multi-line free-text input terminated by a
   blank line; option labels render in the detected user language while
   internal verbs remain stable in English.
2. The template defines an **open-questions detection rule** — scan the
   artifact body for (a) the section heading `## Open questions` and its
   non-empty content, and (b) inline unresolved markers: `TODO:`, `TBD`,
   `FIXME:`, or angle-bracket placeholders matching `<[^>]+>` in body text.
   If any match exists, the menu renders an "Open / unresolved items"
   block listing each match (file location optional in v0) **before** the
   4-option prompt, every time.
3. The template defines a **warning confirmation on option 1 when open
   questions exist**: if the user picks `approve_and_continue` and the
   detection rule from DoD #2 returned at least one match, the skill must
   print an explicit warning naming the count of unresolved items and ask
   the user to confirm `yes` (proceed and chain) / `no` (treat as plain
   `approve`, do not chain). Option 2 (`approve`) is not gated.
4. `skills/discover/SKILL.md` step 4 ("Draft and review") replaces the
   free-text Trigger-1 prompt with a reference to `templates/approval-menu.md`,
   passing the next-phase skill identifier `/yoke:tech-spec` so that option
   1 can chain into Phase 2 (subject to DoD #3 confirmation).
5. `skills/discover/SKILL.md` step 6 ("Output") removes the line `Print:
   "PRD approved. Run `/yoke:tech-spec` to advance to Phase 2."` — superseded
   by the menu's option-1 chained invocation. The skill body explicitly
   documents that option 1 invokes `/yoke:tech-spec` via the `Skill` tool
   in the same turn, and includes a fallback: if the `Skill` tool is
   unavailable in the runtime, the skill prints the manual instruction
   (today's behavior) and exits cleanly.
6. `.vibeflow/patterns/human-triggers.md` Implementation Mapping table
   (line 96–102) is updated to record `templates/approval-menu.md` as the
   menu shape for Trigger 1, with an inline note that Triggers 2 and 3 will
   adopt it in Part 2 and Triggers 4 and 5 are explicitly excluded. The
   open-questions warning is documented as part of the shared menu shape.
7. **Quality gate.** Changes obey `.vibeflow/conventions.md` "Don'ts" — in
   particular: triggers remain distinct (each has its own audit log; only
   the rendered shape is shared), no agent gains new write authority over
   canonical memory, and the change introduces no agentic node (the menu
   is a deterministic surface per "Blueprints wrapping agentic nodes"; the
   detection rule in DoD #2 is a deterministic scan, not LLM judgment).

## Scope

- Create `templates/approval-menu.md` with the 4-option shape, internal
  verbs, multi-line input rule, language-rendering rule, and a documented
  fallback for runtimes without the `Skill` tool.
- Edit `skills/discover/SKILL.md` to swap the Trigger-1 prompt block for a
  reference to the template, and remove the trailing manual-paste line.
- Update `.vibeflow/patterns/human-triggers.md` Implementation Mapping
  table to record the shared menu shape for Trigger 1 and reserve the slot
  for Triggers 2/3 in Part 2.

## Anti-scope

- **Triggers 2 and 3 are NOT modified in this part** — Part 2 handles them.
  This split exists precisely so the mechanism is proven once before
  propagating.
- **Triggers 4 and 5 are NEVER modified in this feature** —
  `patterns/human-triggers.md` rule: each trigger has its own surface, its
  own decision space, and its own audit log. Coalescing them is an
  anti-pattern.
- No changes to `templates/prd.md` or any other artifact template.
- No changes to `agents/generator.md` or any subagent prompt.
- No new bash helpers in `lib/`. The menu is markdown prose interpreted by
  the LLM driving the skill, not a shell script.
- No new persistence: the user's choice acts within the turn. Approval
  metadata in `.yoke/prd.md` (`Status: approved`, `Approved by`,
  `Approved at`) remains the source of truth.
- No changes to `/yoke:bootstrap`, `/yoke:status`, `/yoke:ask`,
  `/yoke:drift-sense`, `/yoke:implement`, `/yoke:canonize`.
- No retroactive migration of existing `.yoke/prd.md` files.

## Technical Decisions

### Menu shape lives in `templates/`, not `lib/`

The menu is interpreted by the LLM that drives the skill — there is no
deterministic shell node to execute. `templates/` is the right home (same
location as `templates/prd.md`, `templates/tech-spec.md`, etc.). A
`lib/triggers/menu.sh` would suggest a runtime helper that does not exist.

**Trade-off.** Templates rely on the LLM to follow the shape exactly. A
shell helper would enforce it deterministically. Accepting LLM-level
discipline is consistent with how the rest of the trigger schemas are
specified today (in skill prose).

### Internal verbs stable in English; labels localized

Option labels render in the detected user language; internal return verbs
(`approve_and_continue`, etc.) stay in English. This matches Vibeflow's
language-detection convention and keeps downstream branching code (in the
skill) language-stable.

**Trade-off.** Two layers (label + verb). Cost: one extra mapping in the
template. Benefit: skill code never needs to know the user's language to
branch.

### Option 1 uses the `Skill` tool from inside the host skill

Slash commands are user-invoked and cannot be synthesized on the user's
behalf. The only viable path for "approve & continue" is for the host
skill to invoke the next-phase skill via the `Skill` tool inside the same
turn.

**Trade-off.** This bypasses the user-typed slash boundary that today
defines a phase transition. Mitigation: option 2 ("Approve") preserves
today's behavior verbatim — users who want the manual transition still
have it. The fallback (DoD #5) handles runtimes without the `Skill` tool.

### Open-questions detection scans body, not only `## Open questions`

The PRD template has a dedicated `## Open questions` section, but tech-spec
and acceptance-contract templates do not (verified against `templates/`).
Defining detection as "section + inline `TODO:` / `TBD` / `FIXME:` /
`<placeholder>` markers" lets the same rule extend to Triggers 2 and 3 in
Part 2 without forcing template additions there.

**Trade-off.** Inline-marker scanning may produce false positives (e.g.,
intentional code-snippet `<placeholder>` inside a fenced block).
**Mitigation:** the rule is documented as best-effort in v0; the warning is
non-blocking — the user can confirm and proceed. False positives cost one
extra confirmation, not a blocked transition.

### Warning is on option 1 only

Option 2 ("Approve") is intentionally not gated by open questions: a user
who picks 2 has consciously chosen to stop and review later, so the
unresolved markers are no longer a transition risk. Adding the gate to
option 2 would conflate "approve" with "approve & advance" — exactly the
collapse the PRD is unwinding.

**Trade-off.** A user who picks option 2 with open questions still ends up
with an approved artifact carrying TODOs. This is acceptable: today's
schema already allows this (the current `approve` verb does not check
open questions). The PRD template line 47–48 ("Block downstream phases
when load-bearing; the Tech Spec must close them") makes the load-bearing
guarantee a Phase-2 responsibility, not a Phase-1 gate.

### Option 3 is "reject" with explicit secondary prompt, not "restart"

The PRD's Open Question on reject-vs-restart resolves in favor of
"reject" (terminal state, no implicit re-run), with a one-line secondary
prompt offering re-run. This avoids forcing a full discovery restart when
the user picked 3 by mistake, while keeping the verb explicit.

**Trade-off.** Adds one extra prompt on the reject path. Cost: minor.
Benefit: the destructive `restart` action is gated behind a confirmation.

## Applicable Patterns

- **`patterns/human-triggers.md`** — primary. The PRD honors the
  "no-coalescing" rule by keeping triggers' decision spaces, audit logs,
  and surfaces distinct; only the rendered shape is shared via the
  template. The Implementation Mapping table is updated by this spec.
- **`patterns/phase-flow.md`** — option 1's chained invocation is exactly a
  Phase-1 → Phase-2 transition. No new phase is introduced.
- **`patterns/roles.md`** — no role changes. Generator continues to drive
  Phase 1; the menu is a surface, not a role.
- **No new pattern introduced.** The "shared menu template across like
  triggers" idea may graduate into a pattern after Part 2 ships and the
  shape stabilizes — explicitly deferred.

## Risks

- **Risk: `Skill` tool unavailable in some runtimes.** Some Claude Code
  versions or non-Claude harnesses may not expose the `Skill` tool to a
  running skill body. **Mitigation:** DoD #5 mandates a fallback that
  prints today's manual instruction and exits cleanly. The skill must
  detect availability before attempting invocation.
- **Risk: option labels render in English when user input was non-English.**
  Vibeflow's language detection lives in skill prose; the template must
  delegate label rendering to the host skill, not hardcode strings.
  **Mitigation:** template specifies "labels rendered in detected user
  language" as a contract, and the discover skill's prose already detects
  language for the dialogue itself.
- **Risk: idempotency interaction.** When `.yoke/prd.md` already exists,
  step 1 of the discover skill prompts overwrite/save-as-v2/abort *before*
  running. The new menu fires *after* a fresh draft. **Mitigation:** the
  two prompts are at different moments in the skill flow and do not
  collide; the spec preserves the existing step-1 prompt unchanged.
- **Risk: LLM rendering drift.** Without a shell helper, the LLM may render
  options inconsistently (e.g., reorder, paraphrase). **Mitigation:** the
  template specifies exact option ordering and verb mapping; the skill
  prose references the template by path, not by paraphrase.
