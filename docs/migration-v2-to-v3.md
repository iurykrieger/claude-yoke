# Migrating from Yoke v2.x to v3.0

> **Migration note:** drain in-flight v2.x cycles before upgrading.

That is the entire migration. There is no formal runbook.

## Why no runbook

Per `2026-05-01-agent-council` PRD Resolved 10 ("No backward
compatibility commitment"), Yoke does not promise to interoperate
v2.x runtime artifacts with v3.0 runtime artifacts. The v3.0 council
protocol replaces the v2.x binary loop in place; per-cycle working
memory under `.yoke/runtime/cycles/<N>/<persona>.md` is a new shape
that the v2.x runtime never produced, and the legacy v2.x agent
files (the binary-loop pair under `agents/`) are deleted.

A loop that is **already running** under v2.x at the moment of
upgrade has no migration path: its per-cycle progress entries assume
the binary-loop shape (`citing_criterion:` for one-criterion cycles,
v2.x `Generator → Validator → Orchestrator` Task spawn order),
which the v3.0 coordinator does not interpret. **Drain it first.**

A loop that is **not yet started** at the moment of upgrade requires
no action: the next `/yoke:implement` invocation reads the same
working-memory artifacts (`prd.md`, `tech-spec.md`,
`acceptance-contract.md`, sprint files) that v2.x produced, then
drives them through the council protocol from cycle 1 onward.

## How to drain

If `/yoke:implement` is mid-loop on v2.x, finish it before upgrading
the plugin:

1. Let the current task converge to merge-ready (every Acceptance
   Contract criterion passes), trigger Trigger 4 (user resolves), or
   trigger the hard bound (escalation halts the loop). Any of the
   three terminates the v2.x loop cleanly and emits the canonize
   handoff.
2. Verify `.yoke/runtime/progress.md` shows full convergence
   (`completed_sprints:` length equals `total_sprints:`) or carries
   the escalation packet.
3. Upgrade the plugin to v3.0 via your marketplace.
4. The next `/yoke:implement` invocation runs the council protocol
   on the next task.

## What changes between v2.x and v3.0

The shipped surface, the binding contract, and the canonical-memory
provider configuration are identical. What changes is **how
`/yoke:implement` runs each cycle**:

- **v2.x** — single Task batch spawning Generator + Validator +
  Orchestrator (consult + monitor) in parallel; single
  `progress.md` cycle entry per cycle; `contracts.md` co-written on
  consensus.
- **v3.0** — single Task batch spawning Sr Eng + Sr QA + Sr Staff
  in parallel behind a deterministic sync barrier (Phase A); a
  bounded council loop with the contradiction-detection arbiter
  (Phase B); cycle entry on consensus or Trigger 4 on cap-exhausted
  divergence (Phase C). Per-cycle slices land at
  `.yoke/runtime/cycles/<N>/<persona>.md`; `progress.md` records
  the round count and exit status per cycle.

The Orchestrator subagent (`agents/orchestrator.md`) survives in
canonize-only mode for the full-run termination handoff; its
legacy `consult` and `monitor` modes are retired.

## See also

- `docs/architecture.md :: ## Council protocol` — text diagram of
  Phase A → Phase B → Phase C and the persona/arbiter dispatch.
- `CLAUDE.md :: ## Architecture` — repo-internal description of the
  council protocol (referenced from the v3.0 architecture overview).
- `docs/migration-v1-to-v2.md` — the v1.x → v2.x upgrade runbook
  (provider extraction; still applies if you are skipping from v1.x
  to v3.0 — perform the v1→v2 steps first, drain v2.x cycles, then
  upgrade to v3.0).
- `.yoke/prds/2026-05-01-agent-council.md` — the source PRD.
- `.yoke/acceptance-contracts/2026-05-01-agent-council.md` — the
  binding Acceptance Contract that operationally defined "done" for
  the v3.0 cutover.
