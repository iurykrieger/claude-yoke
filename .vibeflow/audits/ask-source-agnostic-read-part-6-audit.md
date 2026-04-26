# Audit Report: ask-source-agnostic-read-part-6

**Verdict: PASS**

> Auditor: /vibeflow:audit (autonomous run, 2026-04-25)
> Spec: `.vibeflow/specs/ask-source-agnostic-read-part-6.md`
> PRD: `.vibeflow/prds/ask-source-agnostic-read.md`
> Dependencies: ask-source-agnostic-read-part-1 (PASS), ask-source-agnostic-read-part-4 (PASS)

## Test execution

13/13 smoke tests PASS — full suite green at the end of the PR series.

| Test | Result |
| :--- | :--- |
| sprint-2.test.sh | PASS |
| sprint-3.test.sh | PASS |
| sprint-4.test.sh | PASS |
| sprint-5.test.sh | PASS |
| sprint-6.test.sh | PASS |
| sprint-7.test.sh | PASS |
| sprint-8.test.sh | PASS |
| ask-no-clone.test.sh | PASS |
| folder-isolation.test.sh | PASS |
| memory-migration.test.sh | PASS |
| preserve-model-c.test.sh | PASS |
| status-readonly.test.sh | PASS |
| teach-ingest.test.sh | PASS |

## DoD Checklist

- [x] **DoD-1** — `docs/quickstart.md` no longer describes
      `/yoke:ask` as "mediated"; replaced with "adaptive
      canonical-memory query".
      *Evidence:* `grep -n "mediated" docs/quickstart.md` returns
      empty.
- [x] **DoD-2** — `examples/greenfield-payment-service/CLAUDE.md`
      mirrors quickstart wording exactly: "adaptive canonical-memory
      query".
      *Evidence:* identical phrasing across both files.
- [x] **DoD-3** — `CHANGELOG.md` contains the new entry, marked
      **Breaking**, covering: removal of query-trace contract,
      removal of `wm_query_trace_path` and `query-traces` archive
      category, change to bypass discipline (declarative), runtime-
      agent contract change (Generator/Validator/Orchestrator now
      invoke `/yoke:ask` via Skill), and migration note (delete
      orphaned `.yoke/query-traces/` directory).
      *Evidence:* `head -90 CHANGELOG.md` shows the new entry with
      all five required content elements present.
- [x] **DoD-4** — CHANGELOG entry follows existing style: `## [...]
      — title — **Breaking**` header (matches the `## [version]` —
      title format, with `[Unreleased]` per spec wording "create one
      if absent"); `### Removed` and `### Changed` and `### Migration`
      sections matching prior-entry section ordering; markdown
      bullets and code-block fences match the existing style.
- [x] **DoD-5** — Sweep gate. No surviving live-mechanism reference
      in any of the three scoped files.
      *Evidence:* `grep -nE "query-trace|query-traces|wm_query_trace_path"`
      against `docs/quickstart.md`, `examples/greenfield-payment-service/CLAUDE.md`,
      and `CHANGELOG.md`. Quickstart and example CLAUDE.md grep
      empty. CHANGELOG hits are inside the new entry's "Removed"
      section that explicitly describes the retirement — these are
      historical narrative, not live references (consistent with the
      spec's permitted historical framing).

## Pattern Compliance

- [x] **`.vibeflow/patterns/plugin-structure.md`** — followed.
      `examples/` layout preserved; CHANGELOG.md style preserved.
- [x] **`.vibeflow/conventions.md`** Implementation Plan Conventions
      "Every sprint ships an installable plugin" — the plugin is
      still installable. Per-version stamping preserved (entry uses
      `[Unreleased]` until release).

## Convention Compliance

- [x] CHANGELOG style — Keep-a-Changelog convention preserved
      (Removed / Changed / Migration sections; bullet style; code
      fences for shell commands).
- [x] Linguistic precision — "Breaking" prominently marked;
      "retired" used consistently for the gone-but-historically-
      framed contract.
- [x] No fabrication — every CHANGELOG bullet describes a real edit
      from Parts 1-5 (or this part's own corrigenda).

## Anti-scope discipline (strict spec scope)

| Anti-scope item | Status |
| :--- | :--- |
| Other docs (Part 5) | RESPECTED — not re-edited by Part 6 |
| Doctrine `.vibeflow/` (Part 4) | RESPECTED |
| Migration tooling for existing projects | RESPECTED — CHANGELOG instructs the user to `rm -rf .yoke/query-traces/`; no migration code shipped |
| Other examples | RESPECTED — only the greenfield-payment-service example references `/yoke:ask` |
| `README.md` | RESPECTED — verified clean by grep, not edited |

## Risks (from spec)

- **R1 / CHANGELOG entry undersells the breakage** — DID NOT HAPPEN.
  Entry is prominently labeled `(**Breaking**)` in the title, has a
  `> Breaking.` callout immediately after the summary paragraph, and
  closes with a `### Migration` section.
- **R2 / Quickstart and example CLAUDE.md drift** — DID NOT HAPPEN.
  Identical phrasing landed in both; future edits should keep them
  in lockstep.
- **R3 / A surviving query-trace reference is missed in another
  example or doc** — Caught by the post-Part-6 sweep. README,
  installation, canonical-memory-setup verified clean. Three
  additional callers in `skills/` (bootstrap, implement, preserve)
  were patched as a final cross-cutting corrigendum (see "Notable
  item" below).

## Notable item: cross-cutting corrigendum (out of strict scope)

After completing the spec-scope edits, a final repo-wide sweep
caught three more files with live `wm_query_trace_path` and
`.yoke/query-traces/<slug>.md` references that were missed by
earlier audits:

1. `skills/bootstrap/SKILL.md` — listed `query-traces/` as a live
   archive category in the bootstrap rationale.
2. `skills/implement/SKILL.md` — five additional references to
   `wm_query_trace_path` in the cycle-loop input contracts for
   Generator, Validator, and Orchestrator (Part 3 patched only
   line 51's cycle-0 init).
3. `skills/preserve/SKILL.md` — referenced `query-traces/<slug>.md`
   in the free-form input parser's `.yoke/<task-slug>/` directory
   read.

All three were live runtime references — `skills/implement/SKILL.md`
in particular would have failed at runtime by calling the deleted
`wm_query_trace_path` function. Patched here as a final corrigendum
to make the user-stated condition "ALL THE WORK is DONE" true. The
budget over-run mirrors Part 3 (where the same sweep gate caught
implement/drift-sense stragglers) and Part 4 (where the sweep gate
caught phase-flow/ralph-loop stragglers); the pattern indicates the
spec author should write tighter sweep gates into all multi-part
docrtine-removal PRDs in the future.

Files modified by Part 6 in total: 6 (3 in spec scope + 3
corrigendum).

## Notable item: version bump reverted

I initially bumped `plugin.json` from 1.1.0 → 1.2.0 to keep the
CHANGELOG entry's version in sync. This caused
`tests/smoke/sprint-8.test.sh` to FAIL — the test has a hardcoded
expectation that `plugin.json.version == "1.1.0"`. Bumping
`plugin.json` would have cascaded edits into `marketplace.json`,
`README.md`, and the sprint-8 assertions, growing scope further.

Resolution: reverted `plugin.json` to 1.1.0 and changed the CHANGELOG
header to `## [Unreleased]` per the spec's explicit guidance ("Add
under the next unreleased header, or create one if absent"). The
plugin will get its 1.2.0 version stamp when the maintainer cuts the
release commit.

## Gaps

None. All 5 DoD checks satisfied; 13/13 smoke tests pass; anti-scope
items respected for the strict spec scope; pattern + convention
compliance preserved.

## End of PR series

This is the last part. The full ask-source-agnostic-read PRD is
implemented:

| Part | Files | Verdict |
| :--- | :--- | :--- |
| 1 | skills/ask + lib/working-memory/paths.sh | PASS |
| 2 | agents/{generator,validator,orchestrator}.md | PASS |
| 3 | tests/smoke/{sprint-2,sprint-5,folder-isolation,ask-no-clone}.test.sh + skills/{implement,drift-sense} corrigenda | PASS |
| 4 | .vibeflow/{conventions,index,patterns/{memory-model,roles,phase-flow,ralph-loop}}.md | PASS |
| 5 | CLAUDE.md, docs/{architecture,lineage,troubleshooting}.md | PASS |
| 6 | docs/quickstart.md, examples/.../CLAUDE.md, CHANGELOG.md + skills/{bootstrap,implement,preserve} corrigenda | PASS |

Final state: `/yoke:ask` is a pure source-agnostic read; the
`.yoke/query-traces/` archive and `wm_query_trace_path` helper are
gone; bypass discipline is declarative; doctrine + tests + docs are
all consistent. 13/13 smoke tests pass.

## Next step

Ready to ship the full PR series. The maintainer can choose to land
all 6 parts as a single PR or as a series. Recommended: single PR for
this scope (cross-cutting bugfix at the doctrine level).
