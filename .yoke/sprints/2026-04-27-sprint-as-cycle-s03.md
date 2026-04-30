---
task_id: 2026-04-27-sprint-as-cycle-s03
sprint: 3
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-3
Migrated-from: [.yoke/tasks/2026-04-27-sprint-as-cycle-s03-t01.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s03-t02.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s03-t03.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s03-t04.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s03-t05.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s03-t06.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s03-t07.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s03-t08.md]
---

# Sprint 03: Consumer rewrites (skills + agents + lib + progress.md shape)

## Sprint objective

Every consumer of `wm_task_*` is rewritten to use `wm_sprint_*`. Every skill that interacts with per-task files now interacts with per-sprint files. Agent contracts read sprint files as the cycle's working set. The ralph-loop orchestrator walks sprints serially with per-sprint hard bounds. `progress.md` carries `current_sprint:` and `completed_sprints:` frontmatter. Throughout this sprint, the *running* `/yoke:implement` continues to use OLD-shape working memory for THIS spec — only the on-disk consumer files are rewritten; the running runtime is unaffected until the run ends. Old `wm_task_*` helpers remain in `paths.sh` until sprint 4 to keep the running runtime green.

## Sprint DoD

- `! grep -qE "scaffold-tasks\.sh|wm_list_task_paths|\.yoke/tasks/" skills/tech-spec/SKILL.md && grep -qE "scaffold-sprints\.sh|wm_list_sprint_paths|\.yoke/sprints/" skills/tech-spec/SKILL.md` exits 0.
- `! grep -qE "wm_list_task_paths|\.yoke/tasks/" skills/acceptance-contract/SKILL.md && grep -qE "wm_list_sprint_paths" skills/acceptance-contract/SKILL.md && grep -qE "### Task " skills/acceptance-contract/SKILL.md` exits 0.
- `! grep -qE "wm_list_task_paths|\.yoke/tasks/" skills/implement/SKILL.md lib/ralph-loop/orchestrate.sh && grep -qE "current_sprint:" skills/implement/SKILL.md && grep -qE "current_sprint" lib/ralph-loop/orchestrate.sh` exits 0.
- `! grep -qE "wm_list_task_paths|\.yoke/tasks/" skills/status/SKILL.md && grep -qE "current_sprint" skills/status/SKILL.md && grep -qE "completed_sprints" skills/status/SKILL.md` exits 0.
- `find skills/{bootstrap,discover,ack-sensors,preserve} -name 'SKILL.md' -exec grep -lE "wm_list_task_paths|\.yoke/tasks/" {} +` returns no files.
- `find agents -name "*.md" -exec grep -lE "wm_list_task_paths|\.yoke/tasks/" {} +` returns no files, AND `grep -l "current_sprint" agents/generator.md agents/validator.md agents/orchestrator.md | wc -l` returns `3`.
- `grep -E "^current_sprint:" .yoke/runtime/progress.md && grep -E "^completed_sprints:" .yoke/runtime/progress.md && [ "$(find .yoke/runtime -maxdepth 1 -name 'progress*.md' -type f | wc -l)" = "1" ]` exits 0 (when invoked after a fresh `/yoke:implement` cycle).
- `! grep -qE "^#### Task |\.yoke/tasks/" templates/spec.md && grep -qE "\.yoke/sprints/" templates/spec.md && grep -qE "^## Sprints$" templates/spec.md` exits 0.

## Tasks

### Task 2026-04-27-sprint-as-cycle-s03-t01

**Story:** `/yoke:tech-spec` is the producer of the working-memory shape for every future task. Rewriting it is the single largest consumer-side change: the 3-stage blueprint stays (Stage 1 spec index, Stage 2 deterministic scaffold, Stage 3 LLM-per-unit), but Stage 2 now scaffolds sprint files and Stage 3 fills sprint files. The skill keeps its `task_summary` block in the approval menu — but now each entry is one sprint with its tasks listed inline, not one task file. Approval applies status to sprint files via `wm_list_sprint_paths`. After this task, every NEW task created via `/yoke:tech-spec` lands directly in the sprint shape with no per-task files.

**Technical implementation:**

- Edit `skills/tech-spec/SKILL.md`.
- Replace every reference to `lib/working-memory/scaffold-tasks.sh` with `lib/working-memory/scaffold-sprints.sh`.
- Replace every reference to `wm_list_task_paths` with `wm_list_sprint_paths`.
- Replace every reference to `.yoke/tasks/<slug>-s<NN>-t<MM>.md` with `.yoke/sprints/<slug>-s<NN>.md`.
- Update Stage 1 instructions: the spec body uses `### Sprint <N> — <name>` headings (existing template shape) but body of the sprint section in the spec is now just the delivery objective and the task list as one-liners (no `#### Task <ID>` sub-headings inside the spec; those move to the sprint file's `## Tasks` section).
- Update Stage 2 instructions: invoke `scaffold-sprints.sh` against the spec; expect one empty sprint file per `### Sprint <N>` heading.
- Update Stage 3 instructions: for each sprint file in `wm_list_sprint_paths`, fill (a) `## Sprint objective`, (b) `## Sprint DoD`, (c) `## Tasks` — one `### Task <ID>` subsection per task with the four inline labels (`**Story:**`, `**Technical implementation:**`, `**Validation:**`, `**Acceptance criterion:**`), (d) `## Functional acceptance criteria` placeholder (criterion IDs are filled by Phase 3 / `/yoke:acceptance-contract`), (e) `## Sensors` (sensor IDs from the manifest, scoped to the sprint).
- Update the approval menu inputs: `task_summary` becomes `sprint_summary` (preserve the variable name in the menu template per `templates/approval-menu.md`'s contract — actually keep `task_summary` for backward shape compatibility, but each entry is now `(sprint_id, sprint name, file_path)`).
- Update the `revise` semantics: deletion now removes `wm_spec_path` + every path returned by `wm_list_sprint_paths` for the active slug.
- Update the approval-recording step: iterate `wm_list_sprint_paths` and set `status: approved` on each sprint file's frontmatter.
- DO NOT remove references to OLD helpers in this task — sprint 4 hard-removes them. The skill rewrite assumes the new helpers (sprint 1) exist; OLD helpers may still be present in `paths.sh` until sprint 4 t02 retires them.
- Cite `concepts/yoke-pattern-phase-flow` (Phase 2), `concepts/yoke-pattern-roles` (Generator persona), and the new `concepts/yoke-pattern-sprint-runtime-bundle` (drafted in sprint 4 t06).

**Validation:**

- Static smoke: grep `skills/tech-spec/SKILL.md` for `scaffold-tasks.sh` — zero matches; for `scaffold-sprints.sh` — at least one match.
- Static smoke: grep `skills/tech-spec/SKILL.md` for `wm_list_task_paths` — zero matches; for `wm_list_sprint_paths` — at least one match.
- Static smoke: grep `skills/tech-spec/SKILL.md` for `.yoke/tasks/` — zero matches in skill body.
- Functional smoke: invoke `/yoke:tech-spec` from a clean state on a tiny PRD with 2 sprints; assert that `.yoke/sprints/<slug>-s01.md` and `<slug>-s02.md` are created (no `.yoke/tasks/` files); each sprint file has the 5 required H2 sections; approval flips `status: approved` on both sprint files.
- Existing-skill regression: this task touches ONLY `skills/tech-spec/SKILL.md`. No other consumer is modified here; siblings are scope of t02–t08.

**Acceptance criterion:** `! grep -qE "scaffold-tasks\.sh|wm_list_task_paths|\.yoke/tasks/" skills/tech-spec/SKILL.md && grep -qE "scaffold-sprints\.sh|wm_list_sprint_paths|\.yoke/sprints/" skills/tech-spec/SKILL.md` exits 0.

### Task 2026-04-27-sprint-as-cycle-s03-t02

**Story:** The acceptance-contract skill drafts BDD scenarios per task. Today it iterates `.yoke/tasks/<slug>-s<NN>-t<MM>.md` files; under the new shape it iterates `### Task <ID>` anchors inside sprint files. The criterion IDs (AC-1, AC-2.3) are unchanged — they continue to live in `.yoke/acceptance-contracts/<slug>.md` as the binding source of truth, referenced by sprint files via the `## Functional acceptance criteria` section. This task rewires the iteration source without changing the AC artifact's shape.

**Technical implementation:**

- Edit `skills/acceptance-contract/SKILL.md`.
- Replace every reference to `wm_list_task_paths` with `wm_list_sprint_paths` + an inner pass that extracts `### Task <ID>` anchors from each sprint file body (use `grep -nE "^### Task " <sprint-file>` to enumerate anchors).
- Replace every reference to `.yoke/tasks/<slug>-s<NN>-t<MM>.md` with the anchor form: `.yoke/sprints/<slug>-s<NN>.md#task-<task-id>` (the GitHub-style heading anchor; downstream tooling resolves `#task-<id>` to the H3 location).
- Update the BDD scenario authoring instructions: each scenario maps to a `### Task <ID>` anchor inside a sprint file. The Validator iterates the sprint file's task anchors and resolves Acceptance criterion via the `**Acceptance criterion:**` inline label per task.
- Preserve every OTHER aspect of the skill: the binding statement, the criterion ID format (`AC-1`, `AC-2.3`), the rippability frontmatter contract, the sensor binding rules, the approval-menu integration. Only the working-memory iteration source changes.
- Update the `revise` semantics: deletion now removes `wm_acceptance_contract_path` (unchanged — AC artifacts stay one-file-per-task).
- Cite `concepts/yoke-pattern-phase-flow` (Phase 3), `concepts/yoke-pattern-acceptance-contract`, and the new `concepts/yoke-pattern-sprint-runtime-bundle` for the anchor-based reference.

**Validation:**

- Static smoke: grep `skills/acceptance-contract/SKILL.md` for `wm_list_task_paths` — zero matches; for `wm_list_sprint_paths` — at least one match.
- Static smoke: grep `skills/acceptance-contract/SKILL.md` for `.yoke/tasks/` — zero matches; for `.yoke/sprints/` and `### Task` — at least one match each.
- Functional smoke: invoke `/yoke:acceptance-contract` against a slug with 2 sprints (4 tasks total spread across them); assert it iterates 4 task anchors (not 4 task files), produces 4 BDD scenarios, references criterion IDs in the sprint files' `## Functional acceptance criteria` lists.
- Binding-shape preservation smoke: the AC artifact at `.yoke/acceptance-contracts/<slug>.md` shape is unchanged (single file, criterion IDs, BDD scenarios) — verify by diffing the doctrine-canonization AC's shape vs. a freshly-generated one for a small synthetic slug.

**Acceptance criterion:** `! grep -qE "wm_list_task_paths|\.yoke/tasks/" skills/acceptance-contract/SKILL.md && grep -qE "wm_list_sprint_paths" skills/acceptance-contract/SKILL.md && grep -qE "### Task " skills/acceptance-contract/SKILL.md` exits 0.

### Task 2026-04-27-sprint-as-cycle-s03-t03

**Story:** The single load-bearing runtime change in this PRD: ralph cycles are now scoped per-sprint, not per-task. `/yoke:implement` walks sprint 1 → sprint 2 → … in lexical order, with `current_sprint:` in `progress.md` tracking position. Each cycle reads exactly one sprint file as its working set; convergence appends to `completed_sprints:` and advances the pointer. Hard-bound (≤8 cycles) applies per-sprint. This is the central rewrite that operationalizes "one sprint = one ralph cycle (up to ≤8 cycle attempts)".

**Technical implementation:**

- Edit `skills/implement/SKILL.md`:
  - Replace every reference to per-task file iteration with per-sprint walking. The cycle's working set = the active sprint file at `.yoke/sprints/<slug>-s<current_sprint>.md`.
  - Add the walk algorithm:
    1. Read `current_sprint:` from `.yoke/runtime/progress.md` frontmatter (default to `01` on first invocation).
    2. Load `.yoke/sprints/<slug>-s<current_sprint>.md` — abort if absent.
    3. Spawn the per-cycle Generator + Validator + Orchestrator subagents (existing pattern) with the sprint file as their working set.
    4. On convergence: append `<current_sprint>` to `completed_sprints:` in `progress.md`; increment `current_sprint:` (zero-padded); reset `cycle_count:` to 0; write the sprint contract section to `.yoke/contracts/<slug>.md` as `## Sprint <NN> contract`.
    5. On hard-bound exhaustion (`cycle_count` ≥ 8): emit Trigger 4 escalation packet keyed on the active sprint; do NOT advance the pointer.
    6. Repeat until `current_sprint:` exceeds the highest sprint number in the spec.
- Edit `lib/ralph-loop/orchestrate.sh`:
  - Update the cycle invocation to pass the active sprint file path (not per-task files).
  - Update the cycle counter to reset at sprint boundaries (read `current_sprint:` and `completed_sprints:` from `progress.md` to detect transitions).
  - Update the Trigger 4 packet shape to include `active_sprint: <NN>` instead of `active_task: <id>`.
- Preserve everything else: agent contracts, judge verdict aggregation, snapshot writing, the consult/monitor/canonize Orchestrator modes.
- Cite `concepts/yoke-pattern-ralph-loop`, `concepts/yoke-pattern-roles`, the new `concepts/yoke-pattern-sprint-runtime-bundle`, and `concepts/yoke-pattern-human-triggers` (Trigger 4).

**Validation:**

- Static smoke: grep `skills/implement/SKILL.md` for `wm_list_task_paths` and `.yoke/tasks/` — zero matches; for `current_sprint:` and `wm_sprint_path` — at least one match each.
- Static smoke: grep `lib/ralph-loop/orchestrate.sh` for `current_sprint:` — at least one match; for per-task iteration constructs — zero.
- Walk smoke: against a synthetic slug with 3 sprint files and trivial DoD (a no-op echo statement per sprint), invoke `/yoke:implement <slug>`; assert `progress.md` ends with `current_sprint: 04` (one beyond last sprint), `completed_sprints: [01, 02, 03]`, and the orchestrator exits cleanly.
- Hard-bound smoke: synthetic slug where sprint 2's DoD is unsatisfiable; assert the run exits with Trigger 4 escalation after 8 cycles on sprint 2; `current_sprint:` stays at `02`; `completed_sprints: [01]`.
- Cycle-counter-reset smoke: between sprint 1 and sprint 2 boundaries, `cycle_count:` reset to 0 (verifiable in `progress.md` snapshots).

**Acceptance criterion:** `! grep -qE "wm_list_task_paths|\.yoke/tasks/" skills/implement/SKILL.md lib/ralph-loop/orchestrate.sh && grep -qE "current_sprint:" skills/implement/SKILL.md && grep -qE "current_sprint" lib/ralph-loop/orchestrate.sh` exits 0.

### Task 2026-04-27-sprint-as-cycle-s03-t04

**Story:** `/yoke:status` is the human/operator's window into the runtime. Today it surfaces task-level state. Under the new shape it surfaces sprint-level state: which sprint is active, which sprints have completed, how many cycles into the active sprint. Rewriting it makes `/yoke:status` legible to both humans (during arbitration triggers) and tooling (CI gates that grep status output).

**Technical implementation:**

- Edit `skills/status/SKILL.md`.
- Replace any per-task surface with a per-sprint surface:
  - "Active sprint": `current_sprint:` value from `progress.md` plus the sprint name (lifted from the spec's `### Sprint <N> — <name>` heading for the matching `<N>`).
  - "Cycle progress": `cycle_count:` from `progress.md` plus the per-sprint hard-bound (≤8 by default).
  - "Completed sprints": the `completed_sprints:` array, rendered as a checklist (✓ for completed, → for active, blank for pending).
  - "Working set": the path to the active sprint file (`.yoke/sprints/<slug>-s<current_sprint>.md`).
- Preserve the existing canonical-memory health surface (graphify-out integrity, orphan entities, dangling content, old content checks) per `concepts/yoke-pattern-memory-model`.
- Replace `wm_list_task_paths` with `wm_list_sprint_paths` for any phase-presence enumeration.
- The skill is read-only — no writes to working memory or canonical memory.
- Cite `concepts/yoke-pattern-phase-flow`, `concepts/yoke-pattern-ralph-loop`, and the new `concepts/yoke-pattern-sprint-runtime-bundle`.

**Validation:**

- Static smoke: grep `skills/status/SKILL.md` for `wm_list_task_paths` — zero matches; for `current_sprint` and `completed_sprints` — at least one match each.
- Functional smoke: against a slug with 3 sprints, 2 of which are completed, invoke `/yoke:status`; assert the output contains "Active sprint: 03 — <name>", "Cycle progress: <N>/8", "Completed sprints: ✓ 01, ✓ 02, → 03".
- Read-only smoke: the skill does NOT write to `.yoke/runtime/progress.md` or any other path.

**Acceptance criterion:** `! grep -qE "wm_list_task_paths|\.yoke/tasks/" skills/status/SKILL.md && grep -qE "current_sprint" skills/status/SKILL.md && grep -qE "completed_sprints" skills/status/SKILL.md` exits 0.

### Task 2026-04-27-sprint-as-cycle-s03-t05

**Story:** Beyond the four primary skill rewrites (tech-spec, acceptance-contract, implement, status), several other skills carry incidental references to the old shape. Bootstrap creates the working-memory skeleton — it must create `.yoke/sprints/` (not `.yoke/tasks/`). Discover, ack-sensors, and preserve may have references to per-task paths in error messages, examples, or "see also" sections. This task sweeps them all in one pass.

**Technical implementation:**

- Edit `skills/bootstrap/SKILL.md`:
  - Update the `.yoke/` skeleton creation instructions to create `.yoke/sprints/` instead of `.yoke/tasks/`. The directory is created lazily (only at first sprint write); the docs reflect the new structure.
  - Update the example `.yoke/` tree in the skill body to show `sprints/` instead of `tasks/`.
- Edit `skills/discover/SKILL.md`:
  - Update any reference to `.yoke/tasks/<slug>-s*-t*.md` in the "Other tasks' archives" advisory (the skill warns not to modify other tasks' archives — adapt the example to the new shape).
- Edit `skills/ack-sensors/SKILL.md`:
  - Update any reference to per-task file iteration in the readiness-mode logic (the skill validates that every sensor referenced by an Acceptance Contract has a `.yoke/sensors/<id>.md` file — its iteration source may need updating from per-task AC iteration to per-sprint).
- Edit `skills/preserve/SKILL.md`:
  - Update references in the canonization-packet example to point at sprint files instead of task files where applicable. The packet example showing what gets ratified into canonical memory should mirror the new shape.
- For each file, do NOT change behavior — only the path/identifier references. Rewrites should be `s/wm_list_task_paths/wm_list_sprint_paths/g` and `s|.yoke/tasks/|.yoke/sprints/|g`-style passes plus narrow contextual edits where the example logic refers to per-task structure.
- Cite `concepts/yoke-pattern-plugin-structure` (skill layout) and `concepts/yoke-pattern-memory-model` (working-memory structure).

**Validation:**

- Static smoke (each file): grep for `wm_list_task_paths` — zero matches; grep for `.yoke/tasks/` — zero matches in skill body (excluding any historical-narrative comments which should be removed too).
- Functional smoke for bootstrap: invoke `/yoke:bootstrap` from a clean state; assert `.yoke/sprints/` exists in the resulting directory tree; `.yoke/tasks/` does not.
- Cross-skill consistency smoke: `find skills/ -name 'SKILL.md' -exec grep -l 'wm_list_task_paths\|\.yoke/tasks/' {} +` returns zero files.
- Behavior-preservation smoke: each modified skill's primary functional smoke (from its own existing test suite) still passes — bootstrap creates working memory, discover starts a new task, ack-sensors lists sensors, preserve drafts a packet.

**Acceptance criterion:** `find skills/{bootstrap,discover,ack-sensors,preserve} -name 'SKILL.md' -exec grep -lE "wm_list_task_paths|\.yoke/tasks/" {} +` returns no files.

### Task 2026-04-27-sprint-as-cycle-s03-t06

**Story:** The runtime subagents (Generator, Validator, Orchestrator) consume working-memory files as their cycle's reading material. Today they iterate per-task files; under the new shape they read one sprint file per cycle. The agent contracts in `agents/*.md` declare what files each agent reads / writes / does not touch — those declarations must match the new shape. Sensor IDs (in the sprint file's `## Sensors` list) and AC criterion IDs (in `## Functional acceptance criteria`) resolve via ID lookups against `.yoke/sensors/<id>.md` and `acceptance-contracts/<slug>.md` respectively.

**Technical implementation:**

- Edit `agents/generator.md`:
  - Update the "reads" list: `.yoke/sprints/<slug>-s<current_sprint>.md` (the cycle's working set), `.yoke/runtime/progress.md`, `.yoke/contracts/<slug>.md`, `.yoke/acceptance-contracts/<slug>.md` (binding), `.yoke/sensors/<id>.md` (resolved by ID from the sprint file's `## Sensors` list).
  - Update the "writes" list: continues to write to `.yoke/sprints/<slug>-s<current_sprint>.md` (via Edit on `### Task <ID>` anchors), `.yoke/runtime/progress.md` (cycle-log entries), `.yoke/contracts/<slug>.md` on consensus.
  - Remove any reference to `.yoke/tasks/<slug>-s<NN>-t<MM>.md`.
- Edit `agents/validator.md`:
  - Update the "reads" list similarly. Add the sensor-resolution flow: each sensor ID in the sprint file's `## Sensors` list is loaded from `.yoke/sensors/<id>.md`; each AC criterion ID in `## Functional acceptance criteria` is loaded from `.yoke/acceptance-contracts/<slug>.md`.
  - Update verdict-emission: verdicts continue to land at `.yoke/runtime/.judge-verdicts/cycle-<N>/<sensor-id>.json` (sensor ID directly indexes file naming).
- Edit `agents/orchestrator.md`:
  - Update consult-mode reads: `.yoke/sprints/<slug>-s<current_sprint>.md` is the working set the consult queries derive context from.
  - Monitor-mode: divergence detection now per-sprint (not per-task).
  - Canonize-mode: the post-loop canonization packet at `.yoke/runtime/.preserve-packet.md` consumes sprint files for traceability links.
- Replace every `wm_list_task_paths` with `wm_list_sprint_paths` and every `.yoke/tasks/` with `.yoke/sprints/`.
- Cite `concepts/yoke-pattern-roles`, `concepts/yoke-pattern-ralph-loop`, `concepts/yoke-pattern-memory-model`, and the new `concepts/yoke-pattern-sprint-runtime-bundle`.

**Validation:**

- Static smoke: grep across `agents/{generator,validator,orchestrator}.md` for `wm_list_task_paths` and `.yoke/tasks/` — zero matches.
- Static smoke: grep across the same files for `.yoke/sprints/`, `current_sprint`, sensor-ID-resolution language — at least one match per file.
- Cross-agent consistency smoke: `find agents/ -name '*.md' -exec grep -lE "wm_list_task_paths|\.yoke/tasks/" {} +` returns zero files.
- Reads/writes consistency smoke: the writes list of the Generator does not include any path the Validator's reads list excludes, and vice versa (no role-boundary violations).

**Acceptance criterion:** `find agents -name "*.md" -exec grep -lE "wm_list_task_paths|\.yoke/tasks/" {} +` returns no files, AND `grep -l "current_sprint" agents/generator.md agents/validator.md agents/orchestrator.md | wc -l` returns `3`.

### Task 2026-04-27-sprint-as-cycle-s03-t07

**Story:** `progress.md` is the runtime's append-only log of cycles. Under the new shape it gains two frontmatter fields: `current_sprint:` (zero-padded 2-digit pointer to the active sprint) and `completed_sprints:` (array of completed sprint IDs). The cycle log resets at sprint boundaries — when a sprint converges, the log is archived (or a section break is inserted) and `cycle_count:` resets to 0. The file stays a single file (PRD anti-scope: no per-sprint progress files); the structure inside the file evolves.

**Technical implementation:**

- Locate the `progress.md` template / seed. Likely candidates: `templates/progress.md` or a heredoc inside `lib/working-memory/init-runtime.sh` or `skills/bootstrap/SKILL.md`.
- Define the new frontmatter shape:
  ```yaml
  ---
  slug: <slug>
  current_sprint: 01            # zero-padded 2-digit pointer
  completed_sprints: []          # array of zero-padded sprint IDs
  cycle_count: 0                 # cycles since the active sprint started
  total_sprints: <N>             # populated from spec at run start
  ---
  ```
- Body shape:
  - One H2 section per sprint: `## Sprint <NN>` containing the cycle log entries for that sprint.
  - Inside each sprint section, one H3 per cycle: `### Cycle <C>` containing the cycle's free-form notes.
  - A new sprint H2 is inserted whenever `current_sprint:` advances; the previous sprint's section is implicitly archived (no truncation, just demarcation).
- Update `skills/bootstrap/SKILL.md` if it bootstraps `progress.md` to seed the new frontmatter shape on first creation.
- Update `lib/ralph-loop/orchestrate.sh` (which already gets the cycle-counter changes in t03) to read/write the new fields.
- Add a one-shot migration step: if an existing `progress.md` lacks `current_sprint:` (e.g., from a previous run on the OLD shape), inject `current_sprint: 01`, `completed_sprints: []`, `cycle_count: <existing cycle count>`, `total_sprints: <count from spec>` on next read. The migration is idempotent.
- Cite `concepts/yoke-pattern-ralph-loop`, `concepts/yoke-pattern-memory-model`.

**Validation:**

- Static smoke: `progress.md` template (or seed) contains `current_sprint:`, `completed_sprints:`, `cycle_count:`, `total_sprints:` frontmatter fields.
- Functional smoke: invoke `/yoke:implement` from a clean state on a 3-sprint slug; after sprint 1 converges, assert `progress.md` has `current_sprint: 02`, `completed_sprints: [01]`, `cycle_count: 0`, and a `## Sprint 01` section with the cycle entries from sprint 1.
- File-singleton smoke: at no point does the runtime create `progress-s01.md` or any other per-sprint progress file. `find .yoke/runtime -name 'progress*.md'` returns exactly one match (`progress.md`).
- Migration smoke: starting from a `progress.md` lacking the new fields, on next read the file is updated in place with the new fields seeded; the existing body is preserved.

**Acceptance criterion:** `grep -E "^current_sprint:" .yoke/runtime/progress.md && grep -E "^completed_sprints:" .yoke/runtime/progress.md && [ "$(find .yoke/runtime -maxdepth 1 -name 'progress*.md' -type f | wc -l)" = "1" ]` exits 0 (when invoked after a fresh `/yoke:implement` cycle).

### Task 2026-04-27-sprint-as-cycle-s03-t08

**Story:** `templates/spec.md` defines what `/yoke:tech-spec` Stage 1 produces. Today the template includes inline `#### Task <ID>` entries inside each sprint section. Under the new shape, the spec is the *cross-sprint architecture* — overall objective, contracts and interfaces, dependencies, out-of-scope. Each `### Sprint <NN> — <name>` heading just declares the sprint's existence and its delivery objective; the task list moves to the sprint file. Updating the template is what makes Stage 1's output match the post-migration shape.

**Technical implementation:**

- Edit `templates/spec.md`.
- Replace the existing sprint block:
  ```
  ### Sprint 1 — <name>
  **Delivery objective:** <…>
  
  #### Task <slug>-s01-t01 — <one-line story>
  #### Task <slug>-s01-t02 — <one-line story>
  ```
  with:
  ```
  ### Sprint 1 — <name>
  **Delivery objective:** <…>
  **Tasks:** <see `.yoke/sprints/<slug>-s01.md` `## Tasks` section>
  ```
- Update the explanatory paragraph above the sprint list:
  - Remove: "Each task is rendered as a one-line story anchored on a stable task ID. The full technical implementation and validation for each task lives in `.yoke/tasks/<task-id>.md`"
  - Replace with: "Each sprint declares its delivery objective. The full sprint runtime bundle — sprint objective, sprint DoD, per-task body (Story / Technical implementation / Validation / Acceptance criterion), functional acceptance criteria (referenced by ID), and sensors (referenced by ID) — lives in `.yoke/sprints/<slug>-s<NN>.md`."
- Update the "Task ID shape" paragraph:
  - Replace with a "Sprint ID shape" paragraph: `<slug>-s<NN>` where `<slug>` matches the existing slug regex, `<NN>` is the sprint number zero-padded to 2 digits. Padding is what makes lexical sort = positional order in `wm_list_sprint_paths`. Tasks within a sprint use `t<MM>` zero-padded by convention but are anchors inside the sprint file (not separate files).
- Preserve every other section: Overall objective, Contracts and interfaces, Dependencies, Out of scope, the trailing "When ready, run /yoke:acceptance-contract" line.
- Cite `concepts/yoke-pattern-phase-flow` (Phase 2), and the new `concepts/yoke-pattern-sprint-runtime-bundle` for the cross-sprint vs. per-sprint split.

**Validation:**

- Static smoke: grep `templates/spec.md` for `#### Task` and `\.yoke/tasks/` — zero matches.
- Static smoke: grep `templates/spec.md` for `\.yoke/sprints/<slug>-s<NN>.md` and `## Tasks` (in the explanatory text) — at least one match each.
- Section-preservation smoke: `templates/spec.md` retains the H2 headings `## Overall objective`, `## Sprints`, `## Contracts and interfaces`, `## Dependencies`, `## Out of scope`.
- Functional smoke: invoke `/yoke:tech-spec` Stage 1 against a tiny PRD; the produced spec body matches the new template (no `#### Task` entries inside sprint sections; "Tasks: see .yoke/sprints/..." reference present).
- Backward-narrative smoke: any historical comment in the template referring to per-task files (e.g., the lineage paragraph) is updated to mention "post-sprint-as-cycle" naming where it referred to "post-tech-spec-task-split".

**Acceptance criterion:** `! grep -qE "^#### Task |\.yoke/tasks/" templates/spec.md && grep -qE "\.yoke/sprints/" templates/spec.md && grep -qE "^## Sprints$" templates/spec.md` exits 0.

## Functional acceptance criteria

- See `.yoke/acceptance-contracts/2026-04-27-sprint-as-cycle.md` for the binding criterion IDs and BDD scenarios mapped to each task above.

## Sensors

- tech-spec-skill-no-task-refs
- tech-spec-skill-has-sprint-refs
- ac-skill-no-task-refs
- ac-skill-has-anchor-refs
- implement-skill-no-task-refs
- ralph-orchestrate-has-current-sprint
- status-skill-no-task-refs
- status-skill-has-sprint-fields
- incidental-skills-no-task-refs
- bootstrap-creates-sprints-dir
- agents-no-task-refs
- agents-have-current-sprint
- progress-md-frontmatter-shape
- progress-md-singleton
- templates-spec-md-no-task-refs
- templates-spec-md-preserves-sections
