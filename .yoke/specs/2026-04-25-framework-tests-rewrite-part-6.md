# Spec: Framework tests rewrite — Part 6 (wipe + CI rewrite + docs)

> Generated via /vibeflow:gen-spec on 2026-04-25 from
> .vibeflow/prds/framework-tests-rewrite.md

## Objective

Delete the sprint-shaped suite, rewrite CI to match the new layout,
update `.vibeflow/conventions.md`, and update
`.vibeflow/patterns/plugin-structure.md` so its `tests/` block
reflects the new flat-file shape.

## Context

Parts 1–5 added the new layout alongside the existing sprint files;
CI still runs the old suite. This part atomically retires the old
suite and switches CI. After this part, `tests/` is exclusively
concept-shaped, `.vibeflow/` reflects the new convention, and the
plugin-structure pattern doc shows the canonical layout.

## Definition of Done

1. `tests/smoke/` does not exist; `tests/plugin-install.test.sh` and
   `tests/skills-format.test.sh` do not exist.
2. `.github/workflows/ci.yml` runs each `tests/*.test.sh` (excluding
   `tests/lib/` and `tests/run-all.sh`) as a separate matrix job;
   preserves the existing structural pre-checks (bash 4 version,
   JSON manifest validity, SKILL.md frontmatter, `bash -n` over all
   shell scripts) as a `prep` job that the matrix `needs:`; removes
   every `timeout 600 bash tests/smoke/sprint-N.test.sh` line.
3. `.vibeflow/conventions.md`: the "Smoke test per sprint" subsection
   inside "Implementation Plan Conventions" is replaced with a
   "Test file per framework concept" subsection (one paragraph
   stating: each framework concept maps to one
   `tests/<concept>.test.sh` file; tests assert present-tense
   invariants only; no version literals; no sprint references); the
   `timeout 600` external-wrapper rule is removed.
4. `.vibeflow/patterns/plugin-structure.md`: the `tests/` block in
   the directory diagram is replaced with the new layout
   (`tests/lib/harness.sh`, `tests/run-all.sh`,
   `tests/<concept>.test.sh`, `tests/fixtures/` only if used). The
   `## Examples from this codebase` paragraph (historical record) is
   left untouched.
5. `bash tests/run-all.sh` exits 0 from the repo root.
6. CI is green on the new shape on a feature branch (verified via
   `gh run list` or equivalent).
7. **Craftsmanship gate.**
   `grep -REIn 'tests/smoke|sprint-[0-9]+\.test\.sh' .github/ tests/
   .vibeflow/conventions.md .vibeflow/patterns/plugin-structure.md`
   returns nothing. Surviving references inside
   `.vibeflow/specs/yoke-v1-sprint-*.md` and `CHANGELOG.md` are
   acceptable historical record and explicitly excluded from this
   gate.

## Scope

- Bulk-delete `tests/smoke/*` and the two top-level test stubs
  (`tests/plugin-install.test.sh`, `tests/skills-format.test.sh`).
- Rewrite `.github/workflows/ci.yml` for the new layout.
- Update `.vibeflow/conventions.md`.
- Update `.vibeflow/patterns/plugin-structure.md` (`tests/` block
  only).

## Anti-scope

- **No new test files.** The layout was finalized in Parts 1–5.
- **No changes to `.vibeflow/specs/yoke-v1-sprint-*.md` or
  `CHANGELOG.md` historical entries** — they document past state.
- **No changes to other pattern docs** — only `plugin-structure.md`'s
  `tests/` block is in scope.
- **No CI optimizations beyond the minimum needed** — no caching,
  no artifact uploads, no parallel-shard fanout deeper than one job
  per concern file.
- **No new conventions beyond the swap.** "Test file per framework
  concept" replaces "Smoke test per sprint" and the timeout-600
  rule retires; no other rules added.

## Technical Decisions

- **CI matrix shape: enumerated, not auto-discovered.** Use
  `strategy.matrix.test: [<paths>]` listing each
  `tests/*.test.sh`. Trade-off vs.
  `find tests -name '*.test.sh'`: enumeration gives clearer logs
  and per-job retries; adding a new concept file requires updating
  the matrix line — a deliberate signal, not a chore.
- **Prep job stays.** Bash-4 check, JSON validity, SKILL.md
  frontmatter, and `bash -n` over all shell scripts are
  framework-wide invariants worth fast-failing before the matrix
  fans out. Partial overlap with `tests/plugin-distribution.test.sh`
  and `tests/skills-surface.test.sh` is acceptable redundancy — CI
  pre-checks catch the classes early; the test files own the
  concept-level assertions.
- **Conventions update is a 1:1 swap.** "Smoke test per sprint" →
  "Test file per framework concept". Surrounding "Implementation
  Plan Conventions" header stays.
- **Pattern doc edit is bounded by `<!-- vibeflow:auto:start/end -->`
  markers** — only the `tests/` block inside the diagram changes.
  The manifesto-component → artifact mapping table is unchanged
  (sprint references in that table are about sprints as historical
  fact, not as test-suite shape).

## Applicable Patterns

- `patterns/plugin-structure.md` — itself the target of the update.
- `conventions.md` — itself the target of the update.

## Risks

- **CI regression.** A misconfigured matrix fails every PR.
  Mitigation: implement on a feature branch, push, observe; tune
  until green; merge only after CI is green.
- **Sequence anxiety.** Bulk-delete + CI rewrite must land in the
  same commit (or PR) — otherwise `main` is broken between commits.
  Mitigation: implement as a single PR; the implementer batches
  commits under one merge.
- **Downstream specs that reference `.vibeflow/conventions.md`.**
  Future `/vibeflow:gen-spec` runs read the conventions file; the
  swap changes the wording but not the spirit. Mitigation: the new
  wording is explicit and prescriptive, so future specs stay
  unaffected.
- **`grep` craftsmanship gate** may report hits inside
  `.vibeflow/specs/framework-tests-rewrite-part-*.md` (this spec
  series). Mitigation: the gate's grep paths exclude
  `.vibeflow/specs/`.

## Dependencies

- `.vibeflow/specs/framework-tests-rewrite-part-1.md`
- `.vibeflow/specs/framework-tests-rewrite-part-2.md`
- `.vibeflow/specs/framework-tests-rewrite-part-3.md`
- `.vibeflow/specs/framework-tests-rewrite-part-4.md`
- `.vibeflow/specs/framework-tests-rewrite-part-5.md`
