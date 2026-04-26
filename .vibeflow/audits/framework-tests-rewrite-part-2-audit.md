# Audit Report: framework-tests-rewrite-part-2

> Audited 2026-04-25 against
> `.vibeflow/specs/framework-tests-rewrite-part-2.md`.

**Verdict: PASS**

## Test Run

- `bash tests/skills-surface.test.sh` → exit 0 (71/71 checks).
- `bash tests/agents-surface.test.sh` → exit 0 (7/7 checks).
- `bash tests/run-all.sh` → exit 0 (5/5 files; pre-existing stubs and
  Part 1 file all pass alongside the two new files).

## DoD Checklist

- [x] **DoD 1** — `tests/skills-surface.test.sh` lines 60–82 loop
  over `skills/*/SKILL.md` and assert frontmatter delimiters (≥2 `---`),
  presence of `name`, `description`, `allowed-tools` for every skill.
  14 skills × 4 checks = 56 PASS lines observed at run time.
- [x] **DoD 2** — Lines 89–110 cover the three spec-phase skills:
  Task exclusion (extracted via `fm_field_value` and grep), inline
  persona section (regex
  `Generator persona|Validator persona|Your role .*persona` matches
  "Your role (Product Manager persona, inline)" in `discover`,
  "(Senior Engineer persona, inline)" in `tech-spec`,
  "(Validator persona, inline)" in `acceptance-contract`), and the
  matching `Trigger 1/2/3` literal per skill.
- [x] **DoD 3** — Lines 119–151 cover `skills/ask/SKILL.md`:
  allowed-tools excludes `Task` and `Write` (file declares
  `Bash, Read, Glob, Grep`); regex `never .*(clone|pull|fetch)`
  matches the no-clone declaration; `never fabricate|do not
  fabricate|never invent` matches `**NEVER fabricate**`;
  `resolve-memory.sh` literal present; `15 entit|cap.*15` matches
  the 15-entity cap.
- [x] **DoD 4** — `tests/agents-surface.test.sh` covers all five
  required assertions:
  (a) exact-3 file count via `find agents -maxdepth 1 -name '*.md'`,
  (b) `generator.md`, `validator.md`, `orchestrator.md` presence,
  (c) `sole writer|only.*writer|...|write authority` matches
  "**sole writer**" in `agents/orchestrator.md`,
  (d) `structured.*JSON.*verdict|JSON.*verdict` matches "structured
  JSON verdicts" in `agents/validator.md`,
  (e) progress.md per-cycle regex matches "progress.md at the end of
  every cycle" in `agents/generator.md`.
- [x] **DoD 5** — Both files exit 0 against HEAD; verified via
  direct invocation and via `tests/run-all.sh`.
- [x] **DoD 6** — Craftsmanship gate
  `grep -EIn 'sprint-[0-9]|Sprint [0-9]|Part [0-9]|v[0-9]+\.[0-9]+'`
  on both files: GATE_PASS (no matches).
- [x] **DoD 7** — Both files pass `bash -n`. `shellcheck`
  unavailable on this host; spec wording ("if available") permits.

## Pattern Compliance

- [x] **`patterns/plugin-structure.md`** — followed correctly.
  - "agents/ contains exactly three files (runtime subagents only)"
    is asserted in `agents-surface.test.sh:18-22`.
  - The spec-phase persona-inline rule is asserted in
    `skills-surface.test.sh:99-104`.
- [x] **`patterns/roles.md` / `conventions.md` Don'ts** — write
  authority claims are asserted indirectly via the prose grep on
  `agents/orchestrator.md` (sole-write authority) and
  `skills/ask/SKILL.md` (no Task / no Write — pure read).
- [x] **`conventions.md`** — bash 4+ (associative array
  `declare -A trigger_map`, requires bash 4); `set -euo pipefail`
  inherited from `harness.sh`.

## Convention Violations

None.

## Gaps

None — all DoD checks pass.

## Notes

- The structural per-skill loop covers all 14 skills automatically;
  adding a new skill folder (with valid SKILL.md) extends coverage
  without test edits. Adding a new spec-phase skill, however,
  requires an explicit edit to the hardcoded list — that is by
  design per spec technical decisions.
- The `cmd && pass || err` reverse-logic pattern under
  `set -euo pipefail` is safe because tested-context suppresses
  `set -e`; this matches the existing convention used in the (still
  in place) `tests/smoke/sprint-N.test.sh` files.
- Pre-existing stubs and sprint smoke files remain in place per
  Part 2 anti-scope. Part 6 deletes them alongside the CI rewrite.

## Next Step

Ready to ship Part 2. Proceeding to
`/vibeflow:implement .vibeflow/specs/framework-tests-rewrite-part-3.md`.
