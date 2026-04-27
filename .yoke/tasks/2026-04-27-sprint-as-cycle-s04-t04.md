---
task_id: 2026-04-27-sprint-as-cycle-s04-t04
sprint: 4
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-4
---

# Task 2026-04-27-sprint-as-cycle-s04-t04 — Add assertions to `tests/smoke/sprint-2.test.sh`: zero `-part-N.md` residue under `.yoke/specs/`, every legacy slug has a sprint counterpart under `.yoke/sprints/`, post-migration `git diff --stat` line-count matches pre-migration modulo header reframing.

## Story

The smoke tests are the CI-time guarantor that the new shape stays in place. Adding three assertions to `sprint-2.test.sh` (the working-memory invariants test) protects against regressions: any future PR that reintroduces `-part-N.md` files, drops sprint counterparts for legacy slugs, or corrupts file content during migration trips the test in CI. Sprint-2 is the right test file because the working-memory invariants live there.

## Technical implementation

- Edit `tests/smoke/sprint-2.test.sh` (do NOT replace; add new test cases at the end).
- Add three new assertions:
  1. **Zero -part-N residue:** `find .yoke/specs -name '*-part-[0-9]*.md' -type f | wc -l` returns 0. Failure message: "legacy -part-N.md spec files found under .yoke/specs/; migration regressed".
  2. **Every legacy slug has a sprint counterpart:** for each unique `<slug>` historically present (computed from a hardcoded list of the 24 slugs migrated in sprint 2 t02 — kept in a fixture file `tests/fixtures/legacy-slugs.txt`), assert at least one `.yoke/sprints/<slug>-s<NN>.md` file exists. Failure message: "legacy slug <slug> lost its sprint counterpart".
  3. **Pre/post line-count parity:** the test reads `tests/fixtures/pre-migration-line-count.txt` (a one-time fixture committed in sprint 2 t02 with `wc -l` totals per migrated file) and asserts the post-migration line counts match modulo the header-reframing diff (allow ±2 lines per file for the H1 + Migrated-from annotation). Failure message: "post-migration content drift exceeds reframing budget for <file>".
- Use bash `[[` syntax and `set -euo pipefail` for predictable failure modes.
- Do NOT add the residual sensor invocation here — that's a separate test concern; this test is for working-memory shape invariants, not sensor behavior.
- Cite `concepts/yoke-pattern-memory-model` for the working-memory invariants the test is enforcing.

## Validation

- Static smoke: `tests/smoke/sprint-2.test.sh` contains the three new assertions, identifiable by their failure-message strings.
- Functional smoke (pass case): `bash tests/smoke/sprint-2.test.sh` exits 0 against the post-migration tree.
- Functional smoke (fail case 1): manually create a stub `.yoke/specs/test-part-1.md`; re-run the test; assert it exits non-zero with the "-part-N.md spec files found" message; remove the stub; re-run; assert it passes again.
- Functional smoke (fail case 2): temporarily delete `.yoke/sprints/2026-04-25-bedrock-canonical-memory-port-s01.md`; re-run; assert it exits non-zero with the "legacy slug … lost its sprint counterpart" message; restore the file; re-run; assert it passes again.
- Fixture smoke: `tests/fixtures/legacy-slugs.txt` exists and lists 24 distinct slugs; `tests/fixtures/pre-migration-line-count.txt` exists with one entry per migrated file.

## Acceptance criterion

`bash tests/smoke/sprint-2.test.sh` exits 0, AND `grep -c "legacy -part-N.md\|lost its sprint counterpart\|content drift exceeds" tests/smoke/sprint-2.test.sh` returns ≥ `3`.
