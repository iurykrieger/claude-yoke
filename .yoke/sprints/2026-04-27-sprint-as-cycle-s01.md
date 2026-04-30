---
task_id: 2026-04-27-sprint-as-cycle-s01
sprint: 1
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-1
Migrated-from: [.yoke/tasks/2026-04-27-sprint-as-cycle-s01-t01.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s01-t02.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s01-t03.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s01-t04.md]
---

# Sprint 01: Foundations (additive new shape, OLD shape still works)

## Sprint objective

New path helpers, sprint-file template, scaffolder, and residual sensor exist on disk and are unit-callable. No consumer of the old shape changes; nothing migrates yet. Smoke tests for the existing OLD shape continue to pass unchanged. The codebase is shippable: the new helpers are dormant additions, the old helpers remain authoritative.

## Sprint DoD

- `bash -c 'source lib/working-memory/paths.sh && wm_sprint_path "2026-04-27-sprint-as-cycle" 3 && wm_validate_sprint_id "2026-04-27-sprint-as-cycle-s03" && wm_list_sprint_paths "no-such-slug"'` exits 0 with stdout containing `.yoke/sprints/2026-04-27-sprint-as-cycle-s03.md`, and `tests/smoke/sprint-2.test.sh` exits 0.
- `test -f templates/sprint.md && [ "$(grep -c '^## ' templates/sprint.md)" = "5" ] && grep -q "^## Sprint objective$" templates/sprint.md && grep -q "^## Sensors$" templates/sprint.md && ! grep -qE "^#!/.*bash" templates/sprint.md` exits 0.
- `bash lib/working-memory/scaffold-sprints.sh /tmp/test-spec.md` (where `/tmp/test-spec.md` is a freshly-authored fixture containing exactly one `### Sprint 1 — Test` heading and a valid frontmatter) creates `.yoke/sprints/<slug>-s01.md` matching `templates/sprint.md`'s shape, exits 0 with `wm: scaffolded 1 sprint file(s)…` on stdout; the immediate re-run exits non-zero with the conflict message.
- `bash tests/sensors/legacy-parts-zero-residual.test.sh` exits 0, AND `bash lib/sensors/legacy-parts-zero-residual.sh` against the current working tree (which contains the legacy files) emits ≥ 78 newline-delimited JSON violation objects on stdout and exits 1.

## Tasks

### Task 2026-04-27-sprint-as-cycle-s01-t01

**Story:** The new sprint-bundle shape needs path helpers before any consumer can be migrated. Adding them additively (without touching the existing `wm_task_*` helpers) means the codebase keeps shipping green: old consumers continue to work, new consumers can be authored against the new helpers, and the migration of consumers can happen sprint-by-sprint without a flag-day break. This task is the first additive step; nothing on disk consumes the new helpers yet.

**Technical implementation:**

- Edit `lib/working-memory/paths.sh`. Add three new functions alongside the existing `wm_*` family, in the same shape and style:
  - `wm_sprint_path <slug> <sprint>` — returns `.yoke/sprints/<slug>-s<NN>.md` where `<NN>` is the zero-padded 2-digit form of `<sprint>`. Uses the existing `_wm_archive_path` helper if present, otherwise composes the path from `WM_ROOT` (or the equivalent constant). Errors with `wm: invalid sprint number` if `<sprint>` is not a positive integer 1–99.
  - `wm_list_sprint_paths <slug>` — globs `.yoke/sprints/<slug>-s*.md` and emits matches in lexical order (which equals positional order via the zero-pad). Returns zero matches as empty stdout (not error).
  - `wm_validate_sprint_id <id>` — exits 0 if `<id>` matches `^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]{0,49}-s[0-9]{2}$`, exits non-zero with `wm: invalid sprint id <id>` otherwise.
- Add `sprints` to `WM_ARCHIVE_CATEGORIES` (alongside the existing `tasks` entry — both coexist this sprint). The category list is what `_wm_archive_path` iterates over to validate path requests.
- Do NOT touch `wm_task_path`, `wm_list_task_paths`, `wm_validate_task_id`, or any other existing helper in this task.
- Do NOT create the `.yoke/sprints/` directory eagerly; `mkdir -p` happens lazily at first write (consistent with how `wm_prd_path` handles `prds/`).
- Cite pattern `concepts/yoke-pattern-memory-model` for the working-memory archive layout invariants the new helpers must satisfy.

**Validation:**

- Unit-style smoke: invoke `wm_sprint_path "2026-04-27-sprint-as-cycle" 3` from a bash subshell and assert stdout equals `.yoke/sprints/2026-04-27-sprint-as-cycle-s03.md`.
- Padding smoke: `wm_sprint_path "test" 1` returns `…-s01.md`; `wm_sprint_path "test" 12` returns `…-s12.md`.
- Validation smoke: `wm_validate_sprint_id "2026-04-27-sprint-as-cycle-s03"` exits 0; `wm_validate_sprint_id "2026-04-27-sprint-as-cycle-s3"` exits non-zero.
- List smoke: with no sprint files on disk, `wm_list_sprint_paths "any-slug"` exits 0 with empty stdout.
- Backward-compat smoke: every existing `wm_task_path` / `wm_list_task_paths` / `wm_validate_task_id` call site in the codebase continues to resolve (no signature change to the old helpers).
- The existing test in `tests/smoke/sprint-2.test.sh` (working-memory invariants) passes unchanged, since the new functions are additive.

**Acceptance criterion:** `bash -c 'source lib/working-memory/paths.sh && wm_sprint_path "2026-04-27-sprint-as-cycle" 3 && wm_validate_sprint_id "2026-04-27-sprint-as-cycle-s03" && wm_list_sprint_paths "no-such-slug"'` exits 0 with stdout containing `.yoke/sprints/2026-04-27-sprint-as-cycle-s03.md`, and `tests/smoke/sprint-2.test.sh` exits 0.

### Task 2026-04-27-sprint-as-cycle-s01-t02

**Story:** The sprint-as-cycle PRD declares sprint files are runtime bundles with a fixed section order. Without a template, every consumer that writes a sprint file would re-derive the shape, drift, and the load-bearing invariant ("AC and sensors are referenced by ID, never inlined") would erode. This task lands the canonical template so stage-3 fills, migration concatenations, and any future hand-edit converge on one shape.

**Technical implementation:**

- Create `templates/sprint.md` next to the existing `templates/{spec,task,prd,approval-menu}.md`.
- Frontmatter section (between `---` delimiters):
  - `task_id: <slug>-s<NN>` — keyed on sprint, but the field name keeps `task_id` for compatibility with downstream tooling that treats every working-memory artifact uniformly. (Alternative: rename to `sprint_id` — defer to sprint 3 when consumers update.)
  - `sprint: <N>` (unpadded integer)
  - `slug: <slug>`
  - `status: <draft | approved>`
  - `created_at: <iso8601>`
  - `model: ""` (Generator fills with model ID at fill time)
  - `traceability: ""` (Generator fills with `.yoke/specs/<slug>.md#sprint-<N>`)
  - `Migrated-from: []` (optional; populated only for migrated sprints, listing original `<slug>-part-N.md` or `<slug>-s<NN>-t<MM>.md` paths)
- Body section order (as H2 headings):
  1. `## Sprint objective` — one paragraph capturing what the sprint delivers.
  2. `## Sprint DoD` — bullet list of binary, observable checks (cycle exit conditions for the Validator).
  3. `## Tasks` — one `### Task <ID>` subsection per task, with inline labels `**Story:**`, `**Technical implementation:**`, `**Validation:**`, `**Acceptance criterion:**`. Tasks remain a concept *inside* the sprint file; they no longer carry their own file.
  4. `## Functional acceptance criteria` — bullet list of criterion IDs (e.g., `AC-1`, `AC-2.3`) referencing `acceptance-contracts/<slug>.md`. **No criterion text inlined.**
  5. `## Sensors` — bullet list of sensor IDs referencing `.yoke/sensors/<id>.md`. **No sensor logic inlined.**
- Footer: `> Generated by /yoke:tech-spec (stage 3) from .yoke/specs/<slug>.md. Status flips to approved when Trigger 2 approves the parent spec.`
- Cite `concepts/yoke-pattern-memory-model` and the new `concepts/yoke-pattern-sprint-runtime-bundle` (drafted in sprint 4's preserve packet) in a footer comment for traceability.

**Validation:**

- File exists at `templates/sprint.md`.
- The frontmatter contains all required fields: `task_id`, `sprint`, `slug`, `status`, `created_at`, `model`, `traceability`, `Migrated-from`.
- The body contains exactly five H2 headings in the specified order: `## Sprint objective`, `## Sprint DoD`, `## Tasks`, `## Functional acceptance criteria`, `## Sensors`.
- The template body MUST NOT contain any literal sensor logic (no `#!/usr/bin/env bash` blocks, no shell function bodies) or criterion text excerpts (no Given/When/Then BDD scenarios).
- A grep over `templates/sprint.md` for `<sensor-id>` and `<AC-criterion-id>` placeholder strings confirms the reference-by-ID shape.

**Acceptance criterion:** `test -f templates/sprint.md && [ "$(grep -c '^## ' templates/sprint.md)" = "5" ] && grep -q "^## Sprint objective$" templates/sprint.md && grep -q "^## Sensors$" templates/sprint.md && ! grep -qE "^#!/.*bash" templates/sprint.md` exits 0.

### Task 2026-04-27-sprint-as-cycle-s01-t03

**Story:** `scaffold-tasks.sh` is the deterministic stage-2 bracket that bounds the LLM stages of `/yoke:tech-spec`. The sprint-as-cycle shape needs a peer scaffolder that creates sprint files instead of task files. Authoring it in sprint 1 (additive) means sprint 3's `/yoke:tech-spec` rewrite can swap callsites cleanly without first having to author the helper. The old scaffolder remains untouched and operational this sprint; both coexist until sprint 3 retires the task-shape one.

**Technical implementation:**

- Create `lib/working-memory/scaffold-sprints.sh` next to `lib/working-memory/scaffold-tasks.sh`.
- Shape (mirroring `scaffold-tasks.sh`):
  - Shebang: `#!/usr/bin/env bash`. `set -euo pipefail`.
  - Argument: `<spec_path>` — absolute or relative path to a `.yoke/specs/<slug>.md`.
  - Extract `<slug>` from the basename of `<spec_path>` (strip leading directories and trailing `.md`).
  - Parse sprint headings from the spec body via the deterministic regex `^### Sprint ([0-9]+) — `. The captured group is the sprint number; reject values outside 1–99 with `wm: invalid sprint number <N> in <path>`.
  - For each sprint number found, compute the zero-padded `<NN>` and the target path `.yoke/sprints/<slug>-s<NN>.md`. Skip if the file already exists (refuse to overwrite — exit non-zero with `wm: would overwrite existing sprint file at <path>`, listing all conflicts).
  - Lazily `mkdir -p .yoke/sprints/`.
  - Seed each new sprint file from `templates/sprint.md` with substitutions: `<slug>` → actual slug, `<NN>` → padded sprint number, `<N>` → unpadded sprint number, `<iso8601>` → `date -u +%Y-%m-%dT%H:%M:%SZ`. Leave body section bodies empty (or with the placeholder text from the template).
  - On success: emit `wm: scaffolded <count> sprint file(s) under .yoke/sprints/` to stdout, exit 0.
- Cite `concepts/yoke-pattern-plugin-structure` for the lib/ layout convention.

**Validation:**

- Smoke: invoke `bash lib/working-memory/scaffold-sprints.sh /tmp/test-spec.md` (where `/tmp/test-spec.md` contains `### Sprint 1 — Test\n### Sprint 2 — Two\n### Sprint 3 — Three\n### Sprint 4 — Four\n` plus a valid frontmatter) from a clean state. Assert that 4 files are created (`-s01.md` through `-s04.md`) and the script exits 0 with the expected `wm: scaffolded 4 sprint file(s)` message.
- Idempotency smoke: re-running the same command exits non-zero with the conflict list.
- Negative smoke: invoke against a spec file that contains `### Sprint 0 — …` or `### Sprint 100 — …` and assert the script exits non-zero.
- Frontmatter smoke: read one of the seeded files and assert `task_id: <slug>-s01`, `sprint: 1`, `slug: <slug>`, `status: draft` are present.
- This task does NOT invoke the scaffolder against the active spec at fill time — the script must be runnable but not auto-run during stage 3 of this PRD.

**Acceptance criterion:** `bash lib/working-memory/scaffold-sprints.sh /tmp/test-spec.md` (where `/tmp/test-spec.md` is a freshly-authored fixture containing exactly one `### Sprint 1 — Test` heading and a valid frontmatter) creates `.yoke/sprints/<slug>-s01.md` matching `templates/sprint.md`'s shape, exits 0 with `wm: scaffolded 1 sprint file(s)…` on stdout; the immediate re-run exits non-zero with the conflict message.

### Task 2026-04-27-sprint-as-cycle-s01-t04

**Story:** The migration sprints (2 and 4) move legacy `<slug>-part-N.md` and per-task `<slug>-s<NN>-t<MM>.md` files into the new sprint shape. Without a sensor that asserts zero residue post-migration, regressions can silently re-introduce the old shape (e.g., a future `/yoke:tech-spec` revert, a manual `git mv` mistake). This sensor pins the invariant and the Validator runs it at every cycle's verify step. Authoring it in sprint 1 means sprints 2, 4, and every future cycle can rely on it; the sensor itself is dormant until invoked.

**Technical implementation:**

- Create `lib/sensors/legacy-parts-zero-residual.sh` next to existing sensors (`lib/sensors/no-vibeflow-refs.sh` is the closest peer in shape).
- Shape:
  - Shebang: `#!/usr/bin/env bash`. `set -euo pipefail`.
  - No arguments. Operates on the working tree from the repo root.
  - Two parallel checks:
    1. Find any `.yoke/specs/*-part-[0-9]*.md` matches → if non-zero, emit one structured violation per match with `criterion: legacy-parts-zero-residual`, `status: fail`, `location: <path>`, `fix_instruction: "rename via git mv to .yoke/sprints/<slug>-s<NN>.md per the sprint-as-cycle PRD migration script"`, `sensor: legacy-parts-zero-residual`, `evidence: legacy -part-N spec file present`.
    2. Find any `.yoke/tasks/*-s[0-9]*-t[0-9]*.md` matches → if non-zero, emit one structured violation per match with `fix_instruction: "concatenate into .yoke/sprints/<slug>-s<NN>.md per migration"` and equivalent fields.
  - Output format: emit one JSON object per violation to stdout (newline-delimited), matching the structured-sensor-output convention in `concepts/yoke-pattern-sensors`.
  - Exit 0 if zero violations; exit 1 if any violation found.
- Register the sensor in `lib/sensors/manifest.yaml` (or the equivalent registration file). The registration block includes `id: legacy-parts-zero-residual`, `cost_tier: low` (file globs only, no LLM), `applies_to: [working-memory]`, `path: lib/sensors/legacy-parts-zero-residual.sh`. If the manifest does not exist as a single file, register via the `lib/sensors/` discovery mechanism per `concepts/yoke-pattern-sensors`.
- Add a self-test fixture under `tests/sensors/legacy-parts-zero-residual.test.sh` that creates a tmp working tree, populates one fake `-part-N.md` and one fake `-s<NN>-t<MM>.md`, invokes the sensor, asserts both violations are emitted, then removes the fakes and asserts a clean run. Cite `concepts/yoke-pattern-sensors`'s "Structured sensor output" rule.

**Validation:**

- Functional smoke: with the working tree carrying 62 `-part-N.md` files and 16 `-s<NN>-t<MM>.md` files, the sensor emits 78 violations and exits 1.
- Clean-tree smoke: against a hypothetical post-migration tree (no `-part-N` and no `-s<NN>-t<MM>`), the sensor exits 0 with empty stdout.
- Self-test: `bash tests/sensors/legacy-parts-zero-residual.test.sh` exits 0.
- Catalog smoke: `/yoke:ack-sensors` (catalog mode, if available; otherwise inspect `lib/sensors/manifest.yaml`) lists `legacy-parts-zero-residual`.
- Structured-output smoke: each emitted JSON object contains exactly the keys `criterion`, `status`, `location`, `fix_instruction`, `sensor`, `evidence` per `concepts/yoke-pattern-sensors`.

**Acceptance criterion:** `bash tests/sensors/legacy-parts-zero-residual.test.sh` exits 0, AND `bash lib/sensors/legacy-parts-zero-residual.sh` against the current working tree (which contains the legacy files) emits ≥ 78 newline-delimited JSON violation objects on stdout and exits 1.

## Functional acceptance criteria

- See `.yoke/acceptance-contracts/2026-04-27-sprint-as-cycle.md` for the binding criterion IDs and BDD scenarios mapped to each task above.

## Sensors

- wm-sprint-helpers-callable
- wm-task-helpers-still-callable
- templates-sprint-md-shape
- scaffold-sprints-functional
- legacy-parts-residual-self-test
- legacy-parts-residual-shape
