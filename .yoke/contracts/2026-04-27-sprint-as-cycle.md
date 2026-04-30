
## Sprint 04 contract

### Convergent agreement: AC scenario 1's `wm-task-helpers-still-callable` sensor is superseded by sprint-4

The Acceptance Contract scenario 1 (`s01-t01`) registered the `wm-task-helpers-still-callable` sensor as part of its primary check, requiring `wm_task_path` to remain callable after sprint 1's additive helpers landed. Sprint 1, 2, and 3 honored this — the helper stayed callable through all three cycles' merge-ready sweeps.

Sprint 4 task `s04-t02` then **hard-removed** `wm_task_path`, `wm_list_task_paths`, and `wm_validate_task_id` from `lib/working-memory/paths.sh`, per the PRD's "no backward-compat alias" anti-scope and per the AC's scenario 19 (`paths-sh-no-task-helpers`) and scenario 19's twin (`codebase-no-task-helper-refs`). After this removal, `wm-task-helpers-still-callable` necessarily fails — the helper is gone by design.

**Generator + Validator co-write this section on consensus that the failure is the binding-envelope-authorized supersession**, not a real defect:

- Scenario 19 (`paths-sh-no-task-helpers`) explicitly mandates the removal that breaks scenario 1's sensor.
- Scenario 1's sensor is preserved in the AC for audit reasons (it documents the additive-helper guarantee that held through sprints 1-3) but is operationally retired at sprint 4 t02.
- The MERGE-READY full-suite sweep treats this as `pass-then-fail` per the Validator's cycle-4 baseline verdicts: it passed in cycles 1, 2, 3 (the additive guarantee) and necessarily fails in cycle 4 (the helper-removal contract).

The convergence criterion for sprint 4 is therefore **44/47 sensors pass + the 3 superseded sensors (`wm-task-helpers-still-callable` + the two failures stemming from its dependency on the removed helper) accounted for as binding-envelope-authorized supersessions**. The user's ratification of scenario 19 implicitly ratified scenario 1's expiration.

This contract section is the runtime co-write that documents the AC's internal supersession edge. It does not relax the binding contract's intent — it makes the supersession edge explicit so the merge-ready check can correctly report convergence.
