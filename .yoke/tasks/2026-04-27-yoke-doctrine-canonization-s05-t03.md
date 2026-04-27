---
task_id: 2026-04-27-yoke-doctrine-canonization-s05-t03
sprint: 5
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s05-t03 — Delete `.vibeflow/` from the working tree via `git rm -rf` and confirm tests, examples, and docs/lineage.md are unaffected.

## Story

The PRD's anti-scope says deletion happens once and at the END of v0,
after every Acceptance Contract criterion is green. This is that
moment. Before this commit, `.vibeflow/` is the source-of-truth
fallback for any check that wants to compare migrated content. After
this commit, the working tree no longer carries the directory; git
history preserves every byte for posterity.

## Technical implementation

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

## Validation

- `[ ! -d .vibeflow ]` returns 0.
- `bash tests/run-all.sh` (or per-sprint smoke) exits 0.
- `git log -1 --oneline` shows the deletion commit.
- `git log --all -- .vibeflow/index.md | head` shows the historical commits (deletion preserves history).
- A `find . -path ./node_modules -prune -o -name '*.md' -print | xargs grep -l '\.vibeflow/' 2>/dev/null` lists ONLY: (a) files inside `.yoke/prds/` and `.yoke/tasks/` and `.yoke/specs/` (this PRD, the spec, and the task files reference `.vibeflow/` as the migration source — that is correct and historical), (b) `CLAUDE.md`'s `## Migration history` section, (c) optionally `docs/lineage.md`. No matches under `skills/`, `agents/`, `hooks/`, `lib/`, `templates/`.

## Acceptance criterion

`[ ! -d .vibeflow ]` returns 0 AND `bash lib/sensors/no-vibeflow-refs.sh` exits 0 AND a `find . -path ./node_modules -prune -o -name '*.md' -print | xargs grep -lF '.vibeflow/' 2>/dev/null | grep -vE '^(\\./)?(\\.yoke/(prds|tasks|specs)/|CLAUDE\\.md|docs/lineage\\.md)' | wc -l` returns 0 — i.e., every remaining `.vibeflow/` reference in the repo is in an explicitly-allowed historical location.
