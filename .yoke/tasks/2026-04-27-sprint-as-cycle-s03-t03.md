---
task_id: 2026-04-27-sprint-as-cycle-s03-t03
sprint: 3
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-3
---

# Task 2026-04-27-sprint-as-cycle-s03-t03 — Rewrite `skills/implement/SKILL.md` and `lib/ralph-loop/orchestrate.sh` to walk sprints serially: read `current_sprint:` from `progress.md`, load the matching sprint file as the cycle's working set, run ≤8 cycles to convergence, advance the pointer and reset the cycle counter on convergence.

## Story

The single load-bearing runtime change in this PRD: ralph cycles are now scoped per-sprint, not per-task. `/yoke:implement` walks sprint 1 → sprint 2 → … in lexical order, with `current_sprint:` in `progress.md` tracking position. Each cycle reads exactly one sprint file as its working set; convergence appends to `completed_sprints:` and advances the pointer. Hard-bound (≤8 cycles) applies per-sprint. This is the central rewrite that operationalizes "one sprint = one ralph cycle (up to ≤8 cycle attempts)".

## Technical implementation

- Edit `skills/implement/SKILL.md`:
  - Replace every reference to per-task file iteration with per-sprint walking. The cycle's working set = the active sprint file at `.yoke/sprints/<slug>-s<current_sprint>.md`.
  - Add the walk algorithm:
    1. Read `current_sprint:` from `.yoke/runtime/progress.md` frontmatter (default to `01` on first invocation).
    2. Load `.yoke/sprints/<slug>-s<current_sprint>.md` — abort if absent.
    3. Spawn the per-cycle Generator + Validator + Orchestrator subagents (existing pattern) with the sprint file as their working set.
    4. On convergence: append `<current_sprint>` to `completed_sprints:` in `progress.md`; increment `current_sprint:` (zero-padded); reset `cycle_count:` to 0; write the sprint contract section to `.yoke/contracts/<slug>.md` as `## Sprint <NN> contract`.
    5. On hard-bound exhaustion (`cycle_count` ≥ 8): emit Trigger 4 escalation packet keyed on the active sprint; do NOT advance the pointer.
    6. Repeat until `current_sprint:` exceeds the highest sprint number in the spec.
- Edit `lib/ralph-loop/orchestrate.sh`:
  - Update the cycle invocation to pass the active sprint file path (not per-task files).
  - Update the cycle counter to reset at sprint boundaries (read `current_sprint:` and `completed_sprints:` from `progress.md` to detect transitions).
  - Update the Trigger 4 packet shape to include `active_sprint: <NN>` instead of `active_task: <id>`.
- Preserve everything else: agent contracts, judge verdict aggregation, snapshot writing, the consult/monitor/canonize Orchestrator modes.
- Cite `concepts/yoke-pattern-ralph-loop`, `concepts/yoke-pattern-roles`, the new `concepts/yoke-pattern-sprint-runtime-bundle`, and `concepts/yoke-pattern-human-triggers` (Trigger 4).

## Validation

- Static smoke: grep `skills/implement/SKILL.md` for `wm_list_task_paths` and `.yoke/tasks/` — zero matches; for `current_sprint:` and `wm_sprint_path` — at least one match each.
- Static smoke: grep `lib/ralph-loop/orchestrate.sh` for `current_sprint:` — at least one match; for per-task iteration constructs — zero.
- Walk smoke: against a synthetic slug with 3 sprint files and trivial DoD (a no-op echo statement per sprint), invoke `/yoke:implement <slug>`; assert `progress.md` ends with `current_sprint: 04` (one beyond last sprint), `completed_sprints: [01, 02, 03]`, and the orchestrator exits cleanly.
- Hard-bound smoke: synthetic slug where sprint 2's DoD is unsatisfiable; assert the run exits with Trigger 4 escalation after 8 cycles on sprint 2; `current_sprint:` stays at `02`; `completed_sprints: [01]`.
- Cycle-counter-reset smoke: between sprint 1 and sprint 2 boundaries, `cycle_count:` reset to 0 (verifiable in `progress.md` snapshots).

## Acceptance criterion

`! grep -qE "wm_list_task_paths|\.yoke/tasks/" skills/implement/SKILL.md lib/ralph-loop/orchestrate.sh && grep -qE "current_sprint:" skills/implement/SKILL.md && grep -qE "current_sprint" lib/ralph-loop/orchestrate.sh` exits 0.
