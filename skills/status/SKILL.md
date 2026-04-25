---
name: status
description: >
  Reports the current task's phase, working-memory presence, and recent
  canonical-memory activity. Read-only — never modifies state. Placeholder
  in v0.1.0; full implementation lands in Sprint 8.
argument-hint: "[--all]"
allowed-tools: Read, Bash, Glob
---

# /yoke:status — current task state (placeholder)

Not yet implemented in v0.1.0. Implementation lands in Sprint 8 per
`.vibeflow/specs/yoke-v1-sprint-8.md`. The reporting shape was finalized
in v0.6.0 and is captured below so Sprint 8 can implement against it
directly.

## Planned behavior (v0.6.0 contract)

The skill operates against the v0.6.0 per-category-folder layout:
versioned archive at `.yoke/{prds,tech-specs,acceptance-contracts,contracts,query-traces}/<slug>.md`,
runtime state at `.yoke/runtime/`, active task pointer at
`.yoke/.current`. All paths resolve through
`lib/working-memory/paths.sh`.

### Default invocation (active task only)

1. Source `lib/working-memory/paths.sh`.
2. Read the active slug via `wm_active_slug`. If `.current` is missing,
   print `no active task` to stdout and exit 0 (not an error — the host
   may simply not have a task in flight).
3. For the active slug, report the most-advanced phase reached (see
   "Phase labels" below), the file paths of its archive artifacts, and
   any runtime state under `.yoke/runtime/` (cycle counter, latest
   snapshot).
4. If hard bounds are tracked (Sprint 6+), report cycles consumed vs cap.
5. If a Phase-6 drift-sense run has emitted findings (Sprint 7+),
   summarize the latest run.

### `--all` invocation

1. List every slug via `wm_list_archived_slugs` (one line per slug,
   chronological).
2. For each slug, annotate with the phase label drawn from the set:
   - `prd-only` — only `prds/<slug>.md` exists.
   - `tech-spec` — `tech-specs/<slug>.md` exists.
   - `acceptance-contract` — `acceptance-contracts/<slug>.md` exists.
   - `contracts` — `contracts/<slug>.md` exists (implementation produced
     sprint contracts; loop has run).
   - `complete` — `contracts/<slug>.md` exists AND a corresponding
     canonization marker exists (Sprint 5 ships canonization records;
     final criterion definition deferred to Sprint 5/8 wiring).

   Output one line per slug: `<slug> <phase-label>`.

The phase label is the most-advanced category present for that slug
(e.g., a slug that has PRD + tech-spec + AC files reports
`acceptance-contract`, not three separate lines).

### Read-only contract

The skill never modifies any file under `.yoke/`. It reads `.current`,
`config.yaml`, and globs the archive categories — nothing else.

See also: `.vibeflow/patterns/phase-flow.md`,
`lib/working-memory/paths.sh`.
