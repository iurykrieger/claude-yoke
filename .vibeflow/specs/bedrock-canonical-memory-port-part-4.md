# Spec: Bedrock canonical-memory port — Part 4: `/yoke:preserve` replaces `/yoke:canonize`

> Generated via /vibeflow:gen-spec on 2026-04-25
> Source PRD: `.vibeflow/prds/bedrock-canonical-memory-port.md`

## Objective

Make `/yoke:preserve` the single write entry to canonical memory:
the Orchestrator subagent invokes it at loop termination passing the
entire `.yoke/` working memory, and `/yoke:preserve` owns Model C
impact-class routing on top of bedrock's confirmation gate.

## Context

The current write path (`skills/canonize/SKILL.md` calling
`lib/canonical-memory/propose-write.sh`) has no entity model, no
bidirectional linking, no graceful update semantics. Bedrock's
`/preserve` ships all three. The PRD-resolved decision: Orchestrator
hands `.yoke/` to `/yoke:preserve` and `/preserve` decides what gets
canonized — Model C lives inside `/preserve` Phase 3 as policy on the
proposal, wrapping (not replacing) bedrock's confirmation gate.

## Definition of Done

1. `skills/preserve/SKILL.md` ships, copied from bedrock 1.2.1 with
   namespace renames (`/bedrock:*` → `/yoke:*`, vault → memory). The
   bedrock 7-phase flow is preserved (Phase 0 sync → 1 parse → 2 match
   → 3 propose → 4 execute → 5 link → 6 publish → 7 report).
2. Phase 3 (Change Proposal) is extended with Model C impact-class
   routing: every proposed write reads its `impact_level` (a Yoke
   rippability frontmatter field from Part 1) and routes via
   `lib/canonical-memory/canonization-criteria.sh` —
   `low` → PR with auto-merge; `medium` → PR with veto window;
   `high` → PR with `auto-merge: never` blocked on synchronous human
   ratification; `regulatory` → PR routed to Compliance reviewers
   only. Matches `.vibeflow/patterns/model-c-governance.md`
   Implementation Mapping verbatim.
3. `agents/orchestrator.md` is refactored: the canonize-mode
   responsibility narrows to "invoke `/yoke:preserve` via the Skill
   tool, passing the active task's `.yoke/` directory path." The
   Orchestrator no longer calls `propose-write.sh` and no longer
   classifies impact itself — `/yoke:preserve` Phase 1.2 (free-form
   parsing) and Phase 3 (Model C) own those.
4. `skills/canonize/SKILL.md` and `lib/canonical-memory/propose-write.sh`
   are deleted. `lib/canonical-memory/canonization-criteria.sh`
   survives, repurposed as the Model C classifier invoked from
   `/yoke:preserve` Phase 3.
5. Bidirectional linking (bedrock Phase 5) executes for every accepted
   entity write. People/teams/concepts/topics respect the merge-only
   rule from `entities/{type}.md` (Part 1). The 5 Yoke rippability
   fields are never deleted on update.
6. Three git strategies (`commit-push`, `commit-push-pr`,
   `commit-only`) are honored, read from
   `<memory>/.yoke-memory/config.json`. Default for new memories is
   `commit-push-pr` — Yoke's Model C mandates PR-based protocol;
   `commit-push` is a low-stakes opt-in, `commit-only` is for offline
   use. `templates/yoke-memory-config.json` (Part 1) reflects this
   default.
7. **Quality gate:** No canonical-memory write occurs outside
   `/yoke:preserve` after this part lands. Verified by:
   (a) zero in-tree references to `propose-write.sh`,
   (b) zero direct `git -C <memory> commit` outside `skills/preserve/`
   in the codebase grep, and (c) updates to
   `.vibeflow/patterns/memory-model.md` and
   `.vibeflow/patterns/model-c-governance.md` reflecting the new
   wiring (preserve = single write point; orchestrator delegates).

## Scope

- `skills/preserve/SKILL.md` (new, copied from bedrock 1.2.1).
- `agents/orchestrator.md` refactor (canonize-mode delegation).
- Deletion of `skills/canonize/` and
  `lib/canonical-memory/propose-write.sh`.
- Repurposing of `lib/canonical-memory/canonization-criteria.sh` as
  the Model C classifier inside `/yoke:preserve` Phase 3.
- Pattern updates: `.vibeflow/patterns/memory-model.md`,
  `.vibeflow/patterns/model-c-governance.md`.
- Smoke test: high-impact proposal blocks on synchronous ratification
  (no merge happens without explicit approval).

## Anti-scope

- No `/yoke:teach` ingestion path (Part 5).
- No `/yoke:compress` (Part 6).
- No graphify Phase 0.2 merge logic (deferred sprint).
- No automatic fleeting → permanent promotion (PRD anti-scope).
- No new `code` 9th entity type — preserve's classification ignores
  `file_type: code` for now (TODO in code with reference to the
  graphify sprint).

## Technical Decisions

- **Model C lives inside Phase 3, not as a parallel skill.** Bedrock's
  Phase 3 already has the proposal + confirmation step; injecting
  impact-class routing there keeps governance and mechanics
  co-located. A separate "model-c skill" would fork the write path.
- **Default git strategy for Yoke memories is `commit-push-pr`.** Yoke
  Model C demands PR-based protocol; `commit-push` is allowed only
  for memories explicitly configured as low-stakes (test memories,
  personal scratch). `commit-only` is for offline use. Bedrock's
  default of `commit-push` is **not** carried over — this is a
  deliberate deviation, documented in lineage.
- **Orchestrator passes paths, not contents.** Subagent context is
  expensive; the Orchestrator passes the `.yoke/<task-slug>/` path and
  `/yoke:preserve` reads the files itself. Avoids subagent context
  blow-up (R-4.1).
- **`/yoke:preserve` confirmation prompt depends on impact class.**
  `low` → bedrock's "yes/no/adjust" is the ratification (PR auto-merges
  after checks). `medium` → prompt is informational; PR auto-merges
  after veto window. `high` → prompt is informational; PR blocks until
  human merges manually. `regulatory` → prompt explicitly says "this
  PR will be routed to Compliance only; merge is not yours."

## Applicable Patterns

- `.vibeflow/patterns/memory-model.md` — `/yoke:preserve` becomes the
  sole write entry. This part rewrites the "Who writes" section
  accordingly.
- `.vibeflow/patterns/model-c-governance.md` — Implementation Mapping
  rewrites: `propose-write.sh` → `skills/preserve/` Phase 3 (with
  `canonization-criteria.sh` as the classifier).
- `.vibeflow/patterns/roles.md` — Orchestrator's canonize-mode
  responsibility narrows; this part updates the role description.
- `.vibeflow/patterns/human-triggers.md` — Trigger 5 (canonization
  ratification) now fires inside `/yoke:preserve` Phase 3.
- `.vibeflow/patterns/ralph-loop.md` — loop termination handoff to
  `/yoke:preserve` updated.

## Risks

- **R-4.1 — Orchestrator subagent context window.** Passing `.yoke/`
  contents wholesale would blow the budget. *Mitigation:* pass the
  task path only; `/yoke:preserve` reads files itself. DoD-3 enforces.
- **R-4.2 — Model C regression on `high` writes.** Folding routing
  into bedrock Phase 3 risks accidentally weakening synchronous
  ratification. *Mitigation:* DoD-7 quality gate plus a smoke test
  that submits a `high` proposal and asserts `gh pr view --json
  autoMergeRequest` returns null until manual merge.
- **R-4.3 — Bidirectional-linking storm.** N relations × M entities
  produces huge diffs and slow PRs. *Mitigation:* cap relations per
  write at 20 per entity type (matches bedrock's safety rule in
  Phase 2.2).
- **R-4.4 — Default `commit-push-pr` requires `gh` CLI.** Memories
  configured with `commit-push-pr` will fail without `gh` installed.
  *Mitigation:* bootstrap (Part 2) verifies `gh`; preserve falls back
  to `commit-push` with a warning when `gh` is missing, matching
  bedrock 1.2.1's existing behavior.

## Dependencies

- `.vibeflow/specs/bedrock-canonical-memory-port-part-1.md`
- `.vibeflow/specs/bedrock-canonical-memory-port-part-2.md`
