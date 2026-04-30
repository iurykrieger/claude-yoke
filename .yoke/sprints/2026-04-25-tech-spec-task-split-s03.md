# Sprint 03 of 03: Tech Spec Task Split

> Migrated from: # Spec: Tech Spec Task Split — Part 3 — Acceptance Contract consumer + migration


> Generated via /vibeflow:gen-spec on 2026-04-25
> PRD: `.vibeflow/prds/tech-spec-task-split.md`
> Plugin version target: 0.7.0 (working-memory rev)

## Objective

Update `/yoke:acceptance-contract` to consume the new spec + per-task
layout and emit one BDD scenario per task file; provide a one-shot
migration helper that reuses Part 2's 3-stage pipeline against legacy
`.yoke/tech-specs/<slug>.md` archives.

## Context

After Parts 1 and 2 land, `/yoke:tech-spec` produces
`.yoke/specs/<slug>.md` plus N per-task files. `/yoke:acceptance-contract`
currently reads a single `wm_tech_spec_path` and emits "one BDD
scenario per task" against the inline task list. With the layout
change, the skill must read the spec **plus** every task file the
`wm_list_task_paths` helper returns and emit one BDD scenario per
task file — using each task file's *Validation* section as the input
to that scenario's Then clauses.

Part 3 also lands the migration helper. Yoke v1 is pre-1.0 with no
shipped users, but the framework author has working copies under
`.yoke/tech-specs/` from prior sprints. `migrate-tech-specs.sh`
reuses the 3-stage pipeline: Generator drafts the new spec from the
legacy file, `scaffold-tasks.sh` materializes empty task files, the
Generator fills each. The legacy file is left in place — the helper
is non-destructive.

Phase 3's binding semantics (`patterns/acceptance-contract.md`,
manifesto §8.3) do not change. The Acceptance Contract remains the
binding artifact; the upstream-spec split only changes the **input
shape** to its generation, not the output's authority.

## Definition of Done

1. `/yoke:acceptance-contract` reads `wm_spec_path "$slug"` plus every
   path returned by `wm_list_task_paths "$slug"`, and emits one BDD
   scenario per task file. Each task file's *Validation* section
   feeds that scenario's Then clauses; the spec's overall objective
   feeds the Contract's preamble. Verifiable by inspecting the
   generated `.yoke/acceptance-contracts/<slug>.md` against the
   number of task files for the slug — counts must match exactly.
2. `templates/acceptance-contract.md` documents the BDD-per-task
   shape: each scenario carries `Task: <task-id>` plus `Given` /
   `When` / `Then` blocks plus `Fixture:` / `Sensors:` lines, in a
   shape `hooks/verify-acceptance.sh` already parses (no
   verify-acceptance changes in this spec — the parser already
   tolerates a `Task:` line as opaque metadata). The binding
   statement section is preserved verbatim.
3. The Acceptance Contract remains the binding artifact. The skill
   prints the binding statement before Trigger 3, ratification
   chains into `/yoke:implement` on `approve_and_continue`, and the
   `patterns/acceptance-contract.md` rules ("Contract without
   measurable criteria is rejected", "every BDD scenario must have
   at least one fixture or sensor") are obeyed — verifiable by
   prompt-diff against the prior body and by a smoke-test assertion
   that the rendered Contract contains a `Sensors:` line per scenario.
4. The skill aborts with a `wm:`-prefixed message and non-zero exit
   when `wm_spec_path "$slug"` is missing or unapproved, **or** when
   `wm_list_task_paths "$slug"` returns zero paths, **or** when any
   listed task file lacks `Status: approved` in its frontmatter. No
   silent degradation to "use whatever is there".
5. `lib/working-memory/migrate-tech-specs.sh <legacy-spec-path>`
   produces the new layout for the slug encoded in the legacy
   filename via the 3-stage pipeline:
   (a) Generator drafts `.yoke/specs/<slug>.md` from the legacy
   monolith (LLM call, persona-bounded);
   (b) `scaffold-tasks.sh` materializes the empty task files;
   (c) Generator fills each task file (LLM-per-task).
   The legacy file at `.yoke/tech-specs/<slug>.md` is **not** deleted
   or modified; the new files are written alongside. Re-running with
   the same slug fails fast if `.yoke/specs/<slug>.md` already exists
   (no overwrite).
6. **Craftsmanship gate.** The skill obeys
   `.vibeflow/patterns/acceptance-contract.md` (binding artifact,
   BDD-per-task, no Generator-produced Contract — the Validator
   persona stays inline per the 2026-04-25 decision),
   `.vibeflow/patterns/sensors.md` (structured output preserved
   downstream of `verify-acceptance.sh`), the
   `.vibeflow/conventions.md` Don'ts (no canonical-memory direct
   reads — every cross-task lookup goes through `/yoke:ask`), and
   the `patterns/human-triggers.md` shared-menu rule for Trigger 3.
   No `wm_tech_spec_path` references introduced in the migration
   helper or anywhere else.
7. `tests/smoke/sprint-2.test.sh` is extended end-to-end:
   `/yoke:bootstrap` → `/yoke:discover` → `/yoke:tech-spec`
   (Part 2) → `/yoke:acceptance-contract` (Part 3); asserts the
   resulting `.yoke/acceptance-contracts/<slug>.md` has exactly one
   BDD scenario per task file produced and that
   `hooks/verify-acceptance.sh` parses it without error.

## Scope

- `skills/acceptance-contract/SKILL.md` (modify) — replace the
  single-file read with `wm_spec_path` + `wm_list_task_paths` reads;
  rewrite the drafting prompt to emit one BDD scenario per task
  file, sourcing `Then` clauses from each task's *Validation*
  section; preserve binding statement, Trigger 3 menu, and chain
  into `/yoke:implement` on `approve_and_continue`. Update
  pre-conditions to require approved spec + every task file at
  `Status: approved`.
- `templates/acceptance-contract.md` (modify) — pin the BDD-per-task
  shape per DoD #2; add the per-scenario `Task: <task-id>` line; keep
  the binding-statement section verbatim.
- `lib/working-memory/migrate-tech-specs.sh` (new) — one-shot bash
  helper that orchestrates the 3-stage pipeline against a legacy
  `.yoke/tech-specs/<slug>.md`. Per-stage failure exits non-zero
  with a precise error; the legacy file is read-only throughout.
- `tests/smoke/sprint-2.test.sh` (modify) — extends the Part-2
  smoke test with the `/yoke:acceptance-contract` step and the
  `verify-acceptance.sh` parse assertion.

## Anti-scope

- **No `hooks/verify-acceptance.sh` changes.** The Sprint-3 sensor
  parser already tolerates additional metadata lines per BDD
  scenario; the new `Task:` line is opaque to it. Sensor-type
  expansion is Sprint-5+ territory per
  `.vibeflow/specs/yoke-v1-sprint-3.md` Anti-scope.
- **No multi-language CLAUDE.md parsing.** Sensor discovery via
  `lib/sensors/discover-from-claude-md.sh` is unchanged.
- **No retroactive rewrite of `.vibeflow/specs/yoke-v1-sprint-*.md`.**
  Those are Vibeflow-generated meta-specs for Yoke itself; the new
  layout applies only to `.yoke/specs/` in host projects.
- **No deletion of legacy `.yoke/tech-specs/<slug>.md` files.** The
  migration helper is non-destructive. Cleanup is a manual `git rm`
  the user runs after verifying the new layout.
- **No automatic migration on `/yoke:bootstrap`.** Migration is
  explicit via `migrate-tech-specs.sh`; bootstrap does not silently
  rewrite working memory.
- **No diff-preserving migration.** If the user edited an old
  monolithic tech-spec by hand, those edits land in the new spec via
  the LLM's draft step and may not survive verbatim. The legacy file
  staying on disk is the audit trail.
- **No backward-compat read path** in `/yoke:acceptance-contract`.
  When the spec/task files are absent, the skill aborts with the
  migration instruction; it does not fall back to reading
  `.yoke/tech-specs/<slug>.md`.

## Technical Decisions

- **One BDD scenario per task file, not per Validation bullet.** A
  task's *Validation* section may list multiple checks, but they
  collapse into a single scenario's Then-clause block. Trade-off:
  scenarios with many checks become long; otherwise sensor-to-scenario
  mapping in `verify-acceptance.sh` would need rethinking. Win: clean
  1:1 mapping between task files and scenarios — exactly the
  granularity gain the PRD chases.
- **Migration is non-destructive, not in-place.** Yoke v1 has no
  shipped users, so a destructive rename would be technically safe
  — but the framework author iterates on Yoke itself, and a
  recoverable migration (legacy file kept, new files written
  alongside) costs nothing and preserves the audit trail. Trade-off:
  disk-footprint duplication during the cutover. Acceptable.
- **`migrate-tech-specs.sh` orchestrates LLM calls via the
  Generator persona, not via a separate persona.** The Generator
  persona's drafting capability is what produced the legacy file
  — using the same persona for migration preserves stylistic
  continuity. Trade-off: requires the LLM tool to be available in
  the migration environment. Documented in the helper's `--help`
  output.
- **Pre-condition stricter than Part 2's `Status: approved` check.**
  `/yoke:acceptance-contract` requires `Status: approved` on **every
  task file**, not just the spec. Part 2's `approve` flow writes
  `Status: approved` to all of them as a unit — but a hand-edited
  task file (e.g., user removed `Status: approved` after a manual
  fix) would correctly fail this gate. Trade-off: friction on
  power-user workflows. Win: the binding artifact's input
  pre-conditions are unambiguous — no "partially approved" state.

## Applicable Patterns

- `.vibeflow/patterns/acceptance-contract.md` — binding artifact,
  Validator-produced (persona inline post-2026-04-25), BDD-per-task,
  fixtures + sensors per scenario. Splitting the upstream spec
  changes the input shape; the output's binding semantics are
  preserved.
- `.vibeflow/patterns/phase-flow.md` — Phase 3 (Acceptance
  Contract) input contract, Trigger 3 gate, chain into
  `/yoke:implement` (Phase 4) on `approve_and_continue`.
- `.vibeflow/patterns/sensors.md` — structured-output requirement
  preserved downstream of `verify-acceptance.sh`; sensor list per
  scenario unchanged.
- `.vibeflow/patterns/human-triggers.md` — Trigger 3 schema,
  binding-statement-before-menu rule, the shared
  `templates/approval-menu.md` rendering, modification-rate
  fatigue signals.
- `.vibeflow/patterns/memory-model.md` — Validator persona writes
  `acceptance-contract.md`; reads `spec.md` + every task file via
  the helpers from Part 1; never reads canonical memory directly
  (mediated via `/yoke:ask` if the Validator needs policies).

No new pattern introduced.

## Risks

- **Migration LLM mis-splits coarse legacy tasks.** Legacy
  monolithic tech-specs (e.g., `.vibeflow/specs/yoke-v1-sprint-3.md`-style
  bodies) have lump-DoD shapes; the LLM might emit too few or too
  many task IDs, propagating the granularity problem. **Mitigation:**
  the migration helper prints the proposed task list before
  invoking `scaffold-tasks.sh` and prompts the user to confirm
  (`yes` / `revise` / `abort`) — a one-time human gate that costs
  nothing because Yoke v1 has no shipped users and the helper runs
  in the framework author's environment.
- **Per-task `Status: approved` drift.** A user could approve the
  spec via `/yoke:tech-spec` but later hand-edit a task file and
  remove the status header, causing `/yoke:acceptance-contract` to
  abort. **Mitigation:** the abort message lists the offending file
  and instructs the user to either re-run `/yoke:tech-spec` with
  `revise` or restore the header by hand; no silent fallback.
- **Smoke-test runtime grows.** Adding `/yoke:acceptance-contract`
  to `tests/smoke/sprint-2.test.sh` adds an LLM round-trip per task.
  **Mitigation:** the smoke test fixture pins a small slug
  (1 sprint, ≤ 2 tasks) so total LLM round-trips stay bounded; the
  external `timeout 600` guard from Sprint-2 still applies.
- **Generator persona reused for migration LLM calls.** The
  Generator persona's prompt is tuned for the
  PRD → spec direction, not legacy-monolith → spec. **Mitigation:**
  the migration helper prepends a short framing paragraph
  ("you are converting a legacy monolithic Tech Spec into the new
  spec + per-task layout — preserve every described task as a
  distinct task file") before the persona prompt; this is one-shot
  context, not a permanent change to `skills/tech-spec/SKILL.md`.

## Dependencies

- `.vibeflow/specs/tech-spec-task-split-part-1.md` (must merge first;
  Part 3 calls `wm_spec_path`, `wm_list_task_paths`, and invokes
  `scaffold-tasks.sh` from the migration helper).
- `.vibeflow/specs/tech-spec-task-split-part-2.md` (must merge first;
  Part 3 assumes `/yoke:tech-spec` produces the new layout natively
  and that `Status: approved` propagates to task files via Part 2's
  approval flow).
