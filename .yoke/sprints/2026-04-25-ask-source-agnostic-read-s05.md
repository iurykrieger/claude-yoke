# Sprint 05 of 06: `/yoke:ask` source-agnostic

> Migrated from: # Spec: `/yoke:ask` source-agnostic — Part 5 / Repo CLAUDE.md + main docs


> Generated via /vibeflow:gen-spec on 2026-04-25
> PRD: `.vibeflow/prds/ask-source-agnostic-read.md`

## Objective

Update the repo-root `CLAUDE.md` and the three load-bearing user-facing
docs (`docs/architecture.md`, `docs/lineage.md`, `docs/troubleshooting.md`)
so user- and agent-facing descriptions of `/yoke:ask` and working memory
match the no-trace contract.

## Context

These four documents encode the trace as a live mechanism:

- `CLAUDE.md` (project root) restates the working-memory file list,
  including `query-trace.md`, in the architecture section's table.
- `docs/architecture.md` includes an ASCII diagram of `.yoke/` that
  contains `query-trace.md`, plus a description of consult mode that
  reads "surface relevant subgraph entries to `.yoke/query-trace.md`."
- `docs/lineage.md` includes "audit-trail writing to `.yoke/query-trace.md`
  (Yoke-specific contribution)" framed as current behavior.
- `docs/troubleshooting.md` instructs users to inspect the trace as part
  of debugging canonical-memory access.

Doctrine has been updated in Part 4. These user-facing docs follow.

## Definition of Done

1. Repo-root `CLAUDE.md` working-memory description does not list
   `query-trace.md`. The working-memory tier explanation is consistent
   with `.vibeflow/patterns/memory-model.md` as updated by Part 4.
2. `docs/architecture.md` ASCII diagram of `.yoke/` does not contain
   `query-trace.md`. The consult-mode bullet ("Consult (per cycle) — read
   canonical memory live; surface relevant subgraph entries to
   .yoke/query-trace.md") is rewritten to: "Consult (per cycle) — invoke
   `/yoke:ask` via the Skill tool when canonical-memory context is
   needed."
3. `docs/lineage.md` removes the line "audit-trail writing to
   `.yoke/query-trace.md`" and any other live trace reference. Historical
   narrative about the previous design is acceptable only if explicitly
   framed as past.
4. `docs/troubleshooting.md` does not include a step that checks
   `.yoke/query-traces/` or `.yoke/query-trace.md`. Debugging guidance
   for canonical-memory access is updated to reflect the new flow
   (verify `/yoke:ask` runs without `.yoke/.current`; check
   `lib/canonical-memory/resolve-memory.sh` resolution).
5. **Sweep gate** — no live-mechanism reference to `query-trace.md` or
   `query-traces/<slug>.md` survives in any of the four files; counts
   of working-memory files quoted in prose match the new layout.

## Scope

- Edit `CLAUDE.md` (project root).
- Edit `docs/architecture.md`.
- Edit `docs/lineage.md`.
- Edit `docs/troubleshooting.md`.

## Anti-scope

- `.vibeflow/` doctrine — Part 4.
- `docs/quickstart.md`, `examples/greenfield-payment-service/CLAUDE.md`,
  `CHANGELOG.md` — Part 6.
- `README.md` — verify no live trace reference; if absent, do not touch.
  If present, fold into this part.
- `docs/installation.md`, `docs/canonical-memory-setup.md` — verify;
  fold in only on a hit.
- Documentation about other plugin features (bootstrap, teach, preserve,
  drift-sense, status, memory) is not touched.

## Technical Decisions

1. **CLAUDE.md duplication of the working-memory list.** Single source of
   truth lives in `.vibeflow/patterns/memory-model.md` (Part 4).
   `CLAUDE.md` duplicates a summary of it as quick reference for agents.
   Trade-off: two places to update; risk of drift. Justification:
   `CLAUDE.md` is loaded into every agent context; the duplication is
   load-bearing for correctness.
2. **`docs/lineage.md` historical framing.** Past architectural narrative
   (e.g., "the v0.5 design used a trace") is acceptable so long as the
   surrounding text frames the trace as past, not present. Trade-off:
   slight risk of confusion. Justification: lineage is the place for
   historical narrative; surgical edits are better than wholesale
   rewrites.
3. **`docs/architecture.md` diagram fidelity.** The ASCII diagram is
   updated to remove `query-trace.md`; surrounding labels and counts
   (e.g., "the four working-memory files") are updated accordingly.
   Trade-off: more lines touched than a single edit. Justification: a
   diagram with stale counts is worse than no diagram.
4. **`docs/troubleshooting.md` debugging step rewrite.** Replace
   trace-inspection guidance with: verify `/yoke:ask` runs without
   `.yoke/.current`; verify `lib/canonical-memory/resolve-memory.sh`
   returns a path; verify the registered memory exists on disk. This
   gives the user the actual debugging surface that survives.

## Applicable Patterns

- `.vibeflow/patterns/memory-model.md` — single source of truth on
  working-memory files. CLAUDE.md and `docs/architecture.md` summaries
  must agree with it.
- `.vibeflow/patterns/plugin-structure.md` — repo layout; relevant for
  the architecture diagram.

## Risks

- **R1 / Architecture diagram has multiple occurrences of the trace; one
  is missed.** Mitigation: post-edit grep `query-trace|query-traces`
  across the four files.
- **R2 / Lineage narrative becomes confusing — one trace mention
  removed, another remains historical.** Mitigation: read full sections,
  not just lines; ensure each remaining mention is explicitly framed as
  past.
- **R3 / A doc references the working-memory layout in a way that
  implicitly assumes 6 files (with trace).** Mitigation: search for
  numeric counts ("five", "six", "the … files of"); update each.
- **R4 / Drift between CLAUDE.md and `.vibeflow/patterns/memory-model.md`
  in the future.** Mitigation: Part 4 is dependency; both docs land in
  the same PR series. Long-term: if drift recurs, the future spec is to
  consolidate by having CLAUDE.md include-by-reference.

## Dependencies

- `.vibeflow/specs/ask-source-agnostic-read-part-1.md`
- `.vibeflow/specs/ask-source-agnostic-read-part-4.md`
