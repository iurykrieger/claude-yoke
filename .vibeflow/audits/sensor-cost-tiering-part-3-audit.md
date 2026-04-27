# Audit Report: sensor-cost-tiering — Part 3 (Hook tier filter)

> Audited on 2026-04-27
> Spec: `.vibeflow/specs/sensor-cost-tiering-part-3.md`
> Source PRD: `.vibeflow/prds/sensor-cost-tiering.md`
> Depends on: Parts 1 (PASS) and 2 (PASS)

**Verdict: PASS**

## Test execution

- Commands: `bash tests/sensor-tiering.test.sh`; `bash tests/run-all.sh`.
- Result: **PASS** — 60/60 assertions in `sensor-tiering.test.sh`
  (24 new in (g)+(h) for hook tier filtering / format detection /
  old-format rejection); **19/19 test files PASS** in the full suite
  (zero regressions in `acceptance-and-sensors`, `perf-quickwins-part-*`,
  or any other consumer of `verify-acceptance.sh`).

## DoD Checklist

- [x] **DoD 1 — `--tier` parsed alongside `--criterion`.**
  Argparse extended; both flags parseable in any order, both can be
  combined.
  *Evidence:* `hooks/verify-acceptance.sh` argparse block; tests
  "(g) --tier cheap + --criterion Scenario 1 intersected to 2 sensors"
  + "(g) intersection includes the right sensors" — PASS.

- [x] **DoD 2 — Tier resolved per sensor from sensor files.**
  New-format path reads `command`, `class`, `tier` from
  `.yoke/sensors/<id>.md` frontmatter and applies the class-based
  default (`computational` → `cheap`, `inferential` → `expensive`)
  when `tier:` is absent. Computed at pair-build time and stored in
  `sensor_tier[<id>]` for the filter step.
  *Evidence:* tests "(g) --tier cheap excludes inferential sensor
  judge-voice" (inferential→expensive default) and "(g) --tier
  expensive includes inferential + overridden-expensive sensors" —
  PASS.

- [x] **DoD 3 — Default behavior preserved.** No `--tier` flag →
  `filter_tier="all"` → no filter step → identical to current full-
  suite behavior. Old-format contracts continue to work end-to-end:
  the format-detection branch in
  `hooks/verify-acceptance.sh` falls back to the existing
  inline-bullet parser when `## Sensors registry` is absent.
  *Evidence:* "(g) default (no --tier) ran all 4 sensors" + "(h)
  old-format contract works with no --tier (backward compat)" —
  PASS; `acceptance-and-sensors.test.sh` and
  `perf-quickwins-part-*.test.sh` (which use old-format contracts)
  continue to PASS in the full suite.

- [x] **DoD 4 — `--tier cheap` and `--tier expensive` filter.**
  Verified via tier-override scenario: `playwright-e2e` is
  computational but the fixture sets `tier: expensive` explicitly;
  it's correctly excluded from `--tier cheap` and included in
  `--tier expensive`.
  *Evidence:* "(g) --tier cheap excludes overridden-expensive
  playwright-e2e" + "(g) --tier expensive includes inferential +
  overridden-expensive sensors" — PASS.

- [x] **DoD 5 — Combined filters intersect.** `--tier` and
  `--criterion` are independent narrowing filters; both apply to
  the same `sensor_pairs` list. Empty intersection produces 0
  sensor entries with exit 0.
  *Evidence:* "(g) --tier cheap + --criterion Scenario 1 intersected
  to 2 sensors", "(g) empty intersection produces 0 sensor entries",
  "(g) empty intersection exits 0" — PASS.

- [x] **DoD 6 — Unknown `--tier` value → exit 2 + structured
  violation.** Argparse-level rejection with `expected: cheap |
  expensive | all` and a corrective re-run instruction on stderr
  before any sensor execution.
  *Evidence:* "(g) unknown --tier value exits 2" + "(g) unknown
  --tier emits structured violation with allowed set" — PASS.

- [x] **DoD 7 — Missing / malformed sensor file under tier filter
  → exit 4 + structured violation.** When tier filtering is active
  (`filter_tier != all`), a referenced sensor with a missing or
  malformed `.yoke/sensors/<id>.md` triggers a structured violation
  emitting `expected/actual/correction` and exits 4. The correction
  names `/yoke:ack-sensors --mode upsert` verbatim.
  *Evidence:* "(g) missing sensor file under --tier exits 4" +
  "(g) missing-sensor violation names the offending id" + "(g)
  missing-sensor violation suggests upsert correction" — PASS.

- [x] **DoD 8 — Test coverage.** 24 new assertions in `(g)` (hook
  tier filter) and `(h)` (old-format rejection) covering: 4
  sensor-files-present preconditions, default vs `--tier all`
  equivalence, cheap-tier filtering (3 assertions), expensive-tier
  filtering (2 assertions), intersection (2 assertions), empty
  intersection (2 assertions), unknown-value error (2 assertions),
  missing-file error (3 assertions), old-format default OK (1),
  old-format tier rejection (3 assertions). All PASS.

- [x] **DoD 9 — Craftsmanship.** Per-sensor YAML output schema
  unchanged; only the *set* of sensors run varies. Bash 4+ idioms
  throughout (`declare -A` for the tier map, `[[ ... ]]` patterns,
  `case` statements). No new external dependencies. Back-pressure
  observed on every error path (loud, structured failures with
  expected/actual/correction).

## Pattern Compliance

- [x] **`patterns/sensors.md`** — followed. The tier filter is
  layered on top of the existing parallel-execution model (xargs
  path untouched). Structured-output rule applied to every error
  path. Per-sensor YAML schema preserved.

- [x] **`patterns/ralph-loop.md`** — followed. Cycle-protocol
  invariants preserved: deterministic node, structured per-cycle
  output, hard-bound timing characteristics unchanged.

- [x] **`conventions.md`** — followed. Bash 4+ throughout. Loud
  failure with structured violation on every error path. No
  generic sensor output. Bash-4 patterns (`declare -A`,
  `[[ regex ]]`) only.

## Convention Violations

None identified.

## Scope Discipline

Files changed: **2 / ≤ 4 budget**.

- `hooks/verify-acceptance.sh` (modified) — argparse `--tier`,
  contract-format detection, new-format sensor pair builder
  (reads sensor files), tier filter
- `tests/sensor-tiering.test.sh` (modified) — Part 3 assertions

Anti-scope respected: no timeout/concurrency model changes (xargs
parallel + serial paths are byte-for-byte unchanged); no per-sensor
YAML schema drift; no tier resolution caching across invocations
(each run re-reads); no retry/flake handling; no new flags beyond
`--tier`; no agent / coordinator / Validator changes.

### Architectural note: implicit dual-format support

The Part 3 spec's DoD 3 ("Default behavior preserved") combined with
the Part 1 contract-template change forced the hook to support both
contract formats simultaneously. Pure single-format adoption would
have broken every existing test using old-format contracts
(`acceptance-and-sensors.test.sh`, `perf-quickwins-part-*.test.sh`,
etc.). The implementation introduces a one-line format-detection
step (`grep -qE '^## Sensors registry'`) that selects the parser:

- **New format** → registry block + `Sensors: [<id>]` references
  + sensor-file lookup (full tier metadata available).
- **Old format** → existing inline-bullet parser (no tier metadata;
  `--tier cheap|expensive` is rejected with a structured violation
  pointing the user at `/yoke:ack-sensors --mode upsert`).

This dual-path approach is mentioned in the spec's "Default
behavior preserved" intent but not explicitly called out in the
Scope section; it's documented in the audit + the hook's header
comment for future readers.

## Architectural notes / pitfalls discovered

1. **Format-detection is grep-based.** The detector relies on a
   bare `## Sensors registry` heading match. If a future contract
   variant uses a different heading (e.g., `## Sensors-registry`),
   the hook will silently fall back to the old-format parser. Worth
   considering as a future hardening (regex tightening or schema
   validation).

2. **Sensor `command` parsing is awk-based.** The hook reads the
   sensor file's `command:` field with `awk -F': '`. If a sensor's
   command contains `: ` literally (e.g., `bash -c 'env: blah'`),
   the field-separator split will truncate the value. Mitigation
   not in scope for this part — current sensor commands are simple
   shell strings; revisit if a sensor with a `: `-bearing command
   surfaces.

3. **`acceptance-and-sensors.test.sh` runs before
   `sensor-tiering.test.sh` alphabetically.** Both create separate
   tmp dirs and both clean up via `trap EXIT`, so there is no
   interference. Worth noting that the suite's lexical ordering
   matters when tests share state (none do today).

## Gaps

None. Verdict is PASS.

## Next steps

Ready to ship Part 3. Proceed to Part 4 (Validator scheduling
reads sensor files):

```
/vibeflow:implement .vibeflow/specs/sensor-cost-tiering-part-4.md
```

Part 5 (coordinator + pattern doc) is the final part and depends on
Parts 1, 2, 3, and 4.
