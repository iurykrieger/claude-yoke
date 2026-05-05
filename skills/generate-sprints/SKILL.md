---
name: generate-sprints
description: >
  Phase 2.5 — Sprint synthesis. Takes the approved Tech Spec and the
  ratified Acceptance Criteria for the active slug, synthesizes a task
  list whose entries realize the Acceptance Criteria's User Stories
  (US-NNN), partitions the tasks into sprints with explicit delivery
  objectives and binary DoD, and writes the runtime sprint bundles at
  `.yoke/sprints/<slug>-s<NN>.md` via `templates/sprint.md`. The skill
  is the single Phase 2.5 producer of sprint runtime bundles; the
  legacy `/yoke:tech-spec` stage 3 producer is retired in Sprint 4 of
  the parent PRD. After the bundle render stage, the skill renders the
  shared approval menu (`templates/approval-menu.md`) — Trigger 2.5 —
  and on `approve` / `approve_and_continue` flips every produced
  sprint file's frontmatter `status: draft` → `status: approved`
  atomically.
argument-hint: ""
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Skill
---

# /yoke:generate-sprints — Phase 2.5 (Sprint synthesis)

Synthesize sprint runtime bundles from the approved
`(spec, acceptance-criteria)` pair for the active task. The skill is
the Phase 2.5 producer; it sits between Phase 3 (Acceptance Criteria
ratification) and Phase 4 (`/yoke:implement`'s council protocol).

> **Status (Sprint 03 of parent PRD).** Stages 1–6 are now bodied.
> The skill walks pre-flight, reads the inputs, runs the LLM-driven
> synthesis bracketed by deterministic shell+python validators,
> partitions the resulting task list into sprints (deterministic),
> renders one runtime bundle per partition entry via
> `templates/sprint.md`, and renders the Trigger 2.5 approval menu.
> Sprint 04 of the parent PRD adds the legacy-task rejection branch,
> the cutover of `/yoke:tech-spec` (stage 2 + 3 strip), and the wiring
> with `/yoke:status` and `/yoke:implement`.

## Lineage

`skills/generate-sprints/` is **native to Yoke** — there is no upstream
lineage. The skill was introduced in the parent PRD
`.yoke/prds/2026-05-03-generate-sprints-skill.md` (approved
2026-05-03) to decouple sprint generation from the architectural lens
of `/yoke:tech-spec` and from the use-case-catalog lens of
`/yoke:acceptance-criteria`. The decision to introduce a dedicated
producer is recorded inline in the parent PRD's "Goals" and "Product
invariants" sections; the doctrine entry
`concepts/yoke-pattern-sprint-synthesis` is staged in the parent
spec's Sprint 04 canonize-handoff packet.

## Your role (Senior Engineer persona, inline)

You are running this skill as the **Senior Engineer persona**: a
technical lead who synthesizes shippable sprint plans from a binding
Acceptance-Criteria envelope and an architecture spec. You do not
relax the Acceptance-Criteria envelope (Trigger 3 already bound it);
you partition it into sprints whose tasks each realize one or more
US-NNN entries, respect one or more architecture decisions from the
spec, and ship a coherent value increment per sprint.

You force every produced task to be self-contained enough that any of
the council personas (Sr Eng, Sr QA, Sr Staff) can execute its lens
with no follow-up reads beyond the cited US-NNN and the cited sensors.
You refuse per-persona forks inside a task body (decision 5A of the
parent PRD); you refuse inlined criterion bodies inside the produced
sprint files (reference-by-ID per
`concepts/yoke-pattern-sprint-runtime-bundle` Rule 1); you refuse
non-deterministic output (FR-3 of the binding AC).

## Process

The skill is a **blueprint wrapping agentic nodes**: the synthesis
stage is LLM-driven, every other stage is deterministic Bash.

### 1. Pre-flight

Run five sequential gate checks. Each check that fails exits the
skill non-zero with a `wm:`-prefixed stderr line naming the offending
path and the next-step the user should take. The diagnostics are
exact strings — they're asserted character-for-character in
`tests/smoke/generate-sprints-preflight.test.sh`.

Steps, in order:

1. **Provider hard break.** Source `<plugin_dir>/lib/yoke-prelude.sh`
   and call `yoke_require_provider`. The helper aborts non-zero with
   stderr `wm: <abs_path> not found. Run /yoke:bootstrap to initialize
   this project.` (rc=2) when `.yoke/config.yaml` is missing, or
   `wm: canonical_memory.provider not configured. Run /yoke:bootstrap
   to migrate.` (rc=1) when the provider key is missing/empty. Surface
   the helper's stderr verbatim and exit. (Realises AC-003-1 branch
   `no-config` and `no-provider`; FR-6 of the parent PRD.)

   ```bash
   source <plugin_dir>/lib/yoke-prelude.sh
   yoke_require_provider || exit 1
   ```

2. **Active slug.** Source `<plugin_dir>/lib/working-memory/paths.sh`
   and resolve the slug via `wm_active_slug`. The helper aborts
   non-zero with stderr `wm: no active task; run \`/yoke:discover\`
   first` when `.yoke/runtime/.current` is missing. (Realises
   AC-003-1 branch `no-slug`.)

   ```bash
   source <plugin_dir>/lib/working-memory/paths.sh
   slug="$(wm_active_slug)" || exit 1
   ```

3. **Approved Phase-1 artifact.** Source `<plugin_dir>/lib/working-memory/check-approved.sh`
   and call `wm_check_phase1_approved "$(wm_phase1_artifact_path "$slug")"`.
   The resolver returns whichever Phase-1 artifact backs the slug
   (`.yoke/prds/<slug>.md` for `/yoke:discover`-authored PRDs,
   `.yoke/fixes/<slug>.md` for `/yoke:fix`-authored fix-specs); it
   hard-aborts non-zero with the structured FR-9 recovery diagnostic
   when both archives exist for the same slug (PRD FR-9 / AC-004-1)
   and when neither exists ("Run `/yoke:discover` or `/yoke:fix`
   first."). The approval helper aborts non-zero with stderr
   `wm: Phase-1 artifact missing or unapproved at <path>. Run /yoke:discover or /yoke:fix first.`
   when the resolved file's `> Status:` line is neither `approved`
   nor `ratified`. The artifact is read as opaque Phase-1 input —
   `/yoke:generate-sprints` does not branch its core logic on
   PRD-vs-fix-spec identity.

4. **Approved Spec.** Call `wm_check_spec_approved "$(wm_spec_path
   "$slug")"`. The helper aborts non-zero with stderr `wm: spec
   missing or unapproved at <path>. Run /yoke:tech-spec first.` when
   the file is missing or its `> Status:` line is not `approved`.
   (Realises AC-003-1 branch `unapproved-spec`; FR-7 of the parent PRD.)

5. **Ratified Acceptance Criteria.** Call `wm_check_ac_ratified
   "$(wm_acceptance_criteria_path "$slug")"`. The helper aborts
   non-zero with stderr `wm: acceptance-criteria missing or
   un-ratified at <path>. Run /yoke:acceptance-criteria first.` when
   the file is missing or its `> Status:` line is not `ratified`.
   (Realises AC-003-1 branch `un-ratified-AC`; FR-7 of the parent PRD.)
   The Acceptance-Criteria status is `ratified` (Trigger 3 ratifies);
   `approved` is the spec / PRD status — do not conflate the two.

After gate (3) (Approved PRD) but BEFORE gate (4) (Approved Spec) and
gate (5) (Ratified Acceptance Criteria), run the **legacy-task
rejection branch**. Per Decision 6A of the parent PRD
(`.yoke/prds/2026-05-03-generate-sprints-skill.md`), legacy tasks
emitted by the legacy `/yoke:tech-spec` stage 3 MUST NOT be migrated
automatically — `/yoke:generate-sprints` rejects them and leaves
their sprint files untouched. The detection rule is two-pronged:

1. If `.yoke/acceptance-contracts/<slug>.md` exists, the task is
   legacy (the legacy ratified envelope lives under that path; the
   post-rename canonical envelope lives under
   `.yoke/acceptance-criteria/<slug>.md`).
2. Or, if `.yoke/sprints/<slug>-s*.md` files already exist with
   frontmatter `traceability` lacking the new-flow marker (the
   semicolon-separated AC path containing the substring
   `acceptance-criteria/<slug>.md`), the task is legacy (sprint
   files emitted by the legacy stage 3 cite only the spec).

On legacy detection, abort non-zero with the literal stderr below
and exit cleanly. **Do NOT touch any file under `.yoke/sprints/`.**
The legacy-coexistence guarantee in FR-15 binds: legacy tasks keep
walking under `/yoke:implement` unmodified.

```
wm: legacy task — generate-sprints does not migrate
```

The detection rule is encapsulated in
`lib/generate-sprints/legacy-detect.sh :: legacy_detect`, which the
SKILL body invokes inline:

```bash
# legacy-task rejection (Decision 6A; PRD §"User Stories :: US-007").
# concepts/yoke-pattern-memory-model — legacy archive coexistence is
# permanent; in-flight legacy tasks are never auto-migrated.
source <plugin_dir>/lib/generate-sprints/legacy-detect.sh
legacy_detect "$slug" || exit 1
```

The helper exits non-zero with the literal stderr line above on
either prong of the detection rule and never touches any file under
`.yoke/sprints/`. Callers should run with `set -euo pipefail` so the
short-circuit propagates.

After the legacy-task rejection passes, source
`<plugin_dir>/lib/generate-sprints/plan-io.sh` and call
`init_plan_file "$slug"`. This writes the empty plan stub at
`.yoke/runtime/.generate-sprints-plan.yaml` with top-level keys
`slug`, `generated_at`, `tasks: []`, `sprint_partition: []`. Then
call `ensure_plan_tmp_dir` to scaffold the parser-output scratch
directory at `.yoke/runtime/.generate-sprints-tmp/`.

### 2. Read inputs

Source `<plugin_dir>/lib/generate-sprints/parse-inputs.sh` and run
both helpers, redirecting their stdout into the scratch directory:

```bash
source <plugin_dir>/lib/generate-sprints/parse-inputs.sh

ac_path="$(wm_acceptance_criteria_path "$slug")"
spec_path="$(wm_spec_path "$slug")"

parse_acceptance_criteria "$ac_path" \
    > .yoke/runtime/.generate-sprints-tmp/ac.json

parse_spec_architecture "$spec_path" \
    > .yoke/runtime/.generate-sprints-tmp/spec.json
```

The AC parser emits a JSON object whose top-level keys are
`user_stories` (array of US-NNN entries with `id`, `title`, `story`,
`dod`, `acceptance_criteria`), `functional_requirements` (array of
FR-N entries with `id`, `text`), and `sensor_pool` (flat list of
sensor IDs from `## Sensor pool`). The spec parser emits an object
with `objective`, `contracts`, and `dependencies`. Both helpers exit
non-zero with `wm:`-prefixed stderr on parse failure (missing input,
legacy UC-N shape, malformed US block missing DoD or Acceptance
Criteria).

### 3. Synthesis

The skill's primary agentic node — bracketed by deterministic bash on
both sides. Inputs to the synthesis prompt:

1. The JSON emitted by `parse_acceptance_criteria` (Sprint 02
   helper), at `.yoke/runtime/.generate-sprints-tmp/ac.json`.
2. The JSON emitted by `parse_spec_architecture`, at
   `.yoke/runtime/.generate-sprints-tmp/spec.json`.
3. **Optional** canonical-memory hits — when a User Story names an
   existing pattern / decision / convention, invoke
   `/yoke:search-canonical-memory` via the `Skill` tool with a
   narrowly-scoped query (≤ 15 entity reads, one wikilink hop per
   the progressive-disclosure invariant). Log each invocation once to
   `.yoke/runtime/progress.md` as a `search:` event (per
   FR-12 of the parent PRD; AC-004-4 of the binding AC).

**Pre-flight the inputs.** Before invoking the LLM step, run the
deterministic validator that asserts both intermediates carry the
expected top-level shape:

```bash
source <plugin_dir>/lib/generate-sprints/synthesize.sh
synthesize_validate_inputs \
    .yoke/runtime/.generate-sprints-tmp/ac.json \
    .yoke/runtime/.generate-sprints-tmp/spec.json \
    || exit 1
```

The helper exits non-zero with `wm:`-prefixed stderr on shape
violations (AC has no `user_stories`, US block missing `dod`, spec
missing `objective`, etc.).

**Run the LLM synthesis.** Compose a prompt that carries the two JSON
intermediates verbatim plus the following hard requirements:

- Output is a **JSON array** of tasks (no prose wrapper, no Markdown
  fences).
- Every task object has the keys
  `{task_id, realizes_user_stories, applies_decisions, instructions,
  sensors, acceptance_criterion}` (+ optional `story`, `validation`,
  `technical_implementation` projection hints consumed by the render
  stage).
- `task_id` is a placeholder of the form `T-<n>` (zero-padded
  per-arrival ordinal); the partition stage assigns final
  `<slug>-s<NN>-t<MM>` ids.
- `realizes_user_stories` is a non-empty array whose entries match
  `^US-[0-9]{3}$`.
- `instructions` is a **single unified block** readable by Sr Eng /
  Sr QA / Sr Staff — no per-persona forks like `**For Sr Eng:**`
  (forbidden by FR-1 of the binding AC; the validator below greps
  for the pattern and aborts).
- Every US in the input AC's `user_stories` array MUST appear in
  ≥ 1 task's `realizes_user_stories` (US-coverage invariant).

Persist the LLM's output to
`.yoke/runtime/.generate-sprints-tmp/tasks.json` (the file is
gitignored under the same `.yoke/runtime/.generate-sprints-tmp/`
scratch dir).

**Post-flight the LLM output.** Validate the tasks JSON, enforce the
US-coverage invariant, then merge into the plan via
`synthesize_write_tasks`:

```bash
synthesize_write_tasks \
    .yoke/runtime/.generate-sprints-plan.yaml \
    .yoke/runtime/.generate-sprints-tmp/tasks.json \
    .yoke/runtime/.generate-sprints-tmp/ac.json \
    || exit 1
```

The helper:

- Validates each task's schema (placeholder `task_id` matches
  `^T-[0-9]+$`; non-empty `realizes_user_stories`; non-empty
  `instructions` and `acceptance_criterion`).
- Rejects per-persona forks in `instructions` (FR-1 enforcement).
- Enforces US-coverage by computing `(AC user stories) -
  (realised user stories)`; if non-empty, exits non-zero with stderr
  `wm: unrealized USs: US-NNN[, US-MMM]`.
- Sorts the merged tasks by placeholder ordinal so the plan's
  `tasks` array is stable regardless of LLM emission order.
- Rewrites `.yoke/runtime/.generate-sprints-plan.yaml` with the
  merged tasks via PyYAML's `safe_dump` (deterministic
  serialisation; matches `partition.sh`'s policy).

### 4. Partition

Pure deterministic — zero LLM. Implementation lives in
`lib/generate-sprints/partition.sh :: partition_tasks`.

```bash
source <plugin_dir>/lib/generate-sprints/partition.sh
partition_tasks .yoke/runtime/.generate-sprints-plan.yaml || exit 1
```

The helper:

1. Reads `.yoke/runtime/.generate-sprints-plan.yaml :: tasks`.
2. Builds the overlap graph — two tasks share an edge when they
   share ≥ 2 entries from their `applies_decisions` lists. Connected
   components become candidate sprints.
3. Caps each component at 8 tasks (AC-005-5 upper bound). When a
   component exceeds the cap, splits into chunks of 8 ordered by
   `acceptance_criterion` lexical clustering with placeholder-ordinal
   tie-break.
4. Orders sprints across the partition by their first task's
   placeholder ordinal so re-runs converge.
5. For each resulting sprint, computes
   `delivery_objective` (concatenated realised US ids + dominant
   spec anchor) and `dod` (one entry per task, formatted as
   `<final-task-id>: <acceptance_criterion>`).
6. Assigns final task ids `<slug>-s<NN>-t<MM>` in walk order.
7. Rewrites every task's placeholder `task_id` to the final id and
   re-orders the plan's `tasks` array to match the partition walk
   order; populates `sprint_partition`.
8. Re-serialises the plan via PyYAML (deterministic output across
   runs — FR-3 / AC-005-2).

### 5. Render

Pure deterministic — zero LLM. Implementation lives in
`lib/generate-sprints/render-bundle.sh :: render_sprint_bundle`. The
helper performs the four placeholder substitutions on
`templates/sprint.md` (`<slug>`, `<NN>`, `<N>`, `<iso8601>`), rewrites
the frontmatter (`status: draft`, `traceability:
".yoke/specs/<slug>.md; .yoke/acceptance-criteria/<slug>.md"`,
`Migrated-from: []`), and fills the five body sections from the
partition data:

- **Sprint objective** — from `delivery_objective`.
- **Sprint DoD** — from `dod` (one bullet per task).
- **Tasks** — one `### Task <ID>` per task, four inline labels
  (`**Story:**`, `**Technical implementation:**`, `**Validation:**`,
  `**Acceptance criterion:**`), with `(Realizes: US-NNN[, US-MMM])`
  clause adjacent to the `**Story:**` line. The Story / Technical
  implementation / Validation projection consumes optional `story`,
  `technical_implementation`, `validation` keys when the synthesis
  stage emitted them; otherwise it splits the unified `instructions`
  block on paragraph boundaries (first paragraph → Story, last →
  Validation, remainder → Technical implementation).
- **Functional acceptance criteria** — union of US-IDs realised by
  tasks in the sprint, deduplicated and sorted.
- **Sensors** — union of sensor IDs from the realised US tasks,
  deduplicated and sorted.

Iterate over every `sprint_partition` entry via the convenience
wrapper:

```bash
source <plugin_dir>/lib/working-memory/paths.sh
source <plugin_dir>/lib/generate-sprints/render-bundle.sh
render_all_bundles "$slug" .yoke/runtime/.generate-sprints-plan.yaml \
    || exit 1
```

The wrapper resolves each sprint number from the partition's
`sprint_id` field and calls `render_sprint_bundle` once per sprint.
Each rendered file is validated post-write: 5 H2 headings present
and ordered, otherwise the file is removed and the helper aborts
with `wm: render shape violation at <path>: missing heading <name>`
(or `heading order broken at <name>` for an out-of-order anchor).
This realises AC-005-1.

### 6. Trigger 2.5 — Sprint plan ratification

After all sprint files are rendered, render the shared approval menu
(`templates/approval-menu.md`) with the following inputs:

- `artifact_path`: `.yoke/runtime/.generate-sprints-plan.yaml` (the
  plan is the artifact under review; the sprint files are derivatives
  the user inspects via the per-sprint summary block below).
- `artifact_label`: `"Sprint plan"`.
- `next_skill`: `/yoke:implement`.
- `language`: `<detected>` (whatever the discovery / tech-spec
  dialogues resolved).
- `binding_statement`: empty string (Trigger 2.5 ratifies the
  *partition*, not the *criteria*; the binding envelope is owned by
  Trigger 3 which already ratified the AC).

Per-sprint summary (custom block rendered before the 4-option
prompt) — list each produced sprint id with its delivery objective,
in walk order:

```
### Produced sprint plan (N)

- <slug>-s01 — <delivery_objective>  (.yoke/sprints/<slug>-s01.md)
- <slug>-s02 — <delivery_objective>  (.yoke/sprints/<slug>-s02.md)
…
```

The list is built from `wm_list_sprint_paths "$slug"` (= positional
order via the `s<NN>` filename suffix) joined with the corresponding
`sprint_partition[i].delivery_objective` field of the plan.

The 4 verbs route as follows:

- **`approve_and_continue`** — flip every produced sprint file's
  frontmatter `status: draft` → `status: approved` atomically (one
  pass over `wm_list_sprint_paths "$slug"` rewriting in place via a
  python3 helper). Then chain into `/yoke:implement` via the `Skill`
  tool. When the `Skill` tool is unavailable, fall back to the
  approval-menu template's documented Fallback rule (record approval
  and print the manual-advance instruction).
- **`approve`** — same status flip; do not chain.
- **`reject`** — after the secondary `yes` confirmation, delete
  every path returned by `wm_list_sprint_paths "$slug"` (plain `rm`
  per path) and exit cleanly. The plan file at
  `.yoke/runtime/.generate-sprints-plan.yaml` is preserved (audit
  trail).
- **`revise`** — print a `wm:`-prefixed warning naming every sprint
  file that will be deleted plus the captured feedback; delete every
  sprint file via `wm_list_sprint_paths`; truncate the plan's `tasks`
  and `sprint_partition` arrays back to empty (preserving `slug` +
  `generated_at` so the audit trail is continuous); re-run the
  Synthesis → Partition → Render cascade with the captured feedback
  prepended to the synthesis prompt as additional context; re-render
  the Trigger 2.5 menu.

The atomic status flip for `approve` / `approve_and_continue` is
implemented via:

```bash
for sprint_path in $(wm_list_sprint_paths "$slug"); do
    python3 - "$sprint_path" <<'PY'
import sys, re
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    body = f.read()
new_body, count = re.subn(
    r"^status: draft$",
    "status: approved",
    body,
    count=1,
    flags=re.MULTILINE,
)
if count != 1:
    print(f"wm: status flip failed at {path}: no 'status: draft' line", file=sys.stderr)
    sys.exit(1)
with open(path, "w", encoding="utf-8") as f:
    f.write(new_body)
PY
done
```

The sweep is best-effort atomic — the python step is single-line per
file and the loop fail-fast on any rc=1 (so a partial sweep aborts
before it touches the next file). The contract surface for AC-006-1
(`PASS: approve flips status atomically`) is the post-sweep
invariant: every produced sprint file's frontmatter carries
`status: approved` xor every produced sprint file's frontmatter
carries `status: draft`.

## Pre-conditions

- `.yoke/config.yaml` exists with a non-empty
  `canonical_memory.provider` key (v2.0.0 hard break).
- `.yoke/runtime/.current` exists and points at a valid slug.
- `.yoke/prds/<slug>.md` exists with `> Status: approved` (or
  `ratified`).
- `.yoke/specs/<slug>.md` exists with `> Status: approved`.
- `.yoke/acceptance-criteria/<slug>.md` exists with `> Status:
  ratified` (Trigger 3 already ratified the criteria envelope).

## Output contract

- **Plan file.** The skill writes / mutates
  `.yoke/runtime/.generate-sprints-plan.yaml` with top-level keys
  `slug`, `generated_at`, `tasks` (populated by Synthesis), and
  `sprint_partition` (populated by Partition). The path is
  gitignored.

- **Sprint runtime bundles.** The skill emits one or more files at
  `.yoke/sprints/<slug>-s<NN>.md` conforming to `templates/sprint.md`.
  Each file's frontmatter carries `status: draft` until Trigger 2.5
  approves; on `approve` / `approve_and_continue`, the field flips
  to `status: approved` atomically across every produced sprint file.
  On `reject` (after secondary confirmation), every produced sprint
  file is deleted.

- **Read-only artifacts.** No file under `.yoke/specs/`,
  `.yoke/acceptance-criteria/`, or `.yoke/prds/` is modified. The
  binding-AC envelope (Trigger 3) is preserved verbatim — drift
  between the produced plan and the AC envelope escalates Trigger 4
  in `/yoke:implement`'s council protocol, never an inline AC edit
  here.

## Anti-patterns

- **Inlining criterion bodies inside sprint files.** The
  `## Functional acceptance criteria` and `## Sensors` sections inside
  produced sprint files carry only IDs that resolve against
  `.yoke/acceptance-criteria/<slug>.md` and `.yoke/sensors/<id>.md`
  respectively (Rule 1 of `concepts/yoke-pattern-sprint-runtime-bundle`).

- **Per-persona forks inside a task body.** Each task carries a
  single unified instruction block readable by all three council
  personas. Sub-sections like `**For Sr Eng:**`, `**For Sr QA:**`, or
  `**For Sr Staff:**` are forbidden (decision 5A of the parent PRD;
  FR-1 of the binding AC).

- **Modifying upstream artifacts.** This skill is read-only against
  `.yoke/prds/`, `.yoke/specs/`, and `.yoke/acceptance-criteria/`.
  Drift between the produced sprint plan and the binding AC envelope
  escalates Trigger 4 — never edit the AC inline.

- **Non-deterministic partition output.** Re-running the skill
  against an unchanged `(spec, acceptance-criteria)` pair MUST converge
  to the same sprint partition modulo deterministic ordering (FR-3).
  Random ordering, timestamp-keyed task ids, or LLM-temperature drift
  in the partition stage is a defect.

- **Auto-migrating legacy tasks.** A legacy task (sprint files
  emitted by `/yoke:tech-spec` stage 3, no
  `.yoke/acceptance-criteria/<slug>.md` present) is rejected on re-run
  with stderr `wm: legacy task — generate-sprints does not migrate`
  (decision 6A; AC-007-2 of the binding AC). Sprint 04 of the parent
  PRD implements the rejection branch.

## See also

- `concepts/yoke-pattern-phase-flow` — the six-phase flow envelope.
  This skill sits at Phase 2.5, between Phase 2 (Tech Spec) and
  Phase 3 (Acceptance Criteria ratification's downstream consumer).
- `concepts/yoke-pattern-roles` — the Senior Engineer persona contract
  this skill instantiates.
- `concepts/yoke-pattern-human-triggers` — Trigger 2.5 (Sprint plan
  ratification) is added by the parent PRD and amended into the
  doctrine entry via the Sprint 04 canonize-handoff packet.
- `concepts/yoke-pattern-sprint-runtime-bundle` — the binding shape of
  every produced sprint file (reference-by-ID, single working set per
  cycle, no inlined bodies).
- `concepts/yoke-pattern-memory-model` — Rule 5: runtime state
  (including `.yoke/runtime/.generate-sprints-plan.yaml`) is gitignored
  and never promoted to the versioned archive.
- Parent PRD: `.yoke/prds/2026-05-03-generate-sprints-skill.md`.
- Parent Spec: `.yoke/specs/2026-05-03-generate-sprints-skill.md`.
- Binding Acceptance Criteria:
  `.yoke/acceptance-criteria/2026-05-03-generate-sprints-skill.md`.
