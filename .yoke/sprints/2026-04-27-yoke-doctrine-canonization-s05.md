---
task_id: 2026-04-27-yoke-doctrine-canonization-s05
sprint: 5
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-yoke-doctrine-canonization.md#sprint-5
Migrated-from: [.yoke/tasks/2026-04-27-yoke-doctrine-canonization-s05-t01.md, .yoke/tasks/2026-04-27-yoke-doctrine-canonization-s05-t02.md, .yoke/tasks/2026-04-27-yoke-doctrine-canonization-s05-t03.md]
---

# Sprint 05: Validation + final deletion

## Sprint objective

A reusable validation sensor enforces the zero-`.vibeflow/`-reference invariant, every migrated entity is round-trip validated via `/yoke:ask`, and the `.vibeflow/` directory is removed from the working tree.

## Sprint DoD

- 2026-04-27-yoke-doctrine-canonization-s05-t01: `bash lib/sensors/no-vibeflow-refs.sh` exits 0 AND `bash tests/sensors/no-vibeflow-refs.test.sh` exits 0 AND `[ -x lib/sensors/no-vibeflow-refs.sh ]` returns 0.
- 2026-04-27-yoke-doctrine-canonization-s05-t02: `bash <script-path>` exits 0 AND `.yoke/runtime/round-trip-evidence.txt` exists with at least 16 distinct query/response transcripts AND every expected substring (one per query, hard-coded in the script) appears in the corresponding transcript section.
- 2026-04-27-yoke-doctrine-canonization-s05-t03: `[ ! -d .vibeflow ]` returns 0 AND `bash lib/sensors/no-vibeflow-refs.sh` exits 0 AND a `find . -path ./node_modules -prune -o -name '*.md' -print | xargs grep -lF '.vibeflow/' 2>/dev/null | grep -vE '^(\\./)?(\\.yoke/(prds|tasks|specs)/|CLAUDE\\.md|docs/lineage\\.md)' | wc -l` returns 0 — i.e., every remaining `.vibeflow/` reference in the repo is in an explicitly-allowed historical location.

## Tasks

### Task 2026-04-27-yoke-doctrine-canonization-s05-t01

**Story:**

The "zero `.vibeflow/` references" invariant from the PRD has to be
enforceable forever, not just at the end of v0. A bash sensor under
`lib/sensors/` makes the invariant a deterministic check that any
future Yoke change re-runs — caught by the Validator if a regression
sneaks in. Sprint 4 brings the count to 0; this sensor pins it.

**Technical implementation:**

- Create `lib/sensors/no-vibeflow-refs.sh`:
  ```bash
  #!/bin/bash
  # Sensor: zero .vibeflow/ references in framework surface.
  # Exits 0 if no matches; non-zero with file:line:context output otherwise.
  set -euo pipefail
  matches="$(grep -rnF '.vibeflow/' skills/ agents/ hooks/ lib/ templates/ 2>/dev/null || true)"
  if [[ -n "$matches" ]]; then
    echo "$matches" >&2
    echo "sensor: no-vibeflow-refs found $(echo "$matches" | wc -l) match(es)" >&2
    exit 1
  fi
  exit 0
  ```
- Make the script executable: `chmod +x lib/sensors/no-vibeflow-refs.sh`.
- Register in `/yoke:ack-sensors`: add the sensor to the catalog so it appears in catalog-mode output AND so Acceptance Contracts can declare it.
- Add a self-test at `tests/sensors/no-vibeflow-refs.test.sh` that:
  - Runs the sensor against the current tree; expects exit 0 (post-cutover state).
  - Creates a temp file under `skills/` containing `.vibeflow/`, runs the sensor; expects non-zero exit and the file:line in output. Cleans up the temp file.
  - Both cases are isolated; the test does not pollute the working tree.
- Wire the test into `tests/run-all.sh` (or whatever the smoke runner is) so CI exercises it.

**Validation:**

- `bash lib/sensors/no-vibeflow-refs.sh` exits 0 against the post-cutover tree.
- `bash tests/sensors/no-vibeflow-refs.test.sh` exits 0 (both pass and fail paths exercised).
- `bash skills/ack-sensors/SKILL.md`-driven catalog mode (or whatever invocation the skill exposes) lists `no-vibeflow-refs` as a registered sensor.
- The sensor file has executable permission.

**Acceptance criterion:**

`bash lib/sensors/no-vibeflow-refs.sh` exits 0 AND `bash tests/sensors/no-vibeflow-refs.test.sh` exits 0 AND `[ -x lib/sensors/no-vibeflow-refs.sh ]` returns 0.

### Task 2026-04-27-yoke-doctrine-canonization-s05-t02

**Story:**

Per-task `/yoke:ask` round-trips have happened all along, but the
final v0 gate is a single coherent suite that asserts every migrated
entity class is retrievable. This produces the committable evidence
file that the Validator can re-run and that the Acceptance Contract
binds to. Without it, "doctrine queryable via `/yoke:ask`" is
sentiment, not a check.

**Technical implementation:**

- Implement `lib/sensors/yoke-doctrine-round-trip.sh` (or `tests/round-trip/yoke-doctrine.sh` — final location is a sprint-5 implementation choice):
  - Hard-coded list of N sample queries — one per pattern (9), one per pattern of decision (3 sample decisions: most-recent, one mid-history, one superseded), one for conventions, one for project (`/yoke:ask "what is the claude-yoke project?"`), one for actor (`/yoke:ask "describe the yoke actor"`), one for an audit. ~16 queries total.
  - For each query, capture the response. Assert (deterministic substring match) that the response contains the expected entity filename or path verbatim.
  - On any miss, emit `<query> -> MISS (expected substring: <X>)` to stderr and exit non-zero.
  - On all hits, write the full transcript to `.yoke/runtime/round-trip-evidence.txt` (gitignored — the artifact lives in the runtime dir but the assertion happens at run-time).
- The query list, expected substrings, and the script itself are committed in this task file's Validation section so future readers (and the Acceptance Contract's BDD) can re-derive them.

**Validation:**

- The script runs against a tree where sprints 1-4 have all completed; expected outcome: every query passes.
- `.yoke/runtime/round-trip-evidence.txt` exists after a successful run and contains all 16 transcripts.
- Re-running the script is idempotent — same outputs given same vault state.
- The Validator's Acceptance-Contract sensor list includes this round-trip sensor.

**Acceptance criterion:**

`bash <script-path>` exits 0 AND `.yoke/runtime/round-trip-evidence.txt` exists with at least 16 distinct query/response transcripts AND every expected substring (one per query, hard-coded in the script) appears in the corresponding transcript section.

### Task 2026-04-27-yoke-doctrine-canonization-s05-t03

**Story:**

The PRD's anti-scope says deletion happens once and at the END of v0,
after every Acceptance Contract criterion is green. This is that
moment. Before this commit, `.vibeflow/` is the source-of-truth
fallback for any check that wants to compare migrated content. After
this commit, the working tree no longer carries the directory; git
history preserves every byte for posterity.

**Technical implementation:**

- Pre-flight checks (mandatory; do not proceed if any fails):
  - `bash lib/sensors/no-vibeflow-refs.sh` exits 0 (sprint 5 task 1 sensor).
  - `bash <round-trip-script>` exits 0 (sprint 5 task 2 suite).
  - Every preceding sprint's tasks are marked `status: approved` in their frontmatter (signals that the Acceptance Contract is fully green).
  - `git status` shows a clean working tree (no uncommitted changes from earlier sprints lingering).
- Run `git rm -rf .vibeflow/` from the repo root.
- Stage the deletion. Compose the commit message:
  ```
  yoke: remove .vibeflow/ — content migrated to canonical memory + .yoke/ archives

  Closes the doctrine-canonization PRD (.yoke/prds/2026-04-27-yoke-doctrine-canonization.md).
  Doctrine lives in iurykrieger/brain under tags: [yoke-framework].
  Project history (specs, PRDs) lives under .yoke/specs/ and .yoke/prds/.
  ```
- After the commit, verify the post-conditions:
  - `[ ! -d .vibeflow ]` returns 0.
  - `bash lib/sensors/no-vibeflow-refs.sh` still exits 0 (no source for false positives now exists).
  - Smoke tests under `tests/` still execute green; if any test references `.vibeflow/` as historical example (the PRD-allowed exemption), the test still passes since git history is intact for `git log`-based tests.
  - `examples/` directory's contents are unaffected.
  - `docs/lineage.md` (if it carries `.vibeflow/` references documenting the Vibeflow fork) still exists and reads correctly.

**Validation:**

- `[ ! -d .vibeflow ]` returns 0.
- `bash tests/run-all.sh` (or per-sprint smoke) exits 0.
- `git log -1 --oneline` shows the deletion commit.
- `git log --all -- .vibeflow/index.md | head` shows the historical commits (deletion preserves history).
- A `find . -path ./node_modules -prune -o -name '*.md' -print | xargs grep -l '\.vibeflow/' 2>/dev/null` lists ONLY: (a) files inside `.yoke/prds/` and `.yoke/tasks/` and `.yoke/specs/` (this PRD, the spec, and the task files reference `.vibeflow/` as the migration source — that is correct and historical), (b) `CLAUDE.md`'s `## Migration history` section, (c) optionally `docs/lineage.md`. No matches under `skills/`, `agents/`, `hooks/`, `lib/`, `templates/`.

**Acceptance criterion:**

`[ ! -d .vibeflow ]` returns 0 AND `bash lib/sensors/no-vibeflow-refs.sh` exits 0 AND a `find . -path ./node_modules -prune -o -name '*.md' -print | xargs grep -lF '.vibeflow/' 2>/dev/null | grep -vE '^(\\./)?(\\.yoke/(prds|tasks|specs)/|CLAUDE\\.md|docs/lineage\\.md)' | wc -l` returns 0 — i.e., every remaining `.vibeflow/` reference in the repo is in an explicitly-allowed historical location.

## Functional acceptance criteria

- (criterion IDs to be resolved from .yoke/acceptance-contracts/2026-04-27-yoke-doctrine-canonization.md when that AC artifact migrates to the new shape; left empty for now since the doctrine task already shipped)

## Sensors

- (post-shipped sprint; sensors recorded in audit reports)
