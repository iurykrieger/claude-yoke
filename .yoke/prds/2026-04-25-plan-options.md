# PRD: Structured approval menu at the end of blocking gates

> Generated via /vibeflow:discover on 2026-04-25

## Problem

Today, each Yoke blocking gate (Triggers 1, 2, 3 — PRD, Tech Spec, Acceptance
Contract) ends with a free-text prompt instructing the user to manually run the
next slash command:

```
PRD approved. Run `/yoke:tech-spec` to advance to Phase 2.
```

This forces a copy/paste step between every phase and weakens the gate's
semantics: "approve this artifact" and "advance to the next phase" are two
distinct decisions, but the current UX collapses them into a single instruction
the user has to act on by retyping. The result is friction, slower phase
transitions, and a higher chance the user pauses mid-flow without an explicit
decision recorded against the artifact.

The current schemas (`approve` / `revise <feedback>` / `restart`) are correct
in intent but not surfaced as discrete, choosable options at the end of the
skill — they live in skill documentation, not in the runtime affordance.

## Target Audience

End users of Yoke working through Phases 1–3 of a task: the human ratifier
who reads each generated artifact (PRD, Tech Spec, Acceptance Contract) and
needs to decide what happens next. Not the Generator/Validator agents
themselves — they are upstream of this prompt.

## Proposed Solution

At the end of `/yoke:discover`, `/yoke:tech-spec`, and
`/yoke:acceptance-contract`, replace the trailing free-text instruction with
a structured 4-option menu rendered via an `AskUserQuestion`-style numbered
prompt:

1. **Approve & continue** — record approval (`Status: approved`, `Approved by`,
   `Approved at`) on the current artifact, then invoke the next phase's skill
   in the same turn via the `Skill` tool.
2. **Approve** — record approval on the current artifact, stop. The user
   advances to the next phase later, manually.
3. **Reject** — discard the draft (or mark `Status: rejected`); skill exits
   without writing approval metadata.
4. **Other / revise** — free-text feedback, looped back to the
   Generator/Validator subagent for another iteration of the same artifact.

Each option maps to a verb already present in the trigger schemas — the change
is purely UX surface, not a new decision space.

The menu lives behind a single shared helper (so all three skills render and
parse it the same way). The "approve & continue" branch is the only one with
chained execution; options 2 and 3 terminate the skill cleanly; option 4
re-enters the same skill's iteration loop.

## Success Criteria

- A user moving from PRD → Tech Spec → Contract can complete all three gates
  by typing only digits (`1`/`2`/`3`/`4`) plus, on option 4, free-text
  feedback. No manual paste of `/yoke:tech-spec` or `/yoke:acceptance-contract`
  is required when the user picks option 1.
- Approval metadata on each artifact (`Status`, `Approved by`, `Approved at`)
  is identical to today on options 1 and 2.
- The three skills' end-of-flow code paths route through the same helper —
  there is exactly one place where the menu shape is defined.
- Triggers 4 and 5 are untouched; the skill files for `/yoke:implement` and
  `/yoke:canonize` show no change.

## Scope v0

- New shared helper that renders the 4-option menu and returns a typed result
  (`approve_and_continue` | `approve` | `reject` | `revise <text>`).
- Wire the helper into `/yoke:discover`, `/yoke:tech-spec`,
  `/yoke:acceptance-contract`.
- On `approve_and_continue`, invoke the next phase's skill from inside the
  current skill (discover → tech-spec; tech-spec → acceptance-contract;
  acceptance-contract → implement).
- Update each skill's `## Output contract` and `## Anti-patterns` sections to
  reference the new menu surface and forbid bypassing it.
- Update `patterns/human-triggers.md` Implementation Mapping table to record
  the menu surface for Triggers 1/2/3.

## Anti-scope

- **Trigger 4 (divergence arbitration) is not changed.** Its decision space
  (reformulate Contract / reformulate Tech Spec / accept trade-off / abort) is
  not approve/reject/revise and must not be coalesced into this menu —
  explicit warning in `patterns/human-triggers.md`.
- **Trigger 5 (canonization ratification) is not changed.** Governed by Model
  C (auto-merge / notify-and-apply / synchronous) — adding a synchronous menu
  here would re-introduce a blocking path on every canonization.
- No change to artifact templates (`prd.md`, `tech-spec.md`,
  `acceptance-contract.md`) beyond what `Status` already records.
- No change to the Generator / Validator subagents or their prompts.
- No new persistence: the user's choice is acted on within the turn, not
  stored as a separate audit log entry. Approval metadata in the artifact
  remains the source of truth.
- No change to `/yoke:bootstrap`, `/yoke:status`, `/yoke:ask`,
  `/yoke:drift-sense`.
- No retroactive migration of `.yoke/prd.md` files written under the old flow.

## Technical Context

Relevant from `.vibeflow/`:

- **`patterns/human-triggers.md`** — five distinct triggers, each with its own
  surface and audit log; coalescing them is an anti-pattern. This PRD is
  scoped to Triggers 1/2/3 specifically to honor that rule. The
  Implementation-Mapping table already names the end-of-skill prompt as the
  surface for these three triggers — this PRD upgrades that surface from
  free text to a structured menu without changing the mapping.
- **`patterns/phase-flow.md`** — the per-task phase sequence the menu's
  "approve & continue" branch will chain through.
- **Existing trigger schemas** in each skill (`skills/discover/SKILL.md` line
  58–63, similar in `tech-spec` and `acceptance-contract`) already define
  `approve` / `revise <feedback>` / `restart`. Options 1/2 both map to
  `approve` (differing only in chained execution); option 4 maps to `revise`;
  option 3 maps to `restart` semantics (or to a `rejected` terminal state if
  the user wants to abandon the artifact entirely — this distinction is in
  Open Questions).

Mechanism note: chained skill invocation in option 1 uses the `Skill` tool
from inside the host skill — this is the only viable path, since slash
commands are user-invoked and cannot be synthesized by the runtime on the
user's behalf.

Sprint placement: this is a UX-surface change to three already-shipped skills.
It does not belong inside any of the eight numbered sprints in
`.vibeflow/specs/`. Recommend handling as a post-Sprint-1 refinement once the
three skills are functionally implemented (currently only `/yoke:bootstrap`
is — see project-status note in `CLAUDE.md`). Implement against the skill
files when each one is built; do not retrofit before the skill exists.

## Open Questions

- **Reject vs. restart.** Does option 3 mean *"discard this draft and re-run
  the dialogue from scratch"* (current `restart` semantics) or *"mark the
  artifact rejected and exit"* (a terminal state with no implicit re-run)?
  Recommend the latter, with an explicit secondary prompt offering re-run, so
  users who picked 3 by mistake aren't forced into a full restart.
- **Free-text feedback on option 4** — single-line prompt or multi-line?
  Acceptance Contract feedback can be long (BDD scenarios, fixture changes).
  Recommend multi-line input (terminate on blank line) for option 4 across
  all three skills.
- **Localization.** Skill prompts today render in the user's input language
  (per Vibeflow convention). The menu helper must preserve this — option
  labels translated, return values stable. Confirm before implementation.
- **Idempotency interaction.** When `.yoke/prd.md` already exists, the
  current discover skill prompts overwrite/save-as-v2/abort *before* running.
  The new menu fires *after* a fresh draft is generated. The two prompts do
  not collide, but the spec phase should make the ordering explicit.
