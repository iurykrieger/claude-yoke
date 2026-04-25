# Yoke architecture — 1-page summary

> This is a working summary for plugin contributors. The authoritative
> source is `yoke.md` (the manifesto). When in doubt, read the manifesto.
>
> **Refreshed for v1.1.0** — runtime-only-agents refactor (decision
> 2026-04-25 in `.vibeflow/decisions.md`). Spec phases are skill-only;
> runtime spawns three subagents in parallel.

## Three pillars

1. **Binding spec.** Three sequential artifacts (PRD, Tech Spec, Acceptance Contract) produced by **skills** with embedded persona prompts (Generator persona in `/yoke:discover` and `/yoke:tech-spec`; Validator persona in `/yoke:acceptance-contract`). The Acceptance Contract is binding: once ratified at Trigger 3, "done" is operationally "passes every Contract criterion".

2. **Adversarial loop.** Three runtime subagents — **Generator**, **Validator**, **Orchestrator** — spawned by `/yoke:implement` in a **single concurrent Task batch per cycle**. Generator and Validator are functionally adversarial; Orchestrator consults canonical memory live and owns the canonization handoff at termination. Hard bounds (N cycles, timeout, budget) guarantee termination — no infinite loops.

3. **Governed memory.** Two tiers. Working memory in `.yoke/` per project; canonical memory in a separate git repo. Only the Orchestrator subagent writes canonical memory, and only in **canonize mode at loop termination**, under Model C (contextual authority by impact class) via PRs on the substrate repo.

## Three runtime subagents (v1.1)

- **Generator** (`agents/generator.md`) — runtime subagent. Iterates over the Tech Spec, writes code targeting the next failing Acceptance Contract criterion, persists `.yoke/progress.md` every cycle.
- **Validator** (`agents/validator.md`) — runtime subagent. Runs `hooks/verify-acceptance.sh`, emits structured JSON verdicts per criterion, co-writes `.yoke/contracts.md` on consensus events.
- **Orchestrator** (`agents/orchestrator.md`) — runtime subagent and **sole writer of canonical memory** under Model C. Three modes:
  - **Consult** (per cycle) — read canonical memory live; surface relevant subgraph entries to `.yoke/query-trace.md`.
  - **Monitor** (per cycle) — detect Generator↔Validator divergence; escalate via `lib/ralph-loop/escalate.sh` (Trigger 4).
  - **Canonize** (at loop termination) — apply five-criteria filter; classify Model C impact; propose writes via `lib/canonical-memory/propose-write.sh`.

Spec-phase work is performed by skills with embedded persona — no
spec-phase Generator/Validator subagents exist (eliminated in v1.1).
*Skills deliberate; subagents adapt.*

## Six phases

| Phase | Driver | What it does |
| :--- | :--- | :--- |
| 1 — Discovery | `/yoke:discover` skill (Generator persona inline) | idea → `prd.md` |
| 2 — Tech Spec | `/yoke:tech-spec` skill (Generator persona inline) | PRD → `tech-spec.md` |
| 3 — Acceptance Contract | `/yoke:acceptance-contract` skill (Validator persona inline) | PRD + Tech Spec → binding contract |
| 4 — Runtime | `/yoke:implement` skill (spawns 3 subagents in parallel each cycle) | parallel ralph loop with hard bounds |
| 5 — Canonization (auto) | Orchestrator subagent in canonize mode (final Task call from `/yoke:implement` termination) | working memory → canonical-memory PRs |
| 5 — Canonization (manual escape hatch) | `/yoke:canonize` skill (spawns Orchestrator subagent in canonize mode) | re-runs canonization on existing `.yoke/` |
| 6 — Drift sensing | `/yoke:drift-sense` skill | continuous (out of lifecycle) |

Plus support skills: `/yoke:bootstrap`, `/yoke:ask`
(thin canonical-memory query, calls `query.sh` directly), `/yoke:status`.

## Five human triggers

1. PRD approval (Phase 1 gate)
2. Tech Spec approval (Phase 2 gate)
3. Acceptance Contract ratification (Phase 3 gate, binding)
4. Divergence arbitration (Phase 4, only on irreconcilable conflict or hard bound)
5. Canonization ratification (Phase 5, Model C — auto-merge / veto window / sync ratify)

## Topology diagram

```
                    ┌────────────┐
                    │   user     │
                    └─────┬──────┘
                          │  Triggers 1/2/3 (binding)
            ┌─────────────┼─────────────┬─────────────┐
            ▼             ▼             ▼             │
      ┌──────────┐ ┌──────────┐ ┌────────────────┐    │
      │/discover │ │/tech-spec│ │/acceptance-    │    │
      │          │ │          │ │ contract       │    │
      │(Generator│ │(Generator│ │(Validator      │    │
      │ persona  │ │ persona  │ │  persona       │    │
      │ inline)  │ │ inline)  │ │  inline)       │    │
      └────┬─────┘ └────┬─────┘ └────────┬───────┘    │
           │            │                │            │
           └────────────┼────────────────┘            │
                        │                             │
                       prd.md ── tech-spec.md ── acceptance-contract.md
                        │                             │
                        ▼                             │ Trigger 4 (only on divergence)
              ┌──────────────────────────────────────────────────────┐
              │  /yoke:implement   (skill, deterministic coordinator)│
              │  ─────────────────────────────────────────────────── │
              │  Per cycle, single concurrent Task batch:            │
              │                                                      │
              │   ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
              │   │Generator │  │Validator │  │Orchestrator      │  │
              │   │(runtime  │  │(runtime  │  │(consult+monitor) │  │
              │   │ subagent)│  │ subagent)│  │                  │  │
              │   └────┬─────┘  └────┬─────┘  └────────┬─────────┘  │
              │        │             │                 │            │
              │        ▼             ▼                 ▼            │
              │   progress.md   contracts.md     query-trace.md     │
              │                                                      │
              │   ── deterministic ──> verify-acceptance.sh          │
              │   ── deterministic ──> check-contradiction           │
              │   ── deterministic ──> post-iteration.sh (snapshot)  │
              │   ── deterministic ──> check-hard-bounds.sh          │
              │                                                      │
              │   Loop until criteria pass | divergence | hard bound │
              │                                                      │
              │   ── At termination ──> single Orchestrator call     │
              │                          (mode=canonize)             │
              └────────────────────────┬─────────────────────────────┘
                                       │
                                       ▼
                                ┌────────────────┐
                                │ Orchestrator   │
                                │ (canonize mode)│
                                │                │
                                │ apply 5 criteria│
                                │ classify Model C│
                                │ propose writes │
                                └────────┬───────┘
                                         │
                                         ▼
                              canonical-memory PRs
                              (auto-merge / veto / sync / Compliance)
```

## Model C — write authority by impact class

Every canonical-memory write goes through a PR on the substrate repo,
classified by impact. The Orchestrator subagent (canonize mode)
classifies each candidate keyword-heuristically before invoking
`lib/canonical-memory/propose-write.sh`.

| Impact | Trigger keywords | PR behavior | Decision |
| :--- | :--- | :--- | :--- |
| `regulatory` | regulatory / gdpr / lgpd / pci / hipaa / soc2 / compliance | `auto-merge: never`; routed via CODEOWNERS to Compliance | Compliance ratifies |
| `high` | policy / must / require | `auto-merge: never`; explicit human approval required | Trigger-5 synchronous |
| `medium` | template / convention / naming | Veto window (default 24 h); auto-merge after window closes | Notify-and-apply |
| `low` | (default — no higher-class keyword) | Auto-merge after CI checks | Auto-applied |

Mid-loop canonical-memory writes are forbidden — only the
termination handoff invokes `propose-write.sh`.

See `patterns/model-c-governance.md`, `patterns/human-triggers.md`,
and `patterns/ralph-loop.md` for the authoritative contracts.

## Where things live

```
yoke/                              # this plugin repo
├── .claude-plugin/                # plugin manifest (v1.1.0)
├── skills/                        # /yoke:* slash commands
├── agents/                        # 3 runtime subagents (generator, validator, orchestrator)
├── hooks/                         # deterministic checkpoints
├── templates/                     # artifact templates
├── lib/                           # internal scripts (canonical-memory, ralph-loop, sensors)
└── docs/                          # what you're reading

<host project>/.yoke/              # working memory, per project
└── (prd.md, tech-spec.md, acceptance-contract.md, progress.md,
     contracts.md, query-trace.md, .snapshots/cycle-N.yaml)

<canonical-memory repo>/           # external substrate, organization-wide
└── (markdown + frontmatter, queryable via MCP, write-only by Orchestrator)
```

## Lineage

- **Vibeflow** (<https://github.com/pe-menezes/vibeflow>) — structural source for `/yoke:discover`, `/yoke:tech-spec` skill prompts (forked Sprint 2; refreshed v1.1 to drive dialogue inline).
- **Bedrock** (<https://github.com/iurykrieger/claude-bedrock>) — canonical-memory primitives (read, write, graph), forked Sprint 5. The Orchestrator subagent is Yoke-native.
- Both evolve autonomously inside Yoke from the time of fork. No continuous port.
