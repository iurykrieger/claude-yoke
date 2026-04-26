# Audit Report: ack-sensors-skill-part-4

> Audited 2026-04-25 against `.vibeflow/specs/ack-sensors-skill-part-4.md`

**Verdict: PASS (over budget by 1 file — accepted per spec self-flag)**

## Test execution

Test runner: `bash tests/smoke/ack-sensors-discoverers.test.sh`
Result: **PASS** — exit 0, 0 failures.

The Part 4 smoke chains Parts 1, 2, 3 regression as final assertions
(all reported "still passes"). Effective coverage:

- Part 4 (discoverers + unified catalog): ~40 assertions
- Part 3 (inferential, regression): 54 assertions
- Part 2 (parallel, regression): 43 assertions
- Part 1 (catalog, regression): 28 assertions
- **Total: ~165 assertions, all green**

## Dependencies

- `ack-sensors-skill-part-1.md` — audit verdict: **PASS**

## Budget review

- Spec budget: ≤ 4 files. Implementation used 5 (4 new + 1 modified).
- The spec's Scope section explicitly anticipated this overrun and
  proposed a 4a/4b sub-split if the audit objected.
- The `lib/sensors/ack-sensors.sh` modification is intentionally
  minimal: extends catalog mode with three `bash <discoverer>` calls
  and adds an awk-based dedup pipeline. No structural changes to the
  readiness path, no new public surface.

**Audit decision:** **Accept the overrun.** A 4a/4b split would add
a fifth audit cycle and a sixth audit report for what is effectively
one cohesive feature (catalog extension to three host-project sources
+ dedup). The cost of the split exceeds the benefit. The architect's
own spec self-flag stands as documentation of the deviation.

## DoD Checklist

- [x] **DoD #1 — `discover-from-package-json.sh` parses `scripts`
  and classifies.**
  Evidence: smoke assertions classify `test` → testing, `lint` →
  linting, `build` → build, plus `dev` and `format` falling into
  `other`. Command form `npm run <script>` enforced. Source set to
  `package-json`. Missing/empty file → `sensors: []` + `notes:`.

- [x] **DoD #2 — `discover-from-makefile.sh` parses top-level
  targets, classifies, ignores rule bodies and `.PHONY`.**
  Evidence: 4 targets correctly extracted (`test`, `lint`, `build`,
  `deploy`); rule body `echo "key: value"` did not produce a fake
  `make echo` target; `.PHONY` excluded. BOL-anchored target
  detection works correctly.

- [x] **DoD #3 — `discover-from-pyproject.sh` recognizes `[tool.X]`
  sections.**
  Evidence: smoke maps `[tool.pytest.ini_options]` → `pytest`,
  `[tool.ruff]` → `ruff check`, `[tool.mypy]` → `mypy`. Sub-section
  `[tool.ruff.lint]` does NOT duplicate (only canonical
  `tool.ruff` emits). `[tool.poetry.scripts]` surfaces as
  `category: other`. Inline-table fixture (`tool.ruff = { ... }`)
  produces a `notes:` warning.

- [x] **DoD #4 — `/yoke:ack-sensors --mode catalog` invokes all
  four discoverers, unions, deduplicates by `(category, command)`,
  emits sorted YAML.**
  Evidence: smoke fixture has CLAUDE.md + package.json + Makefile +
  pyproject.toml. Output is byte-identical across consecutive
  invocations. Dedup verified: `npm run lint` (linting) appears
  once (CLAUDE.md wins over package-json — first-seen
  precedence). `pytest` (testing) appears once (CLAUDE.md wins
  over pyproject). Sort order respects `(category, source,
  command)`.

- [x] **DoD #5 — Smoke covers all four sources.**
  Evidence: per-discoverer fixtures
  (`tests/fixtures/...with-package-json/`, `with-makefile/`,
  `with-pyproject/` — implemented as inline temp dirs). Unified
  fixture exercises all four simultaneously; smoke asserts
  `source: claude-md`, `source: makefile`, `source: package-json`,
  `source: pyproject` all present in the unified output.

- [x] **DoD #6 — Best-effort posture.**
  Evidence: 4 broken/missing-input assertions, all return
  `sensors: []` plus structured `notes:` block without non-zero
  exit. Discoverers' headers document unsupported edge cases
  (multi-line JSON values, inline TOML tables).

- [x] **DoD #7 — No new external dependencies.**
  Evidence: smoke greps each new discoverer's body (excluding
  comments/shebang) for invocations of `jq`, `python`, `python3`,
  `node`, `ruby`, `perl`. None found across all three new scripts.
  Discoverers use only bash 4 + POSIX awk + standard sed/grep.

  *Note:* `hooks/verify-acceptance.sh` (touched in Part 3's
  out-of-scope robustness fix) does call `perl` in its timeout
  fallback path — but only when GNU `timeout` / `gtimeout` is not
  on `$PATH`. This is documented in the Part 3 audit and is not a
  new dependency for Part 4.

## Pattern Compliance

- [x] **`patterns/sensors.md` — structured-output preserved.**
  Each discoverer emits the canonical `category / command / source`
  triple per entry. The unified catalog preserves this shape after
  union + dedup. Notes are filtered to drop boilerplate "X not
  found" messages — actionable warnings (multi-line values,
  inline tables) still surface.

- [x] **`patterns/plugin-structure.md` — naming + location.**
  New discoverers follow the existing
  `lib/sensors/discover-from-<source>.sh` naming
  (`discover-from-claude-md.sh` was the precedent). Smoke test
  follows the `tests/smoke/<feature>.test.sh` convention.

- [x] **Conventions: "Bash scripts target bash 4+".**
  All three new discoverers use `set -euo pipefail`, `BASH_REMATCH`,
  `[[ ]]`, `declare -a`. No POSIX-only constraints; verified
  cleanly under bash 5.3 (macOS Homebrew).

- [x] **Conventions: "Shift feedback left".**
  Surfacing package.json / Makefile / pyproject sensors at catalog
  time means contract authors see them during Trigger 3 (before
  runtime), not after a missing-binary failure.

- [x] **Conventions: "Back-pressure: success is silent, failures
  are verbose".**
  Per-discoverer `notes:` block surfaces actual issues
  (multi-line, inline-table); boilerplate "file not found" notes
  are filtered out at the unified level (they're not actionable).

## Convention Violations
None detected.

## Notes — Auditor decisions during the cycle

### Notes filtering rule

The unified catalog filters out per-discoverer `<file> not found`
notes from the merged `notes:` output. Rationale: a host project
legitimately may not have a Makefile, package.json, or
pyproject.toml. Surfacing four "X not found" notes per invocation
would drown the actually-actionable warnings (multi-line values,
inline tables, malformed input) and would also break Part 1's
deterministic catalog assertion (which expected `notes: []` on a
CLAUDE.md-only project). The filter is implemented in
`lib/sensors/ack-sensors.sh::catalog_mode` and documented inline.

This is a behavior refinement, not an architectural decision. No
update to `.vibeflow/decisions.md` required.

### Smoke-test "external runtime" check refinement

The DoD #7 assertion initially flagged
`discover-from-package-json.sh` as referencing `jq` — false
positive on the prose comment "no `jq`, no Python" in the script
header. The smoke test was tightened to strip comments/shebang
before scanning for invocations. Pure tooling adjustment, no
implementation change.

## Files in this part

| File | Status | Lines (approx) |
| :--- | :--- | :---: |
| `lib/sensors/discover-from-package-json.sh` | created | 145 |
| `lib/sensors/discover-from-makefile.sh` | created | 95 |
| `lib/sensors/discover-from-pyproject.sh` | created | 130 |
| `lib/sensors/ack-sensors.sh` | modified | +50 / -10 |
| `tests/smoke/ack-sensors-discoverers.test.sh` | created | 270 |

Total: 5 files / ≤ 4 budget — overrun of 1 accepted (see Budget review).

## Next step

**Ready to ship.** All four parts of the `ack-sensors-skill` PRD are
audited PASS. The full feature stack:

- Part 1: `/yoke:ack-sensors` skill (catalog + readiness, CLAUDE.md only)
- Part 2: Validator parallel computational sensor execution
- Part 3: Inferential `semantic-judge` subagent
- Part 4: Additional discoverers (package.json, Makefile, pyproject.toml)

Suggested next actions:
- `/vibeflow:stats` to get an aggregate quality view across the four audits
- Open a PR with the worktree's commits if not already done
- Update `.vibeflow/index.md` Pattern Registry tags to include
  `parallel-spawn` and `inferential-template` if appropriate (left
  for the architect's discretion — outside the four specs' scope)
