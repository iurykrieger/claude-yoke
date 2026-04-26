# Audit Report: tech-spec-task-split-part-2

> Audited via /vibeflow:audit on 2026-04-25
> Spec: `.vibeflow/specs/tech-spec-task-split-part-2.md`
> PRD: `.vibeflow/prds/tech-spec-task-split.md`
> Depends on: tech-spec-task-split-part-1 (audit verdict PASS)

**Verdict: PASS**

## Test Results

All 13 smoke tests PASS — no regressions introduced.

| Test | Result |
| :--- | :--- |
| ask-no-clone.test.sh | PASS |
| folder-isolation.test.sh | PASS (deprecated alias keeps `wm_tech_spec_path` callers green) |
| memory-migration.test.sh | PASS |
| preserve-model-c.test.sh | PASS |
| sprint-2.test.sh | PASS (extended with new artifact-shape assertions — see DoD #7) |
| sprint-3.test.sh | PASS |
| sprint-4.test.sh | PASS (deprecated alias keeps `tech-specs/` paths green) |
| sprint-5.test.sh | PASS |
| sprint-6.test.sh | PASS |
| sprint-7.test.sh | PASS |
| sprint-8.test.sh | PASS |
| status-readonly.test.sh | PASS |
| teach-ingest.test.sh | PASS |

A transient sprint-6/7/8 failure was caught during the smoke run
(`Trigger-2 schema missing 'back to PRD'` — vestigial from the legacy
schema documentation in the prior `skills/tech-spec/SKILL.md`). Fixed
in-flight by labeling `reject` as the **back to PRD** escape (one-line
documentation addition). All 13 tests then pass.

## DoD Checklist

### [x] DoD #1 — 3-stage flow documented in skill body

Evidence:
- `skills/tech-spec/SKILL.md:25-49` — "The 3-stage blueprint" section
  declares Stage 1 (LLM sprint-index draft), Stage 2 (deterministic
  bash via `scaffold-tasks.sh`), Stage 3 (LLM-per-task fill).
- `skills/tech-spec/SKILL.md:74-101` — step 4 walks through stage 1's
  Generator-persona drafting against `templates/spec.md`.
- `skills/tech-spec/SKILL.md:103-119` — step 5 invokes
  `lib/working-memory/scaffold-tasks.sh "$(wm_spec_path "$slug")"`.
- `skills/tech-spec/SKILL.md:121-146` — step 6 walks through stage 3's
  per-task fill against `templates/task.md`.

The skill body explicitly documents the deterministic-vs-agentic
boundary so a future reader can audit it without re-derivation —
matching `.vibeflow/conventions.md` "Blueprints wrapping agentic
nodes".

### [x] DoD #2 — Stage-3 prompt construction documented and bounded

Evidence:
- `skills/tech-spec/SKILL.md:128-135` — step 6 sub-step 3 explicitly
  enumerates what the per-task prompt carries (sprint preamble +
  empty task file's current contents + the request to fill four
  sections) and what it does NOT carry ("**no sibling task files**,
  **no full spec**, **no canonical memory**").
- Anti-patterns at `skills/tech-spec/SKILL.md:227` reinforce: "Do
  NOT batch stage 3 (filling all tasks in one LLM call) — that
  collapses progressive disclosure. One task per call."

This serves the `patterns/memory-model.md` rule "Content not in
runtime context does not exist for the agent" (progressive
disclosure) by construction.

### [x] DoD #3 — Trigger 2 menu shows per-task summary; approval is atomic

Evidence:
- `templates/approval-menu.md:32-37` — new `task_summary` input
  declared, used only by `/yoke:tech-spec`.
- `templates/approval-menu.md:55-60` — Rendering order step 2 renders
  the Tech-Spec-only block when `artifact_label == "Tech Spec"`.
- `templates/approval-menu.md:63-93` — "Tech-Spec-only block"
  section pins the block's exact rendering shape ("Tasks scheduled
  for approval (N)", one bullet per task with id + story + path).
- `skills/tech-spec/SKILL.md:165-178` — step 7 passes
  `artifact_label: Tech Spec` and constructs `task_summary` from
  `wm_list_task_paths "$slug"`.
- `skills/tech-spec/SKILL.md:209-219` — "Recording approval" section
  flips `Status: approved` on the spec **and** iterates
  `wm_list_task_paths "$slug"` to set `status: approved` on every
  task file's frontmatter; partial filesystem failures abort
  non-zero before the chain into `/yoke:acceptance-contract`.

The extension preserves `patterns/human-triggers.md` "shape is
shared, semantics are distinct" — the conditional fires on input
shape (`task_summary` populated) rather than on trigger semantics,
so Triggers 1 and 3 skip the block automatically.

### [x] DoD #4 — `revise` deletes + rewrites; `reject` preserved

Evidence:
- `skills/tech-spec/SKILL.md:191-204` — step 8 documents the
  `revise` flow: print loud `wm:`-prefixed warning naming spec +
  every task file path that will be deleted, delete each path, re-run
  stages 1-3 with feedback, re-render the menu. "Hand-edits to task
  files are NOT preserved across `revise`. The warning makes this
  explicit."
- `skills/tech-spec/SKILL.md:185-189` — `reject` documented as the
  **back to PRD** escape (preserves the secondary-confirmation flow
  required by `templates/approval-menu.md`).

### [x] DoD #5 — Stage-3 partial failure surfaces precisely; no rollback

Evidence:
- `skills/tech-spec/SKILL.md:148-160` — "Stage-3 partial failure
  recovery" section: the skill exits with a `wm:`-prefixed message
  naming the failed task file path, files filled before the failure
  remain on disk, recovery instruction tells the user to re-run with
  `revise`.
- "Do NOT roll back files filled before the failure. Do NOT proceed
  to Trigger 2." — explicit non-action contract.

Matches `.vibeflow/conventions.md` "back-pressure: success is silent,
failures are verbose" and "include a correction instruction in the
message when applicable".

### [x] DoD #6 — `templates/tech-spec.md` deleted; skill migrated off old refs

Evidence:
- `templates/tech-spec.md` — file no longer exists (verified by
  `ls templates/`; the directory listing shows `spec.md` and
  `task.md` instead).
- `tests/smoke/sprint-2.test.sh:74-76` — asserts
  `[ ! -f "templates/tech-spec.md" ]` — passes.
- `tests/smoke/sprint-2.test.sh:101-110` — asserts
  `skills/tech-spec/SKILL.md` does not contain `wm_tech_spec_path`
  or `templates/tech-spec.md` strings — passes (both checks green
  in the smoke run).

References that **remain** (intentionally, per the option-B
softening captured in the spec edit and `.vibeflow/decisions.md`):
- `lib/ralph-loop/orchestrate.sh`, three `agents/*.md`, five other
  skills (`acceptance-contract`, `implement`, `bootstrap`,
  `discover`, `status`), and the `folder-isolation` / `sprint-4`
  smoke tests — all kept green by Part 1's deprecated
  `wm_tech_spec_path` alias. Final cleanup is the post-Part-3
  pass tracked in the PRD.

### [x] DoD #7 — Craftsmanship + Sprint-2 smoke

Evidence:
- `skills/tech-spec/SKILL.md` honors `.vibeflow/conventions.md`:
  - "Blueprints wrapping agentic nodes" — three explicit stages.
  - "Progressive disclosure" — stage-3 prompt scope documented and
    enforced via Anti-patterns.
  - "back-pressure: success is silent, failures are verbose" —
    `wm:`-prefixed errors with task-file location and recovery
    instruction.
- 2026-04-25 runtime-only-agents decision honored: Generator
  persona stays inline (`skills/tech-spec/SKILL.md:18-23`), no
  subagent spawn (allowed-tools at line 11 excludes `Task`).
- `patterns/human-triggers.md` shared-menu rule honored: extension
  via conditional block, not fork.
- `patterns/memory-model.md` write-authority table honored:
  Generator persona writes the spec and per-task files; canonical
  memory not touched.
- `tests/smoke/sprint-2.test.sh` — extended with 17 new assertions
  covering: spec/task template structure (sections + frontmatter
  fields), 3-stage flow markers, migration off `wm_tech_spec_path`
  and `templates/tech-spec.md`, approval-menu's Tech-Spec-only
  block, task_summary input declaration. All assertions PASS in the
  full smoke run.

## Pattern Compliance

### [x] `.vibeflow/patterns/phase-flow.md` — followed

Phase 2's gate semantics preserved: Trigger 2 still blocks Phase 3,
the chain into `/yoke:acceptance-contract` on `approve_and_continue`
remains intact, the per-task fill happens **before** the gate (so
the user reviews the entire sprint set, not just the index). The
artifact shape changes (sprint index + per-task files); the phase
contract does not.

### [x] `.vibeflow/patterns/human-triggers.md` — followed

Trigger 2's 4-option shape preserved (`approve_and_continue` /
`approve` / `reject` / `revise`). The Tech-Spec-only block extends
the shared menu via a conditional input, honoring the rule that
shapes are shared while decision spaces and audit logs remain
distinct per trigger. Triggers 1 and 3 skip the block automatically
(they don't pass `task_summary`).

### [x] `.vibeflow/patterns/memory-model.md` — followed

Generator persona writes `.yoke/specs/<slug>.md` and
`.yoke/tasks/<slug>-s<NN>-t<MM>.md` — both versioned working-memory
artifacts addressed via Part 1's `wm_spec_path` /
`wm_list_task_paths`. No canonical-memory reads or writes. The
per-task frontmatter is *seeded as working memory*; promotion to
canonical memory remains the Orchestrator's exclusive territory
under Model C (out-of-scope for this part, as anti-scope declares).

### [x] `.vibeflow/conventions.md` — followed

- "Blueprints wrapping agentic nodes" — three explicit stages with
  the deterministic bash node bracketing the LLM stages. The skill
  body documents stages, inputs, outputs.
- "Progressive disclosure" — stage 3 enforces single-task scope.
- "back-pressure: success is silent, failures are verbose" —
  stage-3 partial failure carries identification (failed task path),
  location (which file), correction instruction (re-run with
  `revise`).
- "Sensor output for LLM consumption" — error messages structured
  with `wm:` prefix and precise location.
- "Don'ts" — no canonical-memory direct reads (mediated via
  `/yoke:ask`); no agent except Orchestrator writes canonical memory
  (no canonical writes here at all); no auto-approval; no vague
  acceptance criteria allowed (still enforced — see anti-patterns).

## Convention Violations

None detected.

## Anti-scope Respected

- No runtime subagent changes — `agents/generator.md`,
  `agents/validator.md`, `agents/orchestrator.md` untouched. ✓
- No canonical-memory writes — frontmatter seeded is working
  memory only. ✓
- No diff-preserving re-run — `revise` always deletes and rewrites
  (explicit in step 8 + Anti-patterns). ✓
- No per-task review at Trigger 2 — approval is spec-level, marks
  the entire set together. ✓
- No `/yoke:status` rework. ✓
- No multi-PRD aggregation. ✓
- No multi-line stage-3 batching — explicit in Anti-patterns. ✓

## Gaps

None.

## Architectural Decisions Surfaced

One operationalization captured in `.vibeflow/decisions.md` already
(option B from the Part 1 dialogue applied uniformly to Part 2 DoD
#6, anticipated in the Part 1 audit's next-steps note). No new
decisions.

## Next Steps

- Implement Part 3 (`tech-spec-task-split-part-3.md`) —
  `/yoke:acceptance-contract` consumer rewrite + migration helper.
  Expect to apply the same option-B softening to Part 3's DoD
  language as needed (consumer migrations beyond `acceptance-contract`
  remain in the post-Part-3 cleanup pass).
- Run `/vibeflow:implement .vibeflow/specs/tech-spec-task-split-part-3.md`
  to continue.
