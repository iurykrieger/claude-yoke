---
task_id: 2026-04-27-sprint-as-cycle-s02-t05
sprint: 2
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-2
---

# Task 2026-04-27-sprint-as-cycle-s02-t05 — Run `lib/sensors/legacy-parts-zero-residual.sh` over `.yoke/specs/` and `.yoke/tasks/` (excluding this spec's own task files); assert zero `-part-N.md` matches under `.yoke/specs/` and zero `2026-04-27-yoke-doctrine-canonization-s*-t*.md` matches under `.yoke/tasks/`.

## Story

The migration sprint's last task verifies the on-disk shape post-migration before sprint 2 can converge. The Validator will run this same sensor automatically each cycle, but having an explicit task for it makes the convergence criterion legible: if this task fails, sprint 2 is not done. The sensor's check is intentionally scoped to exclude this spec's own task files (which migrate in sprint 4) — those produce expected violations until that point.

## Technical implementation

- Invoke `bash lib/sensors/legacy-parts-zero-residual.sh` from the repo root, capturing stdout (newline-delimited JSON violations) and exit code.
- Filter the violation stream to exclude paths matching `.yoke/tasks/2026-04-27-sprint-as-cycle-s*-t*.md`:
  - Use `jq` to filter: `jq -c 'select(.location | test(".yoke/tasks/2026-04-27-sprint-as-cycle-s") | not)' < <output>`.
  - If `jq` is not available in the runtime, fall back to a `grep -v` against the JSON line text targeting the same path pattern (less rigorous; flag in stderr if applied).
- Count the filtered violations. If the count is non-zero, fail the task with a clear `wm: sprint-2 migration incomplete; <N> residual violations:\n<violations>` message and exit non-zero.
- If zero filtered violations, success: emit `wm: sprint-2 migration verified — zero residual -part-N.md or doctrine-canonization task files`.
- Cite `concepts/yoke-pattern-sensors` for the structured-output contract.
- This task does NOT modify any files. It is a verification gate.

## Validation

- Pre-condition smoke: t01 backup exists, t02 + t03 spec parts moved, t04 doctrine-canonization tasks concatenated.
- Functional smoke: filtered violation count is exactly 0.
- Negative smoke: temporarily restore one `-part-N.md` file from the legacy archive; re-run the sensor with this filter; assert it now reports 1 violation; remove the restored file; re-run; assert 0 violations again.
- Reporting smoke: the success message includes the timestamp and the migration sprint reference (`sprint-2-of-2026-04-27-sprint-as-cycle`).

## Acceptance criterion

`bash -c 'bash lib/sensors/legacy-parts-zero-residual.sh 2>/dev/null | jq -c "select(.location | test(\".yoke/tasks/2026-04-27-sprint-as-cycle-s\") | not)" | wc -l'` returns `0`.
