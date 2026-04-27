---
task_id: 2026-04-27-sprint-as-cycle-s04-t03
sprint: 4
slug: 2026-04-27-sprint-as-cycle
status: approved
created_at: 2026-04-27T22:33:44Z
model: claude-opus-4-7[1m]
traceability: .yoke/specs/2026-04-27-sprint-as-cycle.md#sprint-4
---

# Task 2026-04-27-sprint-as-cycle-s04-t03 — Run `lib/sensors/legacy-parts-zero-residual.sh` globally and confirm zero `-part-N.md` under `.yoke/specs/` and zero `<slug>-s<NN>-t<MM>.md` under any directory in the working tree.

## Story

The closing verification: with all migrations done, the residual sensor must report a clean tree. This task removes the filter from sprint 2 t05 (which excluded this spec's own task files) and asserts an unfiltered zero-violation result. If this task fails, sprint 4 cannot converge — the migration is incomplete. The Validator runs this same sensor automatically, but having an explicit task makes the convergence criterion legible.

## Technical implementation

- Invoke `bash lib/sensors/legacy-parts-zero-residual.sh` from the repo root, capturing stdout (newline-delimited JSON violations) and exit code.
- Do NOT apply any filter — the sensor runs against the whole working tree.
- Assert exit code is 0 AND stdout is empty.
- If non-zero violations remain, fail the task with `wm: sprint-4 closing migration incomplete; <N> residual violations:\n<violations>` and exit non-zero.
- If clean, success: emit `wm: sprint-4 closing migration verified — zero residual legacy files anywhere in the working tree`.
- This task DOES NOT modify any files. It is a pure verification gate.
- Cite `concepts/yoke-pattern-sensors`.

## Validation

- Pre-condition smoke: t01 (own-spec migration) and t02 (helper removal) have committed.
- Functional smoke: sensor exits 0 with empty stdout.
- Sensor-correctness smoke: temporarily restore one `-part-N.md` from `.yoke/.legacy-archive/2026-04-27-pre-migration/specs/` to `.yoke/specs/`; re-run sensor; assert it reports 1 violation; remove the restored file; re-run; assert clean again. (The negative case validates the sensor isn't silently passing.)
- Filter-removal smoke: this task does NOT use the `jq` filter that sprint 2 t05 used; the invocation is a bare `bash lib/sensors/legacy-parts-zero-residual.sh` from the repo root.

## Acceptance criterion

`bash lib/sensors/legacy-parts-zero-residual.sh; [ $? -eq 0 ]` exits 0, AND `bash lib/sensors/legacy-parts-zero-residual.sh 2>/dev/null | wc -c` returns `0` (zero bytes of output, no violations).
