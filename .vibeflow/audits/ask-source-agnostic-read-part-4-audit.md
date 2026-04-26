# Audit Report: ask-source-agnostic-read-part-4

**Verdict: PASS**

> Auditor: /vibeflow:audit (autonomous run, 2026-04-25)
> Spec: `.vibeflow/specs/ask-source-agnostic-read-part-4.md`
> PRD: `.vibeflow/prds/ask-source-agnostic-read.md`
> Dependency: ask-source-agnostic-read-part-1 (PASS)

## Test execution

13/13 smoke tests PASS — no regression introduced by the doctrine
edits. Doctrine changes are documentation only; they do not change
runtime behavior, but the test suite is run as a defensive
sanity-check that no doc edit accidentally hit live code.

| Test | Result |
| :--- | :--- |
| `tests/smoke/sprint-2.test.sh` | PASS |
| `tests/smoke/sprint-3.test.sh` | PASS |
| `tests/smoke/sprint-4.test.sh` | PASS |
| `tests/smoke/sprint-5.test.sh` | PASS |
| `tests/smoke/sprint-6.test.sh` | PASS |
| `tests/smoke/sprint-7.test.sh` | PASS |
| `tests/smoke/sprint-8.test.sh` | PASS |
| `tests/smoke/ask-no-clone.test.sh` | PASS |
| `tests/smoke/folder-isolation.test.sh` | PASS |
| `tests/smoke/memory-migration.test.sh` | PASS |
| `tests/smoke/preserve-model-c.test.sh` | PASS |
| `tests/smoke/status-readonly.test.sh` | PASS |
| `tests/smoke/teach-ingest.test.sh` | PASS |

## DoD Checklist

- [x] **DoD-1** — `.vibeflow/conventions.md` `Working memory —
      canonical files` section no longer lists `query-trace.md`. The
      relevant Don't is restated declaratively: "Do NOT allow any
      agent to read canonical memory directly. All reads route
      through `/yoke:ask` invoked via the Skill tool — direct
      filesystem reads … are prohibited."
      *Evidence:* `grep -nE "query-trace" .vibeflow/conventions.md`
      returns empty.
- [x] **DoD-2** — `.vibeflow/patterns/memory-model.md` table no
      longer contains the `query-trace.md` row. The Canonical-memory
      access timing → Consult paragraph rewritten: "Any runtime
      subagent — Generator, Validator, or Orchestrator — invokes
      `/yoke:ask` via the Skill tool on demand and reasons over the
      response in-conversation." Example tree no longer includes
      `query-trace.md`. Implementation Mapping list rewritten —
      "Canonical-memory reads do not materialize a working-memory
      artifact". Bypass anti-pattern rewritten: "agents reading
      canonical memory by `cat`/`grep`/cloning the substrate —
      bypasses progressive disclosure and the `/yoke:ask` mediation
      contract".
      *Evidence:* `grep -nE "query-trace" .vibeflow/patterns/memory-model.md`
      returns empty.
- [x] **DoD-3** — `.vibeflow/patterns/roles.md` Generator and
      Validator sections rewritten: "Reads canonical memory: only via
      `/yoke:ask` invoked through the Skill tool; never directly.
      Direct filesystem reads of the registered memory (cat, grep,
      clone, pull) are prohibited." Orchestrator consult-mode
      description: "Invokes `/yoke:ask` via the Skill tool and reasons
      over the response in-conversation. The skill enforces
      progressive disclosure (≤ 15 entity reads, 1-level wikilink
      hop) — never the full memory." Bypass discipline restated as
      declarative rule (no "absence of trace entry" phrasing).
      *Evidence:* `grep -nE "query-trace" .vibeflow/patterns/roles.md`
      returns empty.
- [x] **DoD-4** — Cross-document consistency. All three load-bearing
      docs (`conventions.md`, `memory-model.md`, `roles.md`) describe
      the canonical-memory read path identically: "invoke `/yoke:ask`
      via the Skill tool" with declarative bypass rule. The
      progressive-disclosure cap (15 entity reads, 1-level hop) is
      stated consistently. The two-tier memory model (working memory
      vs canonical memory) and the single-write-path invariant
      (`/yoke:preserve` via Skill tool, Orchestrator only) are
      preserved consistently across all docs. Verified by reading
      each doc end-to-end.
- [x] **DoD-5** — Sweep gate. No file under `.vibeflow/` references
      `query-trace.md` or `query-traces/<slug>.md` as a live
      mechanism. Surviving occurrences (verified via
      `grep -RnE "query-trace|query-traces|wm_query_trace_path"
      .vibeflow/`) are all in `.vibeflow/decisions.md` (lines 21, 56)
      — historical decision records explicitly framed as past state.
      The spec's anti-scope makes decisions.md historical entries
      out-of-scope.

## Pattern Compliance

This part is self-referential — the patterns being edited *are* the
project's pattern docs. Compliance check is "do the rewritten docs
remain internally consistent with the project's actual runtime?":

- [x] **memory-model.md** — agrees with the runtime now established
      by Parts 1-3. `/yoke:ask` is a pure read; Generator and
      Validator invoke it directly via Skill tool; Orchestrator
      consult mode invokes it and reasons inline; the trace handoff
      is gone.
- [x] **roles.md** — agrees with `agents/orchestrator.md`,
      `agents/generator.md`, `agents/validator.md` as updated by
      Part 2. Read/write authorities preserved verbatim except for
      the trace path replacement.
- [x] **conventions.md** Don'ts — preserves "no agent except
      Orchestrator writes canonical memory" and "no full canonical
      memory in any context" while updating the read-path Don't to
      match the new contract.
- [x] **plugin-structure.md** — not edited; no inconsistency with
      the updated docs.

## Convention Compliance

- [x] Markdown style — preserved (table syntax, list bullets, code
      block fences, emphasis).
- [x] No documentation fabrication — every replacement statement
      reflects an actual code/agent state established by Parts 1-3.
- [x] Linguistic precision — "must" / "never" / "any agent" used
      consistently with the doctrine doc style.

## Anti-scope discipline

| Anti-scope item | Status |
| :--- | :--- |
| `CLAUDE.md` (project root) — Part 5 | RESPECTED — not edited |
| `docs/architecture.md`, `docs/lineage.md`, `docs/troubleshooting.md` — Part 5 | RESPECTED |
| `docs/quickstart.md`, `examples/*`, `CHANGELOG.md` — Part 6 | RESPECTED |
| `.vibeflow/decisions.md` — historical | RESPECTED — untouched |
| `.vibeflow/index.md` — fold-in if hit | FOLDED IN (line 49 had a hit; spec explicitly permits this) |
| Code/test files — Parts 1-3 | RESPECTED |

## Risks (from spec)

- **R1 / Doctrine drift vs runtime** — DID NOT HAPPEN. Doctrine and
  runtime are now consistent (Parts 1-2 updated runtime; Part 4
  updated doctrine). Both flow through `/yoke:ask` via the Skill tool
  on demand.
- **R2 / Stale reference missed** — DID NOT HAPPEN. DoD-5 sweep gate
  passed. The grep that originally caught the strays in
  `phase-flow.md` and `ralph-loop.md` was the very mechanism that
  prompted the budget over-run.
- **R3 / Pattern doc loses load-bearing invariant unrelated to the
  trace** — DID NOT HAPPEN. The 15-cap, no-clone, single-write-path,
  two-tier-memory invariants are all explicitly preserved in the
  rewrites; only trace-related prose was replaced.
- **R4 / Cross-document inconsistency** — DID NOT HAPPEN. Final
  read-through across all 6 modified docs confirms the canonical-memory
  read path is described identically.

## Notable item: budget over-run

The spec scoped 3 explicit files + `.vibeflow/index.md` as fold-in.
Implementation modified 6:

1. `.vibeflow/conventions.md` (in scope)
2. `.vibeflow/patterns/memory-model.md` (in scope)
3. `.vibeflow/patterns/roles.md` (in scope)
4. `.vibeflow/index.md` (spec-allowed fold-in)
5. `.vibeflow/patterns/phase-flow.md` (DoD-5 sweep fold-in)
6. `.vibeflow/patterns/ralph-loop.md` (DoD-5 sweep fold-in)

Files 5 and 6 were not anticipated by the spec author. They contain
live mechanism descriptions — phase-flow's Phase 4 output column and
ralph-loop's Orchestrator consult+monitor description — that the
spec's DoD-5 sweep gate ("no file under `.vibeflow/` references
query-trace as a live mechanism") demands fixing. Without those
edits, DoD-5 fails. Edit was minimal-scope: one cell in phase-flow's
table, three sections in ralph-loop. Both edits preserve every
non-trace invariant verbatim.

Pattern same as Part 3's stragglers: sweep-gate fold-ins with
declared rationale. Treating as in-scope corrections; PASS-compatible
under the audit skill's rules (the only automatic-fail trigger is
"tests fail").

## Gaps

None. All 5 DoD checks satisfied; 13/13 smoke tests pass; anti-scope
items respected; convention compliance preserved; cross-document
consistency verified.

## Notes for downstream parts

- Part 5 must update `CLAUDE.md` (project root) and `docs/*.md` so
  user- and agent-facing docs match the doctrine now established by
  Parts 1-4.
- Part 6 must update `docs/quickstart.md`, the example CLAUDE.md,
  and `CHANGELOG.md` with a clearly-marked **Breaking** entry that
  records the contract change end-to-end (including the Part 1
  corrigendum to `skills/implement` + `skills/drift-sense` and the
  Part 4 sweep fold-ins to `phase-flow.md` + `ralph-loop.md`).

## Next step

Ready to ship Part 4. Proceed to Part 5: repo `CLAUDE.md` + main docs.
