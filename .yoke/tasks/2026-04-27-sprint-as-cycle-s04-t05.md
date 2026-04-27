---
task_id: 2026-04-27-sprint-as-cycle-s04-t05
sprint: 4
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-4
---

# Task 2026-04-27-sprint-as-cycle-s04-t05 — Add assertions to `tests/smoke/sprint-4.test.sh`: `current_sprint:` advances monotonically through sprint list during a successful `/yoke:implement` run; `progress.md` is never split into per-sprint files; `completed_sprints:` array length equals total sprint count at run end.

## Story

The runtime invariants for the new sprint walk live in `tests/smoke/sprint-4.test.sh` (the ralph-loop walking test). Three new assertions guarantee that future changes to `/yoke:implement` or `lib/ralph-loop/orchestrate.sh` cannot regress the per-sprint walk: monotonic advancement of `current_sprint:`, file-singleton invariant on `progress.md`, and completion equality at run end. Together these are the binary checks that enforce "one sprint = one ralph cycle, sprints execute serially".

## Technical implementation

- Edit `tests/smoke/sprint-4.test.sh` (do NOT replace; add new test cases at the end).
- Add three new assertions, each scoped around a synthetic fixture run:
  1. **Monotonic advancement:** create a synthetic spec at `/tmp/test-spec.md` with 3 sprints, each with a trivial DoD (`echo $RANDOM > /tmp/sprint-<NN>.txt`). Invoke `/yoke:implement` against this spec. After the run, parse `progress.md` for the sequence of `current_sprint:` values seen across snapshots in `.yoke/runtime/.snapshots/`; assert the sequence is `01 → 02 → 03 → 04` (one beyond last, post-completion). Failure message: "current_sprint: did not advance monotonically; observed sequence: <seq>".
  2. **`progress.md` singleton:** at every snapshot during the synthetic run, `find .yoke/runtime -maxdepth 1 -name 'progress*.md' -type f | wc -l` returns exactly 1. Failure message: "progress.md was split into per-sprint files".
  3. **Completion equality:** at run end, `progress.md` frontmatter has `completed_sprints: [01, 02, 03]` (length 3, matching `total_sprints: 3`). Failure message: "completed_sprints array does not equal total_sprints at run end".
- Each test cleans up: removes synthetic spec, sprint files under `.yoke/sprints/test-*`, snapshots under `.yoke/runtime/.snapshots/test-*`, and any fixture state.
- Use a `WM_TEST_DIR` env var or `TEST_TMPDIR` to isolate the synthetic test runs from real working memory.
- Cite `concepts/yoke-pattern-ralph-loop`, `concepts/yoke-pattern-memory-model`, and the new `concepts/yoke-pattern-sprint-runtime-bundle`.

## Validation

- Static smoke: `tests/smoke/sprint-4.test.sh` contains the three new assertions, identifiable by their failure-message strings.
- Functional smoke (pass case): `bash tests/smoke/sprint-4.test.sh` exits 0.
- Isolation smoke: the test runs do NOT pollute `.yoke/sprints/2026-04-27-sprint-as-cycle-s*.md` or any real working memory paths. Verify by `git status` after the test — no untracked files or modifications outside `WM_TEST_DIR`.
- Negative-case smoke: temporarily patch `lib/ralph-loop/orchestrate.sh` to skip incrementing `current_sprint:` after sprint 1; re-run the test; assert it exits non-zero with the monotonic-advancement failure message; revert the patch; re-run; assert it passes again.

## Acceptance criterion

`bash tests/smoke/sprint-4.test.sh` exits 0, AND `grep -c "current_sprint: did not advance\|progress.md was split\|completed_sprints array does not equal" tests/smoke/sprint-4.test.sh` returns ≥ `3`.
