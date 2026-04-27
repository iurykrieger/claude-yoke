# Spec: Yoke v1 — Sprint 6 — Hard bounds + 5 triggers + full Model C + progressive disclosure

> Generated via /vibeflow:gen-spec on 2026-04-24
> PRD: `.vibeflow/prds/yoke-v1.md`
> Plugin version target: 0.6.0

## Objective

Complete the manifesto's core governance. Hard bounds are enforced;
the five human triggers fire with distinguishable schemas; medium- and
high-impact Model C paths work; canonical-memory queries return only
the relevant subgraph.

## Context

After this sprint Yoke is "minimally usable end-to-end for small
projects" — runtime is bounded, governance is contextual, and queries
don't blow up the agent's context. Sprint 7 adds drift sensing on top
of this foundation; Sprint 8 packages and ships.

## Definition of Done

1. `hooks/check-hard-bounds.sh` enforces N cycles + timeout + token
   budget per `.yoke/config.yaml` (defaults N = 5–8 cycles, timeout
   2–4 h). Per-project overrides are honored.
2. Reaching any bound triggers `lib/ralph-loop/escalate.sh` (Trigger 4)
   with a structured arbitration packet (progress, contracts, the
   unresolved sprint contract, divergence category) — does NOT abort
   the task; preserves state for human arbitration.
3. The five triggers fire with non-coalescable schemas — verifiable: a
   diff between any two trigger messages shows distinct fields.
4. Medium-impact PRs comment-announce the veto window (default 24 h)
   and auto-merge only after the window closes without objection.
5. High-impact PRs are opened with `auto-merge: never` and require
   explicit human approval; regulatory PRs are routed to Compliance
   reviewers via `CODEOWNERS`-style configuration in the canonical repo.
6. `lib/canonical-memory/query.sh` returns a subgraph (≤ 10 entries)
   even on a synthetic 1000-entry canonical memory; query latency < 2s.
7. **Craftsmanship gate:** `tests/smoke/sprint-6.test.sh` exercises all
   three (hard-bound hit → Trigger 4; medium-impact veto window;
   progressive-disclosure query); impact-class rules are documented in
   the Orchestrator skill prompt and traceable; no `conventions.md`
   Don'ts violated.

## Scope

- `hooks/check-hard-bounds.sh`.
- `lib/ralph-loop/escalate.sh` — emits the Trigger-4 arbitration packet.
- Update `lib/canonical-memory/propose-write.sh` for medium- and
  high-impact paths (veto window comment, `auto-merge: never`,
  Compliance routing).
- Update `lib/canonical-memory/query.sh` with subgraph traversal
  (`depends_on`, `supersedes`, `applies_to`, `contradicts_with`).
- Update Orchestrator skill prompt with explicit impact-classification
  rules.
- Update relevant skills to emit per-trigger schemas (Triggers 1–5).
- `docs/architecture.md` includes the Model C table.
- `tests/smoke/sprint-6.test.sh`.

## Anti-scope

- Drift sensing / Phase 6 — Sprint 7.
- Adversarial canonical-memory audit — out of v1.0 entirely (planned
  extension §17).
- Performance optimization beyond < 2 s on 1000 entries.
- Per-task-class hard-bound profiles — single profile in v1.0 (PRD
  Open Question 4); per-class deferred.
- Backfill of existing low-impact PRs into the new schemas — Sprint-5
  PRs stay as-is.

## Technical Decisions

- **Single hard-bound profile in v1.0** with `.yoke/config.yaml`
  overrides. Trade-off: misses small/medium/large differentiation;
  Sprint 8 example tunes per project size.
- **Subgraph traversal depth** configurable via
  `.yoke/config.yaml` (default depth 2). Trade-off: deeper graphs blow
  context; depth 2 covers `depends_on` chains adequately for current
  schema.
- **Veto-window length configurable** (default 24 h). Trade-off: shorter
  windows accelerate canonization but reduce real review.
- **Impact classification rules live in the Orchestrator skill prompt**
  (auditable; visible in `query-trace.md`). Trade-off: prompt size vs.
  governance transparency.
- **Subgraph awareness tightens criterion 5 (non-contradiction):** must
  check loaded subgraph for `contradicts_with` edges before proposing.
- **Compliance routing via `CODEOWNERS`** in the canonical repo. Trade-off:
  requires a `CODEOWNERS` convention; documented in
  `docs/canonical-memory-setup.md`.

## Applicable Patterns

- `model-c-governance.md` — full path (all impact classes); PR labels;
  veto windows.
- `human-triggers.md` — all five triggers with their distinct schemas.
- `ralph-loop.md` — hard bounds; Trigger-4 arbitration packet shape;
  divergence categories.
- `memory-model.md` — graph relationships; subgraph traversal.

No new patterns introduced.

## Risks

- **R2 — query latency.** If Sprint-5 measurement showed borderline
  latency, Sprint 6 may need a SQLite index. **Mitigation:** spec allows
  shipping without index if latency is < 2 s; index is v1.1 work.
- **R3 — hard bounds tuned wrong.** Single profile may chafe on
  non-trivial projects. **Mitigation:** Sprint 8 example tunes per
  project size; `.yoke/config.yaml` overrides documented.
- **Trigger-schema drift.** Coalescence creep over time. **Mitigation:**
  DoD #3 prompt-diff check; CI gate ships in Sprint 8.
- **Compliance routing not used in practice.** Without a real
  `CODEOWNERS` setup, regulatory PRs may auto-merge. **Mitigation:**
  `propose-write.sh` fails if `impact_level: regulatory` is set but no
  `CODEOWNERS` is found in the canonical repo.

## Dependencies

- `.vibeflow/specs/yoke-v1-sprint-5.md`
