# Spec: `/yoke:ask` source-agnostic — Part 6 / Trailing docs + changelog

> Generated via /vibeflow:gen-spec on 2026-04-25
> PRD: `.vibeflow/prds/ask-source-agnostic-read.md`

## Objective

Sweep the remaining user-facing surfaces (`docs/quickstart.md`,
`examples/greenfield-payment-service/CLAUDE.md`) and add a CHANGELOG
entry that records the breaking change for any project already
bootstrapped against an older Yoke.

## Context

Two trailing surfaces still describe `/yoke:ask` as "mediated
canonical-memory query" — accurate while the trace mediated, misleading
once `/yoke:ask` is a direct, source-agnostic read. The CHANGELOG is the
contract surface for downstream users: any project that previously ran
`/yoke:bootstrap` against an older Yoke version now has a stale
`.yoke/query-traces/` directory and stale agent prompts. The migration
note tells them what to do.

## Definition of Done

1. `docs/quickstart.md` no longer describes `/yoke:ask` as "mediated".
   The phrase is replaced with "adaptive canonical-memory query" (or
   equivalent wording consistent with `skills/ask/SKILL.md`'s revised
   description from Part 1).
2. `examples/greenfield-payment-service/CLAUDE.md` mirrors the
   quickstart wording — same phrasing for the `/yoke:ask` description
   line. No new content is added; only the description is corrected.
3. `CHANGELOG.md` contains a new entry — clearly marked **Breaking** —
   describing:
   - Removal of the query-trace contract.
   - Removal of `wm_query_trace_path` and the `query-traces` archive
     category from `lib/working-memory/paths.sh`.
   - Change to bypass discipline (declarative rule on each subagent
     prompt).
   - Runtime-agent contract change: Generator, Validator, and
     Orchestrator now read canonical memory by invoking `/yoke:ask` via
     the Skill tool.
   - Migration note: any pre-existing `.yoke/query-traces/` directory
     in a host project is now orphaned and may be deleted.
4. The CHANGELOG entry follows the existing CHANGELOG.md style
   conventions: section ordering, version line, link style, date format.
5. **Sweep gate** — no surviving reference in any of the three files
   to `query-trace.md` or `query-traces/<slug>.md` as a live mechanism.

## Scope

- Edit `docs/quickstart.md`.
- Edit `examples/greenfield-payment-service/CLAUDE.md`.
- Edit `CHANGELOG.md`.

## Anti-scope

- `.vibeflow/` doctrine — Part 4.
- `CLAUDE.md` (project root), `docs/architecture.md`, `docs/lineage.md`,
  `docs/troubleshooting.md` — Part 5.
- Migration tooling for existing projects — explicitly excluded by the
  PRD anti-scope. The CHANGELOG note instructs the user; we do not ship
  code that mutates host repos.
- Other examples (`examples/` may grow over time; only the
  greenfield-payment-service example references `/yoke:ask` today).
- README.md — verify no live trace reference; if absent, do not touch.
  If present, fold into this part.

## Technical Decisions

1. **Description wording.** "Adaptive canonical-memory query" matches
   `bedrock:ask`'s framing and the new `skills/ask/SKILL.md`
   description. Trade-off: small lexical drift from earlier docs.
   Justification: accuracy and consistency across surfaces.
2. **Migration note instead of migration code.** The CHANGELOG simply
   tells the user that any `.yoke/query-traces/` directory is orphaned
   and can be deleted. Trade-off: a tiny user-side step. Justification:
   PRD anti-scope explicitly defers migration tooling; the user can
   `rm -rf .yoke/query-traces/` (or simply ignore it) without harm.
3. **CHANGELOG section placement.** Add under the next unreleased
   header, or create one if absent, matching the repo's existing style.
   Mark the entry **Breaking**. Cross-link to Parts 1–5 via a single
   "removes the query-trace contract end-to-end" sentence rather than
   listing every file edited (the diff already enumerates them).
4. **Identical phrasing in quickstart and example CLAUDE.md.** Reduces
   future drift. Trade-off: minor. Justification: both files describe
   the same thing; differences invite questions.

## Applicable Patterns

- `.vibeflow/patterns/plugin-structure.md` — `examples/` layout and
  scope.
- `.vibeflow/conventions.md` "Implementation Plan Conventions" → "Every
  sprint ships an installable plugin": each shipped change must update
  the changelog.

## Risks

- **R1 / CHANGELOG entry undersells the breakage.** Mitigation: explicit
  **Breaking** label + migration note; do not bury under "internal
  refactor".
- **R2 / Quickstart and example CLAUDE.md drift in wording over future
  edits.** Mitigation: identical phrasing landed in both files in this
  part; future edits to one should update the other.
- **R3 / A surviving `query-trace` reference is missed in another
  example or doc not enumerated here.** Mitigation: post-edit grep
  `query-trace|query-traces` across the entire repo before merging
  the part-6 PR; any hit is fixed in scope.

## Dependencies

- `.vibeflow/specs/ask-source-agnostic-read-part-1.md`
- `.vibeflow/specs/ask-source-agnostic-read-part-4.md`
