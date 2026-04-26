# Audit Report: ask-source-agnostic-read-part-1

**Verdict: PASS**

> Auditor: /vibeflow:audit (autonomous run, 2026-04-25)
> Spec: `.vibeflow/specs/ask-source-agnostic-read-part-1.md`
> PRD: `.vibeflow/prds/ask-source-agnostic-read.md`

## Test execution

No project-wide test runner exists (no `package.json`, `pyproject.toml`,
`Cargo.toml`, `go.mod`, etc.). The repo's tests are individual bash smoke
scripts under `tests/smoke/`. The spec's anti-scope explicitly excludes
test changes (those are owned by Part 3).

| Verification | Result |
| :--- | :--- |
| `lib/working-memory/paths.sh` smoke-load in subshell | exit 0 |
| `wm_query_trace_path` removed (`type` returns "not found") | PASS |
| `WM_ARCHIVE_CATEGORIES` reduced to 4 entries | PASS |
| Other `wm_*` helpers (`wm_prd_path`, `wm_contracts_path`, …) still load | PASS |
| `tests/smoke/sprint-3.test.sh` not affected by Part 1 | PASS (no `query-trace` references) |
| `tests/smoke/sprint-4.test.sh` not affected by Part 1 | PASS (no `query-trace` references) |
| `tests/smoke/sprint-2.test.sh` (asserts old contract) | FAIL — owned by Part 3 |
| `tests/smoke/sprint-5.test.sh` (asserts old YAML trace shape) | FAIL — owned by Part 3 |
| `tests/smoke/folder-isolation.test.sh` (asserts query-traces category) | FAIL — owned by Part 3 |
| `tests/smoke/ask-no-clone.test.sh` (built around old trace flow) | FAIL — owned by Part 3 |

The four failing smoke tests all fail for the same root cause: they assert
the *old* trace contract that this PR deliberately removes. The PRD and the
multi-part split anticipated this — the test-suite alignment is the entire
purpose of Part 3, which depends on Parts 1 and 2 having landed first.
Verifying *that* this is the failure mode (and not a system regression)
required reading the asserting code in each test and confirming each hit
matches the symbols deleted in Part 1.

## DoD Checklist

- [x] **DoD-1** — `skills/ask/SKILL.md` no longer references
      `.yoke/.current`, `wm_active_slug`, `wm_query_trace_path`,
      `query-traces`, or any YAML trace shape. The pre-condition section
      that aborted on missing active task is removed; Phase 5 contains
      only response composition.
      *Evidence:* `grep -E "\.yoke/\.current|wm_active_slug|wm_query_trace_path|query-traces|query-trace" skills/ask/SKILL.md`
      returns empty. `grep -nE "\btrace\b" skills/ask/SKILL.md` returns
      empty. The "Phase 5 — Compose response" section contains only
      composition rules (no 5.1 trace write).
- [x] **DoD-2** — `skills/ask/SKILL.md` description rewritten:
      source-agnostic, registry-resolved, filesystem-only, 15-cap, no
      trace.
      *Evidence:* Frontmatter (lines 1–14) reads "Source-agnostic read
      against the registered canonical memory. Resolves the active
      memory via lib/canonical-memory/resolve-memory.sh … reads the
      local filesystem directly … Caps total entity reads at 15. Pure
      read — writes nothing on disk and does not depend on any active
      task."
- [x] **DoD-3** — `lib/working-memory/paths.sh` does not export
      `wm_query_trace_path`; `WM_ARCHIVE_CATEGORIES` does not contain
      `query-traces`.
      *Evidence:* `grep -n "wm_query_trace_path" lib/working-memory/paths.sh`
      returns empty. `WM_ARCHIVE_CATEGORIES=(prds tech-specs acceptance-contracts contracts)`
      at line 44. Subshell smoke-load confirms `type
      wm_query_trace_path` reports "not found" while other `wm_*`
      helpers still resolve as functions. The file-header layout
      comment was also updated so the documentation matches the code.
- [x] **DoD-4** — Invariants preserved.
      *Evidence:*
      - 15-entity cap: 5 mentions in SKILL.md (Phase 2.4 limit; Phase
        2.5 hard cap; Critical rule #4; anti-pattern; description).
      - No clone/pull/fetch: rule #1 + Phase 0 explicit "no `git clone`,
        no `git pull`, no `git fetch`" + description.
      - No fabrication: rule #7 + Phase 5.5 explicit "NEVER fabricate".
      - `resolve-memory.sh`: description + Phase 0 source line +
        rule #6 + See-also.
      - Bare wikilinks: Phase 5.3 + rule #5.
- [x] **DoD-5** — `allowed-tools` excludes `Task`.
      *Evidence:* `allowed-tools: Bash, Read, Glob, Grep`. Note: `Write`
      was also dropped (no longer needed; the skill is pure read). This
      is a tightening of the tool envelope, not a regression.

## Pattern Compliance

- [x] **`.vibeflow/patterns/memory-model.md`** — followed.
      The skill remains the canonical-memory read mediator; reads stop
      at the 15-entity cap (progressive disclosure preserved); Phase 0
      uses `lib/canonical-memory/resolve-memory.sh` (no clone, no pull,
      no fetch). The two-tier model is unchanged. Note: the doctrine
      doc itself still describes the trace mechanism — that is the
      explicit subject of Part 4 and is properly anti-scoped here.
- [x] **`.vibeflow/patterns/plugin-structure.md`** — followed.
      `skills/ask/SKILL.md` retains the standard frontmatter shape
      (`name`, `description`, `argument-hint`, `allowed-tools`). No new
      files introduced; no skill layout disturbed.

## Convention Compliance

- [x] `.vibeflow/conventions.md` "Don'ts → Do NOT allow the Generator
      or the Validator to read canonical memory directly — every query
      goes through the Orchestrator." — preserved. `/yoke:ask` is the
      mediated read path; Part 1 does not relax this.
- [x] `.vibeflow/conventions.md` "Don'ts → Do NOT load the entire
      canonical memory into any agent's context — only the relevant
      subgraph". — preserved (15-cap intact).
- [x] No backwards-compatibility shim added (per PRD anti-scope and
      conventions doctrine). `wm_query_trace_path` is deleted outright.

## Anti-scope discipline

| Anti-scope item | Status |
| :--- | :--- |
| Test changes (Part 3) | RESPECTED — `tests/` untouched |
| Agent contract changes (Part 2) | RESPECTED — `agents/` untouched |
| Doctrine `.vibeflow/` updates (Part 4) | RESPECTED — `.vibeflow/` untouched |
| User-facing doc changes (Parts 5–6) | RESPECTED — `docs/`, `CLAUDE.md`, `CHANGELOG.md` untouched |
| `lib/canonical-memory/resolve-memory.sh` | RESPECTED — untouched |
| Memory registry shape | RESPECTED — `memories.json` schema untouched |
| Compatibility shim for `wm_query_trace_path` | RESPECTED — none added |
| New graphify or `/yoke:teach` escalation logic | RESPECTED — none added |

## Risks (from spec)

- **R1 / Internal callers still reference `wm_query_trace_path`** —
  REMAINS, by design. Confirmed callers in `agents/{generator,validator,
  orchestrator}.md` and four smoke tests; each is owned by Parts 2/3
  per the multi-part split. Loud failure on those callers is the
  intended signal until Parts 2/3 land.
- **R2 / SKILL.md rewrite drops a load-bearing invariant** — DID NOT
  HAPPEN. Each invariant was independently grep-verified (DoD-4).
- **R3 / `_WM_PATHS_LOADED` re-source guard breaks** — DID NOT HAPPEN.
  Subshell smoke-load returns exit 0 and all preserved helpers resolve
  as functions.

## Gaps

None. All 5 DoD checks satisfied; all anti-scope items respected;
budget used 2 / ≤ 4 files; no convention violations.

## Notes for downstream parts

- Part 2 must replace each Generator/Validator/Orchestrator reference
  to `wm_query_trace_path` and `.yoke/query-traces/<slug>.md` with the
  declarative `/yoke:ask` invocation rule.
- Part 3 must update the four smoke tests so they assert the new
  contract — every removed assertion must either map to a preserved
  invariant (Part 1's DoD-4) or be intentionally deleted with the trace
  contract.

## Next step

Ready to ship Part 1. Proceed to Part 2: `agents/{orchestrator,generator,
validator}.md` rewrite.
