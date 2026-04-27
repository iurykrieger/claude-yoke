# Spec: Approval menu — roll out to Triggers 2 and 3

> Generated via /vibeflow:gen-spec on 2026-04-25 from `.vibeflow/prds/plan-options.md`.
> Part 2 of 2. Propagates the menu shape established in Part 1 to
> `/yoke:tech-spec` (Trigger 2) and `/yoke:acceptance-contract` (Trigger 3),
> including the special handling required by the Acceptance Contract's
> binding statement.

## Dependencies

- `.vibeflow/specs/plan-options-part-1.md`

Part 1 must ship first: it creates `templates/approval-menu.md` and proves
the chained-skill mechanism on `/yoke:discover`. Part 2 references that
template by path and inherits its behavior contracts (4 options, internal
verbs, multi-line input on option 4, language-localized labels,
open-questions detection rule, warning confirmation on option 1, fallback
when `Skill` tool is unavailable).

## Objective

Apply the shared 4-option approval menu (defined in Part 1) to
`/yoke:tech-spec` (Trigger 2 → next phase `/yoke:acceptance-contract`) and
`/yoke:acceptance-contract` (Trigger 3 → next phase `/yoke:implement`),
while preserving the Acceptance Contract's binding statement.

## Context

After Part 1 ships, `/yoke:discover` ends with the structured menu and
chains into `/yoke:tech-spec` on option 1. But `/yoke:tech-spec` and
`/yoke:acceptance-contract` still print free-text manual-paste lines —
`skills/tech-spec/SKILL.md` line 71 and `skills/acceptance-contract/SKILL.md`
line 100. Until Part 2 ships, the user lands back into copy/paste mode at
the second and third gates and the feature does not deliver end-to-end.

The Acceptance Contract introduces one wrinkle: Trigger 3 carries a
**binding statement** that must be ratified verbatim (per
`patterns/human-triggers.md` and `agents/validator.md` — the contract is
"binding" once approved). The approval menu must not paraphrase, replace,
or hide this binding text. The menu options (1–4) follow the binding
statement; they do not substitute for it.

## Definition of Done

1. `skills/tech-spec/SKILL.md` references `templates/approval-menu.md` for
   Trigger 2 in place of today's free-text prompt at line 71. Option 1's
   chained next-phase target is `/yoke:acceptance-contract`.
2. `skills/acceptance-contract/SKILL.md` references `templates/approval-menu.md`
   for Trigger 3 in place of today's free-text prompt at line 100. Option
   1's chained next-phase target is `/yoke:implement`.
3. The Acceptance Contract skill body explicitly preserves the binding
   statement: the menu is rendered **after** the binding-ratification text,
   not in place of it. The skill prose names "binding statement" as a
   required pre-menu element.
4. The open-questions detection rule from Part 1 (DoD #2) extends to both
   skills: scan the artifact body for inline `TODO:` / `TBD:` / `FIXME:` /
   `<placeholder>` markers and any `## Open questions` section content if
   present. The warning confirmation on option 1 (Part 1 DoD #3) fires
   identically across all three gates — count of unresolved items is named,
   confirmation `yes` / `no` is required.
5. Approval-metadata semantics on options 1 and 2 match Part 1's pattern:
   `Status: approved`, `Approved by`, `Approved at` written to
   `.yoke/tech-spec.md` and `.yoke/acceptance-contract.md` respectively.
   Today's per-skill metadata format is preserved unchanged.
6. `.vibeflow/patterns/human-triggers.md` Implementation Mapping table is
   updated to mark Triggers 2 and 3 as using `templates/approval-menu.md`
   (replacing the "trigger-N schema" cells), with an explicit exclusion
   note retained for Triggers 4 and 5.
7. **Quality gate.** A grep over `skills/implement/SKILL.md` and
   `skills/canonize/SKILL.md` returns zero references to
   `templates/approval-menu.md`. Triggers 4 and 5 must remain untouched
   — the structural separation called out in `patterns/human-triggers.md`
   ("coalescing them is a smell") survives this spec.

## Scope

- Edit `skills/tech-spec/SKILL.md`: replace the free-text Trigger-2 prompt
  block and the trailing manual-paste line with a reference to
  `templates/approval-menu.md`. Specify the chained next-phase target
  (`/yoke:acceptance-contract`).
- Edit `skills/acceptance-contract/SKILL.md`: same pattern, with the
  binding-statement preservation requirement called out explicitly in the
  skill prose. Chained next-phase target is `/yoke:implement`.
- Update `.vibeflow/patterns/human-triggers.md` Implementation Mapping
  table to reflect the final state: shared menu shape for Triggers 1/2/3,
  exclusion note for Triggers 4/5.

## Anti-scope

- **Triggers 4 and 5 remain untouched.** Trigger 4 (`/yoke:implement`
  divergence arbitration) has 4 distinct decisions (reformulate Contract /
  reformulate Tech Spec / accept trade-off / abort) that do not fit the
  generic 4-option shape. Trigger 5 (`/yoke:canonize`) is governed by
  Model C and adding a synchronous menu reintroduces blocking on every
  canonization. DoD #7 enforces this with a grep.
- **No changes to `templates/tech-spec.md` or `templates/acceptance-contract.md`.**
  The open-questions detection rule from Part 1 scans for inline `TODO:` /
  `TBD:` / `FIXME:` / `<placeholder>` markers and works without forcing a
  dedicated `## Open questions` section in those templates.
- **No changes to `agents/generator.md` or `agents/validator.md`** — they
  produce the artifact body; the menu is a post-artifact surface.
- **No changes to chained-execution semantics established in Part 1** —
  same `Skill` tool invocation, same fallback behavior. If Part 1's
  fallback works for `/yoke:discover`, it works identically here.
- **No changes to the binding-contract concept itself** — Trigger 3 stays
  binding once ratified; the menu does not relax this property, only
  surfaces the decision differently.
- **No retroactive migration** of existing `.yoke/tech-spec.md` or
  `.yoke/acceptance-contract.md` files written under the old flow.

## Technical Decisions

### Binding statement appears before the menu, not inside it

The Acceptance Contract's binding statement is doctrinally distinct from
the menu options — it is the legal text that defines what the user is
ratifying, while the menu is the choice of how to act on it. Embedding the
binding statement inside an option label would dilute both: the binding
text gets truncated and the menu option becomes a long sentence.

**Trade-off.** Two visible blocks (binding statement + menu) at the end of
Phase 3, instead of one. Cost: slightly more vertical space. Benefit:
preserves the binding statement's audit-log status.

### Open-questions detection unchanged from Part 1

Reuse Part 1's body-scanning rule (inline markers + optional section).
Tech-spec and acceptance-contract templates do not have an `## Open
questions` section today and Part 2 does not add one — the inline-marker
fallback is sufficient and avoids a 5-file change in Part 2.

**Trade-off.** Tech-spec authors who want explicit open questions must
either use inline `TODO:` markers or add an `## Open questions` section
manually. Acceptable for v0; if patterns shift, a template update can be
proposed separately under Model C.

### No new pattern doc

Part 1's decision deferred a "shared menu template across like triggers"
pattern until shape stabilized. After Part 2, the shape is exercised on
all three gates — but proposing a new pattern is an Orchestrator/Phase-5
canonization concern, not a spec-level concern. Leave the pattern proposal
to a future canonization round; this spec only updates the existing
Implementation Mapping table.

## Applicable Patterns

- **`patterns/human-triggers.md`** — same primary pattern as Part 1.
  DoD #6 finalizes the Implementation Mapping table. DoD #7 enforces the
  "no coalescing" rule against Triggers 4/5.
- **`patterns/phase-flow.md`** — option 1 chained invocations: Phase 2 →
  Phase 3 (`/yoke:tech-spec` → `/yoke:acceptance-contract`) and Phase 3 →
  Phase 4 (`/yoke:acceptance-contract` → `/yoke:implement`). No new phase.
- **`patterns/acceptance-contract.md`** — relevant for DoD #3
  (binding-statement preservation).
- **`patterns/roles.md`** — no role changes, same as Part 1.

## Risks

- **Risk: binding statement gets paraphrased or omitted.** The skill body
  for `/yoke:acceptance-contract` may, when refactored to use the menu,
  inadvertently absorb the binding statement into option 1's label.
  **Mitigation:** DoD #3 makes the binding statement an explicit pre-menu
  element. Implementation review must confirm a verbatim binding-statement
  block remains.
- **Risk: chained invocation lands in `/yoke:implement` (Phase 4) too
  eagerly.** Trigger 3 → Phase 4 transition is the highest-stakes
  transition in the system (binding contract → adversarial ralph loop).
  Auto-chaining via option 1 may surprise users who expected a manual
  break here. **Mitigation:** the open-questions warning from Part 1 DoD
  #3 already provides a confirmation barrier when unresolved items exist.
  For the case where no open questions exist and the user explicitly picks
  option 1, this is the desired behavior — but a future spec may add a
  per-trigger config to disable auto-chain on Trigger 3 specifically.
  Out of scope for this spec.
- **Risk: Triggers 4/5 are accidentally touched.** A future skill author
  may copy the menu pattern into `/yoke:implement` or `/yoke:canonize`
  thinking it is a generic "trigger" surface. **Mitigation:** DoD #7
  bakes a grep check into the spec; the human-triggers pattern doc
  retains the "do not coalesce" anti-pattern note (line 86).
- **Risk: tech-spec users miss the open-questions warning because their
  artifact uses no inline markers.** A tech-spec author may write a
  Tech Spec with implicit gaps (vague language) but no `TODO:`/`TBD:`.
  Detection returns empty; warning never fires. **Mitigation:**
  documented in Part 1's "best-effort" framing. Improving detection (e.g.,
  vagueness heuristics) is an LLM-judgment problem and would violate the
  "deterministic surface" decision in Part 1. Leave for a future iteration.
