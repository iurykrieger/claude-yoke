---
task_id: 2026-05-05-cycle-counter-reset-on-sprint-advance-s01
sprint: 1
slug: 2026-05-05-cycle-counter-reset-on-sprint-advance
status: approved
created_at: 2026-05-05T19:02:53Z
model: ""
traceability: ".yoke/specs/2026-05-05-cycle-counter-reset-on-sprint-advance.md; .yoke/acceptance-criteria/2026-05-05-cycle-counter-reset-on-sprint-advance.md"
Migrated-from: []
---

# Sprint 01 of 01: reset `.cycle-counter` on sprint advance

> Hand-composed sprint runtime bundle (Phase 2.5 parser shim — see
> `.yoke/runtime/.generate-sprints-plan.yaml` for the parser
> mismatch encountered during this run). All four user stories share
> a single logical surface (`lib/working-memory/paths.sh` plus
> `skills/implement/SKILL.md` plus a new smoke test) and ship as one
> cohesive sprint per the `applies_decisions` overlap rule of
> `concepts/yoke-pattern-sprint-runtime-bundle`. Sprint files are
> runtime bundles, not sources of truth — sources of truth (Acceptance
> Criteria entries, sensor logic) stay authoritative in their own
> files; this sprint references them by ID and never inlines their
> bodies. Cite `concepts/yoke-pattern-memory-model` and
> `concepts/yoke-pattern-sprint-runtime-bundle` for the load-bearing
> invariants.

## Sprint objective

Restore the documented sprint-advance reset of
`.yoke/runtime/.cycle-counter` by adding a deterministic helper
(`wm_reset_cycle_counter`) inside `lib/working-memory/paths.sh`,
documenting its invocation in the council coordinator's
sprint-advance prose at `skills/implement/SKILL.md`, and pinning the
contract with a behavior smoke test under `tests/smoke/`. The fix is
narrowly scoped to honor the `≤ 8-cycles-per-sprint` guarantee
declared in `concepts/yoke-pattern-sprint-runtime-bundle`; the dual
source of truth between `progress.md :: cycle_count` and
`.cycle-counter` is preserved as-is and stays under issue #14.

## Sprint DoD

- `grep -n '^wm_reset_cycle_counter()' lib/working-memory/paths.sh` returns exactly one match.
- `grep -c 'wm_reset_cycle_counter' skills/implement/SKILL.md` returns ≥ 1.
- `test -x tests/smoke/cycle-counter-reset-on-sprint-advance.test.sh && bash tests/smoke/cycle-counter-reset-on-sprint-advance.test.sh` exits 0.
- `find .yoke/sprints -name '2026-05-05-cycle-counter-reset-on-sprint-advance-s*.md' | wc -l` equals 1.
- `shellcheck lib/working-memory/paths.sh` reports no new warnings vs. the pre-fix baseline.

## Tasks

### Task 2026-05-05-cycle-counter-reset-on-sprint-advance-s01-t01

**Story:** Provide a deterministic `.cycle-counter` reset primitive in `lib/working-memory/paths.sh` so the sprint-advance code path has a single deterministic call to zero the runtime counter. (Realizes: US-001)

**Technical implementation:** Add a new function
`wm_reset_cycle_counter` to
`lib/working-memory/paths.sh`, immediately below
`wm_cycle_counter_path` (line 407) inside the existing `# --- runtime
paths ---` region. Body sequence: (1) resolve target via
`wm_cycle_counter_path`; (2) `mkdir -p "$(dirname "$target")"` to
create the runtime dir if absent (post-`wm_wipe_runtime` state);
(3) `printf '0' > "$target"` (no trailing newline, mirroring
`wm_set_active`'s convention at line 96–117); (4) on filesystem
error, surface a `wm:`-prefixed stderr line and exit non-zero. The
function takes no arguments; the contract is fixed by the existing
`wm_cycle_counter_path()` resolver. Inherits the
`concepts/yoke-pattern-plugin-structure` rule — the `lib/working-
memory/paths.sh` file is the canonical home for `wm_*` helpers.

**Validation:** Source the file in a fresh shell and call
`wm_reset_cycle_counter` against three preconditions:
runtime dir absent, `.cycle-counter` already at `0`, `.cycle-counter`
seeded to `7`. Each call must end with the file containing exactly
the byte `0` and no other side effect (no write to `progress.md`, no
spurious file under `.yoke/runtime/`). The behavior smoke test in
task t04 pins these assertions.

**Acceptance criterion:** AC-001-1 ∧ AC-001-2 ∧ AC-001-3 ∧ AC-001-4 from `.yoke/acceptance-criteria/2026-05-05-cycle-counter-reset-on-sprint-advance.md` all pass.

### Task 2026-05-05-cycle-counter-reset-on-sprint-advance-s01-t02

**Story:** Document the new helper as part of the sprint-advance contract in `skills/implement/SKILL.md` so the council coordinator (an LLM) discovers the deterministic primitive without reverse-engineering it. (Realizes: US-002)

**Technical implementation:** Amend the prose in
`skills/implement/SKILL.md` at lines 74, 193, and 425–428 (the
sprint-advance bullets in the framework prose, the inner-cycle pseudo-
code's reset bullet, and the per-sprint-convergence step-9 narrative).
Each touch point names `wm_reset_cycle_counter` alongside the existing
`cycle_count: 0` frontmatter reset, so a future contributor reading
the prose discovers the deterministic primitive. The amendment is
markdown text; no schema changes. The amendment must place the helper
invocation **after** the `completed_sprints:` append and the
`current_sprint:` increment in step 9's sequence (not before — placing
it before would zero the counter mid-sprint per AC-001-4 risk in the
fix-spec).

**Validation:** `grep -n 'wm_reset_cycle_counter' skills/implement/SKILL.md` returns ≥ 1 match. The amended prose preserves the file's existing H2 structure (no `## Sprints` section, no `### Task` anchors introduced). The amendment does not contradict `concepts/yoke-pattern-sprint-runtime-bundle` (canonical memory) — sprint advance still resets the counter; hard-bound exhaustion still fires Trigger 4 keyed on the active sprint.

**Acceptance criterion:** AC-002-1 ∧ AC-002-2 ∧ AC-002-3 from `.yoke/acceptance-criteria/2026-05-05-cycle-counter-reset-on-sprint-advance.md` all pass.

### Task 2026-05-05-cycle-counter-reset-on-sprint-advance-s01-t03

**Story:** Ensure `hooks/check-hard-bounds.sh` observes a per-sprint cycle count (not cumulative cross-sprint) by relying on the new helper invocation from the prose-driven coordinator. (Realizes: US-003)

**Technical implementation:** No code change in
`hooks/check-hard-bounds.sh` or `lib/ralph-loop/status-snapshot.sh`
(both are read-only consumers of `wm_cycle_counter_path()` and stay
unchanged). This task is a downstream observable of t01 + t02 — it
asserts that the helper plus the prose update together cause the
hook to read `0` at the start of every sprint after the first. The
implementation is t01 and t02; this task captures the cross-cutting
contract that the consumer behavior is restored without consumer
edits.

**Validation:** Two checks: (a) a manual or scripted simulation of
sprint advance against an isolated `WM_RUNTIME_DIR` shows
`hooks/check-hard-bounds.sh` reading `0` at the first iteration of
the next sprint (covered by the smoke test in t04 indirectly); (b)
single-sprint tasks (only `*-s01.md` exists) observe identical
behavior to the pre-fix baseline (zero regression on
`current_sprint == 01`). The validation is by-construction: the
helper is only invoked by the coordinator on sprint advance, which
the coordinator only triggers when `current_sprint > 01`.

**Acceptance criterion:** AC-003-1 ∧ AC-003-2 ∧ AC-003-3 from `.yoke/acceptance-criteria/2026-05-05-cycle-counter-reset-on-sprint-advance.md` all pass.

### Task 2026-05-05-cycle-counter-reset-on-sprint-advance-s01-t04

**Story:** Pin the helper's contract with a behavior smoke test under `tests/smoke/` so a regression in the file-side reset is caught by CI. (Realizes: US-004)

**Technical implementation:** Create a new file
`tests/smoke/cycle-counter-reset-on-sprint-advance.test.sh`. The
test: (1) installs the documented internal watchdog (`sleep 600 &&
kill -TERM $$ &`) per `CLAUDE.md :: ## Testing`; (2) creates a
temporary `WM_RUNTIME_DIR` via `mktemp -d` and exports the override
so the test cannot pollute the worktree's actual `.yoke/runtime/`;
(3) sources `lib/working-memory/paths.sh`; (4) exercises three
cases — runtime dir absent (helper creates `.cycle-counter == 0`),
file at `0` (idempotent), file at `7` (overwrite to `0`); (5) seeds
a non-zero value before each non-absent case so a coincidentally-zero
counter cannot hide a missing helper invocation; (6) asserts no file
beyond `.cycle-counter` is written under the temporary runtime dir;
(7) cleans up the temp dir and exits 0. The test is named for the
behavior it asserts (per the `CLAUDE.md` testing convention) — not
for a sprint number.

**Validation:** Run the test in isolation: `bash tests/smoke/cycle-counter-reset-on-sprint-advance.test.sh` exits 0 and completes in ≤ 10s wall-clock. Inverting the `wm_reset_cycle_counter` body (e.g. removing the `printf '0'`) makes the test fail — i.e. the test actually measures the contract, not a coincidence. The watchdog is the safety bound (≤ 600s), not the target.

**Acceptance criterion:** AC-004-1 ∧ AC-004-2 ∧ AC-004-3 ∧ AC-004-4 ∧ AC-004-5 ∧ AC-004-6 from `.yoke/acceptance-criteria/2026-05-05-cycle-counter-reset-on-sprint-advance.md` all pass.

> **US-trace clause.** Every Task's `**Story:**` line above ends with
> the canonical `(Realizes: US-<NNN>)` clause anchored to the binding
> Acceptance Criteria document at
> `.yoke/acceptance-criteria/2026-05-05-cycle-counter-reset-on-sprint-advance.md`.
> Cite `concepts/yoke-pattern-sprint-runtime-bundle` Rule 1
> (reference-by-ID, never inline) — the AC bodies stay in the AC.

## Functional acceptance criteria

- AC-001-1
- AC-001-2
- AC-001-3
- AC-001-4
- AC-002-1
- AC-002-2
- AC-002-3
- AC-003-1
- AC-003-2
- AC-003-3
- AC-004-1
- AC-004-2
- AC-004-3
- AC-004-4
- AC-004-5
- AC-004-6
- FR-1
- FR-2
- FR-3
- FR-4
- FR-5
- FR-6

## Sensors

- tests-smoke
- lint
- code-review
- build
- llm-as-judge
