# Audit Report: tech-spec-task-split-part-3

> Audited via /vibeflow:audit on 2026-04-25
> Spec: `.vibeflow/specs/tech-spec-task-split-part-3.md`
> PRD: `.vibeflow/prds/tech-spec-task-split.md`
> Depends on: tech-spec-task-split-part-1 (PASS), tech-spec-task-split-part-2 (PASS)

**Verdict: PASS**

## Test Results

All 13 smoke tests under `tests/smoke/` PASS — no regressions.

| Test | Result |
| :--- | :--- |
| ask-no-clone.test.sh | PASS |
| folder-isolation.test.sh | PASS |
| memory-migration.test.sh | PASS |
| preserve-model-c.test.sh | PASS |
| sprint-2.test.sh | PASS (extended with Part-3 assertions + verify-acceptance.sh BDD-per-task parse check) |
| sprint-3.test.sh | PASS |
| sprint-4.test.sh | PASS |
| sprint-5.test.sh | PASS |
| sprint-6.test.sh | PASS |
| sprint-7.test.sh | PASS |
| sprint-8.test.sh | PASS |
| status-readonly.test.sh | PASS |
| teach-ingest.test.sh | PASS |

A transient false negative was caught during the smoke run
(`grep -qF "$marker" "$mig"` interpreting `--scaffold` as a flag).
Fixed in-flight by switching to `grep -qF -- "$marker"` plus
explicit exit-code capture for the precondition-guard test (the
`set -e` parent was aborting before the expected non-zero exit
could be evaluated). All 13 tests then PASS.

## DoD Checklist

### [x] DoD #1 — Skill reads spec + every task file, emits one BDD scenario per task

Evidence:
- `skills/acceptance-contract/SKILL.md:55-69` — pre-flight reads
  `wm_spec_path "$slug"` and iterates `wm_list_task_paths "$slug"`,
  aborting on missing/unapproved spec, zero task paths, or any
  task missing `status: approved`.
- `skills/acceptance-contract/SKILL.md:84-97` — step 3 reads the
  approved spec PLUS every path returned by `wm_list_task_paths`,
  pinning the per-task *Validation* section as the primary input
  to that scenario's Then clauses.
- `skills/acceptance-contract/SKILL.md:103-122` — step 4 produces
  exactly one BDD scenario per task file, each carrying the
  `Task: <task-id>` 1:1 anchor; "scenario count MUST equal the
  task-file count" pinned explicitly.
- Smoke check #13 verifies the SKILL.md migrated off
  `wm_tech_spec_path` and now references `wm_spec_path`,
  `wm_list_task_paths`, "one scenario per task file", and
  `Task: <task-id>`.

### [x] DoD #2 — Template carries BDD-per-task shape

Evidence:
- `templates/acceptance-contract.md:21-24` — "Exactly one scenario
  per task file" rule pinned; references the `Task: <task-id>`
  anchor and the *Validation*-feeds-Then derivation.
- `templates/acceptance-contract.md:26-39` — example scenario
  block shows the exact shape: `Task: <slug>-s01-t01` line +
  Given/When/Then + Fixture + Sensors.
- The binding-statement section is preserved verbatim
  (`templates/acceptance-contract.md:11-16`); `verify-acceptance.sh`
  parses the new shape without changes (the `Task:` line is opaque
  metadata) — confirmed by smoke check #15 emitting `results:`
  header and running the declared sensor.

### [x] DoD #3 — Acceptance Contract remains the binding artifact

Evidence:
- `skills/acceptance-contract/SKILL.md:107-114` — binding statement
  printed verbatim before Trigger 3 menu.
- `skills/acceptance-contract/SKILL.md:170-184` — `approve_and_continue`
  chains into `/yoke:implement` via the `Skill` tool; binding
  semantics fully preserved ("Approving this contract operationally
  defines 'done' as 'passes every criterion below'. Changes during
  runtime require a fresh ratification round.").
- The Validator persona stays inline (line 11 `allowed-tools` excludes
  `Task`; lines 28-46 `Your role (Validator persona, inline)` block).
- Smoke check #15 — synthetic Acceptance Contract with two BDD
  scenarios carrying `Task: <id>` lines parses through
  `hooks/verify-acceptance.sh` and runs the declared sensor; no
  hook code changes were needed.

### [x] DoD #4 — Fail-closed pre-conditions

Evidence:
- `skills/acceptance-contract/SKILL.md:55-58` — aborts on
  missing/unapproved PRD or spec, with `wm:`-prefixed messages and
  the recovery instruction (`Run /yoke:tech-spec first`).
- `skills/acceptance-contract/SKILL.md:60-63` — aborts non-zero if
  `wm_list_task_paths` returns zero paths (a slug with an approved
  spec but no task files = stages 2/3 of `/yoke:tech-spec` did not
  complete).
- `skills/acceptance-contract/SKILL.md:65-69` — partial-approval
  guard: aborts non-zero if **any** task file lacks
  `status: approved`, with the offending path named in the error.
  Matches the spec's technical decision: "the binding artifact's
  input pre-conditions are unambiguous — no 'partially approved'
  state."

### [x] DoD #5 — Migration helper

Evidence:
- `lib/working-memory/migrate-tech-specs.sh` exists, executable,
  bash 4+, `set -euo pipefail`, sources `paths.sh` for the path
  helpers, with the file header documenting the 3-stage pipeline
  (Stage 1 LLM → Stage 2 bash → Stage 3 LLM) and the
  non-destructive contract.
- Behavioral verification of every documented exit code (direct
  `$?` capture, no pipe interference):
  - `plan mode (existing new spec)` → exit 3 ✓
  - `bad path (not under .yoke/tech-specs/)` → exit 2 ✓
  - `no args` → exit 2 ✓
  - `--scaffold + existing spec (clean run)` → exit 0 ✓ (creates
    task files via `scaffold-tasks.sh`).
  - `--scaffold before Stage 1` → exit 4 (smoke check, on a
    legacy-only state).
  - `plan mode after migration` → refuses overwrite (prints
    `wm: refusing to plan migration — ... already exists`).
- Legacy file is preserved across all paths (smoke verified
  `[ -f ".yoke/tech-specs/<slug>.md" ]` after a successful
  `--scaffold` run).
- Re-running with the same slug fails fast (exit 3) — matches the
  spec: "Re-running with the same slug fails fast if
  `.yoke/specs/<slug>.md` already exists (no overwrite)."

### [x] DoD #6 — Craftsmanship

Evidence:
- `patterns/acceptance-contract.md` followed:
  - Binding artifact preserved (binding statement + Trigger 3 menu
    chain into `/yoke:implement`).
  - BDD-per-task contract pinned in the template + skill body.
  - Validator-produced (Validator persona inline; no Generator
    leakage).
- `patterns/sensors.md` followed: the `Task:` line is opaque to
  `verify-acceptance.sh` — sensor parsing + structured output
  preserved (smoke #15 emits `results:` and runs the linter
  sensor).
- `conventions.md` Don'ts respected: no canonical-memory direct
  reads (every cross-task lookup still goes through `/yoke:ask`);
  no Validator-subagent spawn; no auto-ratification; no
  `wm_tech_spec_path` references introduced in the migration
  helper or anywhere else (verified — migrate-tech-specs.sh sources
  paths.sh and uses `wm_spec_path` / `wm_list_task_paths` only).
- `patterns/human-triggers.md` shared-menu rule honored: Trigger 3
  still uses `templates/approval-menu.md`; binding-statement
  rendered before the menu, not inside it; `approve_and_continue`
  / `approve` / `reject` / `revise` verbs preserved verbatim.

### [x] DoD #7 — Sprint-2 smoke extended end-to-end

Evidence:
- `tests/smoke/sprint-2.test.sh` — Part 3 assertions added at
  blocks #13 (skill migration off `wm_tech_spec_path` + new
  references), #14 (migration helper presence + exit-code 4 guard),
  and #15 (verify-acceptance.sh parses BDD-per-task contract +
  runs declared sensor against new shape).
- All 13 smoke tests PASS — broader regression net than DoD #7
  required.
- The "exactly one BDD scenario per task file" claim from the
  spec is verified at the **artifact-shape** level (template +
  skill prose) rather than via runtime LLM execution (which the
  bash smoke harness cannot exercise) — the runtime contract is
  documented in `skills/acceptance-contract/SKILL.md:121-124`
  ("scenario count MUST equal the task-file count. Drafts where
  the two diverge are rejected").

## Pattern Compliance

### [x] `.vibeflow/patterns/acceptance-contract.md` — followed

The Acceptance Contract remains the binding artifact, produced by
the Validator persona (now inline post-2026-04-25 runtime-only
decision), with one BDD scenario per Tech-Spec task — refined to
**one scenario per task file** since the upstream spec now has a
1:1 mapping between tasks and task files. Every scenario must have
a `Fixture:` or `Sensors:` entry that decides pass/fail (rule
preserved). Regulatory policies still mediated through `/yoke:ask`,
never read directly from canonical memory.

### [x] `.vibeflow/patterns/phase-flow.md` — followed

Phase 3 input contract changes shape (spec + task files instead of
monolithic tech-spec) but Phase 3's gate semantics are unchanged:
Trigger 3 with binding statement still blocks Phase 4; chain into
`/yoke:implement` on `approve_and_continue` preserved.

### [x] `.vibeflow/patterns/sensors.md` — followed

`hooks/verify-acceptance.sh` is unchanged — the new `Task:` line in
each BDD scenario is opaque metadata to the parser. Structured
output (`results:` header + per-criterion `pass` / `fail` / `skip`)
preserved. Smoke check #15 verifies this end-to-end against a
synthetic two-scenario contract.

### [x] `.vibeflow/patterns/human-triggers.md` — followed

Trigger 3's 4-option shape preserved (`approve_and_continue` /
`approve` / `reject` / `revise`). The binding-statement-before-menu
rule is preserved (`skills/acceptance-contract/SKILL.md:107-114`).
Migration helper does not interact with any trigger — it's a
deterministic CLI bridge between Stage 1 (LLM) and Stage 3 (LLM).

### [x] `.vibeflow/patterns/memory-model.md` — followed

Validator persona writes `acceptance-contract.md` (working memory);
reads `.yoke/specs/<slug>.md` and every `.yoke/tasks/<slug>-s*-t*.md`
(working memory) via Part 1's helpers. Never reads canonical memory
directly (mediated via `/yoke:ask` for policies). Migration helper
does not write to canonical memory.

## Convention Violations

None detected.

## Anti-scope Respected

- No `hooks/verify-acceptance.sh` changes ✓ (the `Task:` line is
  opaque; hook parsing unchanged).
- No multi-language CLAUDE.md parsing — sensor discovery via
  `lib/sensors/discover-from-claude-md.sh` unchanged. ✓
- No retroactive rewrite of `.vibeflow/specs/yoke-v1-sprint-*.md`. ✓
- No deletion of legacy `.yoke/tech-specs/<slug>.md` files —
  migration is non-destructive (verified). ✓
- No automatic migration on `/yoke:bootstrap` — migration is
  explicit via `migrate-tech-specs.sh`. ✓
- No diff-preserving migration. ✓
- No backward-compat read path in `/yoke:acceptance-contract` —
  when spec/task files are absent, the skill aborts with the
  migration instruction (no silent fallback to
  `.yoke/tech-specs/<slug>.md`). ✓

## Gaps

None.

## Architectural Decisions Surfaced

No new decisions. The option-B softening introduced for Part 1's
DoD #6 was applied uniformly to Part 3 implicitly: the SKILL only
migrates off `wm_tech_spec_path`/`tech-specs/` references **for
its own scoped file**; the deprecated alias from Part 1 keeps the
remaining 9 consumer files (`lib/ralph-loop/orchestrate.sh`, three
`agents/*.md`, four other skills, two smoke tests) green until the
post-Part-3 cleanup pass tracked in the PRD.

## Final Cleanup Pass — Remaining Work for the Full PRD

After Parts 1, 2, and 3 land (all PASS), the PRD's "no
backward-compat shim" anti-scope remains conditional on a final
cleanup pass that:

1. Migrates `lib/ralph-loop/orchestrate.sh` to call `wm_spec_path`.
2. Migrates `agents/{generator,validator,orchestrator}.md` references
   from `.yoke/tech-specs/<slug>.md` to `.yoke/specs/<slug>.md`.
3. Migrates `skills/{implement,bootstrap,discover,status}/SKILL.md`
   references off `wm_tech_spec_path` / `tech-specs/`.
4. Migrates `tests/smoke/{folder-isolation,sprint-4}.test.sh`
   references off `wm_tech_spec_path` / `tech-specs/`.
5. Removes `wm_tech_spec_path` from
   `lib/working-memory/paths.sh` and removes `tech-specs` from
   `WM_ARCHIVE_CATEGORIES`.
6. Updates `.vibeflow/decisions.md` to mark the
   "wm_tech_spec_path retained as deprecated soft alias" entry as
   "supersedes" by the cleanup commit.
7. Updates `.vibeflow/patterns/memory-model.md` Implementation
   Mapping to reflect the new archive entries.

That's ~10 files; surface analysis suggests it splits into 2 specs
(runtime helpers + agents/skills/tests; then the final
`paths.sh` removal + pattern updates). The cleanup is **not** part
of this PRD's "Parts 1-3" — it's tracked as a separate follow-up
PRD or as the `tech-spec-task-split-cleanup` spec in
`.vibeflow/specs/`.

## Next Steps

- The three-part `tech-spec-task-split` PRD is **complete** with
  all parts at audit verdict PASS.
- (Optional) Generate the `tech-spec-task-split-cleanup` spec via
  `/vibeflow:gen-spec` to schedule the final removal of the
  deprecated alias and consumer migration.
- The PRD's user-facing wins (granular per-task files, BDD-per-task
  Acceptance Contract, 3-stage blueprint with progressive
  disclosure) are all live and exercised by the smoke harness.
