# Audit Report: framework-tests-rewrite-part-6

> Audited 2026-04-26 against
> `.vibeflow/specs/framework-tests-rewrite-part-6.md`.

**Verdict: PARTIAL**

PARTIAL strictly because DoD 6 (CI green on push) requires a remote
GitHub Actions run that cannot be observed from the audit environment.
All local-verifiable evidence passes; the workflow YAML is valid and
the matrix references match the shipped concept files. Promote to PASS
after the first push lands green.

## Test Run

- `bash tests/run-all.sh` → exit 0 (11/11 concept files pass).
- `tests/smoke/` directory does not exist; `tests/plugin-install.test.sh`
  and `tests/skills-format.test.sh` are gone.
- `.github/workflows/ci.yml` parses with `python3 -c "import yaml;
  yaml.safe_load(...)"`.

## DoD Checklist

- [x] **DoD 1** — `tests/smoke/` removed (verified
  `ls tests/smoke 2>/dev/null` returns nothing);
  `tests/plugin-install.test.sh` and `tests/skills-format.test.sh`
  removed (same).
- [x] **DoD 2** — `.github/workflows/ci.yml` rewritten:
  - `prep` job (lines 19–58) preserves the four framework-wide
    pre-checks (bash 4 version, JSON manifests, SKILL.md frontmatter,
    `bash -n` over all shell scripts).
  - `test` job (lines 60–85) declares
    `strategy.matrix.test: [<11 paths>]` with `needs: prep`.
  - No `timeout 600 bash tests/smoke/sprint-N.test.sh` lines remain
    (`grep -n 'timeout 600' .github/workflows/ci.yml` empty).
- [x] **DoD 3** — `.vibeflow/conventions.md` line 139:
  the "Smoke test per sprint" subsection is replaced by
  "Test file per framework concept"; the `timeout 600` external-wrapper
  rule is removed (`grep 'Smoke test per sprint\|timeout 600'
  .vibeflow/conventions.md` empty).
- [x] **DoD 4** — `.vibeflow/patterns/plugin-structure.md` lines 87–94:
  the `tests/` block in the directory diagram now shows
  `tests/lib/harness.sh`, `tests/run-all.sh`, and a
  `<concept>.test.sh` entry enumerating the eleven concept files.
  The `## Examples from this codebase` paragraph below the
  auto-block is untouched (historical record).
- [x] **DoD 5** — `bash tests/run-all.sh` exits 0 from the repo root
  with all 11 concept files green.
- [ ] **DoD 6** — CI green on the new shape on a feature branch.
  **Cannot be verified from the audit environment.** YAML is
  syntactically valid, matrix references match the eleven shipped
  files, and the `prep` job mirrors the (previously-green) inline
  pre-checks from the prior workflow. The first push to a remote
  branch will exercise this — promote to PASS once observed.
- [x] **DoD 7** — Craftsmanship gate
  `grep -REIn 'tests/smoke|sprint-[0-9]+\.test\.sh' .github/ tests/
  .vibeflow/conventions.md .vibeflow/patterns/plugin-structure.md`
  returns nothing (GATE_PASS). `.vibeflow/specs/yoke-v1-sprint-*.md`
  and `CHANGELOG.md` historical entries are explicitly excluded by
  the gate's path scope, per spec.

## Pattern Compliance

- [x] **`patterns/plugin-structure.md`** — directly the target of the
  update. The new `tests/` block matches reality (post-Part-1..5
  layout) and the manifesto-component → artifact mapping table is
  unchanged (sprint references in that table are historical fact,
  not test-suite shape).
- [x] **`conventions.md`** — directly the target of the update. The
  swap is minimal — surrounding "Implementation Plan Conventions"
  header preserved.

## Convention Violations

None.

## Gaps

- **DoD 6** — only the remote CI observation. No code change is
  needed; the gap closes the moment the workflow runs green on a
  push.

## Notes

- `tests/fixtures/generator-slug-collision.md` was left in place
  per anti-scope (the spec lists the smoke directory and the two
  stubs as the only deletes). It carries no `tests/smoke|sprint-N`
  references and so passes Part 6's gate.
- The CI matrix is enumerated rather than auto-discovered, per
  spec technical decision: adding a new concept file requires a
  matrix-line edit — a deliberate signal, not a chore.
- A `Configure git identity` step was added to the matrix job so
  `tests/canonical-memory-read.test.sh` (which scaffolds a memory
  repo and commits) survives a fresh GitHub runner without global
  git config. This is a CI prerequisite, not a CI optimization,
  and aligns with spec anti-scope.

## Next Step

Local work is complete: 11/11 concept files green, conventions and
pattern doc reflect the new shape, sprint suite gone, CI workflow
rewritten. The only outstanding item is observing the first
remote CI run; push to a feature branch and check
`gh run list --branch <branch>` to promote DoD 6 from deferred
to PASS.

The full six-part rewrite is implemented and audited:
- Part 1 — foundation (PASS)
- Part 2 — skills & agents surface (PASS)
- Part 3 — memory tests (PASS)
- Part 4 — runtime tests (PASS)
- Part 5 — project artifacts & docs (PASS)
- Part 6 — wipe + CI rewrite + conventions + pattern (PARTIAL,
  pending remote CI observation)
