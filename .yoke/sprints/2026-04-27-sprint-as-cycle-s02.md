---
task_id: 2026-04-27-sprint-as-cycle-s02
sprint: 2
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-2
Migrated-from: [.yoke/tasks/2026-04-27-sprint-as-cycle-s02-t01.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s02-t02.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s02-t03.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s02-t04.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s02-t05.md]
---

# Sprint 02: Legacy data migration (62 spec parts + 16 doctrine-canonization task files)

## Sprint objective

Every legacy `<slug>-part-N.md` under `.yoke/specs/` is renamed to `.yoke/sprints/<slug>-s<NN>.md` with `Part N of M` headers reframed to `Sprint NN of MM`; every legacy `<slug>-s<NN>-t<MM>.md` under `.yoke/tasks/` (i.e., the 16 doctrine-canonization task files — *excluding* this spec's own in-progress task files, which migrate in sprint 4) is concatenated by sprint into `.yoke/sprints/<slug>-s<NN>.md` with a `Migrated-from:` frontmatter array preserving the original paths. Originals are backed up to `.yoke/.legacy-archive/2026-04-27-pre-migration/` before any move. The residual sensor passes against the migrated files. Old helpers and consumers are NOT touched in this sprint — the runtime keeps reading the OLD shape for THIS spec.

## Sprint DoD

- `test -f .yoke/.legacy-archive/2026-04-27-pre-migration/MANIFEST.txt && [ "$(wc -l < .yoke/.legacy-archive/2026-04-27-pre-migration/MANIFEST.txt)" = "78" ] && git check-ignore .yoke/.legacy-archive/2026-04-27-pre-migration/MANIFEST.txt` exits 0.
- `find .yoke/specs -name '*-part-[0-9]*.md' -type f | wc -l` returns `0`, AND `find .yoke/sprints -name '*-s[0-9][0-9].md' -type f | wc -l` returns ≥ `62`, AND `git log --follow .yoke/sprints/2026-04-25-bedrock-canonical-memory-port-s01.md --oneline | wc -l` returns ≥ `2` (history preserved).
- `grep -lE "^# Spec:.*Part [0-9]+( of [0-9]+)?$" .yoke/sprints/*.md` returns zero matches (no migrated file retains the legacy H1), AND `grep -lE "^# Sprint [0-9]{2}( of [0-9]{2})?:" .yoke/sprints/*.md | wc -l` returns ≥ `62`.
- `find .yoke/sprints -name '2026-04-27-yoke-doctrine-canonization-s*.md' -type f | wc -l` returns `5`, AND `find .yoke/tasks -name '2026-04-27-yoke-doctrine-canonization-s*-t*.md' -type f | wc -l` returns `0`, AND `grep -l "^Migrated-from:" .yoke/sprints/2026-04-27-yoke-doctrine-canonization-s*.md | wc -l` returns `5`.
- `bash -c 'bash lib/sensors/legacy-parts-zero-residual.sh 2>/dev/null | jq -c "select(.location | test(\".yoke/tasks/2026-04-27-sprint-as-cycle-s\") | not)" | wc -l'` returns `0`.

## Tasks

### Task 2026-04-27-sprint-as-cycle-s02-t01

**Story:** The migration sprint moves and concatenates 78 files. A bad regex on header reframing or a partial concatenation could damage spec content. Restoring from `git reflog` works but is tedious. The pre-flight backup gives a one-step rollback: `cp -R .yoke/.legacy-archive/2026-04-27-pre-migration/* .yoke/`. This task lands the safety net before any move happens, in the FIRST task of sprint 2, so every subsequent migration task assumes the archive exists.

**Technical implementation:**

- Create the archive root: `mkdir -p .yoke/.legacy-archive/2026-04-27-pre-migration/specs/ .yoke/.legacy-archive/2026-04-27-pre-migration/tasks/`. The `.yoke/.legacy-archive/` directory is gitignored (add to `.yoke/.gitignore` if not already covered by the existing pattern).
- Copy every `.yoke/specs/*-part-[0-9]*.md` to `.yoke/.legacy-archive/2026-04-27-pre-migration/specs/`, preserving filenames. Use `cp -p` to preserve mtime.
- Copy every `.yoke/tasks/2026-04-27-yoke-doctrine-canonization-s*-t*.md` (the 16 doctrine-canonization task files; THIS spec's own task files at `.yoke/tasks/2026-04-27-sprint-as-cycle-s*-t*.md` migrate in sprint 4 and are backed up then) to `.yoke/.legacy-archive/2026-04-27-pre-migration/tasks/`.
- Compute a manifest at `.yoke/.legacy-archive/2026-04-27-pre-migration/MANIFEST.txt` listing each archived path with its sha256 sum (`sha256sum <path> >> MANIFEST.txt`). The manifest is the integrity check: post-migration, restore-and-rehash must reproduce the same sums.
- Update `.yoke/.gitignore` if needed to ensure `.legacy-archive/` is ignored (check with `git check-ignore .yoke/.legacy-archive/test`).
- Cite `concepts/yoke-pattern-memory-model` for the working-memory archive rules and the rationale for keeping the backup off git history (it's a transient one-shot artifact, not doctrine).

**Validation:**

- Manifest smoke: `wc -l .yoke/.legacy-archive/2026-04-27-pre-migration/MANIFEST.txt` reports 78 lines (62 spec parts + 16 doctrine-canonization task files).
- File-count smoke: `find .yoke/.legacy-archive/2026-04-27-pre-migration/specs -name '*-part-*.md' | wc -l` = 62; `find .yoke/.legacy-archive/2026-04-27-pre-migration/tasks -name '2026-04-27-yoke-doctrine-canonization-s*-t*.md' | wc -l` = 16.
- Gitignore smoke: `git check-ignore .yoke/.legacy-archive/2026-04-27-pre-migration/MANIFEST.txt` exits 0 (path is ignored).
- Hash-roundtrip smoke: pick any one archived file, compute its sha256, compare against the line in MANIFEST.txt — they match.
- Idempotency: re-running the backup is safe (overwrites archive contents; manifest re-emitted).

**Acceptance criterion:** `test -f .yoke/.legacy-archive/2026-04-27-pre-migration/MANIFEST.txt && [ "$(wc -l < .yoke/.legacy-archive/2026-04-27-pre-migration/MANIFEST.txt)" = "78" ] && git check-ignore .yoke/.legacy-archive/2026-04-27-pre-migration/MANIFEST.txt` exits 0.

### Task 2026-04-27-sprint-as-cycle-s02-t02

**Story:** 62 legacy spec parts live under `.yoke/specs/` from the pre-2026-04-25 `tech-spec-task-split` rollout. Each one is semantically a sprint-sized chunk (its own Objective, shipped as a separate PR), but the filename declares it as a "part" — wrong directory, wrong shape. This task renames them to the new sprint shape via `git mv`, preserving git history. After this task: `.yoke/specs/` has zero `-part-N.md` files; `.yoke/sprints/` has 62 `<slug>-s<NN>.md` files. The corresponding header reframing happens in t03.

**Technical implementation:**

- For each of the 24 distinct legacy slugs, enumerate the matching `.yoke/specs/<slug>-part-N.md` files. Use `find .yoke/specs -name '*-part-[0-9]*.md' -type f | sort` to get the deterministic list.
- For each match, parse `<slug>` (everything before `-part-`) and `N` (everything after `-part-`, before `.md`). Compute zero-padded `<NN>` (printf `%02d`). Target path: `.yoke/sprints/<slug>-s<NN>.md`.
- Ensure `.yoke/sprints/` exists: `mkdir -p .yoke/sprints/`.
- For each source/target pair: `git mv "<source>" "<target>"`. Use a guard: if `<target>` already exists (e.g., a slug in the migration overlaps with one we're authoring fresh), abort with a loud `wm: collision at <target>` and stop the whole task. No silent overwrites.
- Do NOT modify file contents in this task. Header reframing is t03; this task is purely path-level moves with `git mv` so history is preserved.
- Special case: legacy specs whose stem includes `-part-N-cleanup` or `-part-N-followup` (look for double `-part-` patterns) are renamed conservatively — keep the second qualifier as a body annotation, not a sprint number. If detected, abort with a `wm: ambiguous part suffix at <path>` and surface to the user. From the inventory above, `2026-04-25-tech-spec-task-split-cleanup-part-*.md` is one such case (3 files). Treat the cleanup variant as a separate slug `2026-04-25-tech-spec-task-split-cleanup` and number its sprints independently (`-s01.md`, `-s02.md`, `-s03.md`).
- Commit the moves in one git commit with message `chore(working-memory): migrate 62 legacy -part-N spec files to sprints/`.

**Validation:**

- Post-task globs: `find .yoke/specs -name '*-part-[0-9]*.md' -type f | wc -l` = 0; `find .yoke/sprints -name '*-s[0-9][0-9].md' -type f | wc -l` ≥ 62.
- Per-slug smoke: for slug `2026-04-25-bedrock-canonical-memory-port`, assert files `s01.md` through `s06.md` exist under `.yoke/sprints/` (it had 6 parts).
- Git-history smoke: `git log --follow .yoke/sprints/2026-04-25-bedrock-canonical-memory-port-s01.md` shows commits inherited from `.yoke/specs/2026-04-25-bedrock-canonical-memory-port-part-1.md` (proves `git mv` preserved history).
- File-content smoke: `diff .yoke/.legacy-archive/2026-04-27-pre-migration/specs/2026-04-25-bedrock-canonical-memory-port-part-1.md .yoke/sprints/2026-04-25-bedrock-canonical-memory-port-s01.md` shows zero diff (header reframing happens in t03, not here).
- Sensor smoke: `bash lib/sensors/legacy-parts-zero-residual.sh` over `.yoke/specs/` only emits zero violations for the `-part-N.md` check (the `-s<NN>-t<MM>.md` check still emits the 16 task-file violations until t04).

**Acceptance criterion:** `find .yoke/specs -name '*-part-[0-9]*.md' -type f | wc -l` returns `0`, AND `find .yoke/sprints -name '*-s[0-9][0-9].md' -type f | wc -l` returns ≥ `62`, AND `git log --follow .yoke/sprints/2026-04-25-bedrock-canonical-memory-port-s01.md --oneline | wc -l` returns ≥ `2` (history preserved).

### Task 2026-04-27-sprint-as-cycle-s02-t03

**Story:** After t02 renames files, the H1 inside each migrated file still reads `# Spec: ... — Part N of M`. That heading misrepresents the new shape (which is "sprint", not "spec part") and confuses readers. This task rewrites those H1s to a consistent sprint-shaped form via deterministic regex on the migrated files. It also strips the `# Spec:` prefix so the H1 is a clean `# Sprint <NN> of <MM>: <title>`.

**Technical implementation:**

- Iterate every file under `.yoke/sprints/` matching `*-s[0-9][0-9].md` that has `Migrated-from:` empty or absent (i.e., the 62 files migrated in t02; sprint files freshly authored or migrated in t04 are out of scope).
- For each file, locate the H1 line (first `^# ` match in the body, after frontmatter). Apply the deterministic regex transform:
  - Pattern: `^# Spec:\s*(.+?)\s*[—-]\s*Part\s+(\d+)(?:\s+of\s+(\d+))?(.*?)$` (match titles like "# Spec: Foo — Part 3 of 6" or "# Spec: Foo — Part 3").
  - Replacement: `# Sprint <NN> of <MM>: <title>` where `<NN>` = zero-padded `\2`, `<MM>` = zero-padded `\3` (default to total sprint count for that slug if `\3` absent), `<title>` = `\1`. Append the original H1 as a body annotation block immediately after frontmatter: `> Migrated from: <original H1>`.
- For files whose H1 doesn't match the pattern (edge cases — e.g., the H1 doesn't say "Part N"): leave the H1 unchanged but emit a `wm: H1 reframe skipped at <path>` warning to stderr. The sensor in t05 will flag any unreframed file.
- Implement as a one-shot bash + sed (or perl for safer multi-line) script invoked inline within this task. Do NOT add a permanent script file under `lib/` — the reframe is one-shot.
- Commit the rewrites in one git commit with message `chore(working-memory): reframe H1 of migrated sprint files (Part N → Sprint NN)`. Two commits total for sprint 2 so far (t02 + t03), keeps the diff reviewable.

**Validation:**

- Reframe smoke: for `.yoke/sprints/2026-04-25-bedrock-canonical-memory-port-s03.md`, the H1 reads `# Sprint 03 of 06: Bedrock canonical-memory port` (or similar; exact title carried from `\1`).
- Original-H1 preservation: the same file body contains a block `> Migrated from: # Spec: Bedrock canonical-memory port — Part 3: ...` immediately after frontmatter.
- Regex non-match smoke: any sprint file whose original H1 didn't match the pattern (edge cases) emits the warning to stderr but is not modified, and the sensor in t05 flags the path.
- Diff smoke: `git diff HEAD~1 -- .yoke/sprints/*.md` for this commit shows H1 changes only — no body changes outside the H1 line and the appended `> Migrated from:` annotation.
- Spot check: 5 random migrated files have correctly-reframed H1s.

**Acceptance criterion:** `grep -lE "^# Spec:.*Part [0-9]+( of [0-9]+)?$" .yoke/sprints/*.md` returns zero matches (no migrated file retains the legacy H1), AND `grep -lE "^# Sprint [0-9]{2}( of [0-9]{2})?:" .yoke/sprints/*.md | wc -l` returns ≥ `62`.

### Task 2026-04-27-sprint-as-cycle-s02-t04

**Story:** The 2026-04-27 doctrine-canonization run shipped on the per-task-file shape and produced 16 task files (sprint 1: 4, sprint 2: 3, sprint 3: 2, sprint 4: 4, sprint 5: 3). Under the new shape, each sprint is one file with tasks as `### Task <ID>` subsections. This task collapses the 16 task files into 5 sprint files retroactively, preserving every task body verbatim and recording the migration in `Migrated-from:` frontmatter for audit. After this task, `.yoke/tasks/` carries only THIS spec's own task files (the 23 `2026-04-27-sprint-as-cycle-s*-t*.md` ones, which migrate in sprint 4).

**Technical implementation:**

- Group source files by sprint. The 16 source files form 5 groups by `s<NN>` prefix:
  - `s01`: 4 files (`-s01-t01.md` through `-s01-t04.md`)
  - `s02`: 3 files (`-s02-t01.md` through `-s02-t03.md`)
  - `s03`: 2 files (`-s03-t01.md` through `-s03-t02.md`)
  - `s04`: 4 files (`-s04-t01.md` through `-s04-t04.md`)
  - `s05`: 3 files (`-s05-t01.md` through `-s05-t03.md`)
- For each sprint group `s<NN>`:
  - Compose the target file at `.yoke/sprints/2026-04-27-yoke-doctrine-canonization-s<NN>.md` (must not exist; abort if it does).
  - Frontmatter: lift fields from the FIRST task file in the group (`task_id` becomes `2026-04-27-yoke-doctrine-canonization-s<NN>`, `sprint: <N>`, `slug: 2026-04-27-yoke-doctrine-canonization`, `status: approved` — preserved from the original since the doctrine task already shipped, `created_at: <iso8601 from first task>`, `model: claude-opus-4-7[1m]`, `traceability: .yoke/specs/2026-04-27-yoke-doctrine-canonization.md#sprint-<N>`). Add `Migrated-from: [.yoke/tasks/2026-04-27-yoke-doctrine-canonization-s<NN>-t01.md, ..., -t<NN-last>.md]` listing every source path in the group.
  - Body header: `# Sprint <NN>: <sprint name>` lifted from the corresponding `### Sprint <N> — <name>` heading in `.yoke/specs/2026-04-27-yoke-doctrine-canonization.md`.
  - Append `## Sprint objective` lifted from the spec's `**Delivery objective:**` line for the sprint.
  - Append `## Sprint DoD` — synthesize from the spec's delivery objective + each task's binary criterion (one bullet per task's Acceptance criterion).
  - Append `## Tasks` — for each source task file, append a `### Task <task_id>` subsection containing the four inline labels: `**Story:** <Story body>`, `**Technical implementation:** <Technical implementation body>`, `**Validation:** <Validation body>`, `**Acceptance criterion:** <Acceptance criterion body>`. Lift verbatim — do NOT rewrite or summarize.
  - Append `## Functional acceptance criteria` — placeholder bullet `- (criterion IDs to be resolved from .yoke/acceptance-contracts/2026-04-27-yoke-doctrine-canonization.md when that AC artifact migrates to the new shape; left empty for now since the doctrine task already shipped)`.
  - Append `## Sensors` — list the sensors used by the sprint (synthesized from the spec's Validation section, or left empty with a `(post-shipped sprint; sensors recorded in audit reports)` annotation).
- After composing the 5 sprint files, `git rm` each of the 16 source task files (one git rm command).
- Commit the change in one git commit with message `chore(working-memory): concatenate doctrine-canonization tasks into 5 sprint files`. (Third commit of sprint 2.)

**Validation:**

- Count smoke: `find .yoke/sprints -name '2026-04-27-yoke-doctrine-canonization-s*.md' -type f | wc -l` returns `5`.
- Source-removal smoke: `find .yoke/tasks -name '2026-04-27-yoke-doctrine-canonization-s*-t*.md' -type f | wc -l` returns `0`.
- Frontmatter smoke: each of the 5 sprint files has `Migrated-from: [...]` listing the original task file paths in its frontmatter.
- Body-content smoke: each `### Task <id>` subsection contains the four inline labels (`**Story:**`, `**Technical implementation:**`, `**Validation:**`, `**Acceptance criterion:**`).
- Verbatim smoke: pick `2026-04-27-yoke-doctrine-canonization-s01-t01.md` from `.yoke/.legacy-archive/2026-04-27-pre-migration/tasks/`, locate the `## Story` body, and confirm that exact text appears under `### Task 2026-04-27-yoke-doctrine-canonization-s01-t01` in the migrated `s01.md` sprint file.
- Sensor smoke: `bash lib/sensors/legacy-parts-zero-residual.sh` against `.yoke/tasks/` only emits violations for the remaining 23 `2026-04-27-sprint-as-cycle-s*-t*.md` files (THIS spec's own tasks; sprint 4 migrates them).

**Acceptance criterion:** `find .yoke/sprints -name '2026-04-27-yoke-doctrine-canonization-s*.md' -type f | wc -l` returns `5`, AND `find .yoke/tasks -name '2026-04-27-yoke-doctrine-canonization-s*-t*.md' -type f | wc -l` returns `0`, AND `grep -l "^Migrated-from:" .yoke/sprints/2026-04-27-yoke-doctrine-canonization-s*.md | wc -l` returns `5`.

### Task 2026-04-27-sprint-as-cycle-s02-t05

**Story:** The migration sprint's last task verifies the on-disk shape post-migration before sprint 2 can converge. The Validator will run this same sensor automatically each cycle, but having an explicit task for it makes the convergence criterion legible: if this task fails, sprint 2 is not done. The sensor's check is intentionally scoped to exclude this spec's own task files (which migrate in sprint 4) — those produce expected violations until that point.

**Technical implementation:**

- Invoke `bash lib/sensors/legacy-parts-zero-residual.sh` from the repo root, capturing stdout (newline-delimited JSON violations) and exit code.
- Filter the violation stream to exclude paths matching `.yoke/tasks/2026-04-27-sprint-as-cycle-s*-t*.md`:
  - Use `jq` to filter: `jq -c 'select(.location | test(".yoke/tasks/2026-04-27-sprint-as-cycle-s") | not)' < <output>`.
  - If `jq` is not available in the runtime, fall back to a `grep -v` against the JSON line text targeting the same path pattern (less rigorous; flag in stderr if applied).
- Count the filtered violations. If the count is non-zero, fail the task with a clear `wm: sprint-2 migration incomplete; <N> residual violations:\n<violations>` message and exit non-zero.
- If zero filtered violations, success: emit `wm: sprint-2 migration verified — zero residual -part-N.md or doctrine-canonization task files`.
- Cite `concepts/yoke-pattern-sensors` for the structured-output contract.
- This task does NOT modify any files. It is a verification gate.

**Validation:**

- Pre-condition smoke: t01 backup exists, t02 + t03 spec parts moved, t04 doctrine-canonization tasks concatenated.
- Functional smoke: filtered violation count is exactly 0.
- Negative smoke: temporarily restore one `-part-N.md` file from the legacy archive; re-run the sensor with this filter; assert it now reports 1 violation; remove the restored file; re-run; assert 0 violations again.
- Reporting smoke: the success message includes the timestamp and the migration sprint reference (`sprint-2-of-2026-04-27-sprint-as-cycle`).

**Acceptance criterion:** `bash -c 'bash lib/sensors/legacy-parts-zero-residual.sh 2>/dev/null | jq -c "select(.location | test(\".yoke/tasks/2026-04-27-sprint-as-cycle-s\") | not)" | wc -l'` returns `0`.

## Functional acceptance criteria

- See `.yoke/acceptance-contracts/2026-04-27-sprint-as-cycle.md` for the binding criterion IDs and BDD scenarios mapped to each task above.

## Sensors

- legacy-archive-78-files
- legacy-archive-gitignored
- parts-zero-residue-specs
- sprints-counterpart-exists
- git-mv-history-preserved
- h1-reframe-zero-spec-residue
- h1-reframe-sprint-headings
- doctrine-canonization-5-sprints
- migrated-from-frontmatter
- task-anchor-labels
- sprint2-residual-filtered
