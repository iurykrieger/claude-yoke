# Audit Report: phase-persona-rebalance — Part 1

> Audited 2026-04-25 against `.vibeflow/specs/phase-persona-rebalance-part-1.md`.

**Verdict: PASS**

## Test Results

Full bash test suite executed: **15 / 15 PASS, 0 FAIL.**

```
PASS  tests/plugin-install.test.sh
PASS  tests/skills-format.test.sh
PASS  tests/smoke/ask-no-clone.test.sh
PASS  tests/smoke/folder-isolation.test.sh
PASS  tests/smoke/memory-migration.test.sh
PASS  tests/smoke/preserve-model-c.test.sh
PASS  tests/smoke/sprint-2.test.sh        ← exercises discover + tech-spec
PASS  tests/smoke/sprint-3.test.sh
PASS  tests/smoke/sprint-4.test.sh
PASS  tests/smoke/sprint-5.test.sh
PASS  tests/smoke/sprint-6.test.sh
PASS  tests/smoke/sprint-7.test.sh
PASS  tests/smoke/sprint-8.test.sh
PASS  tests/smoke/status-readonly.test.sh
PASS  tests/smoke/teach-ingest.test.sh
```

The most directly relevant suite (`sprint-2.test.sh`) covers
`/yoke:discover` and `/yoke:tech-spec` end-to-end across 32
assertions including:

- frontmatter validity for both skills
- `allowed-tools` excludes `Task` (skill-only invariant)
- both skills "embed persona inline" (asserted via the regex
  `Generator persona|Your role .*persona` — the post-edit headings
  `## Your role (Product Manager persona, inline)` and
  `## Your role (Senior Engineer persona, inline)` both match the
  second alternation, preserving the assertion)
- canonical-memory reads route through `/yoke:ask`
- Trigger-1 / Trigger-2 binding prompts present
- pre-rename / spec-phase agent files removed in v1.1

## DoD Checklist

- [x] **DoD #1 — Discover persona is literal Product Manager.**
  `skills/discover/SKILL.md:28` reads
  `## Your role (Product Manager persona, inline)`. Body line
  `skills/discover/SKILL.md:30` opens with
  `You are running this skill as the **Product Manager persona**`.
  The umbrella label "Generator persona" no longer appears as a role
  declaration in this skill (only as a literal inside the lineage
  comment block at the top of the file describing what was *renamed
  from*, which is allowed historical context).

- [x] **DoD #2 — Discover dialogue is product-only.**
  `git diff skills/discover/SKILL.md` is bounded to the
  `## Your role` section. The whole-file grep for forbidden terms
  ("architecture", "framework", "stack", "file layout", "integration
  contract", "dependency direction") inside the persona / dialogue
  surfaces exactly one hit at line 99
  (`- Alert if the idea conflicts with current architecture.`),
  which sits inside the pre-existing `Use canonical memory (via
  /yoke:ask) when relevant to:` block at lines 96–99. DoD #2
  explicitly excludes "canonical-memory / `/yoke:ask` references and
  pre-existing scaffolding text" — verified pre-existing by `git
  diff`, which shows the line unchanged.

- [x] **DoD #3 — Tech-spec persona is literal Senior Engineer.**
  `skills/tech-spec/SKILL.md:27` reads
  `## Your role (Senior Engineer persona, inline)`. Body line
  `skills/tech-spec/SKILL.md:29` opens with
  `You are running this skill as the **Senior Engineer persona**
  (CTO- style)`. Persona body cites architecture, frameworks /
  libraries, integration contracts, dependency directions — every
  marker required by the engineering-shaped persona. Umbrella
  "Generator persona" label removed.

- [x] **DoD #4 — Tech-spec clarity check is engineering-shaped.**
  `skills/tech-spec/SKILL.md:64–82` carries exactly three
  engineering checks: **Stack fit** (line 66), **Framework /
  library choices named with trade-offs?** (line 69), **Sprint
  partitionable with binary acceptance criterion per task?**
  (line 73). The prior product-shaped trio
  (use-cases-unambiguous? / constraints-documented? /
  sprint-partitionable?) is **replaced**, not appended — diff
  confirmed.

- [x] **DoD #5 — Sprint + use-case-task + binary-acceptance-
  criterion mandate survives.**
  Step 4 (lines 84–104) retains all six bullets:
  acceptance-criterion (with examples that PASS / FAIL the bar),
  ≥ 1 sprint, ≥ 1 task per sprint as use case, contracts and
  interfaces, dependencies, risks per sprint. The
  binary-acceptance-criterion bullet is hoisted to position 1 and
  reinforced with the new sentence
  `This is the load-bearing requirement of the Tech Spec — every
  task without one is rejected before it leaves the draft.` —
  the mandate strengthens, never weakens, exactly as Decision 1
  in the spec authorizes.

- [x] **DoD #6 — Decisions + lineage updated.**
  `.vibeflow/decisions.md` carries exactly two new entries dated
  `2026-04-25`, both prepended above the prior 2026-04-25 entries
  per the "newest first" log convention:
  - "Discover persona = Product Manager (literal naming, drop
    umbrella label)"
  - "Tech-spec persona = Senior Engineer / CTO (literal naming,
    engineering clarity-checks)"

  Both entries follow the existing format
  (`### YYYY-MM-DD — <title>`, `**Decision:**`, `**Context:**`,
  `**Discarded alternatives:**`) and cite the PRD source
  (`phase-persona-rebalance.md`) plus the open-question they
  resolve.

  `docs/lineage.md` gained two adaptation bullets — one in
  `### skills/discover/SKILL.md` and one in
  `### skills/tech-spec/SKILL.md`. Each bullet starts with
  `**Persona rebalance (2026-04-25):**` and cross-references the
  matching `.vibeflow/decisions.md` entry. The pre-existing
  adaptation bullets (namespace rename, output-shape switch,
  Generator-subagent wiring, `/yoke:ask` routing, Trigger
  prompts) are preserved unchanged.

- [x] **DoD #7 — Craftsmanship, no scaffolding regression.**
  `git diff --stat` reports four files touched
  (`.vibeflow/decisions.md`, `docs/lineage.md`,
  `skills/discover/SKILL.md`, `skills/tech-spec/SKILL.md`) — at
  budget, no extras. Per-file inspection:
  - `skills/discover/SKILL.md` — only the `## Your role` block
    changed (lines 28–45). Every `wm_*_path` invocation, every
    Trigger-1 menu reference, every `Skill`-tool fallback line,
    every `/yoke:ask` constraint, the entire `## Anti-patterns`
    section, `## Pre-conditions`, `## Output contract`, and
    `## See also` are byte-identical to baseline.
  - `skills/tech-spec/SKILL.md` — three regions changed:
    `## Your role` (lines 27–40), step 3 clarity-evaluation
    (lines 62–82), and step 4 bullet reorder + reinforcement
    (lines 88–95). All three are explicitly authorized by the
    spec's Scope section. Every `wm_tech_spec_path` /
    `wm_active_slug` / `wm_prd_path` invocation, the Trigger-2
    menu invocation, the `Skill`-tool fallback, the
    `/yoke:ask`-only canonical-memory constraint, the entire
    `## Anti-patterns` section, `## Pre-conditions`,
    `## Output contract`, and `## See also` are byte-identical to
    baseline.
  - Neither skill has `Task` in `allowed-tools` (verified by
    `grep "^allowed-tools:"` and by `sprint-2.test.sh`).
  - `tests/smoke/sprint-2.test.sh` — 32/32 assertions PASS.

## Pattern Compliance

- [x] **`patterns/roles.md` — spec-phase Generator persona inline
  in skills.** Both skills retain inline persona (just renamed
  literally). Neither spawns subagents at spec phase. `Task` not
  in `allowed-tools`. Canonical-memory reads route through
  `/yoke:ask`. Adversarial separation preserved (the human at
  Triggers 1/2/3 remains the adversary; no subagent
  adversariality introduced at spec phase). The pattern's claim
  that "spec-phase Generator persona lives inline" remains
  factually true after the rename — the *abstract Generator role*
  at the manifesto level is unchanged; only the *literal
  per-skill persona name* shifts.

- [x] **`patterns/phase-flow.md` — Phase 1 / Phase 2 binding
  artifacts and gates preserved.** PRD remains the binding artifact
  of Phase 1; Tech Spec remains the binding artifact of Phase 2.
  Trigger 1 / Trigger 2 surfaces preserved at the end of each
  skill. No phase boundary moved.

- [x] **`patterns/human-triggers.md` — Triggers 1 and 2 surfaces
  intact.** Both skills still render the shared approval menu via
  `templates/approval-menu.md`, both still apply the
  open-questions detection block, both still carry the
  `Skill`-tool fallback. The `binding_statement` parameter is
  empty for both (correct — Triggers 1 and 2 are non-binding gates
  per pattern).

- [x] **`patterns/plugin-structure.md` — file layout unchanged.**
  `skills/discover/SKILL.md`, `skills/tech-spec/SKILL.md`, and
  `docs/lineage.md` remain at their canonical paths.

- [x] **`conventions.md` § Lineage is documented honestly.** Both
  refined skills receive a new adaptation bullet in
  `docs/lineage.md` citing the persona rebalance and linking to
  the matching `.vibeflow/decisions.md` entry. The honesty
  statement at the bottom of `lineage.md` is preserved unchanged.

- [x] **`conventions.md` Don'ts.** No Don'ts violated. In
  particular:
  - "Do NOT pin Yoke to a specific upstream version of Vibeflow
    or Bedrock" — neither edit introduces a runtime dependency on
    upstream; the lineage row reference to "1.10.0" is a frozen
    historical pointer, not a subscription.
  - "Spec-phase skills do not spawn subagents" — preserved
    (`allowed-tools` excludes `Task` in both files).

## Convention Violations

None.

## Anti-scope Compliance

All anti-scope items respected:

- `agents/generator.md` — not touched (Part 2 territory).
- All other skill files (`acceptance-contract`, `implement`,
  `bootstrap`, `status`, `ask`, `preserve`, `drift-sense`,
  `compress`, `teach`, `memory`, `confluence-to-markdown`,
  `gdoc-to-markdown`) — not touched.
- `templates/`, `lib/`, `hooks/`, `tests/`, `.vibeflow/index.md` —
  not touched.
- No new patterns introduced.
- No port of Vibeflow's PRD-validation 5-check gate verbatim
  (only the *ethos* — engineering questions — crossed over).
- Neither skill gained `Task` in `allowed-tools`.

## Risks Surfaced During Implementation

The spec listed five risks (R-P1.1 through R-P1.5). Audit
disposition:

- **R-P1.1 (persona drift back to shared territory)** — mitigated.
  The Discover persona is purely product-shaped; the Tech-spec
  persona is purely engineering-shaped. Side-by-side comparison
  confirms zero overlap on the persona role description.
- **R-P1.2 (engineering questions list grows)** — mitigated. The
  clarity-check stays at three checks, mirroring the discover
  fast-track shape.
- **R-P1.3 (`docs/lineage.md` shape clash with Sprint 8)** —
  non-issue. The file already existed in expanded form (Bedrock
  port additions through Part 6); the new bullets append into the
  existing skill-specific sections without restructuring the file.
- **R-P1.4 (smoke-test regression on persona text)** — mitigated.
  The pre-existing assertion at `tests/smoke/sprint-2.test.sh:60`
  uses the regex `Generator persona|Your role .*persona`, which
  the new heading `Your role (Product Manager persona, inline)` /
  `Your role (Senior Engineer persona, inline)` both satisfy via
  the second alternation. No test edit needed.
- **R-P1.5 (decision-log convention drift)** — mitigated. Both new
  entries copy the existing entry shape exactly (header, three
  bold fields, no invented fields).

## Gaps

None.

## Next Steps

**Ready to ship Part 1.** Part 2 is unblocked. Recommend:

```
/vibeflow:implement .vibeflow/specs/phase-persona-rebalance-part-2.md
```
