---
name: drift-sense
description: >
  Phase 6 — continuous drift sensing across codebase, canonical memory,
  and historical traces. Three modes (--target codebase | canonical-memory
  | traces). Findings emitted as structured YAML; deprecation propositions
  go through Model C (typically medium-impact). Runs manually or via the
  scheduled GitHub Actions workflow at `.github/workflows/yoke-drift-sense.yml`.
argument-hint: "--target <codebase|canonical-memory|traces|all>"
allowed-tools: Read, Write, Bash, Grep, Glob
---

# /yoke:drift-sense — Phase 6 (continuous drift sensing)

Phase 6 is the continuous, out-of-lifecycle observation layer. Per
`.vibeflow/patterns/phase-flow.md`, it operates on three targets and
emits structured findings that the Orchestrator (Canonizer mode) can
turn into deprecation propositions via Model C.

## Modes

### `--target codebase`

Detects dead code, drift from canonical memory, and pattern decay in the
**host project** (not the plugin). Delegates to language-appropriate
tools discovered from the host's `CLAUDE.md` per the same convention
`/yoke:acceptance-contract` uses for sensor discovery (see Sprint 3).

Process:
1. Parse the host `CLAUDE.md` for sections like `## Dead code`, `## Linting`, `## Build`.
2. For each declared command, run it (with timeout) and capture output.
3. Emit findings keyed by file path + finding kind.

If no detector is declared, return a structured `notes:` entry with a
recommendation: "no dead-code detector configured in CLAUDE.md".

### `--target canonical-memory`

Reads the canonical-memory repo via the cached path
(`~/.cache/yoke/canonical/<slug>/`) and applies pure-metadata heuristics
(no LLM judgment) via `lib/canonical-memory/staleness-check.sh`:

- **Staleness:** items not consulted for > N days (default 30; configurable
  via `.yoke/config.yaml` `overrides.drift_sense.staleness_max_days`).
  Source for "consulted" is the entry's `last_validated` frontmatter
  field. (The per-task query-trace source was retired in
  ask-source-agnostic-read Part 1 — `/yoke:ask` no longer emits a trace.)
- **Model drift:** items with `model_calibrated_against` ≠ the configured
  current model (env `YOKE_MODEL_ID` or default `claude-opus-4-7`).
- **Contradictions:** items with `contradicts_with` referring to entries
  that exist in the current canonical memory.

### `--target traces`

Globs `.yoke/contracts/*.md` from completed tasks (those merged to main
of the host project — every task with files in this versioned archive
folder) and detects recurring patterns that never reached canonization.
Invokes `lib/canonical-memory/trace-analyzer.sh`. (The
`.yoke/query-traces/*.md` source was retired in
ask-source-agnostic-read Part 1; the mode now relies on contracts
alone.)

- Counts occurrences of each contract `topic:` across tasks.
- Flags topics that recur ≥ N times (default 3) but have no
  corresponding canonical-memory entry.

This signals that the canonization criteria are too conservative or
the observation scope is too narrow — feedback for the Orchestrator's
threshold calibration.

### `--target all`

Convenience: runs all three modes in sequence. The GitHub Actions
workflow uses this.

## Process

### 1. Pre-flight

- Verify `.yoke/config.yaml` exists (warn if not — proceed in standalone mode without overrides).
- Determine target mode from `--target` flag. Default: `all`.
- Print mode declaration:
  `[orchestrator:canonizer drift-sense] target=<mode>` (drift sensing is
  a Canonizer-mode invocation per `skills/orchestrator/SKILL.md`).

### 2. Run the appropriate detector

- **codebase** → invoke each detector command discovered from host `CLAUDE.md`; capture structured output.
- **canonical-memory** → invoke `lib/canonical-memory/staleness-check.sh`.
- **traces** → invoke `lib/canonical-memory/trace-analyzer.sh`.
- **all** → run all three above in order.

### 3. Emit findings

Output is structured YAML to stdout:

```yaml
findings:
  - target: codebase | canonical-memory | traces
    kind: dead-code | stale | model-drift | contradiction | uncanonized-recurrence
    severity: low | medium | high
    location: <file path or canonical entry path>
    excerpt: "<short evidence>"
    suggestion: "<actionable recommendation>"
notes:
  - "<context>"
```

False-positive rate target: < 20 % on the synthetic-injection smoke test
(per Sprint-7 DoD #7). When in doubt, prefer fewer findings — drift
sensing should be a high-signal channel, not a noisy one.

### 4. Output handoff

- **Manual invocation** → findings printed to stdout; user reviews.
- **Scheduled invocation** (via GitHub Actions) → findings posted to a
  GitHub issue (one issue per workflow run, idempotent: only opens a
  new issue if findings differ from the last run).
- **Drift-sense findings can become canonization propositions** —
  typically `medium`-impact deprecation entries. They go through Model
  C exactly like any other write (no auto-merging of drift-sense
  propositions in v0.7.0; see anti-scope).

## Pre-conditions

- `.yoke/config.yaml` exists (recommended; standalone mode possible).
- For canonical-memory mode: `canonical_memory.url` is configured.
- For traces mode: at least one completed task has emitted
  `.yoke/contracts/<slug>.md`. (`.yoke/query-traces/<slug>.md` retired
  in ask-source-agnostic-read Part 1.)
- For codebase mode: host `CLAUDE.md` declares a detector under
  `## Dead code`, `## Linting`, or `## Build`.

## Output contract

- Exit 0 with structured findings (zero or more).
- Exit non-zero only on missing pre-conditions or hard tool failures.

## Anti-patterns

- Do NOT auto-merge drift-sense propositions. They follow Model C just
  like any other canonization PR.
- Do NOT use LLM judgment for staleness or contradiction detection in
  v0.7.0. Pure metadata math only — keeps findings cheap and predictable.
- Do NOT analyze working memory of in-flight tasks (only completed,
  merged-to-main tasks count for trace mode).
- Do NOT flood the issue tracker. The workflow is idempotent: only
  opens a new issue if findings differ from the last run.

## See also

- `.vibeflow/patterns/phase-flow.md` (Phase 6 section).
- `.vibeflow/patterns/model-c-governance.md` — deprecation propositions.
- `.vibeflow/patterns/sensors.md` — structured findings.
- `.vibeflow/patterns/memory-model.md` — frontmatter metadata.
- `lib/canonical-memory/staleness-check.sh`.
- `lib/canonical-memory/trace-analyzer.sh`.
- `.github/workflows/yoke-drift-sense.yml`.
- `docs/scheduling-strategy.md`.
