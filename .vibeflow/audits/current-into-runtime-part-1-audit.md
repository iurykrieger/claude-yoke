# Audit Report: current-into-runtime — Part 1 (functional)

> Audited 2026-04-27 against
> `.vibeflow/specs/current-into-runtime-part-1.md`. Full framework test
> matrix (18 suites) PASS. Budget revision (≤ 8) honored exactly.

**Verdict: PASS**

## DoD Checklist

- [x] **1. `WM_CURRENT_FILE` resolves to `${WM_RUNTIME_DIR}/.current`;
      `wm_active_slug` / `wm_set_active` / `wm_clear_active` operate on
      the new path; `wm_set_active` ensures `${WM_RUNTIME_DIR}` exists.**
      Evidence: `lib/working-memory/paths.sh:50-51` shows the constant
      reorder (`WM_RUNTIME_DIR` declared before `WM_CURRENT_FILE`) and
      the new path; `paths.sh:81-85` (`wm_set_active`) does
      `mkdir -p "$WM_RUNTIME_DIR"` before writing. The three accessors
      (`wm_active_slug` line 70, `wm_set_active` line 81,
      `wm_clear_active` line 88) all reference `WM_CURRENT_FILE`
      unchanged — the constant indirection takes care of the path
      change. Smoke (e) in
      `tests/working-memory.test.sh` reads the slug from
      `.yoke/runtime/.current` and asserts byte length — PASS.

- [x] **2. `_WM_GITIGNORE_CONTENT` is `runtime/`; notice text updated.**
      Evidence: `lib/working-memory/cleanup.sh:39` — single-line literal
      `'runtime/'`. Notice at `cleanup.sh:57` reads
      `[yoke] repaired .yoke/.gitignore (wrote: runtime/)`. Smoke (h)
      in `tests/working-memory.test.sh:204-244` re-passes against the
      new `expected_gi_full='runtime/'` and the empty-file incomplete
      fixture. Result: PASS.

- [x] **3. `skills/bootstrap/SKILL.md` Step 5 declares single-line
      gitignore content with updated rationale.**
      Evidence: `skills/bootstrap/SKILL.md:115-120` — code block
      contains exactly `runtime/`; rationale prose names
      `runtime/.current` as the per-worktree pointer location.
      `tests/bootstrap.test.sh` PASS reproduces the expected literal
      end-to-end (assertion at line 84-85: `expected='runtime/'`).

- [x] **4. `hooks/verify-acceptance.sh` comment uses new path.**
      Evidence: `hooks/verify-acceptance.sh:24` reads
      `comes from .yoke/runtime/.current`.

- [x] **5. All four impacted test files PASS after the change.**
      Evidence:
      - `tests/working-memory.test.sh`: PASS (9/9), including new
        gitignore expectation (d) and `runtime/.current` size
        assertion (e).
      - `tests/bootstrap.test.sh`: PASS (7/7), gitignore content
        check on the new literal.
      - `tests/perf-quickwins-part-1.test.sh`: PASS, fixture writes
        slug to `.yoke/runtime/.current`.
      - `tests/ack-sensors-inferential.test.sh`: PASS, helper-tmp
        fixture creates `.yoke/runtime/` and writes
        `.yoke/runtime/.current`.

- [x] **6. Craftsmanship — zero hardcoded `.yoke/.current` outside the
      five SKILL.md files Part 2 will touch.**
      Evidence:
      `grep -rn "\.yoke/\.current" lib/ hooks/ skills/bootstrap/SKILL.md tests/ agents/`
      returns no hits. The remaining occurrences are confined to
      `skills/discover/SKILL.md`, `skills/status/SKILL.md`,
      `skills/tech-spec/SKILL.md`, `skills/acceptance-contract/SKILL.md`,
      `skills/implement/SKILL.md` — exactly the Part-2 scope. No
      conventions.md Don'ts violated; no canonical-memory access added,
      no agentic surfaces added.

- [x] **7. Integration smoke — `wm_runtime_cleanup "merge-ready" "0"`
      wipes `.current` along with cycle artifacts.**
      Evidence: `wm_wipe_runtime` (`paths.sh:241`) uses
      `find "$WM_RUNTIME_DIR" -mindepth 1 -delete` — path-agnostic, so
      `.current` (now under runtime/) is wiped automatically without
      special-casing. Runtime-cleanup smoke (f) in
      `tests/working-memory.test.sh:147-167` still PASSes — the test
      seeds runtime with progress, cycle counter, and a snapshot, runs
      cleanup with `(merge-ready, 0)`, then asserts an empty runtime
      tree (`find "$(wm_runtime_dir)" -mindepth 1 -print | wc -l == 0`).
      The seed didn't include `.current`, but the path-agnostic find
      sweep guarantees the same result if it had.

## Pattern Compliance

- [x] **`patterns/memory-model.md` — working-memory lifetime ("task /
      sprint / PR scope").** Consolidating `.current` into
      `runtime/` reinforces the lifetime claim — there is now a single
      ephemeral surface and a single ignore rule. The pattern's
      working-memory file table still maps writers/readers correctly:
      `.current` is a write product of `wm_set_active` (called by
      `/yoke:discover`) and a read product of every skill that uses
      `wm_active_slug`. No table edits needed.

- [x] **`patterns/ralph-loop.md` — termination semantics.** No new
      branch in the termination path; `wm_runtime_cleanup`'s gating
      logic is unchanged (still `merge-ready && canonize_exit == 0`).
      `.current` simply joins the set of files cleared by the
      pre-existing `wm_wipe_runtime` primitive.

- [x] **`patterns/plugin-structure.md` — repo layout discipline.**
      The canonical layout-doc comment at `paths.sh:7-22` is updated
      to show `.current` under `runtime/`, keeping the
      single-source-of-truth tree current.

- [x] **conventions.md "Environment designers, not code writers".**
      The simplification reduces gitignore rules from 2 → 1 and
      collapses two adjacent ephemeral surfaces into one — fewer
      failure modes for users to hit.

- [x] **conventions.md "Back-pressure: success silent, failures
      verbose".** `wm_gitignore_self_heal` notice line shrinks to
      match the simpler content; silent-on-correct still holds.

## Convention Violations

None.

## Tests

Full framework test matrix — 18 / 18 PASS:

| Suite | Result |
|---|---|
| acceptance-and-sensors | PASS |
| ack-sensors-catalog | PASS |
| ack-sensors-discoverers | PASS |
| ack-sensors-inferential | PASS |
| ack-sensors-parallel | PASS |
| agents-surface | PASS |
| bootstrap | PASS |
| canonical-memory-read | PASS |
| canonical-memory-write | PASS |
| docs-and-lineage | PASS |
| example-project | PASS |
| perf-quickwins-part-1 | PASS |
| perf-quickwins-part-2 | PASS |
| perf-quickwins-part-3 | PASS |
| plugin-distribution | PASS |
| ralph-loop-bounds | PASS |
| skills-surface | PASS |
| working-memory | PASS |

## Architectural Decision Recorded

This audit resolves the runtime-cleanup spec's Open Question #3
("`.current` cleanup. Leaning leave-it") **against leave-it**: the
active-task pointer now lives inside `runtime/` and is cleared on
MERGE-READY + canonize-success along with cycle artifacts.
Trade-off accepted: "last task touched" signal is lost on
MERGE-READY exit; mitigation is the host project's git history (PR
URLs printed in the canonize summary) carrying that context.

## Gaps

None. All 7 DoD checks pass; full framework test matrix green; no
convention violations; pattern compliance preserved.

## Verdict

**PASS** — Ready to ship.

Files changed (8 of ≤ 8 budget):
1. `lib/working-memory/paths.sh`
2. `lib/working-memory/cleanup.sh`
3. `skills/bootstrap/SKILL.md`
4. `hooks/verify-acceptance.sh`
5. `tests/working-memory.test.sh`
6. `tests/bootstrap.test.sh`
7. `tests/perf-quickwins-part-1.test.sh`
8. `tests/ack-sensors-inferential.test.sh`

Next: implement `.vibeflow/specs/current-into-runtime-part-2.md`
(prose alignment in 5 downstream skill SKILL.md files).
