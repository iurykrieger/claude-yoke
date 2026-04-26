# Audit Report: tech-spec-task-split-part-1

> Audited via /vibeflow:audit on 2026-04-25
> Spec: `.vibeflow/specs/tech-spec-task-split-part-1.md`
> PRD: `.vibeflow/prds/tech-spec-task-split.md`

**Verdict: PASS**

## Test Results

All 13 smoke tests under `tests/smoke/` PASS — no regressions
introduced.

| Test | Result |
| :--- | :--- |
| ask-no-clone.test.sh | PASS |
| folder-isolation.test.sh | PASS |
| memory-migration.test.sh | PASS |
| preserve-model-c.test.sh | PASS |
| sprint-2.test.sh | PASS |
| sprint-3.test.sh | PASS |
| sprint-4.test.sh | PASS |
| sprint-5.test.sh | PASS |
| sprint-6.test.sh | PASS |
| sprint-7.test.sh | PASS |
| sprint-8.test.sh | PASS |
| status-readonly.test.sh | PASS |
| teach-ingest.test.sh | PASS |

The deprecated `wm_tech_spec_path` alias keeps the consumer call sites
in `lib/ralph-loop/orchestrate.sh`, `tests/smoke/folder-isolation.test.sh`,
and `tests/smoke/sprint-4.test.sh` working through the rollout —
exactly as the revised technical decision predicted.

## DoD Checklist

### [x] DoD #1 — paths.sh exposes new helpers + deprecated alias

Evidence:
- `lib/working-memory/paths.sh:96` — `wm_spec_path()` definition
  delegates to `_wm_archive_path "specs"`.
- `lib/working-memory/paths.sh:121-148` — `wm_task_path()` with full
  argument validation.
- `lib/working-memory/paths.sh:154-170` — `wm_list_task_paths()`.
- `lib/working-memory/paths.sh:50` — `WM_ARCHIVE_CATEGORIES=(prds
  specs tasks tech-specs acceptance-contracts contracts query-traces)`
  — `specs` and `tasks` added; `tech-specs` retained transitionally.
- `lib/working-memory/paths.sh:99-115` — DEPRECATED block comment
  listing every consumer call site (12 files) and the cleanup pass.
- `lib/working-memory/paths.sh:116` — `wm_tech_spec_path()` preserved
  as soft alias.

Behavioral verification:
- `wm_spec_path "$slug"` → `.yoke/specs/<slug>.md` ✓
- `wm_tech_spec_path "$slug"` → `.yoke/tech-specs/<slug>.md` ✓ (unchanged)
- `wm_task_path "$slug" 1 1` → `.yoke/tasks/<slug>-s01-t01.md` ✓
- `wm_task_path "$slug" 12 7` → `.yoke/tasks/<slug>-s12-t07.md` ✓

### [x] DoD #2 — wm_task_path validation + wm_list_task_paths sort

Validation tests (each emitted `wm:`-prefixed stderr + non-zero exit):
- `wm_task_path "<slug>" 0 1` → "invalid sprint number: '0' (expected
  positive integer 1..999)" ✓
- `wm_task_path "<slug>" 1 abc` → "invalid task number: 'abc' …" ✓
- `wm_task_path "bad-slug-format" 1 1` → "invalid slug: …" ✓

Sort order under `wm_list_task_paths`:
```
.yoke/tasks/<slug>-s01-t01.md
.yoke/tasks/<slug>-s01-t02.md
.yoke/tasks/<slug>-s01-t10.md
.yoke/tasks/<slug>-s02-t01.md
```
Lexical = positional thanks to 2-digit zero-padding (s01, s02, …,
t01, t02, …, t10). Empty case for an unrelated slug returns empty
output (len=0).

### [x] DoD #3 — scaffold-tasks.sh deterministic + no-overwrite

`lib/working-memory/scaffold-tasks.sh` parses task IDs via the
deterministic regex `^#### Task ([slug])-s([N])-t([M])($|[^0-9])`
(line 53) — no LLM. Behavioral test:
- First run on a synthetic 4-task spec → "wm: scaffolded 4 task
  file(s) under .yoke/tasks/", exit 0.
- Second run on the same spec → "wm: refusing to overwrite 4 existing
  task file(s)" with each conflicting path listed, exit 3.

Frontmatter stub seeded from `templates/task.md` with 7 fields
(`task_id`, `sprint`, `slug`, `status: draft`, `created_at`,
`model: ""`, `traceability: ""`) — verified by inspecting a
generated task file.

### [x] DoD #4 — templates/spec.md sprint-index shape

`templates/spec.md` carries:
- Overall objective
- Sprints with delivery objective
- Task lines rendered as `#### Task <slug>-s<NN>-t<MM> — <story>`
  (no body section per task — DoD #4's "no inline task body"
  requirement)
- Cross-cutting sections: Contracts and interfaces, Dependencies,
  Out of scope
- Trigger 2 chain hint at the end

Note on the 2-digit zero-padding (`s01`, `t02`): documented inline
under "## Sprints" in the template — explicit cross-reference back
to `wm_list_task_paths`.

### [x] DoD #5 — templates/task.md per-task body shape

`templates/task.md` carries:
- YAML frontmatter with 7 fields (matching the scaffold-tasks.sh
  output and the canonization-seed-ready shape)
- Body sections: *Story*, *Technical implementation*, *Validation*,
  *Acceptance criterion* — all four required sections present
- Canonization-seed note in the body explaining how the frontmatter
  feeds Phase 5 / `/yoke:preserve` per `patterns/memory-model.md`
  rippability fields

### [x] DoD #6 — craftsmanship gate

- `bash -n` syntax-checks both `paths.sh` and `scaffold-tasks.sh`
  cleanly.
- `shellcheck` not available in the audit environment — flagged but
  not blocking. Manual review against shellcheck rules (no unquoted
  expansions in critical paths, `[[` not `[`, `set -euo pipefail`,
  no inline-array iteration without quoting).
- Idempotent re-source guard preserved at `paths.sh:36-39` and
  verified by double-sourcing and reading `_WM_PATHS_LOADED=1`
  unchanged.
- DEPRECATED comment block at `paths.sh:99-115` enumerates all 12
  consumer call sites and names the cleanup pass.
- Bash 4+ idioms used: associative-style indexed arrays, `[[ … =~
  … ]]`, `mapfile`, parameter expansion `${var//pat/repl}`.
- `_wm_archive_path` validates slug; `wm_task_path` validates
  positive-integer N/M via `WM_TASK_NUM_REGEX='^[1-9][0-9]{0,2}$'`.

### [x] DoD #7 — Sprint-2 smoke still PASS

Direct run: `bash tests/smoke/sprint-2.test.sh` exits 0 with
`--- Result --- PASS`. Plus the 12 other smoke tests in the suite
(folder-isolation, sprint-3..8, ask-no-clone, memory-migration,
preserve-model-c, status-readonly, teach-ingest) all pass — broader
regression net than the spec required.

## Pattern Compliance

### [x] `.vibeflow/patterns/memory-model.md` — followed

Working-memory archive layout extended with two new categories
(`specs/`, `tasks/`) without disturbing the existing slug regex,
the per-task lifetime, or the working-vs-canonical separation.
The new task-file frontmatter fields (`task_id`, `sprint`, `slug`,
`status`, `created_at`, `model`, `traceability`) are seeded as
*working memory* — Phase 5 promotion to canonical memory remains
the Orchestrator's exclusive territory under Model C.

The DEPRECATED block on `wm_tech_spec_path` follows the pattern's
rule that working-memory artifact-write authority is per-file:
the alias does not change the artifact's location (`.yoke/tech-specs/`),
only buys time to migrate consumers. No canonical-memory writes
introduced.

### [x] `.vibeflow/patterns/plugin-structure.md` — followed

New files placed in canonical locations:
- `lib/working-memory/scaffold-tasks.sh` — internal helper script,
  matches `lib/<purpose>/<verb>.sh` convention.
- `templates/spec.md` and `templates/task.md` — artifact templates
  alongside `templates/prd.md`, `templates/acceptance-contract.md`,
  etc. No new top-level directories.

`paths.sh` retains its idempotent-source-guard convention used by
the rest of the `lib/` helpers.

### [x] `.vibeflow/conventions.md` — followed

- "Blueprints wrapping agentic nodes" — `scaffold-tasks.sh` is the
  deterministic node bracketed by the future LLM stages 1 and 3 of
  Part 2. Pure bash; zero LLM cost; pure side-effect (file
  materialization).
- "Bash scripts target bash 4+" — both files use bash 4+ idioms;
  `set -euo pipefail` honored; `wm:`-prefixed stderr on every error
  path.
- "Sensor output for LLM consumption" — error messages from
  `wm_task_path` and `scaffold-tasks.sh` carry precise identification
  (parameter name + value), location (which validation regex), and
  correction context (expected shape) — exactly the structured-
  output bar the convention requires.

## Anti-scope Respected

- No skill-body changes — `skills/tech-spec/SKILL.md` and
  `skills/acceptance-contract/SKILL.md` untouched. ✓
- `templates/tech-spec.md` not deleted (Part 2 territory). ✓
- No `migrate-tech-specs.sh` (Part 3 territory). ✓
- No new pattern doc. ✓
- No frontmatter consumption logic (the seeded fields are inert
  until Part 2's LLM fill stage and Phase 5 / `/yoke:preserve`). ✓

## Architectural Decisions Surfaced

Two decisions made during implementation that warrant capture in
`.vibeflow/decisions.md`:

1. **Task IDs zero-pad to 2 digits** (`<slug>-s01-t01`, not
   `<slug>-s1-t1`) so lexical sort = positional order in
   `wm_list_task_paths`. The PRD's abstract shape `<slug>-s<N>-t<M>`
   is preserved; padding is a filename-only concern. YAML frontmatter
   stores the unpadded integer (`sprint: 1`, not `sprint: 01`).

2. **`wm_tech_spec_path` preserved as deprecated soft alias** during
   the tech-spec-task-split rollout (Option B in the
   discover-revision dialogue). Surface analysis surfaced 11 consumer
   files outside Part 1's 4-file budget; a hard break would either
   explode the budget or leave the runtime broken between merges.
   The alias is a 10-line bridge with a DEPRECATED block comment that
   names every consumer call site. Final cleanup removes alias +
   `tech-specs` from `WM_ARCHIVE_CATEGORIES` once Parts 2, 3, and a
   consumer-migration follow-up land.

## Gaps

None.

## Next Steps

- Implement Part 2 (`tech-spec-task-split-part-2.md`) — note that
  Part 2's DoD #6 will likely surface the same `grep -r tech-specs`
  contradiction Part 1 resolved with the deprecated alias; expect to
  apply the same softening when its turn comes.
- Run `/vibeflow:implement .vibeflow/specs/tech-spec-task-split-part-2.md`
  to continue.
