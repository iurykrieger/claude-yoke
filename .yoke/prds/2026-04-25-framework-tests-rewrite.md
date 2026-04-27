# PRD: Framework tests rewrite

> Generated via /vibeflow:discover on 2026-04-25

## Problem

Today's `tests/` folder is shaped by Yoke's construction history, not by
Yoke's framework surface. The bulk of the suite lives in
`tests/smoke/sprint-{2..8}.test.sh` — each file frames its assertions as
"what Sprint N delivered" and `sprint-8.test.sh` literally re-runs every
prior sprint as a "full audit gate". Two top-level files
(`plugin-install.test.sh`, `skills-format.test.sh`) are stubs that
`exit 0` with comments saying "real logic lands in Sprint 8".

The remaining files (`folder-isolation`, `ask-no-clone`,
`preserve-model-c`, `memory-migration`, `status-readonly`,
`teach-ingest`) are correctly feature-shaped, but they coexist with
sprint files that still own assertions about the same subsystems —
duplicate ownership and split coverage. Many assertions are framed as
release history ("v1.1 retired `skills/orchestrator/`", "Part 3
retired `query.sh`") instead of present-tense invariants.

The result: a contributor who has never seen Yoke before cannot navigate
`tests/` without learning the build history. CI
(`.github/workflows/ci.yml`) reflects the same shape — it enumerates
every `sprint-N.test.sh` by name, locking the gate to dev-time
structure. The convention in `.vibeflow/conventions.md` ("Every sprint
adds `tests/smoke/sprint-N.test.sh`") was right while v1.0 was being
built and is wrong now that the framework is shipped.

## Target Audience

- **Yoke contributors** changing framework behavior who need to find the
  right test file by feature name rather than by sprint chronology.
- **The CI gate** that runs on every PR to `iurykrieger/yoke` — must
  invoke a stable, feature-shaped layout instead of a sprint matrix.
- **Future maintainers** reading `tests/` cold to understand what Yoke
  guarantees as a framework.

## Proposed Solution

Wipe `tests/` entirely and rebuild from Yoke's current framework
surface. One test file per framework concern at the top level of
`tests/`. Each file asserts present-tense invariants — no references to
sprints, "v1.1", "Part N", or version-bump commentary in file names,
comments, or assertion messages. Shared boilerplate (`PLUGIN_ROOT`
discovery, `pass`/`err` helpers, exit handling) extracted into
`tests/lib/harness.sh`. CI workflow rewritten to match. The "Smoke test
per sprint" rule retired from `.vibeflow/conventions.md`.

## Success Criteria

- `tests/` contains zero references to sprint numbers, "Part N", or
  release-history commentary in file names, headers, or assertion
  messages (`grep -RIE 'sprint-[0-9]|Sprint [0-9]|Part [0-9]|v1\.[0-9]'
  tests/` returns nothing).
- Every test file's name maps 1:1 to a framework concept readable by
  someone who has never seen Yoke. A new contributor opens `tests/`,
  scans the file list, and can predict where to add an assertion for a
  given behavior.
- `.github/workflows/ci.yml` invokes the new layout and gates PRs
  identically to today (no behavior regression in CI strictness).
- Plugin still installs (`/plugin install iurykrieger/yoke`) and every
  command exercised today by the existing suite still has at least one
  assertion in the new suite, OR has been explicitly dropped with a
  reason recorded in the spec.
- `.vibeflow/conventions.md` "Smoke test per sprint" rule is removed
  and replaced with a "Test file per framework concept" rule.

## Scope v0

- Delete the entire current `tests/` tree (`tests/smoke/`, the two
  top-level stubs, `tests/fixtures/` only if obsolete).
- Create `tests/lib/harness.sh` with shared `pass`/`err`/`PLUGIN_ROOT`
  helpers + an optional external-`timeout` wrapper.
- Create one `tests/<concern>.test.sh` per framework concern. Initial
  proposed list (subject to one round of inspection-driven refinement
  during gen-spec):
  - `plugin-distribution.test.sh` — `.claude-plugin/{plugin,marketplace}.json`
    validity, version consistency, top-level repo layout matches
    `patterns/plugin-structure.md`.
  - `skills-surface.test.sh` — every `SKILL.md` has valid frontmatter
    (name, description, allowed-tools); spec-phase skills exclude
    `Task` from allowed-tools; persona is embedded inline in
    spec-phase skills; binding Trigger prompts present.
  - `agents-surface.test.sh` — `agents/` contains exactly the three
    runtime subagents (`generator.md`, `validator.md`,
    `orchestrator.md`); each declares its read/write authority and the
    Orchestrator is the sole canonical-memory writer.
  - `working-memory.test.sh` — `lib/working-memory/paths.sh` is the
    single path constructor; allowed `.yoke/` locations enforced via
    a simulated end-to-end flow; no flat-path leaks; `.gitignore` and
    `.current` formats exact.
  - `canonical-memory-read.test.sh` — `/yoke:ask` no-clone invariant
    (reflog stable across resolutions), source-agnostic read, no
    fabrication, 15-entity cap, registry + `resolve-memory.sh`
    present and side-effect-free.
  - `canonical-memory-write.test.sh` — `/yoke:preserve` is the single
    write entry point (no `propose-write.sh`, no `skills/canonize/`);
    Model C impact-class routing (low / medium / high / regulatory);
    high never auto-merges; regulatory routes via CODEOWNERS; five
    rippability fields enforced on create; no direct
    `git -C $MEMORY_PATH commit` outside `skills/preserve/`.
  - `bootstrap.test.sh` — `/yoke:bootstrap` scaffolds `.yoke/`
    correctly in a clean repo (config.yaml, .gitignore, folder
    layout) and registers a canonical-memory entry without touching
    its working tree.
  - `acceptance-and-sensors.test.sh` — `hooks/verify-acceptance.sh`
    runs against a fixture and emits structured output;
    `lib/sensors/discover-from-claude-md.sh` extracts sensors from
    CLAUDE.md sections.
  - `ralph-loop-bounds.test.sh` — `hooks/check-hard-bounds.sh`
    enforces N cycles / timeout / budget; `escalate.sh` exists and
    surfaces the divergence trigger.
  - `example-project.test.sh` — `examples/greenfield-payment-service/`
    artifacts present, statuses are approved/ratified, contract has
    BDD scenarios + functional requirements, sensors discoverable
    from its CLAUDE.md.
  - `docs-and-lineage.test.sh` — `docs/lineage.md` honesty + upstream
    URLs; `docs/troubleshooting.md` has phase sections;
    `docs/architecture.md` has Model C; `README.md` credits Vibeflow
    and Bedrock and links install + quickstart + architecture.
- Single `tests/run-all.sh` convenience runner that iterates
  `tests/*.test.sh` for local use.
- Rewrite `.github/workflows/ci.yml` to run each concern file as a
  matrix job (one job per `tests/*.test.sh`) so failures isolate
  cleanly per concern.
- Update `.vibeflow/conventions.md`: drop "Smoke test per sprint",
  add "Test file per framework concept".
- Drop the `timeout 600` external-wrapper rule from conventions —
  `hooks/check-hard-bounds.sh` ships now, so the pre-Sprint-6
  precaution is obsolete. Tests that exercise the loop still wrap
  with `timeout` defensively, but as an in-test detail, not a
  framework-wide rule.

## Anti-scope

- **No new test framework.** No Bats, ShellSpec, jest, etc. Plain
  bash 4 + `tests/lib/harness.sh`.
- **No subdirectories under `tests/`.** Only `tests/lib/` and
  `tests/fixtures/`. Each concern is one flat file.
- **No migration of sprint-shaped assertions.** Wipe-and-rebuild from
  the framework's current invariants. Whatever isn't worth re-asserting
  against today's surface is gone, full stop.
- **No release-history assertions.** No "v1.1 retires X", "Part 3
  removed Y", "Sprint 8 introduced Z". Either the invariant holds
  today or the assertion doesn't exist.
- **No new framework behavior tests for unimplemented features.** If
  Phase 6 drift sensing or any other capability is not yet wired up,
  this PRD does not commission new coverage for it — only re-shapes
  what exists.
- **No host-project end-to-end ralph loop runs in CI.** Real
  Implementation↔Validation cycles happen in user repos at runtime;
  this suite stays at the framework-surface level.
- **No version-bump-driven test updates.** Tests assert structural
  invariants, not "the manifest says X.Y.Z". Version consistency
  checks compare files to each other, not to a hard-coded literal.

## Technical Context

- **Conventions in scope to update.** `.vibeflow/conventions.md`
  currently says "Every sprint adds `tests/smoke/sprint-N.test.sh`"
  and "Smoke tests must complete in minutes and have an external
  timeout (`timeout 600 ...`) to guard against pre-Sprint-6 ralph
  loops without hard bounds." Both retire as part of this work —
  hard bounds ship now, sprint scaffolding is over.
- **CI surface.** `.github/workflows/ci.yml` enumerates every
  `sprint-N.test.sh` and wraps `sprint-4.test.sh` in `timeout 600`.
  The rewrite turns this into a matrix (one job per
  `tests/*.test.sh`) and drops the explicit `timeout 600` wrapper.
- **Existing feature smokes.** `folder-isolation`, `ask-no-clone`,
  `preserve-model-c`, `memory-migration`, `status-readonly`,
  `teach-ingest` are already feature-shaped. Their *content* is the
  best starting reference for what assertions to bring forward into
  the new layout — but per anti-scope, the new files are written
  fresh against today's framework surface, not copy-pasted.
- **Framework surface inventory** (for sizing the file list):
  - `skills/`: 14 skills (acceptance-contract, ask, bootstrap,
    compress, confluence-to-markdown, discover, drift-sense,
    gdoc-to-markdown, implement, memory, preserve, status, teach,
    tech-spec).
  - `agents/`: 3 runtime subagents (generator, orchestrator,
    validator).
  - `hooks/`: check-hard-bounds, post-iteration, pre-implementation,
    verify-acceptance.
  - `lib/`: canonical-memory, ralph-loop, sensors, working-memory.
  - `templates/`, `docs/`, `examples/greenfield-payment-service/`,
    `.claude-plugin/`.
- **Patterns governing test shape.**
  `.vibeflow/patterns/plugin-structure.md` is the source of truth for
  the directory layout that `plugin-distribution.test.sh` validates.
  `patterns/sensors.md` governs `acceptance-and-sensors.test.sh`.
  `patterns/ralph-loop.md` governs `ralph-loop-bounds.test.sh`.
  `patterns/memory-model.md` and `patterns/model-c-governance.md`
  govern the canonical-memory pair.
- **Bash target.** Bash 4+ per existing convention. `harness.sh`
  uses associative arrays where useful (bash 4 feature) and `set
  -euo pipefail` everywhere.

## Open Questions

- **Concern-file count refinement.** The proposed 11-file list is a
  starting point. During gen-spec, inspect each existing assertion
  in the current `tests/` suite once and decide:
  (a) which concern file it belongs in,
  (b) whether it's a present-tense invariant or release history (drop
      it if the latter).
  The final list may collapse two of the proposed files into one or
  split one into two — but the principle stays: one file per concept,
  no sprint shape.
- **Compress / teach / status / discover / tech-spec / drift-sense
  coverage.** Each is a distinct skill but several have no dedicated
  smoke today (only `teach-ingest` and `status-readonly` exist as
  feature smokes; `compress`, `discover`, `tech-spec`, `drift-sense`
  are covered, if at all, indirectly via `sprint-N.test.sh`). The
  rewrite must decide per skill: subsume into `skills-surface.test.sh`
  (frontmatter + allowed-tools level) or get a dedicated behavior
  file. Lean: `skills-surface.test.sh` covers the structural
  contract for all 14; behavior tests exist only where today's suite
  has substantive assertions worth preserving (ask, preserve,
  bootstrap, status, teach).
- **CI matrix vs. single job.** Lean is matrix (one job per
  `tests/*.test.sh`) for clean failure isolation, but the simpler
  single-job-runs-`run-all.sh` shape is also defensible. Decision
  deferred to the spec phase, where we can size the GH Actions
  parallelism cost against the readability win.
