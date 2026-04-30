---
task_id: 2026-04-27-sprint-as-cycle-s04
sprint: 4
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-4
Migrated-from: [.yoke/tasks/2026-04-27-sprint-as-cycle-s04-t01.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s04-t02.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s04-t03.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s04-t04.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s04-t05.md, .yoke/tasks/2026-04-27-sprint-as-cycle-s04-t06.md]
---

# Sprint 04: Final atomic switch (this spec's own migration + helper removal + smoke tests + canonization packet)

## Sprint objective

This spec's own task files (under `.yoke/tasks/2026-04-27-sprint-as-cycle-s*-t*.md`) are concatenated into `.yoke/sprints/2026-04-27-sprint-as-cycle-s*.md` per sprint, the legacy `wm_task_path`, `wm_list_task_paths`, `wm_validate_task_id` helpers are hard-removed from `lib/working-memory/paths.sh`, the `tasks` entry is removed from `WM_ARCHIVE_CATEGORIES` (replaced by `sprints`), the residual sensor passes globally, smoke tests for both invariants land in `tests/smoke/`, and a canonization packet for Phase 5 is drafted under `.yoke/runtime/.preserve-packet.md`.

## Sprint DoD

- `find .yoke/sprints -name '2026-04-27-sprint-as-cycle-s*.md' -type f | wc -l` returns `4`, AND `find .yoke/tasks -name '2026-04-27-sprint-as-cycle-s*-t*.md' -type f | wc -l` returns `0`.
- `! grep -qE "wm_task_path|wm_list_task_paths|wm_validate_task_id" lib/working-memory/paths.sh && find skills/ agents/ lib/ -type f \( -name '*.sh' -o -name '*.md' \) -exec grep -lE "wm_task_path|wm_list_task_paths|wm_validate_task_id" {} + | head -1 | wc -l | grep -qE "^\s*0\s*$"` exits 0.
- `bash lib/sensors/legacy-parts-zero-residual.sh; [ $? -eq 0 ]` exits 0, AND `bash lib/sensors/legacy-parts-zero-residual.sh 2>/dev/null | wc -c` returns `0` (zero bytes of output, no violations).
- `bash tests/smoke/sprint-2.test.sh` exits 0, AND `grep -c "legacy -part-N.md\|lost its sprint counterpart\|content drift exceeds" tests/smoke/sprint-2.test.sh` returns ≥ `3`.
- `bash tests/smoke/sprint-4.test.sh` exits 0, AND `grep -c "current_sprint: did not advance\|progress.md was split\|completed_sprints array does not equal" tests/smoke/sprint-4.test.sh` returns ≥ `3`.
- `test -f .yoke/runtime/.preserve-packet.md && git check-ignore .yoke/runtime/.preserve-packet.md && grep -c "^## " .yoke/runtime/.preserve-packet.md | grep -qE "^\s*[4-9]\s*$"` exits 0 (file exists, gitignored, has at least 4 H2 sections).

## Tasks

### Task 2026-04-27-sprint-as-cycle-s04-t01

**Story:** This is the closing migration: this spec's own 23 task files (4 + 5 + 8 + 6 spread across the 4 sprints) get concatenated into 4 sprint files in the new shape, completing the on-disk shape switch. Until this task runs, the spec carries dual artifacts (per-task files for the running ralph loop + sprint files for everything else). After this task runs, only sprint files remain. This is also the last point at which the running `/yoke:implement` reads from `.yoke/tasks/` — by the time the cycle returns from this task, the working set has migrated.

**Technical implementation:**

- Pre-flight: extend the backup from sprint 2 t01 to also archive THIS spec's task files. Copy every `.yoke/tasks/2026-04-27-sprint-as-cycle-s*-t*.md` to `.yoke/.legacy-archive/2026-04-27-pre-migration/tasks/own-spec/`, append paths + sha256 sums to MANIFEST.txt.
- Group the 23 source files by sprint (parsing `s<NN>` from filenames):
  - `s01`: 4 files (`-s01-t01.md` through `-s01-t04.md`)
  - `s02`: 5 files (`-s02-t01.md` through `-s02-t05.md`)
  - `s03`: 8 files (`-s03-t01.md` through `-s03-t08.md`)
  - `s04`: 6 files (`-s04-t01.md` through `-s04-t06.md`)
- For each sprint group:
  - Compose target file `.yoke/sprints/2026-04-27-sprint-as-cycle-s<NN>.md` (must not exist; abort with conflict message otherwise).
  - Frontmatter: `task_id: 2026-04-27-sprint-as-cycle-s<NN>`, `sprint: <N>`, `slug: 2026-04-27-sprint-as-cycle`, `status: approved` (lifted from the source task files which become approved at Trigger 2 of this current run), `created_at: <iso8601 of first task>`, `model: claude-opus-4-7[1m]`, `traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-<N>`, `Migrated-from: [<23-original-paths>]`.
  - Body header: `# Sprint <NN>: <name lifted from spec>`.
  - Append `## Sprint objective` lifted from the spec's `**Delivery objective:**` line for that sprint.
  - Append `## Sprint DoD` synthesized from each source task's Acceptance criterion (one bullet per task).
  - Append `## Tasks` — one `### Task <task_id>` subsection per source task, with the four inline labels lifted verbatim from the source task's body sections.
  - Append `## Functional acceptance criteria` placeholder bullet (criterion IDs filled by Phase 3 / `/yoke:acceptance-contract` when this slug's AC is authored).
  - Append `## Sensors` — list any sensor IDs explicitly referenced across the source tasks' Validation sections.
- After composing the 4 sprint files, `git rm` each of the 23 source task files in one git commit.
- Final commit message: `chore(working-memory): self-migrate sprint-as-cycle task files (closing migration)`.

**Validation:**

- Count smoke: `find .yoke/sprints -name '2026-04-27-sprint-as-cycle-s*.md' -type f | wc -l` returns `4`.
- Source-removal smoke: `find .yoke/tasks -name '2026-04-27-sprint-as-cycle-s*-t*.md' -type f | wc -l` returns `0`.
- Frontmatter smoke: each of the 4 sprint files has `Migrated-from: [...]` listing the original 23 paths in aggregate (4 + 5 + 8 + 6 = 23 across the four files).
- Body-content smoke: each `### Task <id>` subsection contains the four inline labels.
- Verbatim smoke: pick one source task body from `.yoke/.legacy-archive/2026-04-27-pre-migration/tasks/own-spec/`, locate its `## Story` body, and confirm that exact text appears under the corresponding `### Task <id>` in the migrated sprint file.

**Acceptance criterion:** `find .yoke/sprints -name '2026-04-27-sprint-as-cycle-s*.md' -type f | wc -l` returns `4`, AND `find .yoke/tasks -name '2026-04-27-sprint-as-cycle-s*-t*.md' -type f | wc -l` returns `0`.

### Task 2026-04-27-sprint-as-cycle-s04-t02

**Story:** After all consumers are rewritten (sprint 3) and all data is migrated (sprints 2 + this sprint's t01), the legacy path helpers become unused. The PRD's anti-scope mandates a hard cut — no deprecated alias, no soft delegation. This task removes the three functions and the `tasks` archive category in one commit. After this commit, any reintroduction of `wm_task_*` callers fails at sourcing because the function doesn't exist.

**Technical implementation:**

- Edit `lib/working-memory/paths.sh`.
- Remove the function definitions for `wm_task_path`, `wm_list_task_paths`, `wm_validate_task_id` (and any helper they call internally that has no other consumer).
- Remove `tasks` from the `WM_ARCHIVE_CATEGORIES` array (or equivalent registration mechanism).
- Verify no other helper depends on those functions (e.g., a `wm_active_slug` doesn't call `wm_validate_task_id` indirectly). If it does, refactor before removing.
- Update any `# DEPRECATED:` block comment in `paths.sh` if one exists for the soon-to-be-removed helpers (cleanup).
- Optionally remove `lib/working-memory/scaffold-tasks.sh` in this same task. If kept (e.g., for git-history reasons), add a `# RETIRED 2026-04-27 — see scaffold-sprints.sh` comment at the top.
- Cite `concepts/yoke-pattern-memory-model` (working-memory archive layout) and `concepts/yoke-conventions` (the no-deprecated-alias rule, ratified per the PRD).
- Commit message: `feat(working-memory): hard-remove wm_task_* helpers and tasks archive category`.

**Validation:**

- Static smoke: grep `lib/working-memory/paths.sh` for `wm_task_path`, `wm_list_task_paths`, `wm_validate_task_id` — zero matches.
- Static smoke: grep `lib/working-memory/paths.sh` for `tasks` in `WM_ARCHIVE_CATEGORIES` — zero matches; for `sprints` — at least one match.
- Source-and-call smoke: `bash -c 'source lib/working-memory/paths.sh && wm_task_path 2>&1 || true'` exits non-zero with `command not found: wm_task_path`.
- Cross-codebase smoke: `find . -name '*.sh' -o -name '*.md' -path '*/skills/*' -o -name '*.md' -path '*/agents/*' | xargs grep -l 'wm_task_path\|wm_list_task_paths\|wm_validate_task_id' 2>/dev/null | wc -l` returns 0.
- Smoke-test smoke: `bash tests/smoke/sprint-2.test.sh` exits 0 (tests still pass; sensors are now scoped to sprint paths).

**Acceptance criterion:** `! grep -qE "wm_task_path|wm_list_task_paths|wm_validate_task_id" lib/working-memory/paths.sh && find skills/ agents/ lib/ -type f \( -name '*.sh' -o -name '*.md' \) -exec grep -lE "wm_task_path|wm_list_task_paths|wm_validate_task_id" {} + | head -1 | wc -l | grep -qE "^\s*0\s*$"` exits 0.

### Task 2026-04-27-sprint-as-cycle-s04-t03

**Story:** The closing verification: with all migrations done, the residual sensor must report a clean tree. This task removes the filter from sprint 2 t05 (which excluded this spec's own task files) and asserts an unfiltered zero-violation result. If this task fails, sprint 4 cannot converge — the migration is incomplete. The Validator runs this same sensor automatically, but having an explicit task makes the convergence criterion legible.

**Technical implementation:**

- Invoke `bash lib/sensors/legacy-parts-zero-residual.sh` from the repo root, capturing stdout (newline-delimited JSON violations) and exit code.
- Do NOT apply any filter — the sensor runs against the whole working tree.
- Assert exit code is 0 AND stdout is empty.
- If non-zero violations remain, fail the task with `wm: sprint-4 closing migration incomplete; <N> residual violations:\n<violations>` and exit non-zero.
- If clean, success: emit `wm: sprint-4 closing migration verified — zero residual legacy files anywhere in the working tree`.
- This task DOES NOT modify any files. It is a pure verification gate.
- Cite `concepts/yoke-pattern-sensors`.

**Validation:**

- Pre-condition smoke: t01 (own-spec migration) and t02 (helper removal) have committed.
- Functional smoke: sensor exits 0 with empty stdout.
- Sensor-correctness smoke: temporarily restore one `-part-N.md` from `.yoke/.legacy-archive/2026-04-27-pre-migration/specs/` to `.yoke/specs/`; re-run sensor; assert it reports 1 violation; remove the restored file; re-run; assert clean again. (The negative case validates the sensor isn't silently passing.)
- Filter-removal smoke: this task does NOT use the `jq` filter that sprint 2 t05 used; the invocation is a bare `bash lib/sensors/legacy-parts-zero-residual.sh` from the repo root.

**Acceptance criterion:** `bash lib/sensors/legacy-parts-zero-residual.sh; [ $? -eq 0 ]` exits 0, AND `bash lib/sensors/legacy-parts-zero-residual.sh 2>/dev/null | wc -c` returns `0` (zero bytes of output, no violations).

### Task 2026-04-27-sprint-as-cycle-s04-t04

**Story:** The smoke tests are the CI-time guarantor that the new shape stays in place. Adding three assertions to `sprint-2.test.sh` (the working-memory invariants test) protects against regressions: any future PR that reintroduces `-part-N.md` files, drops sprint counterparts for legacy slugs, or corrupts file content during migration trips the test in CI. Sprint-2 is the right test file because the working-memory invariants live there.

**Technical implementation:**

- Edit `tests/smoke/sprint-2.test.sh` (do NOT replace; add new test cases at the end).
- Add three new assertions:
  1. **Zero -part-N residue:** `find .yoke/specs -name '*-part-[0-9]*.md' -type f | wc -l` returns 0. Failure message: "legacy -part-N.md spec files found under .yoke/specs/; migration regressed".
  2. **Every legacy slug has a sprint counterpart:** for each unique `<slug>` historically present (computed from a hardcoded list of the 24 slugs migrated in sprint 2 t02 — kept in a fixture file `tests/fixtures/legacy-slugs.txt`), assert at least one `.yoke/sprints/<slug>-s<NN>.md` file exists. Failure message: "legacy slug <slug> lost its sprint counterpart".
  3. **Pre/post line-count parity:** the test reads `tests/fixtures/pre-migration-line-count.txt` (a one-time fixture committed in sprint 2 t02 with `wc -l` totals per migrated file) and asserts the post-migration line counts match modulo the header-reframing diff (allow ±2 lines per file for the H1 + Migrated-from annotation). Failure message: "post-migration content drift exceeds reframing budget for <file>".
- Use bash `[[` syntax and `set -euo pipefail` for predictable failure modes.
- Do NOT add the residual sensor invocation here — that's a separate test concern; this test is for working-memory shape invariants, not sensor behavior.
- Cite `concepts/yoke-pattern-memory-model` for the working-memory invariants the test is enforcing.

**Validation:**

- Static smoke: `tests/smoke/sprint-2.test.sh` contains the three new assertions, identifiable by their failure-message strings.
- Functional smoke (pass case): `bash tests/smoke/sprint-2.test.sh` exits 0 against the post-migration tree.
- Functional smoke (fail case 1): manually create a stub `.yoke/specs/test-part-1.md`; re-run the test; assert it exits non-zero with the "-part-N.md spec files found" message; remove the stub; re-run; assert it passes again.
- Functional smoke (fail case 2): temporarily delete `.yoke/sprints/2026-04-25-bedrock-canonical-memory-port-s01.md`; re-run; assert it exits non-zero with the "legacy slug … lost its sprint counterpart" message; restore the file; re-run; assert it passes again.
- Fixture smoke: `tests/fixtures/legacy-slugs.txt` exists and lists 24 distinct slugs; `tests/fixtures/pre-migration-line-count.txt` exists with one entry per migrated file.

**Acceptance criterion:** `bash tests/smoke/sprint-2.test.sh` exits 0, AND `grep -c "legacy -part-N.md\|lost its sprint counterpart\|content drift exceeds" tests/smoke/sprint-2.test.sh` returns ≥ `3`.

### Task 2026-04-27-sprint-as-cycle-s04-t05

**Story:** The runtime invariants for the new sprint walk live in `tests/smoke/sprint-4.test.sh` (the ralph-loop walking test). Three new assertions guarantee that future changes to `/yoke:implement` or `lib/ralph-loop/orchestrate.sh` cannot regress the per-sprint walk: monotonic advancement of `current_sprint:`, file-singleton invariant on `progress.md`, and completion equality at run end. Together these are the binary checks that enforce "one sprint = one ralph cycle, sprints execute serially".

**Technical implementation:**

- Edit `tests/smoke/sprint-4.test.sh` (do NOT replace; add new test cases at the end).
- Add three new assertions, each scoped around a synthetic fixture run:
  1. **Monotonic advancement:** create a synthetic spec at `/tmp/test-spec.md` with 3 sprints, each with a trivial DoD (`echo $RANDOM > /tmp/sprint-<NN>.txt`). Invoke `/yoke:implement` against this spec. After the run, parse `progress.md` for the sequence of `current_sprint:` values seen across snapshots in `.yoke/runtime/.snapshots/`; assert the sequence is `01 → 02 → 03 → 04` (one beyond last, post-completion). Failure message: "current_sprint: did not advance monotonically; observed sequence: <seq>".
  2. **`progress.md` singleton:** at every snapshot during the synthetic run, `find .yoke/runtime -maxdepth 1 -name 'progress*.md' -type f | wc -l` returns exactly 1. Failure message: "progress.md was split into per-sprint files".
  3. **Completion equality:** at run end, `progress.md` frontmatter has `completed_sprints: [01, 02, 03]` (length 3, matching `total_sprints: 3`). Failure message: "completed_sprints array does not equal total_sprints at run end".
- Each test cleans up: removes synthetic spec, sprint files under `.yoke/sprints/test-*`, snapshots under `.yoke/runtime/.snapshots/test-*`, and any fixture state.
- Use a `WM_TEST_DIR` env var or `TEST_TMPDIR` to isolate the synthetic test runs from real working memory.
- Cite `concepts/yoke-pattern-ralph-loop`, `concepts/yoke-pattern-memory-model`, and the new `concepts/yoke-pattern-sprint-runtime-bundle`.

**Validation:**

- Static smoke: `tests/smoke/sprint-4.test.sh` contains the three new assertions, identifiable by their failure-message strings.
- Functional smoke (pass case): `bash tests/smoke/sprint-4.test.sh` exits 0.
- Isolation smoke: the test runs do NOT pollute `.yoke/sprints/2026-04-27-sprint-as-cycle-s*.md` or any real working memory paths. Verify by `git status` after the test — no untracked files or modifications outside `WM_TEST_DIR`.
- Negative-case smoke: temporarily patch `lib/ralph-loop/orchestrate.sh` to skip incrementing `current_sprint:` after sprint 1; re-run the test; assert it exits non-zero with the monotonic-advancement failure message; revert the patch; re-run; assert it passes again.

**Acceptance criterion:** `bash tests/smoke/sprint-4.test.sh` exits 0, AND `grep -c "current_sprint: did not advance\|progress.md was split\|completed_sprints array does not equal" tests/smoke/sprint-4.test.sh` returns ≥ `3`.

### Task 2026-04-27-sprint-as-cycle-s04-t06

**Story:** The doctrine writes happen at Phase 5 (`/yoke:preserve`, post-loop), governed by Model C. This task drafts the packet that `/yoke:preserve` consumes: three canonical-memory writes, each bundled with the rippability frontmatter required by `concepts/yoke-pattern-memory-model`. The packet itself is working memory (gitignored under `.yoke/runtime/`) — the actual canonical-memory PR opens after the loop terminates.

**Technical implementation:**

- Create `.yoke/runtime/.preserve-packet.md` (gitignored, runtime artifact).
- Section 1: **New entity** at `concepts/yoke-pattern-sprint-runtime-bundle.md` in canonical memory.
  - Frontmatter:
    ```yaml
    ---
    type: concept
    name: "yoke-pattern-sprint-runtime-bundle"
    aliases: ["sprint-runtime-bundle pattern", "Sprint runtime bundle"]
    category: "pattern"
    description: "Sprint files are self-contained ralph-cycle runtime bundles. One sprint = one ralph cycle (with up to 8 cycle attempts). Sprint files reference AC criteria and sensors by ID; they never inline."
    status: "active"
    ratified: 2026-04-27
    last_validated: 2026-04-27
    traceability: ".yoke/prds/2026-04-27-sprint-as-cycle.md"
    project: "claude-yoke"
    refines: ["yoke-pattern-memory-model"]
    tags: [type/concept, kind/pattern, yoke-framework, status/active, domain/runtime]
    ---
    ```
  - Body: explanation of the pattern. Sections: What (sprint = ralph-cycle atom), Where (`.yoke/sprints/<slug>-s<NN>.md`), The Pattern (frontmatter + 5 H2 sections), Rules (reference-by-ID; serial walk; per-sprint hard bound; phase artifacts stay one-file-per-task), Examples, Anti-patterns, Implementation Mapping. Cite the PRD as the source.
- Section 2: **Refinement** of `concepts/yoke-pattern-memory-model.md`.
  - Diff to add `refined_by: [yoke-pattern-sprint-runtime-bundle]` to the frontmatter.
  - Diff to update the "post-tech-spec-task-split" working-memory layout block to show `.yoke/sprints/<slug>-s<NN>.md` (not `.yoke/tasks/<slug>-s<NN>-t<MM>.md`).
  - Body diff to replace the per-task-file clause: "Sprint index → one-line stories; per-task file → full Story / Technical implementation / Validation / Acceptance criterion" with: "Sprint index → cross-sprint architecture; per-sprint runtime bundle → full Story / Technical implementation / Validation / Acceptance criterion per task as anchors inside the bundle. See `concepts/yoke-pattern-sprint-runtime-bundle` for the runtime-bundle shape."
- Section 3: **New decision** at `concepts/yoke-decision-2026-04-27-sprint-id-zero-pad-supersedes-task-id-zero-p.md`.
  - Frontmatter with `supersedes: [yoke-decision-2026-04-25-task-ids-zero-pad-to-2-digits-filename-only]`, `superseded_by: []`, `status: active`, `ratified: 2026-04-27`, etc.
  - Body: "Sprint IDs zero-pad to 2 digits (filename only). Task IDs become anchors inside sprint files (no filename concern). The original decision is superseded because the per-task-file shape it parameterized has been retired by the sprint-as-cycle PRD."
- Section 4: **Supersession** of `yoke-decision-2026-04-25-task-ids-zero-pad-to-2-digits-filename-only`.
  - Diff to add `superseded_by: [yoke-decision-2026-04-27-sprint-id-zero-pad-supersedes-task-id-zero-p]` to the existing decision's frontmatter.
  - Diff to update its `status: active` → `status: superseded`.
- Each section in the packet is structured as a JSON-friendly block so `/yoke:preserve` Phase 3 (Model C cascade) can route each diff to the correct impact class. Cite `concepts/yoke-pattern-model-c-governance` for the routing rules.

**Validation:**

- File exists at `.yoke/runtime/.preserve-packet.md` and is gitignored (`git check-ignore .yoke/runtime/.preserve-packet.md` exits 0).
- Section count smoke: the packet contains exactly 4 H1/H2-level sections (one new entity, one memory-model refinement, one new decision, one supersession diff).
- Frontmatter completeness smoke: the new entity body's frontmatter has all 5 rippability fields per `concepts/yoke-pattern-memory-model` (`ratified`, `last_validated`, `traceability`, etc.) plus the relationship fields (`refines`, optionally `supersedes`).
- Cross-reference smoke: every supersession backlink referenced in the packet's section 4 names an entity that exists in the registered canonical memory (verifiable by `/yoke:ask "does yoke-decision-2026-04-25-task-ids-zero-pad-to-2-digits-filename-only exist?"`).
- Phase-5-readiness smoke: `/yoke:preserve --dry-run` (if available) on the packet produces a non-error diff summary; otherwise this assertion is deferred to runtime invocation.

**Acceptance criterion:** `test -f .yoke/runtime/.preserve-packet.md && git check-ignore .yoke/runtime/.preserve-packet.md && grep -c "^## " .yoke/runtime/.preserve-packet.md | grep -qE "^\s*[4-9]\s*$"` exits 0 (file exists, gitignored, has at least 4 H2 sections).

## Functional acceptance criteria

- See `.yoke/acceptance-contracts/2026-04-27-sprint-as-cycle.md` for the binding criterion IDs and BDD scenarios mapped to each task above.

## Sensors

- own-spec-4-sprints
- own-spec-zero-tasks
- paths-sh-no-task-helpers
- codebase-no-task-helper-refs
- legacy-parts-residual-clean
- smoke-sprint2-passes
- smoke-sprint2-has-3-assertions
- smoke-sprint4-passes
- smoke-sprint4-has-3-assertions
- preserve-packet-exists
- preserve-packet-gitignored
- preserve-packet-has-4-sections
