# Audit Report: runtime-cleanup

> Audited 2026-04-27 against `.vibeflow/specs/runtime-cleanup.md`.

**Verdict: PASS**

## DoD Checklist

- [x] **1. Cleanup deletes contents of `wm_runtime_dir` for the active
      task on a MERGE-READY exit, only after the canonize handoff
      returns exit 0; the directory itself remains.**
      Evidence: `lib/working-memory/cleanup.sh:81-94` — `wm_runtime_cleanup`
      requires both args, returns early when `reason != "merge-ready"`
      or `canonize_exit != "0"`, and otherwise delegates to
      `wm_wipe_runtime` (which uses
      `find "$WM_RUNTIME_DIR" -mindepth 1 -delete`,
      preserving the directory). Smoke (f) in
      `tests/working-memory.test.sh:163-167` writes
      `progress.md`, a cycle counter, and a snapshot, calls cleanup
      with `(merge-ready, 0)`, then asserts zero remaining files.
      Result: PASS.

- [x] **2. No deletion on paused exits (`divergence`,
      `contract-conflict`, `hard-bound`, `infeasibility`).**
      Evidence: same gate at `cleanup.sh:88-93`. Smoke (g) in
      `tests/working-memory.test.sh:172-191` exercises both the
      paused-exit case (`hard-bound`) and the canonize-failure case
      (`merge-ready`, exit 7); both leave runtime contents intact.
      Result: PASS.

- [x] **3. Gitignore self-heal at preflight: writes/repairs missing or
      incomplete `.yoke/.gitignore`; exactly one notice line on
      repair, zero lines when correct.**
      Evidence: `cleanup.sh:48-58` — branches: file-correct returns
      silently; otherwise overwrites with `_WM_GITIGNORE_CONTENT`
      (`.current\nruntime/`) and prints
      `[yoke] repaired .yoke/.gitignore (wrote: .current, runtime/)`.
      Smoke (h) in `tests/working-memory.test.sh:204-244` covers
      missing-file, incomplete-file, and already-correct cases;
      verifies output cardinality and final content. Wired into
      `/yoke:implement` preflight at `skills/implement/SKILL.md:36-46`.
      Result: PASS.

- [x] **4. Tracked-files hint when `.yoke/runtime/` has tracked
      paths; never executes `git rm` automatically.**
      Evidence: `cleanup.sh:65-73` — uses `git ls-files
      --error-unmatch` (read-only); on hit prints exactly
      `[yoke] .yoke/runtime/ has tracked files. Run: git rm -r --cached .yoke/runtime/`;
      short-circuits silently outside a git work tree. Smoke (i)
      in `tests/working-memory.test.sh:248-296` initializes a git
      repo, force-tracks a runtime file, asserts the hint fires,
      asserts `git status --porcelain` is byte-identical before and
      after, then untracks and asserts the helper goes silent.
      Result: PASS.

- [x] **5. `tests/working-memory.test.sh` asserts (a) cleanup wipes
      on merge-ready+canonize-success, (b) preserves on paused
      termination, (c) gitignore self-heal repairs, (d) tracked
      hint fires without state change.**
      Evidence: cases (f) through (i) added at
      `tests/working-memory.test.sh:147-298`; full test suite output
      `PASS (9 check(s))` covers the four new assertions plus the
      five pre-existing ones. Result: PASS.

- [x] **6. Craftsmanship — deterministic bash functions in
      `lib/working-memory/cleanup.sh`, reuse `wm_runtime_dir` from
      `paths.sh`, zero hardcoded `.yoke/runtime/` strings; no
      conventions.md Don'ts violated.**
      Evidence:
      - cleanup.sh sources nothing externally; declares hard
        dependency on paths.sh via the `_WM_PATHS_LOADED` guard at
        `cleanup.sh:32-35`.
      - All path references go through `WM_ROOT`/`WM_RUNTIME_DIR`
        constants from paths.sh; the only literal string is
        `_WM_GITIGNORE_CONTENT` at `cleanup.sh:39`, which is
        gitignore *content* (necessarily a literal), not a
        filesystem path.
      - No agentic calls in cleanup.sh — all functions are pure
        bash.
      - Conventions Don'ts: no canonical-memory access, no agent
        permissioning changes, no sensor changes, no acceptance
        contract changes, no canonize bypass. All clear.
      Result: PASS.

## Pattern Compliance

- [x] **`patterns/ralph-loop.md` — termination semantics.**
      Cleanup attaches to §4 ("Termination paths") in
      `skills/implement/SKILL.md:308-323` *after* the canonize
      handoff in §3 returns. The five termination reasons in the
      pattern (`merge-ready` | `divergence` | `contract-conflict` |
      `hard-bound` | `infeasibility`) are honored: only
      `merge-ready` triggers cleanup; the others remain pause
      states with cycle history preserved. No change to parallel
      spawn, hard bounds, or sprint-contract semantics.

- [x] **`patterns/memory-model.md` — working-memory lifetime
      ("task / sprint / PR scope").**
      The implementation operationalizes the pattern's lifetime
      declaration: at PR-readiness (MERGE-READY + canonize success),
      runtime contents are reclaimed. The pattern itself is
      unchanged. The `.yoke/.current` pointer remains outside
      `runtime/` per the spec's Open Question #3 ("leaning leave-it"),
      so it is not affected by `wm_runtime_cleanup`.

- [x] **conventions.md — "Blueprints wrapping agentic nodes".**
      `cleanup.sh` is a pure deterministic node — three bash
      functions, no LLM calls, no Task spawns, no MCP queries.
      Invoked by `/yoke:implement` from preflight (silent or one-line)
      and termination (gated no-op or wipe). Aligns exactly with
      "LLM only where judgment is genuinely necessary".

- [x] **conventions.md — "Back-pressure: success is silent,
      failures are verbose".**
      `wm_gitignore_self_heal` is silent when the file is already
      correct; emits one line on repair. `wm_check_runtime_tracked`
      is silent when nothing is tracked; emits one line on hit.
      `wm_runtime_cleanup` is silent on success and on no-op paths;
      stderr-noisy only on missing-arg (a programming error, not
      a runtime state).

- [x] **conventions.md — "Environment designers, not code
      writers".**
      The fix treats the leak as an environment-design problem —
      gitignore self-heal + automatic sweep — instead of a code
      problem requiring user discipline. Matches the convention's
      framing.

- [x] **Implementation Plan convention — "Test file per framework
      concept".**
      No new test file; the four assertions extend the existing
      `tests/working-memory.test.sh`. Working-memory hygiene is the
      same concept as path resolution and bootstrap output (per
      the test file's own header comment), so adding to it is the
      correct placement.

## Convention Violations

None.

## Tests

- `tests/working-memory.test.sh` — PASS (9/9)
- `tests/bootstrap.test.sh` — PASS (7/7) — gitignore literal still
  asserted at `tests/bootstrap.test.sh:84` matches the literal in
  `cleanup.sh:39`; spec-anti-scope ("no shared template") respected.
- `tests/skills-surface.test.sh` — PASS (75/75) — `implement/SKILL.md`
  edits did not break declared surface invariants.
- `tests/ralph-loop-bounds.test.sh` — PASS (23/23) — termination
  taxonomy intact.
- `tests/perf-quickwins-part-2.test.sh` — PASS — Generator/Validator
  contracts undisturbed.
- `tests/perf-quickwins-part-3.test.sh` — PASS — model resolution
  contracts undisturbed.
- `tests/ack-sensors-inferential.test.sh` — PASS — judge-verdict
  paths still resolved through paths.sh helpers.

## Positive Deviations from Spec

- **Reused `wm_wipe_runtime` from `lib/working-memory/paths.sh:239-245`
  instead of re-implementing the wipe primitive in `cleanup.sh`.**
  The spec described `wm_runtime_cleanup` as the wipe function; the
  pre-existing `wm_wipe_runtime` already implements
  `find "$WM_RUNTIME_DIR" -mindepth 1 -delete` with idempotent
  directory recreation. Treating `wm_runtime_cleanup` as a *gate*
  around that primitive (rather than a fresh implementation)
  removes a duplication risk and aligns with the craftsmanship DoD.
  No spec field violated.

## Gaps

None. All 6 DoD checks pass; all referenced patterns and conventions
respected; all impacted tests green.

## Verdict

**PASS** — Ready to ship.

Files changed (3 of ≤ 4 budget):
1. `lib/working-memory/cleanup.sh` (NEW, 94 lines)
2. `skills/implement/SKILL.md` (preflight + termination wiring + anti-pattern)
3. `tests/working-memory.test.sh` (4 new assertions added)
