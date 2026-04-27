---
name: status
description: >
  Reports the current task's phase + working-memory presence and the
  active canonical memory's health. Read-only — never modifies state.
  Absorbs bedrock's /healthcheck surface (graphify-out integrity,
  orphan entities, dangling content, old content >15 days) into a
  single skill. Safe to run at any frequency.
argument-hint: "[--working-memory | --canonical | --all] [--memory <name>]"
allowed-tools: Read, Bash, Glob, Grep
---

# /yoke:status — current task state + canonical-memory healthcheck

> **v1.2 refresh (Part 6 of the bedrock canonical-memory port).**
> `/yoke:status` now subsumes bedrock's `/healthcheck`. They are the
> same skill. The `--canonical` scope produces bedrock's 5-check
> diagnostic surface for the registered active memory.
>
> Lineage: working-memory contract is Yoke-original (v0.6.0); the
> canonical-memory healthcheck section is copied from bedrock 1.2.1
> `/healthcheck` with kebab-case Yoke renames.

## Scopes

The skill takes one optional scope flag. Default is `--all`.

| Flag | What it reports |
| :--- | :--- |
| `--working-memory` | Active task slug, phase reached, runtime counters, drift findings |
| `--canonical` | Active memory's health (the 5 healthcheck checks below) |
| `--all` *(default)* | Both sections, separated by a horizontal rule |

`--memory <name>` selects which canonical memory to report on (passed
through to Part 1's `resolve-memory.sh`). Without `--memory`, the
default-marked memory is used (or CWD detection if invoked from
inside a registered memory).

## Read-only contract

This skill **never** modifies any file under `.yoke/` or under any
registered canonical memory. It only reads, globs, and greps. Smoke
tests assert the read-only invariant.

## Section 1 — Working memory (`--working-memory` / `--all`)

Source `lib/working-memory/paths.sh`.

### 1.1 Active task

1. Read the active slug via `wm_active_slug`.
2. If `.yoke/.current` is missing, print `no active task` and skip
   to Section 2 (this is not an error — the host may simply not have
   a task in flight).

### 1.2 Phase reached

For the active slug, check which archive categories contain
`<slug>.md`:

- `prds/<slug>.md` exists → at least Phase 1 reached.
- `specs/<slug>.md` plus at least one `tasks/<slug>-s*-t*.md` → Phase 2.
- `acceptance-contracts/<slug>.md` → Phase 3.
- `contracts/<slug>.md` → Phase 4 has run.
- a canonization marker (Sprint 8 wiring) → complete.

Report the most-advanced phase as a single label.

### 1.3 Runtime state

If `.yoke/runtime/` exists, report:

- `cycle counter` (from `.yoke/runtime/.cycle-counter`).
- Latest snapshot file (from `.yoke/runtime/.snapshots/cycle-N.yaml`).
- Hard-bound progress (cycles consumed vs cap, when configured).

### 1.4 Drift findings (Sprint 7+)

If a Phase-6 drift-sense run has emitted findings under
`.yoke/runtime/drift-*`, print the latest run's summary.

### 1.5 `--all` invocation

When invoked with `--all` and the host has multiple archived slugs:

```bash
wm_list_archived_slugs | while read -r slug; do
  echo "<slug> <phase-label>"
done
```

The phase label is the most-advanced category present for that slug.

## Section 2 — Canonical memory health (`--canonical` / `--all`)

Resolve the active memory:

```bash
source <plugin_dir>/lib/canonical-memory/resolve-memory.sh
yoke_resolve_memory --memory "$EXPLICIT_NAME"
```

If no memory is registered, print
`> [!info] No canonical memory registered.` and skip to the next
section. This is not an error.

When a memory resolves, run the 5 read-only checks below against
`$YOKE_MEMORY_PATH`.

### 2.1 Setup verification

Verify the memory is structurally complete:

- `.yoke-memory/config.json` exists and parses as JSON.
- All 8 entity directories exist
  (`actors/ people/ teams/ concepts/ topics/ discussions/ projects/ fleeting/`).
- Each entity directory contains `_template.md`.

Report `OK` per item or list the missing pieces.

### 2.2 Graphify-out integrity

Check `<memory>/graphify-out/`:

- If absent, report `n/a — graphify not configured for this memory`.
- If present, report `graph.json` size + node/edge count and
  `obsidian/*.md` count.
- Flag `stale: true` in `.graphify_analysis.json` if present.

### 2.3 Orphan entities

For each entity file in `<memory>/{actors,people,...}/<file>.md`:

- Parse wikilinks from frontmatter and body.
- Cross-check that every wikilink resolves to an existing file in the
  same memory.

Report orphans (wikilinks that don't resolve) — typically caused by
typos, deletions, or yet-unprocessed `/teach` runs.

### 2.4 Dangling content

For each entity file:

- Verify mandatory frontmatter (`type`, `name`/`title`, `updated_at`,
  `updated_by`, plus the 5 Yoke rippability fields:
  `ratified_at`, `model_calibrated_against`, `last_validated`,
  `traceability`, `impact_level`).
- Flag entries missing any of the 5 rippability fields — these are
  pruning candidates per `concepts/yoke-conventions` "Minimalist
  canonical memory with mandatory traceability".

### 2.5 Stale content (rippability)

- For each entity, compute `today − last_validated`.
- Flag entities older than 15 days.
- Compare `model_calibrated_against` to the current model
  (`claude-opus-4-7` in 2026-04). Flag entries calibrated against
  retired models — they are candidates for `/yoke:compress` or a
  rippability re-run.

This subsection replaces the standalone
`lib/canonical-memory/staleness-check.sh` library. Part 6 retired
that file; its rippability re-validation logic now lives here.

## Output shape

```
## Yoke status

### Working memory
- active task: <slug-or-none>
- phase: <prd-only | tech-spec | acceptance-contract | contracts | complete>
- runtime: <cycles N/M, latest snapshot path>
- drift: <findings or "no recent run">

---

### Canonical memory: <name> @ <path>
- setup: <OK | missing X, Y>
- graphify: <n/a | <stats>>
- orphans: <none | N entities — list>
- dangling: <none | N entities missing rippability — list>
- stale: <none | N entities older than 15 days — list>
```

Sections that pass with no findings collapse to a single `OK` line
to keep `--all` output readable.

## Critical rules

| # | Rule |
|---|---|
| 1 | NEVER modify any file under `.yoke/` or under any registered canonical memory |
| 2 | NEVER invoke another skill (e.g., never call `/yoke:preserve`, `/yoke:teach`, or `/yoke:compress` from here) |
| 3 | NEVER spawn subagents — read-only diagnostic |
| 4 | ALWAYS resolve the active memory through Part 1's `resolve-memory.sh` |
| 5 | Cap entity reads at 1k entities per memory — beyond that, sample uniformly and report sampling rate |
| 6 | Safe to run at any frequency — no rate-limiting needed |

## Anti-patterns

- Auto-fixing detected issues — that's `/yoke:compress`'s job.
- Writing the report to a file inside the memory — output to stdout
  only.
- Failing on missing `.yoke/.current` — degrade to "no active task"
  and continue.
- Claiming a section as `OK` without actually running its checks.

## See also

- `concepts/yoke-pattern-memory-model` — read-only role.
- `concepts/yoke-pattern-phase-flow` — phase labels.
- `lib/working-memory/paths.sh` — working-memory paths.
- `lib/canonical-memory/resolve-memory.sh` — memory resolution.
- `skills/compress/SKILL.md` — alignment maintenance (the skill that
  *fixes* the issues `/yoke:status` reports).
