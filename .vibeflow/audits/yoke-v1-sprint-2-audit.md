# Audit Report: Yoke v1 — Sprint 2 (Discovery + Tech Spec)

> Audited: 2026-04-25
> Spec: `.vibeflow/specs/yoke-v1-sprint-2.md`
> Plugin version target: 0.2.0
> Dependencies satisfied: `.vibeflow/audits/yoke-v1-sprint-1-audit.md` (PASS)

**Verdict: PASS**

All 7 DoD checks satisfied. Pattern compliance clean across 4 patterns
(`roles.md`, `phase-flow.md`, `memory-model.md`, `human-triggers.md`).
Sprint-2 smoke test is green (25/25); Sprint-1 placeholder tests are
green (no regression); JSON manifests valid; all 14 shell scripts parse.

One **convention gap** discovered (not a DoD failure): the plugin
version was not bumped to 0.2.0 in `plugin.json`, `marketplace.json`,
and `CHANGELOG.md`. The Sprint-2 spec scope did not list these files,
but the post-marker `Implementation Plan Conventions` section in
`.vibeflow/conventions.md` requires it. Resolved as a 3-file post-audit
cleanup (see "Convention follow-ups").

DoD #2 (Generator dialogue + Trigger 1 approval pause) and DoD #3
(`/yoke:tech-spec` interactive flow) carry intrinsic runtime-verification
dependency on actually invoking the Generator subagent via Claude Code.
Strong in-code evidence (subagent prompt is substantive, skill scripts
contract the trigger prompts explicitly) makes PASS the right verdict
for the static artifacts. Runtime is manual.

## DoD Checklist

- [x] **Check 1 — `/yoke:discover` produces a valid `.yoke/prd.md` matching `templates/prd.md`.** Evidence: `skills/discover/SKILL.md` Step 4 ("Generator drafts `.yoke/prd.md` per `templates/prd.md`"); `templates/prd.md` carries the 5 manifesto sections (`Product invariants`, `Business context`, `Known constraints`, `Risks`, `Open questions`) — verified by smoke checks 5–9. Runtime PRD generation pending manual verification.
- [x] **Check 2 — Generator asks ≥1 clarifying question; doesn't return without explicit Trigger-1 approval.** Evidence: `agents/generator.md` Behaviors → "Ask at least one clarifying question before drafting an artifact if any meaningful ambiguity exists" + "Pause for explicit human approval after each artifact"; `skills/discover/SKILL.md` Step 4 explicit Trigger-1 prompt with `approve` / `revise <feedback>` / `restart` options and "skill does not return until the user responds explicitly". Runtime dialogue pending manual verification.
- [x] **Check 3 — `/yoke:tech-spec` produces valid `.yoke/tech-spec.md`, aborts on missing/unapproved PRD.** Evidence: `skills/tech-spec/SKILL.md` Step 1 ("If missing or unapproved, abort with: 'PRD missing or unapproved. Run /yoke:discover first.'"); Step 3 contracts ≥1 sprint, ≥1 task, explicit acceptance criterion per task; `templates/tech-spec.md` has `## Sprints` + `Acceptance criterion:` + `## Contracts and interfaces` + `## Dependencies` — verified by smoke checks 10–13. Runtime generation pending manual verification.
- [x] **Check 4 — `/yoke:ask` returns text-matched entries or empty-state; never loads full memory.** Evidence: `lib/canonical-memory/query.sh` caps output at 20 matches with truncation note; emits "no entries yet" / "no matches" / "not configured" empty-state messages — all three paths exercised by smoke checks 14–16 (empty repo, populated with match, populated without match).
- [x] **Check 5 — Generator subagent distinct from Implementation Agent (verifiable by prompt diff).** Evidence: smoke check 17 confirms Generator file size (~3.7KB) is more than 2× the Implementation placeholder (~0.9KB); content diff shows distinct persona, behaviors, restrictions, lineage section. The Generator's "Distinct from the Implementation Agent" section explicitly documents the separation.
- [x] **Check 6 — `tests/smoke/sprint-2.test.sh` exercises the flow end-to-end.** Evidence: `tests/smoke/sprint-2.test.sh` runs 25 checks covering frontmatter (3 SKILL.md), Generator substantiveness, both templates' manifesto-shape sections (9 checks), `query.sh` runtime behavior (3 paths), Generator/Implementation distinctness, and 7 anti-scope checks (Validator/Implementation/Validation/Orchestrator placeholders untouched + 4 hooks still skeletons). 25/25 PASS.
- [x] **Check 7 — Craftsmanship: Generator never reads canonical memory directly; no Don'ts violated.** Evidence: `agents/generator.md` "Never read canonical memory directly (no `cat`, no `grep`, no cloning the substrate repo). All reads go through `/yoke:ask`"; `skills/discover/SKILL.md` and `skills/tech-spec/SKILL.md` route Generator queries via `/yoke:ask` only. No `conventions.md` Don'ts violated.

## Pattern Compliance

- [x] **`roles.md` — Generator definition.** `agents/generator.md` matches the Implementation Mapping addendum exactly: memory scope `project`, allowed tools include `/yoke:ask`, restrictions explicit (never writes canonical memory, never reads canonical memory directly, never advances without approval). Distinction from Implementation Agent (runtime instance, Sprint 4) is explicitly documented.
- [x] **`phase-flow.md` — Phase 1 and Phase 2.** Both phases mapped to slash commands per the Implementation Mapping table: `/yoke:discover` (`skills/discover/SKILL.md`) and `/yoke:tech-spec` (`skills/tech-spec/SKILL.md`). The skills enforce the phase gate semantics — Phase 2 aborts without an approved Phase-1 artifact.
- [x] **`memory-model.md` — working-memory file ownership.** Generator writes only `.yoke/prd.md` (Phase 1) and `.yoke/tech-spec.md` (Phase 2). Canonical memory access goes only through `/yoke:ask` (mediated read; no write). The two tiers remain separated: working memory in `.yoke/` of the host project; canonical memory in an external repo accessed via cache at `~/.cache/yoke/canonical/<slug>/`.
- [x] **`human-triggers.md` — Triggers 1 and 2.** `/yoke:discover` emits the Trigger-1 prompt with options `approve` / `revise <feedback>` / `restart`; `/yoke:tech-spec` emits the Trigger-2 prompt with options `approve` / `revise <feedback>` / `back to PRD`. Schemas are non-coalescable — Trigger 1 has `restart`, Trigger 2 has `back to PRD`, both option sets are intentionally distinct.

## Convention Compliance

`conventions.md` Don'ts — applicable items honored:

- "Do NOT allow Generator/Validator to read canonical memory directly" → ✓ `agents/generator.md` restrictions explicit; both consuming skills route via `/yoke:ask`.
- "Do NOT allow any agent except Orchestrator to write to canonical memory" → ✓ no canonical-memory write logic in this sprint.
- "Do NOT load entire canonical memory into context" → ✓ `query.sh` caps at 20 matches.
- "Do NOT pin Yoke to upstream Vibeflow/Bedrock version" → ✓ both `skills/discover/SKILL.md` and `skills/tech-spec/SKILL.md` document the one-time-fork model with explicit upstream URLs and the planned per-skill mapping in `docs/lineage.md` at Sprint 8.

`Implementation Plan Conventions` (post-marker section):

- "Vertical slice before horizontal completeness" → ✓ Sprint 2 ships the spec-generation half of the binding-spec pillar; runtime ships in Sprint 4.
- "Smoke test per sprint" → ✓ `tests/smoke/sprint-2.test.sh` present, 25/25 PASS, exercises the new capability end-to-end against synthetic state.
- "Bash scripts target bash 4+" → ✓ `query.sh` uses standard POSIX features; bash 4-only features not invoked yet (script works on bash 3 too in practice, but spec deliberately targets 4+).
- "Lineage is documented honestly" → ✓ both new skills credit `pe-menezes/vibeflow` with explicit upstream URLs; per-skill mapping in `docs/lineage.md` (Sprint 8 scope).

### Convention gap discovered

**"Every sprint ships an installable plugin" / "Each sprint bumps the plugin version" not honored.**

- `.claude-plugin/plugin.json` — still `"version": "0.1.0"` (should be `0.2.0`).
- `.claude-plugin/marketplace.json` — `metadata.version` and `plugins[0].version` still `0.1.0`.
- `CHANGELOG.md` — has only the `[0.1.0]` entry; missing `[0.2.0]` for Sprint 2.

Sprint-2 spec scope did not include these three files, so the implementer
correctly stayed within the scope contract. This is a **spec-vs-convention
gap**: the spec template needs to include version-bump tasks per the
convention, OR the convention needs to be relaxed. Resolved as a 3-file
post-audit cleanup (see "Convention follow-ups" below) so v0.2.0 ships
honestly.

## Tests

- `tests/smoke/sprint-2.test.sh` → exit 0 (25/25 PASS) ✓
- `tests/plugin-install.test.sh` → exit 0 ✓ (Sprint 1 regression check)
- `tests/skills-format.test.sh` → exit 0 ✓ (Sprint 1 regression check)
- `python3 -c "import json; json.load(...)"` on both manifests → no errors ✓
- `bash -n` on all 14 shell scripts (including new `tests/smoke/sprint-2.test.sh`) → all parse ✓
- 9/9 SKILL.md frontmatters valid ✓

No `npm/pip/cargo/go` test runner (Claude Code plugin stack). Smoke test
is the de-facto test runner for this repo.

**No test failures.**

## Notes / process observations

- **One fix attempt during implementation.** `lib/canonical-memory/query.sh` initially failed the no-match smoke check because `set -e -o pipefail` aborted when grep returned 1 (no matches found). Fixed by capturing matches once with `|| true` and deriving total count from the captured output. Single attempt; fix is clean and idiomatic.
- **`/yoke:ask` cache directory and clone behavior.** New external dependency: `query.sh` clones the canonical-memory repo into `~/.cache/yoke/canonical/<slug>/` and best-effort pulls on subsequent runs. Documented in `docs/canonical-memory-setup.md`'s "How it works" section is not yet updated for this; worth a small docs follow-up in Sprint 3 or Sprint 8 polish.
- **`/yoke:discover` and `/yoke:tech-spec` use the Task tool.** This is the first sprint that exercises subagent invocation via the Task tool from within a skill. Validates Risk R1's PRD amendment ("skill invokes subagent" rather than "subagent spawns subagent") at the contract level. Runtime validation comes when an actual `/yoke:discover` is run against Claude Code.

## Manual verification owed

These items are intrinsic to a discover/tech-spec sprint and require Claude Code runtime testing:

1. Run `/yoke:discover "<idea>"` end-to-end and confirm the Generator asks ≥1 clarifying question, drafts a PRD matching `templates/prd.md`, and pauses on Trigger-1 (validates DoD #1 + #2).
2. Run `/yoke:tech-spec` against an approved PRD and confirm the produced Tech Spec has ≥1 sprint with ≥1 task and explicit acceptance criteria, and that the skill aborts when PRD is missing/unapproved (validates DoD #3).
3. Run `/yoke:ask "<term>"` against a real canonical-memory repo (multiple states: empty, populated with match, populated without match) — validates DoD #4 against a real `gh`-cloned canonical repo rather than a synthetic temp directory.

## Convention follow-ups (out-of-spec, applied post-audit)

To honor "Every sprint ships an installable plugin" / "Each sprint bumps the plugin version":

- `plugin.json` → bump `"version": "0.1.0"` to `"0.2.0"`.
- `marketplace.json` → bump `metadata.version` and `plugins[0].version` to `0.2.0`.
- `CHANGELOG.md` → add `[0.2.0] — 2026-04-25` entry above the `[0.1.0]` entry, listing the 8 Sprint-2 changes.

Recommendation: update the spec template (and `.vibeflow/conventions.md`)
to include version-bump tasks in every sprint's Scope section, so this
gap doesn't recur in Sprints 3–8. Worth a `/vibeflow:teach` round; not
blocking Sprint 3.

## Outstanding amendments (still pending from Sprint 1)

- PRD's v0 amendment ("Orchestrator becomes a skill") not yet backported to `.vibeflow/decisions.md`, `patterns/roles.md`, `patterns/plugin-structure.md`, `patterns/model-c-governance.md`. Required before Sprint 5. Sprint-2 implementation is consistent with the un-amended patterns.
- R1 spike (skill invokes subagent via Task tool) not yet executed. Sprint 2's `/yoke:discover` and `/yoke:tech-spec` are the first to ride this assumption at the contract level — validates conceptually but real Claude Code runtime testing still owed before Sprint 4.
- Pitfall from Sprint 1 audit ("default budget ≤ 4 wrong for scaffolding sprints") still pending a `/vibeflow:teach` follow-up.

---

**Verdict: PASS.** Sprint 2 is implementation-complete. Pattern + convention compliance clean modulo the version-bump gap, which is fixed as a post-audit 3-file cleanup. Runtime verification (Generator dialogue, `/yoke:ask` against a real canonical repo) is intrinsic manual work owed before public release.

Ready to proceed to Sprint 3 (`.vibeflow/specs/yoke-v1-sprint-3.md`).
