---
name: canonize
description: >
  Phase 5 — Canonization. Orchestrator skill in canonizer mode. Reads
  working memory after a successful task, applies the five canonization
  criteria, and proposes writes to canonical memory via PRs (Model C).
  v0.5.0 ships only the low-impact path (auto-merge after CI checks);
  medium/high-impact paths ship in Sprint 6.
argument-hint: ""
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# /yoke:canonize — Phase 5 (Canonization, low-impact)

Take a completed task's working memory and propose canonical-memory
writes that pass the five-criterion cascade.

> **Lineage.** The canonical-memory operations under
> `lib/canonical-memory/` are forked one-time at the start of Sprint 5
> from [iurykrieger/claude-bedrock](https://github.com/iurykrieger/claude-bedrock).
> Yoke layers the five-criteria filter and Model C impact classes on
> top of Bedrock's read/write/graph primitives. The Orchestrator skill
> itself is Yoke-native (not in upstream Bedrock). Per-script lineage
> recorded in `docs/lineage.md` at Sprint 8.

## Process

### 1. Pre-flight

- Verify `.yoke/config.yaml` exists with a populated
  `canonical_memory.url`.
- Verify the task is complete: `.yoke/progress.md` exists AND the most
  recent verify-acceptance snapshot
  (`.yoke/.snapshots/cycle-<latest>.yaml`) shows every criterion at
  `status: pass`. Abort otherwise: "Task not complete; run
  `/yoke:implement` to convergence first."
- Print Orchestrator mode declaration:
  `[orchestrator:canonizer] candidates=…`.

### 2. Apply canonization criteria

Invoke `lib/canonical-memory/canonization-criteria.sh`:

- Reads `.yoke/progress.md`, `.yoke/contracts.md`, `.yoke/query-trace.md`.
- Reads thresholds from `.yoke/config.yaml`:
  - `canonization.repeatability_min` (default 3)
  - `canonization.generality_min` (default 2)
  - `canonization.stability_min_days` (default 14)
- Emits a structured YAML candidate list (criterion 5 — non-contradiction
  — already filtered out).

### 3. Filter to low-impact

In v0.5.0, only candidates with `impact: low` are eligible for
auto-application. Medium / high / regulatory candidates are listed in
the output but **not** opened as PRs (Sprint 6 ships those paths).
Print:

> "v0.5.0 ships only the low-impact path. <count> medium/high candidates
> deferred to Sprint 6."

### 4. Open PRs

For each low-impact candidate, invoke
`lib/canonical-memory/propose-write.sh --candidate <yaml-fragment-file>`:

- Creates a new branch on the canonical-memory repo (slug derived from
  candidate `id`).
- Writes the entry to `<content_path>` with the mandatory frontmatter
  (`ratified_at`, `model_calibrated_against`, `last_validated`,
  `traceability`, `impact_level`).
- Opens a PR with labels `yoke-proposal` and `impact-low`.
- Configures auto-merge after CI checks (does NOT force-merge).
- Returns the PR URL.

### 5. Output

Print one line per candidate processed:

```
[low]   c1 → PR <url>          (auto-merge after CI)
[low]   c2 → SKIP (failed criterion 5 — contradicted Acceptance Contract)
[med]   c3 → DEFERRED (Sprint 6)
[high]  c4 → DEFERRED (Sprint 6)
```

If no candidates: "No candidates passed the canonization criteria.
Working memory traces preserved for future sprints."

## Pre-conditions

- `.yoke/config.yaml` exists with `canonical_memory.url` set.
- Task is complete: every Acceptance Contract criterion passes in the
  latest snapshot.
- `gh` CLI authenticated (verified by `propose-write.sh`).

## Output contract

- Exit 0 with PR URLs for any low-impact candidates that were opened.
- Exit non-zero on missing pre-conditions, `gh` failure, or critical
  errors in the criteria script.

## Anti-patterns

- Do NOT skip the canonization criteria — every candidate must pass
  1–4 and be non-contradicting (5).
- Do NOT auto-apply medium/high/regulatory candidates in v0.5.0.
- Do NOT canonize against the production canonical-memory repo in tests
  — use a test substrate or `--dry-run`.
- Do NOT canonize without traceability — every candidate cites at
  least one working-memory file.

## See also

- `.vibeflow/patterns/model-c-governance.md` — low-impact path.
- `.vibeflow/patterns/memory-model.md` — canonical-memory frontmatter.
- `skills/orchestrator/SKILL.md` — canonizer mode declaration.
- `lib/canonical-memory/canonization-criteria.sh`.
- `lib/canonical-memory/propose-write.sh`.
- `templates/canonical-entry-frontmatter.yaml`.
