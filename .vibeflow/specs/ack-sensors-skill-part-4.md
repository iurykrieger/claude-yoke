# Spec: Additional sensor discoverers — `package.json`, `Makefile`, `pyproject.toml` (Part 4 of 4)

> Generated via /vibeflow:gen-spec on 2026-04-25 from `.vibeflow/prds/ack-sensors-skill.md`

## Dependencies

- `.vibeflow/specs/ack-sensors-skill-part-1.md` — the
  `/yoke:ack-sensors` skill must already exist; this part plugs
  three new discoverers into its catalog mode.

## Objective

Extend `/yoke:ack-sensors` catalog mode beyond `CLAUDE.md` so projects
that haven't curated a `## Testing` / `## Linting` / `## Build`
section in `CLAUDE.md` still get useful sensor discovery from
`package.json` `scripts`, `Makefile` targets, and `pyproject.toml`
`[tool.*]` sections.

## Context

Part 1 shipped catalog mode with only `CLAUDE.md` discovery. That's
sufficient for projects that follow Yoke's `CLAUDE.md` convention,
but most host projects have testing/linting/build commands buried in
`package.json` scripts or `Makefile` targets. Surfacing those gives
contract authors a richer catalog without requiring them to maintain
`CLAUDE.md` sections by hand.

## Definition of Done

1. New `lib/sensors/discover-from-package-json.sh` parses
   `package.json` `scripts` and emits sensors classified as
   `category: testing` (script names matching `test*`), `linting`
   (`lint*`, `eslint*`, `prettier*`), or `build` (`build*`,
   `compile*`, `bundle*`); other scripts are emitted as
   `category: other` so the human can review. Unknown JSON or
   missing file → `sensors: []` + explanatory `notes:`.
2. New `lib/sensors/discover-from-makefile.sh` parses top-level
   `Makefile` targets (lines matching `^[A-Za-z][A-Za-z0-9_-]*:`),
   classifies known names (`test`, `lint`, `check`, `build`,
   `compile`) into `testing` / `linting` / `build`, others into
   `other`. Skips `.PHONY:` declarations and rule bodies.
3. New `lib/sensors/discover-from-pyproject.sh` parses
   `pyproject.toml` and surfaces `[tool.pytest.ini_options]` →
   `category: testing` (with command `pytest`), `[tool.ruff]` /
   `[tool.flake8]` / `[tool.mypy]` → `category: linting`,
   `[tool.poetry.scripts]` / `[project.scripts]` →
   `category: other`. Best-effort: malformed TOML produces a
   `notes:` warning, never a non-zero exit.
4. `/yoke:ack-sensors --mode catalog` invokes all four discoverers
   (CLAUDE.md + the three new ones), unions their output,
   deduplicates by `(category, command)`, and emits the unified
   sorted YAML. Catalog output remains byte-identical across two
   consecutive invocations on the same project.
5. `tests/smoke/ack-sensors-discoverers.test.sh` exercises each
   discoverer in isolation against fixture files
   (`tests/fixtures/ack-sensors/with-package-json/`,
   `with-makefile/`, `with-pyproject/`), then exercises catalog
   mode against a fixture project that has all four sources
   simultaneously (asserting deduplication when CLAUDE.md and
   package.json declare the same `npm test` command).
6. **Quality gate (best-effort posture).** Each discoverer's failure
   modes (file missing, malformed content, no recognized targets)
   produce `sensors: []` + structured `notes:` block — never a
   non-zero exit, never silent output. Asserted by smoke-test
   golden-diff against three "broken" fixture files.
7. **Quality gate (no new dependencies).** Discoverers use only
   bash 4 + standard POSIX tools (`awk`, `grep`, `sed`). No
   `jq`, no Python, no external parsers. `package.json` parsing
   uses a minimal regex-based extractor for the `scripts` block
   only (we do not need full JSON parsing). `pyproject.toml`
   parsing is line-based (TOML's section headers are
   regex-friendly). Documented in each discoverer's header.

## Scope

- `lib/sensors/discover-from-package-json.sh` (new): regex-based
  `scripts` block extractor; classifier; YAML emitter. Mirrors the
  shape of `discover-from-claude-md.sh`.
- `lib/sensors/discover-from-makefile.sh` (new): awk-based target
  extractor; classifier; YAML emitter.
- `lib/sensors/discover-from-pyproject.sh` (new): line-based
  section-header detector; classifier; YAML emitter.
- `tests/smoke/ack-sensors-discoverers.test.sh` (new): per-discoverer
  fixture tests + integration test asserting catalog-mode union +
  dedup.
- Modify `skills/ack-sensors/SKILL.md` (Part 1's file): add the three
  new `bash lib/sensors/discover-from-*.sh` invocations to catalog
  mode, union their output, deduplicate.

(File count: 4 new + 1 modified = 5 file touches. **This exceeds
the ≤4 budget by one.** Mitigation: the modification to
`SKILL.md` is intentionally minimal — only the catalog-mode
function gains three lines of new shell-out plus a dedup awk
filter. If the audit flags this, split the modification into a
Part 4a/4b along discoverer-pair boundaries.)

## Anti-scope

- **No** classification heuristics beyond the simple name-prefix
  matching above. We do **not** parse Makefile rule bodies, do
  **not** introspect package.json `dependencies` to guess
  frameworks, do **not** evaluate pyproject.toml plugin sections
  beyond the named-tool list. Best-effort means literally what it
  says.
- **No** support for non-canonical package managers
  (`yarn workspaces`, `pnpm` script aliases beyond what shows up
  in `package.json` `scripts`, `bun` task runners). All three
  surface their commands through `package.json scripts` in
  practice.
- **No** support for `Makefile.include`, sub-makefiles, or
  recursive `make`. Top-level only.
- **No** support for Cargo, Go modules, Gradle, Maven, etc.
  Yoke's first three host-project ecosystems are JS/TS, Python,
  and shell — these three discoverers cover the bulk. Other
  ecosystems are explicit follow-ups.
- **No** modification of the readiness-mode contract — discoverers
  feed catalog mode only. Readiness still consumes the Acceptance
  Contract directly (Part 1's behavior).
- **No** automatic CLAUDE.md generation from discovered sources —
  the catalog suggests, the human curates.

## Technical Decisions

### Regex-based parsing instead of full grammar
JSON / Makefile / TOML all have well-known full parsers, but adding
`jq` / `awk -e` / `python3 -c` would create runtime dependencies
that break the bash-4-only constraint. Each discoverer extracts the
narrow slice it needs (a single block / target list / section list)
with regex — fragile under exotic inputs but predictable, fast,
and dependency-free.

**Trade-off:** edge cases exist (multi-line JSON values in
`scripts`, Makefile recipes with embedded `:` colons, TOML inline
tables). Each discoverer documents what it does NOT handle and
emits a `notes:` warning when it detects an unsupported shape.

### Best-effort, never blocking
Per the PRD: discoverers are additive and `CLAUDE.md` remains
authoritative. A broken `package.json` or unparseable `Makefile`
must not break catalog generation. Every discoverer exits 0 even
on malformed input, emitting `sensors: []` + `notes: [...]`.

### Deduplication by `(category, command)` pair
A project might declare `npm test` in both `CLAUDE.md` and
`package.json`. The skill dedupes on the exact `(category,
command)` tuple, keeping the first-seen `source` (CLAUDE.md wins
since it comes first in the discovery order). Asserted by the
smoke test.

### Discovery order: CLAUDE.md first, then alphabetical
`claude-md` → `makefile` → `package-json` → `pyproject` (stable,
documented). Dedup gives precedence to the first discoverer that
emits a tuple — making CLAUDE.md authoritative without needing
explicit precedence rules in the skill.

### Classification list is short and conservative
We only classify by exact prefix match against a hardcoded list
(testing: `test*`, `unit*`, `e2e*`; linting: `lint*`, `eslint*`,
`ruff*`, `mypy*`, `flake8*`, `prettier*`; build: `build*`,
`compile*`, `bundle*`). Anything else falls into `category: other`
— surfaced but unclassified. The contract author chooses.

## Applicable Patterns

- **`patterns/sensors.md`** — discoverers feed catalog mode but do
  not run sensors. Structured-output rule still applies: every
  emitted entry includes `category`, `command`, `source`.
- **`patterns/plugin-structure.md`** — `lib/sensors/discover-*.sh`
  naming convention extends what Part 1 reused; new files mirror
  `discover-from-claude-md.sh`'s shape.
- **Conventions: "Bash scripts target bash 4+"** — applies; no new
  external runtime dependencies.
- **Conventions: "Shift feedback left"** — surfacing
  package.json/Makefile/pyproject sensors at catalog time means
  contract authors see them during Trigger 3, before runtime
  discovers a missing binary.

## Risks

| Risk | Likelihood | Impact | Mitigation |
| :--- | :--- | :--- | :--- |
| Regex-based JSON parsing breaks on multi-line script values or escaped quotes | medium | medium | Discoverer documents what it does NOT handle; emits `notes:` when it detects a multi-line value and skips that script. Smoke-test fixture covers a multi-line script |
| `Makefile` parser confuses targets with rule bodies (lines containing `:` are common in commands) | medium | medium | Awk script anchors target detection to BOL + `^[A-Za-z]` prefix; smoke-test fixture includes a Makefile with `:` inside a rule body (e.g., `echo "key: value"`) |
| `pyproject.toml` parsing fragile under inline tables or array-of-tables | medium | low | Discoverer covers only top-level `[tool.X]` headers; inline tables are explicitly out of scope (`notes:` warning when detected). The pyproject convention is to use `[tool.X]` for our targeted tools, so this is well-bounded |
| Dedup logic drops a sensor that should be kept (different `category` for the same command) | low | medium | Dedup key is `(category, command)`, not `command` alone. Two entries with the same command but different categories are both kept |
| The classification heuristics misclassify project-specific naming (e.g., `npm run sanity` is a smoke test) | high | low | Misclassification falls into `category: other`, which the contract author reviews. The catalog is a suggestion, not a binding declaration |
| Spec exceeds 4-file budget by one; audit may flag and force a re-split | medium | low | Split on audit signal: Part 4a (one discoverer + skill update) and Part 4b (the remaining two discoverers). Documented in Scope's note |
