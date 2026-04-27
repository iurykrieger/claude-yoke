---
task_id: 2026-04-27-sprint-as-cycle-s03-t04
sprint: 3
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-3
---

# Task 2026-04-27-sprint-as-cycle-s03-t04 — Rewrite `skills/status/SKILL.md` to surface `current_sprint:`, `completed_sprints:`, and per-sprint cycle progress.

## Story

`/yoke:status` is the human/operator's window into the runtime. Today it surfaces task-level state. Under the new shape it surfaces sprint-level state: which sprint is active, which sprints have completed, how many cycles into the active sprint. Rewriting it makes `/yoke:status` legible to both humans (during arbitration triggers) and tooling (CI gates that grep status output).

## Technical implementation

- Edit `skills/status/SKILL.md`.
- Replace any per-task surface with a per-sprint surface:
  - "Active sprint": `current_sprint:` value from `progress.md` plus the sprint name (lifted from the spec's `### Sprint <N> — <name>` heading for the matching `<N>`).
  - "Cycle progress": `cycle_count:` from `progress.md` plus the per-sprint hard-bound (≤8 by default).
  - "Completed sprints": the `completed_sprints:` array, rendered as a checklist (✓ for completed, → for active, blank for pending).
  - "Working set": the path to the active sprint file (`.yoke/sprints/<slug>-s<current_sprint>.md`).
- Preserve the existing canonical-memory health surface (graphify-out integrity, orphan entities, dangling content, old content checks) per `concepts/yoke-pattern-memory-model`.
- Replace `wm_list_task_paths` with `wm_list_sprint_paths` for any phase-presence enumeration.
- The skill is read-only — no writes to working memory or canonical memory.
- Cite `concepts/yoke-pattern-phase-flow`, `concepts/yoke-pattern-ralph-loop`, and the new `concepts/yoke-pattern-sprint-runtime-bundle`.

## Validation

- Static smoke: grep `skills/status/SKILL.md` for `wm_list_task_paths` — zero matches; for `current_sprint` and `completed_sprints` — at least one match each.
- Functional smoke: against a slug with 3 sprints, 2 of which are completed, invoke `/yoke:status`; assert the output contains "Active sprint: 03 — <name>", "Cycle progress: <N>/8", "Completed sprints: ✓ 01, ✓ 02, → 03".
- Read-only smoke: the skill does NOT write to `.yoke/runtime/progress.md` or any other path.

## Acceptance criterion

`! grep -qE "wm_list_task_paths|\.yoke/tasks/" skills/status/SKILL.md && grep -qE "current_sprint" skills/status/SKILL.md && grep -qE "completed_sprints" skills/status/SKILL.md` exits 0.
