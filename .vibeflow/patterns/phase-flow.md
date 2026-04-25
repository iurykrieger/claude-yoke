---
tags: [workflow, phases, gates, per-task, drift-sensing, lifecycle]
modules: []
applies_to: [commands, agents, skills, workflow-orchestration]
confidence: validated
---
# Pattern: Phase Flow (5 Per-Task + 1 Continuous)

<!-- vibeflow:auto:start -->
## What
Yoke organizes development into **five sequential per-task phases** (Discovery,
Tech Spec, Acceptance Contract, Runtime, Canonization) and **one continuous
phase** (Drift Sensing) operating outside the change lifecycle. Each per-task
phase has a named human gate; Phase 6 runs in the background.

## Where
Every Yoke task threads through Phases 1→5 in order. Phase 6 runs concurrently
across the codebase, canonical memory and ephemeral traces. Each phase has a
typed input artifact (the previous phase's output) and a typed output artifact.

## The Pattern

### Per-task phases (sequential, with explicit human gates)

```
┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
│ Phase 1 │──│ Phase 2 │──│ Phase 3 │──│ Phase 4 │──│ Phase 5 │
│Discover │  │TechSpec │  │AcptCnt  │  │Runtime  │  │Canoniz. │
└─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘
```

| Phase | Owner | Input | Output | Gate |
| :--- | :--- | :--- | :--- | :--- |
| 1 — Discovery | Generator | raw idea | `prd.md` | Trigger 1 (PRD approval) |
| 2 — Tech Spec | Generator | approved PRD | `tech-spec.md` | Trigger 2 (Tech Spec approval) |
| 3 — Acceptance Contract | Validator | PRD + Tech Spec | `acceptance-contract.md` | Trigger 3 (Contract ratification) |
| 4 — Runtime | Orchestrator (spawns Implementation + Validation Agents) | approved Contract | merge-ready code + `progress.md` + `contracts.md` | Trigger 4 (only on divergence or bound) |
| 5 — Canonization | Orchestrator | full working memory | proposed writes to canonical memory | Trigger 5 (Model C ratification) |

### Continuous phase (out-of-lifecycle)

```
┌────────────────────────────────────────────────────────────┐
│                    Phase 6 — continuous                    │
│ ──── background agents run outside the change lifecycle ── │
│  codebase · canonical memory · historical traces           │
└────────────────────────────────────────────────────────────┘
```

Phase 6 observes three targets:
1. **Project codebase** — dead code, coverage, complexity drift, divergence from canonical memory. Background agents open small refactor PRs.
2. **Canonical memory** — staleness, emergent contradictions across policies ratified at different times, guides with zero utilization. Orchestrator proposes deprecation under Model C.
3. **Historical ephemeral artifacts** — traces in working memory that never reached canonization despite recurrence. Signal that canonization criteria are too conservative or observation scope too narrow.

## Rules
- Phases are strictly sequential per task. Phase N cannot start without an approved Phase N-1 artifact.
- Each phase produces exactly one binding artifact. Anything beyond that is ephemeral context.
- Phases 1, 2 and 3 always pause at their gate. Generator/Validator never advance unilaterally.
- Phase 4 only invokes the human via Trigger 4 (irreconcilable divergence, sprint contract trying to contradict the Contract, or hard bound hit).
- Phase 5 is non-blocking — Trigger 5 follows Model C: low impact auto-applies, medium notifies-and-applies, high requires synchronous ratification.
- Phase 6 must not couple with any specific task. It is observational and proposes via Model C.
- Phase 6 requires three properties from Phases 1–5: working-memory traces are post-hoc analyzable, canonical memory carries utilization metadata, sensors are re-executable in non-triggered contexts.

## Examples from this codebase
> Repository is empty. Expected slash-command surface for the user-facing flow:

```
/discover "<idea>"        → Phase 1, produces prd.md
/spec                     → Phase 2, produces tech-spec.md
/contract                 → Phase 3, produces acceptance-contract.md
/run                      → Phase 4, spawns Implementation + Validation Agents
                            (Phase 5 fires automatically on completion)
/ask <question>           → orchestrator-mediated read of canonical memory
                            (callable from any phase by Generator or Validator)
```

<!-- vibeflow:auto:end -->

## Anti-patterns
- Skipping a phase ("just run, we'll write the spec later") — destroys binding semantics of the Acceptance Contract.
- Letting Phase 4 modify the Acceptance Contract silently — sprint contracts cannot override it; that requires a fresh Trigger 3.
- Treating Phase 5 as optional — the system stops learning if canonization is skipped.
- Running Phase 6 inside the change lifecycle — couples drift sensing with task latency and breaks its purpose.
- Coalescing Triggers 1–5 into a single "needs review" event — different urgencies, different escalation paths, different decisions.

## Implementation Mapping

From `yoke-implementation-plan.md` (2026-04-24) — slash commands and skill
files implementing each phase:

| Phase | Slash command | Skill file |
| :--- | :--- | :--- |
| 1 — Discovery | `/yoke:discover "<idea>"` | `skills/discover/SKILL.md` |
| 2 — Tech Spec | `/yoke:tech-spec` | `skills/tech-spec/SKILL.md` |
| 3 — Acceptance Contract | `/yoke:acceptance-contract` | `skills/acceptance-contract/SKILL.md` |
| 4 — Runtime | `/yoke:implement` | `skills/implement/SKILL.md` + `lib/ralph-loop/` + hooks |
| 5 — Canonization | `/yoke:canonize` | `skills/canonize/SKILL.md` + `lib/canonical-memory/` |
| 6 — Drift sensing | `/yoke:drift-sense` (also scheduled via GitHub Actions) | `skills/drift-sense/SKILL.md` |

Mediated canonical-memory queries (callable from any phase) → `/yoke:ask`,
backed by `skills/ask/SKILL.md` + `lib/canonical-memory/query.sh`.

Bootstrap and status helpers → `/yoke:bootstrap`, `/yoke:status`.
