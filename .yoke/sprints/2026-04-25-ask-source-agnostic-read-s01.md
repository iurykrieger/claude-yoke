# Spec: `/yoke:ask` source-agnostic — Part 1 / Skill + working-memory lib

> Generated via /vibeflow:gen-spec on 2026-04-25
> PRD: `.vibeflow/prds/ask-source-agnostic-read.md`

## Objective

Make `/yoke:ask` invocable from any caller by deleting the active-task
pre-condition and the query-trace write at Phase 5.1 of `skills/ask/SKILL.md`,
and removing the working-memory helper that backed it.

## Context

`skills/ask/SKILL.md` aborts unless `.yoke/.current` exists, because Phase 5.1
writes a YAML trace entry whose path comes from `wm_active_slug()` →
`wm_query_trace_path()` in `lib/working-memory/paths.sh`. Memory resolution
itself (`lib/canonical-memory/resolve-memory.sh`) is already source-agnostic
and works without a task. The trace is the only blocker. This part removes
the trace contract from the skill and the lib; the doctrine, agent prompts,
tests, and docs follow in Parts 2–6.

## Definition of Done

1. `skills/ask/SKILL.md` no longer references `.yoke/.current`,
   `wm_active_slug`, `wm_query_trace_path`, `.yoke/query-traces/`, or any
   YAML trace shape; the pre-condition section that aborted on missing
   active task is removed; Phase 5 contains only response composition.
2. `skills/ask/SKILL.md` description (frontmatter) is rewritten to match
   the new contract: source-agnostic, registry-resolved, filesystem-only
   read, 15-entity cap, no trace.
3. `lib/working-memory/paths.sh` does not export `wm_query_trace_path`;
   `WM_ARCHIVE_CATEGORIES` does not contain `query-traces`.
4. `skills/ask/SKILL.md` preserves: 15-entity progressive-disclosure cap,
   no-clone / no-pull / no-fetch invariants, no-fabrication rule, memory
   resolution via `lib/canonical-memory/resolve-memory.sh`, and the
   bare-wikilink citation rule.
5. `skills/ask/SKILL.md` `allowed-tools` does not include `Task`
   (spec-phase / read skills must not spawn subagents per `patterns/roles.md`).

## Scope

- Edit `skills/ask/SKILL.md` — remove pre-condition and Phase 5.1 trace
  write; rewrite description; preserve invariants in DoD #4.
- Edit `lib/working-memory/paths.sh` — drop `wm_query_trace_path`; remove
  `query-traces` from `WM_ARCHIVE_CATEGORIES`; preserve every other helper
  and constant.

## Anti-scope

- Test changes (Part 3).
- Agent contract changes (Part 2).
- Doctrine doc changes (Part 4).
- User-facing doc changes (Parts 5–6).
- Changes to `lib/canonical-memory/resolve-memory.sh` or the memory
  registry shape.
- A backwards-compatibility shim for `wm_query_trace_path`. Any caller
  that breaks after this part is fixed in Parts 2–3, not preserved.
- Any new graphify or `/yoke:teach` escalation logic.

## Technical Decisions

1. **Helper removal vs deprecation.** Delete `wm_query_trace_path` outright.
   Trade-off: any internal caller still referencing it fails loudly at
   runtime. Justification: the project's anti-pattern policy forbids
   compatibility shims; loud failure is the correct signal.
2. **`WM_ARCHIVE_CATEGORIES` shrink.** Reduce to
   `(prds tech-specs acceptance-contracts contracts)`. Trade-off:
   `wm_slug_in_use` no longer detects collisions in the (removed)
   `query-traces` directory. Justification: that directory will not exist
   and must not be re-created by `wm_*` callers.
3. **SKILL.md description rewrite.** Replace "Read-only adaptive query …
   Writes a YAML trace entry to .yoke/query-traces/<slug>.md for bypass
   detection" with a description aligned with the PRD: source-agnostic,
   `lib/canonical-memory/resolve-memory.sh` resolution, filesystem-only,
   15-entity cap. Trade-off: the description gets shorter and loses the
   bypass-detection claim. Justification: that claim is no longer true.
4. **No new file output.** The skill writes nothing on disk after this
   part — pure read. Any future audit signal is a separate spec.

## Applicable Patterns

- `.vibeflow/patterns/memory-model.md` — read-mediator role; 15-entity
  progressive-disclosure cap; consult-live access timing.
- `.vibeflow/patterns/plugin-structure.md` — `skills/` layout; SKILL.md
  frontmatter shape.

## Risks

- **R1 / Internal callers still reference `wm_query_trace_path`.**
  Mitigation: grep `wm_query_trace_path|query-traces|query-trace` across
  `skills/`, `agents/`, `lib/`, `hooks/` before merging Parts 2–3; every
  hit is fixed in its corresponding part.
- **R2 / SKILL.md rewrite drops a load-bearing invariant.** Mitigation:
  DoD #4 enumerates the invariants explicitly; reviewer must confirm each
  survives in the rewritten skill text.
- **R3 / `lib/working-memory/paths.sh` re-source guard breaks.** The file
  uses `_WM_PATHS_LOADED` to be idempotent; removing one helper must not
  perturb that guard. Mitigation: smoke-load the file in a subshell post-edit.

## Dependencies

- None.
