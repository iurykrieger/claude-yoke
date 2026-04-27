# Spec: `/yoke:ask` source-agnostic — Part 4 / Doctrine update

> Generated via /vibeflow:gen-spec on 2026-04-25
> PRD: `.vibeflow/prds/ask-source-agnostic-read.md`

## Objective

Update the three doctrine documents — `.vibeflow/conventions.md`,
`.vibeflow/patterns/memory-model.md`, and `.vibeflow/patterns/roles.md` —
so the project's authoritative descriptions of working memory and
canonical-memory mediation reflect the no-trace, source-agnostic
`/yoke:ask` contract.

## Context

Each of the three doctrine documents encodes the trace contract:

- `conventions.md` lists `query-trace.md` as a working-memory canonical
  file (line ~80) and frames bypass detection around its absence.
- `patterns/memory-model.md` table of working-memory files contains a
  `query-trace.md` row; the "Canonical-memory access timing" section
  describes the Orchestrator surfacing entries to the trace; the
  example tree and the Implementation Mapping list both include
  `query-trace.md`; an anti-pattern references "bypass detection."
- `patterns/roles.md` Generator and Validator sections describe their
  canonical-memory read path as consuming `.yoke/query-trace.md`; the
  Orchestrator consult-mode description names the trace as the surface;
  one sentence states "any read that does not leave a trace entry is a
  bypass."

Doctrine is the project's source of truth and must be coherent with the
runtime behavior. This part rewrites the doctrine in line with the PRD's
declarative bypass discipline.

## Definition of Done

1. `.vibeflow/conventions.md` `Working memory — canonical files` section
   no longer lists `query-trace.md`. The relevant entry under "Don'ts"
   is restated declaratively: "no agent reads canonical memory directly;
   reads route through `/yoke:ask`."
2. `.vibeflow/patterns/memory-model.md` table of working-memory files
   no longer contains the `query-trace.md` row. The "Canonical-memory
   access timing → Consult" paragraph no longer mentions writing to the
   trace; it describes the Orchestrator invoking `/yoke:ask` and
   reasoning over the response. The example working-memory layout no
   longer includes `query-trace.md`. The Implementation Mapping list
   no longer includes `query-trace.md`. The anti-pattern about bypass
   detection is rewritten to point at the declarative `/yoke:ask`
   mediation rule.
3. `.vibeflow/patterns/roles.md` Generator and Validator sections do
   not reference `.yoke/query-trace.md`; their canonical-memory read
   path is "invoke `/yoke:ask` via the Skill tool". The Orchestrator
   consult-mode description does not mention surfacing entries to the
   trace. The "Bypass detection" sentence is rewritten or removed
   consistent with DoD #1's declarative rule.
4. **Cross-document consistency** — no statement in one doctrine doc
   contradicts another (e.g., one declaring "no trace" while another
   still describes consult-mode subgraph surfacing).
5. **Sweep gate** — no file under `.vibeflow/` references `query-trace.md`
   or `query-traces/<slug>.md` as a live mechanism. Historical
   references (e.g., decisions log entries that record past state) are
   acceptable only if explicitly framed as historical.

## Scope

- Edit `.vibeflow/conventions.md` (working-memory file list ~line 80;
  Don'ts ~line 102; bypass-related anti-pattern statements).
- Edit `.vibeflow/patterns/memory-model.md` (table at line ~40;
  consult-timing paragraphs ~lines 92–101; example tree ~line 162;
  Implementation Mapping ~lines 191–193; anti-pattern at ~line 177).
- Edit `.vibeflow/patterns/roles.md` (Generator section ~lines 43–46;
  Validator section ~lines 58–60; Orchestrator consult-mode + bypass
  ~lines 66–82; spec-phase note that already routes through `/yoke:ask`
  is preserved).

## Anti-scope

- `CLAUDE.md` (project root) — Part 5.
- `docs/architecture.md`, `docs/lineage.md`, `docs/troubleshooting.md` —
  Part 5.
- `docs/quickstart.md`, `examples/greenfield-payment-service/CLAUDE.md`,
  `CHANGELOG.md` — Part 6.
- `.vibeflow/decisions.md` — historical record; entries that record past
  decisions are not rewritten.
- `.vibeflow/index.md` — verify it has no live trace reference; touch
  only if a hit is found (then fold into this part).
- Code/test files — Parts 1–3.

## Technical Decisions

1. **Doctrine wording for bypass discipline.** Replace every variant of
   "absence of trace entry is the signal" with the declarative form: "no
   agent reads canonical memory directly; reads route through `/yoke:ask`."
   Trade-off: loses the automation hook the trace once provided.
   Justification: doctrine should describe what is true, not what was
   true. The PRD explicitly defers a replacement signal.
2. **Anti-pattern rewrite in `memory-model.md`.** Replace "agents reading
   canonical memory by cat/grep/cloning the substrate — bypasses
   progressive disclosure and bypass detection" with "… bypasses
   progressive disclosure and the `/yoke:ask` mediation contract."
   Trade-off: subtle wording change. Justification: precision — the
   anti-pattern is still real; only the enforcement mechanism changed.
3. **Historical references.** `decisions.md`, the changelog, and any
   "Scoped Analyses" entry in `index.md` may continue to reference the
   trace as historical. Doctrine prose (the rules themselves) must not.
4. **Generator/Validator wording.** "Reads canonical memory: never
   directly" becomes "Reads canonical memory: only via `/yoke:ask`."
   Trade-off: the prohibition is unchanged; the affirmative path
   becomes explicit. Justification: a positive instruction is more
   actionable than a negation.

## Applicable Patterns

- `.vibeflow/patterns/memory-model.md` — self-referential; this part
  edits it.
- `.vibeflow/patterns/roles.md` — self-referential; this part edits it.
- `.vibeflow/patterns/plugin-structure.md` — unchanged; referenced for
  consistency check (working-memory layout described in plugin-structure
  must agree with the updated `memory-model.md`).

## Risks

- **R1 / Doctrine drift vs runtime.** Part 4 lands before Part 2 →
  doctrine says "invoke `/yoke:ask`" while `agents/orchestrator.md`
  still writes to the trace. Mitigation: dependency declared (Part 4 →
  Part 1); reviewers should land Parts 1, 2, 4 close together. Worst
  case is a transient inconsistency window.
- **R2 / Stale reference missed.** Mitigation: DoD #5 is a sweep gate;
  grep `query-trace|query-traces|bypass.*trace|trace.*entry` across
  `.vibeflow/` post-edit and reconcile every hit.
- **R3 / A pattern doc loses a load-bearing invariant unrelated to the
  trace** (e.g., the 15-cap, no-clone, single-write-path invariants).
  Mitigation: edits are scoped to trace-related prose; non-trace
  invariants are explicitly out of scope and must read identically
  before and after.
- **R4 / Cross-document inconsistency.** Easy to miss when editing
  three docs in parallel. Mitigation: DoD #4 + final read-through of
  all three docs in sequence as the last step.

## Dependencies

- `.vibeflow/specs/ask-source-agnostic-read-part-1.md`
