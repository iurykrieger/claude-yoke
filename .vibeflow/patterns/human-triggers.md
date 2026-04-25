---
tags: [hitl, gates, approval, arbitration, ratification, triggers]
modules: []
applies_to: [workflow, agents, ratification-ux, fatigue-monitoring]
confidence: validated
---
# Pattern: Five Distinct Human-in-the-Loop Triggers

<!-- vibeflow:auto:start -->
## What
Yoke invokes the human at **five distinct triggers** with different origins,
urgencies and escalation paths. Coalescing them into a single "needs review"
event loses critical information and overloads the same human role with
incompatible decisions.

## Where
Triggers 1–3 close Phases 1–3 as gates. Trigger 4 fires from Phase 4 only on
exceptional conditions (divergence, contract conflict, hard bound). Trigger 5
fires from Phase 5 (canonization) and follows Model C — non-blocking by
default.

## The Pattern

### Trigger 1 — PRD approval
- **Origin:** end of Phase 1.
- **Nature:** does the Generator correctly understand the user's intent?
- **Urgency:** blocks Phase 2.
- **Decision:** approve / request revision / restart.

### Trigger 2 — Tech Spec approval
- **Origin:** end of Phase 2.
- **Nature:** is the technical approach, sprint breakdown and acceptance criteria sound?
- **Urgency:** blocks Phase 3.
- **Decision:** approve / request revision / go back to PRD.

### Trigger 3 — Acceptance Contract ratification
- **Origin:** end of Phase 3.
- **Nature:** does this Contract correctly define "done" — tests, fixtures, policies?
- **Urgency:** blocks Phase 4.
- **Decision:** ratify / request revision / go back to Tech Spec.

### Trigger 4 — Implementation↔Validation divergence arbitration
- **Origin:** the runtime loop (Phase 4).
- **Nature:** technical viability, quality/policy, or business need are in conflict.
- **Urgency:** blocks task progress.
- **Escalation:** spec author or area tech lead.
- **Decision:** reformulate Acceptance Contract / reformulate Tech Spec / accept trade-off / abort.
- **Longitudinal signal:** recurring divergences in similar specs → Orchestrator proposes template or pattern updates.

### Trigger 5 — Canonization ratification
- **Origin:** Phase 5 (post-implementation).
- **Nature:** canonize a new pattern, policy, or template adjustment.
- **Urgency:** non-blocking — system continues operating.
- **Escalation:** depends on Model C — low impact auto-applied, medium notifies-and-applies, high requires synchronous ratification.
- **Decision:** accept / reject / amend the proposition.
- **Longitudinal signal:** human rejection rate of propositions → Orchestrator calibration.

### Per-trigger metrics (fatigue monitoring)
- **Average time spent per ratification.** Decreasing over time can signal rubber-stamping.
- **Modification rate.** If the human never edits the proposition, they may not be reviewing.
- **Per-trigger volume.** Use to rate-limit Orchestrator propositions when fatigue is detected.

## Rules
- Triggers 1, 2 and 3 are blocking gates. The flow does not advance without an explicit decision.
- Trigger 4 is reactive — the Orchestrator only escalates on the four divergence categories or on hard bounds. It is never a routine check.
- Trigger 5 follows Model C. Synchronous ratification is reserved for high-impact and regulatory writes.
- Each trigger has its own UI surface and audit log. Coalescing them is a smell.
- Time-spent and modification-rate metrics are tracked per trigger and per ratifier. Drops trigger calibration review of the Orchestrator's auto-apply thresholds.
- Recurring divergences (Trigger 4) are an Orchestrator input — not a human burden to absorb without feedback.

## Examples from this codebase
> Repository is empty. Expected per-trigger artifact shapes:

```
trigger-1 (PRD)            → review of prd.md, list of pending questions
trigger-2 (Tech Spec)      → review of tech-spec.md, sprint-by-sprint plan
trigger-3 (Contract)       → review of acceptance-contract.md, BDD scenarios + sensors
trigger-4 (Divergence)     → arbitration packet: state of progress.md + contracts.md
                              + the unresolved sprint contract + the divergence category
trigger-5 (Canonization)   → PR on the canonical substrate (Model C controls auto-merge)
```

<!-- vibeflow:auto:end -->

## Anti-patterns
- A single "approval queue" combining all five triggers — destroys urgency differentiation, drives fatigue.
- Routing Trigger 4 to a generic reviewer instead of the spec author or tech lead — context loss, slower resolution.
- Skipping Trigger 3 because "the Tech Spec is good enough" — collapses binding semantics of the Acceptance Contract.
- Setting Trigger 5 to always-synchronous — Model C's whole point is to scale canonization without bottlenecking on humans.
- Not tracking modification rate — the cheapest fatigue indicator goes unused.

## Implementation Mapping

From `yoke-implementation-plan.md` (2026-04-24) — concrete artifacts per trigger:

| Trigger | Surface | Artifact |
| :--- | :--- | :--- |
| 1 — PRD approval | `/yoke:discover` end-of-skill prompt | trigger-1 schema |
| 2 — Tech Spec approval | `/yoke:tech-spec` end-of-skill prompt | trigger-2 schema |
| 3 — Acceptance Contract ratification | `/yoke:acceptance-contract` end-of-skill prompt | trigger-3 schema with binding statement |
| 4 — Divergence arbitration | `lib/ralph-loop/escalate.sh` | trigger-4 packet: `progress.md` + `contracts.md` + unresolved sprint contract + divergence category |
| 5 — Canonization ratification | PR opened by `lib/canonical-memory/propose-write.sh` (Model C controls auto-merge) | trigger-5 PR with `yoke-proposal` + impact label |

Each trigger has a distinct schema — they are not coalescable into a single
"approval" event. Sprint-6 formalizes the per-trigger schemas.
