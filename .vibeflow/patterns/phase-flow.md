---
tags: [workflow, phases, gates, per-task, drift-sensing, lifecycle]
modules: []
applies_to: [commands, agents, skills, workflow-orchestration]
confidence: validated
---
# Pattern: Phase Flow (5 Per-Task + 1 Continuous)

<!-- vibeflow:auto:start -->
## What
Yoke organizes development into **five sequential per-task phases**
(Discovery, Tech Spec, Acceptance Contract, Runtime, Canonization) and
**one continuous phase** (Drift Sensing) operating outside the change
lifecycle. Each per-task phase has a named human gate; Phase 6 runs in
the background.

## Where
Every Yoke task threads through Phases 1→5 in order. Phase 6 runs
concurrently across the codebase, canonical memory and ephemeral
traces. Each phase has a typed input artifact (the previous phase's
output) and a typed output artifact.

## The Pattern

### Per-task phases (sequential, with explicit human gates)

```
┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
│ Phase 1 │──│ Phase 2 │──│ Phase 3 │──│ Phase 4 │──│ Phase 5 │
│Discover │  │TechSpec │  │AcptCnt  │  │Runtime  │  │Canoniz. │
└─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘
```

| Phase | Driver | Input | Output | Gate |
| :--- | :--- | :--- | :--- | :--- |
| 1 — Discovery | `/yoke:discover` skill (Generator persona inline) | raw idea | `prd.md` | Trigger 1 (PRD approval) |
| 2 — Tech Spec | `/yoke:tech-spec` skill (Generator persona inline) | approved PRD | `tech-spec.md` | Trigger 2 (Tech Spec approval) |
| 3 — Acceptance Contract | `/yoke:acceptance-contract` skill (Validator persona inline) | PRD + Tech Spec | `acceptance-contract.md` | Trigger 3 (Contract ratification) |
| 4 — Runtime | `/yoke:implement` skill (spawns Generator + Validator + Orchestrator subagents in parallel each cycle) | approved Contract | merge-ready code + `progress.md` + `contracts.md` | Trigger 4 (only on divergence or bound) |
| 5 — Canonization (auto) | Orchestrator subagent in canonize mode (final Task call from `/yoke:implement`) | full working memory + termination reason | proposed writes to canonical memory (PRs) | Trigger 5 (Model C ratification) |
| 5 — Canonization (manual escape hatch) | `/yoke:canonize` skill (spawns Orchestrator subagent in canonize mode against existing `.yoke/`) | existing working memory | proposed writes | Trigger 5 |

### Continuous phase (out-of-lifecycle)

```
┌────────────────────────────────────────────────────────────┐
│                    Phase 6 — continuous                    │
│ ──── background agents run outside the change lifecycle ── │
│  codebase · canonical memory · historical traces           │
└────────────────────────────────────────────────────────────┘
```

Phase 6 observes three targets:

1. **Project codebase** — dead code, coverage, complexity drift,
   divergence from canonical memory. Background agents open small
   refactor PRs.
2. **Canonical memory** — staleness, emergent contradictions across
   policies ratified at different times, guides with zero
   utilization. Orchestrator proposes deprecation under Model C.
3. **Historical ephemeral artifacts** — traces in working memory
   that never reached canonization despite recurrence. Signal that
   canonization criteria are too conservative or observation scope
   too narrow.

## Rules
- Phases are strictly sequential per task. Phase N cannot start
  without an approved Phase N−1 artifact.
- Each phase produces exactly one binding artifact. Anything beyond
  that is ephemeral context.
- Phases 1, 2 and 3 always pause at their gate. The skill never
  advances unilaterally — Triggers 1/2/3 surface the binding prompt
  and wait for explicit user response.
- Phase 4 only invokes the human via Trigger 4 (irreconcilable
  divergence, sprint contract trying to contradict the Contract,
  hard bound, or fundamental infeasibility).
- Phase 5 fires automatically at `/yoke:implement` loop termination
  (the auto handoff is the primary canonization path). The
  `/yoke:canonize` skill exists as a manual escape hatch only.
  Trigger 5 follows Model C: low-impact auto-applies, medium
  notifies-and-applies, high requires synchronous ratification.
- Phase 6 must not couple with any specific task. It is
  observational and proposes via Model C.
- Phase 6 requires three properties from Phases 1–5: working-memory
  traces are post-hoc analyzable, canonical memory carries
  utilization metadata, sensors are re-executable in non-triggered
  contexts.
- Skills drive Phases 1–3 with embedded persona prompts; subagents
  drive Phase 4 (parallel spawn) and Phase 5 auto-canonize. *Skills
  deliberate; subagents adapt.*

## Examples from this codebase
> Slash-command surface for the user-facing flow:

```
/yoke:discover "<idea>"        → Phase 1, produces prd.md
/yoke:tech-spec                → Phase 2, produces tech-spec.md
/yoke:acceptance-contract      → Phase 3, produces acceptance-contract.md
/yoke:implement                → Phase 4 (parallel ralph loop) +
                                 Phase 5 auto-canonize at termination
/yoke:canonize                 → Phase 5 manual escape hatch
                                 (re-runs canonization on existing .yoke/)
/yoke:ask <question>           → mediated canonical-memory read
                                 (callable from any spec phase)
```

<!-- vibeflow:auto:end -->

## Anti-patterns
- Skipping a phase ("just run, we'll write the spec later") — destroys binding semantics of the Acceptance Contract.
- Letting Phase 4 modify the Acceptance Contract silently — sprint contracts cannot override it; that requires a fresh Trigger 3.
- Treating Phase 5 as optional — the system stops learning if canonization is skipped. The auto handoff prevents this when the loop terminates normally.
- Running Phase 6 inside the change lifecycle — couples drift sensing with task latency and breaks its purpose.
- Coalescing Triggers 1–5 into a single "needs review" event — different urgencies, different escalation paths, different decisions.
- Treating `/yoke:canonize` as the primary canonization entry point — the auto handoff inside `/yoke:implement` is primary; the manual skill is for re-runs.

## Implementation Mapping

From `yoke-implementation-plan.md` (2026-04-24, refreshed 2026-04-25
— see `.vibeflow/decisions.md` "Skills deliberate; subagents adapt"
and "Consult live, canonize on termination") — slash commands and
skill files implementing each phase:

| Phase | Slash command | Skill file | Subagents involved |
| :--- | :--- | :--- | :--- |
| 1 — Discovery | `/yoke:discover "<idea>"` | `skills/discover/SKILL.md` | none (skill-only; Generator persona inline) |
| 2 — Tech Spec | `/yoke:tech-spec` | `skills/tech-spec/SKILL.md` | none (skill-only; Generator persona inline) |
| 3 — Acceptance Contract | `/yoke:acceptance-contract` | `skills/acceptance-contract/SKILL.md` | none (skill-only; Validator persona inline) |
| 4 — Runtime | `/yoke:implement` | `skills/implement/SKILL.md` + `lib/ralph-loop/` + hooks | Generator + Validator + Orchestrator (parallel spawn each cycle) |
| 5 — Canonization (auto) | (fires inside `/yoke:implement` termination) | — | Orchestrator (canonize mode) |
| 5 — Canonization (manual) | `/yoke:canonize` | `skills/canonize/SKILL.md` | Orchestrator (canonize mode) |
| 6 — Drift sensing | `/yoke:drift-sense` (also scheduled via GitHub Actions) | `skills/drift-sense/SKILL.md` | (Sprint 7+) |

Mediated canonical-memory queries:

- Spec phases (1–3) → `/yoke:ask` skill (thin direct call to
  `lib/canonical-memory/query.sh`).
- Runtime (Phase 4) → Orchestrator subagent in consult mode (also
  calls `query.sh`).

Bootstrap and status helpers → `/yoke:bootstrap`, `/yoke:status`.
