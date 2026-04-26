# Spec: Framework tests rewrite — Part 1 (foundation)

> Generated via /vibeflow:gen-spec on 2026-04-25 from
> .vibeflow/prds/framework-tests-rewrite.md

## Objective

Establish a reusable bash test harness, a local runner, and the first
concept-shaped test file (`tests/plugin-distribution.test.sh`) so
subsequent parts can plug new test files into a stable foundation.

## Context

`tests/` today is sprint-shaped. Wiping it in one shot would break CI
(`.github/workflows/ci.yml` enumerates every `sprint-N.test.sh` by
name). This part adds the new foundation **alongside** the existing
sprint files; the wipe + CI rewrite happens in Part 6, after Parts 2–5
populate the new layout. CI stays green throughout the rewrite.

`patterns/plugin-structure.md` is the source of truth for the
top-level repo layout this part validates.

## Definition of Done

1. `tests/lib/harness.sh` exposes `pass()`, `err()`, `PLUGIN_ROOT`
   (absolute path, resolved from `${BASH_SOURCE[0]}`), and a
   `harness::summary` function that prints `PASS` if `fail==0` else
   `FAIL ($fail check(s) failed)` and exits 0/1. Uses
   `set -euo pipefail`. Bash-4-compatible.
2. `tests/run-all.sh` iterates `tests/*.test.sh` (excluding
   `tests/lib/` and itself) in lexicographic order, runs each, prints
   each test's name + result, exits non-zero if any test failed.
3. `tests/plugin-distribution.test.sh` sources `harness.sh` and asserts:
   (a) `.claude-plugin/plugin.json` and
   `.claude-plugin/marketplace.json` parse as JSON; (b) the `version`
   field in `plugin.json` equals `marketplace.json.metadata.version`
   and `marketplace.json.plugins[0].version`; (c) the most recent
   `## [<version>]` heading in `CHANGELOG.md` matches that version;
   (d) every directory listed in the
   `tests/plugin-distribution.test.sh` directory-array (sourced from
   `patterns/plugin-structure.md` at write time) exists; (e) top-level
   files `README.md`, `LICENSE`, `CHANGELOG.md`, `CLAUDE.md` exist.
4. `bash tests/plugin-distribution.test.sh` exits 0 against HEAD.
5. **Craftsmanship gate.**
   `grep -EIn 'sprint-[0-9]|Sprint [0-9]|Part [0-9]|v[0-9]+\.[0-9]+'
   tests/lib/harness.sh tests/run-all.sh
   tests/plugin-distribution.test.sh` returns nothing.
6. All new shell files pass `bash -n` and (if available) `shellcheck`
   with no errors.

## Scope

- Create `tests/lib/harness.sh`.
- Create `tests/run-all.sh`.
- Create `tests/plugin-distribution.test.sh`.

## Anti-scope

- **No deletes.** `tests/smoke/`, `tests/plugin-install.test.sh`,
  `tests/skills-format.test.sh` stay until Part 6.
- **No CI changes.** CI keeps running the old sprint suite until
  Part 6.
- **No coverage of skills, agents, hooks, lib, docs, examples,
  working memory, or canonical memory** — those land in Parts 2–5.
- **No copy-paste from `sprint-N.test.sh`.** New files are written
  from the framework-surface inventory.
- **No version literals in tests.** Manifest version is read from
  `plugin.json` and compared cross-file.

## Technical Decisions

- **Bash 4 only, no extra deps.** Honors PRD anti-scope and
  `.vibeflow/conventions.md`. `python3 -c` is used for JSON parsing
  (already a CI dep).
- **`PLUGIN_ROOT` discovery.** `harness.sh` resolves it as
  `cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd`. Tests source
  `harness.sh` and use the variable.
- **Named summary over auto-trap.** Each test calls
  `harness::summary` at end-of-file. One extra line per test buys
  explicit control flow.
- **Directory list is hardcoded from the pattern.** Auto-discovery
  would couple the test to filesystem drift; the hardcoded array
  forces deliberate updates when the pattern doc changes.
- **`run-all.sh` lexicographic order.** No inter-test dependencies,
  but reproducible output.

## Applicable Patterns

- `patterns/plugin-structure.md` — directory list and top-level files
  validated by `plugin-distribution.test.sh`.
- `conventions.md` — bash 4+, `set -euo pipefail`.

This part is the first realization of a NEW pattern — **Test file
per framework concept** — formalized in Part 6's conventions update.

## Risks

- **Pattern doc drift.** `patterns/plugin-structure.md` lists `lib/`
  subdirs that may not all exist at HEAD; the test's hardcoded array
  reflects only directories that exist *and* are listed in the
  pattern. Adding a subdir requires explicit edit — that is a
  deliberate signal.
- **Silent rot between Parts 1–5.** The new file isn't gated by CI
  until Part 6. Mitigation: contributors run `bash tests/run-all.sh`
  locally; Part 6 switches CI atomically.

## Dependencies

None.
