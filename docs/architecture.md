# Yoke architecture — 1-page summary

> This is a working summary for plugin contributors. The authoritative source
> is `yoke.md` (the manifesto). When in doubt, read the manifesto.

## Three pillars

1. **Binding spec.** Three sequential artifacts (PRD, Tech Spec, Acceptance Contract) produced by separate agents (Generator and Validator). The Acceptance Contract is binding: once ratified, "done" is operationally "passes every Contract criterion".

2. **Adversarial loop.** Implementation Agent and Validation Agent iterate with disjoint prompts and contexts. Hard bounds (N cycles, timeout, budget) guarantee termination — no infinite loops.

3. **Governed memory.** Two tiers. Working memory in `.yoke/` per project; canonical memory in a separate git repo. Only the Orchestrator writes canonical memory, under Model C (contextual authority by impact class) via PRs on the substrate repo.

## Five subagents (four after the v0 amendment)

- **Generator** (`agents/generator.md`) — produces PRD and Tech Spec.
- **Validator** (`agents/validator.md`) — produces Acceptance Contract.
- **Implementation Agent** (`agents/implementation.md`) — runtime instance, iterates over Tech Spec, writes `progress.md`.
- **Validation Agent** (`agents/validation.md`) — runtime instance, runs sensors, emits structured verdicts, co-writes `contracts.md`.
- **Orchestrator** — *originally a fifth subagent; v0 amendment makes it a skill (`skills/orchestrator/`) that invokes the four subagents via the Task tool. Lands in Sprint 5.*

## Six phases

| Phase | Skill | What it does |
| :--- | :--- | :--- |
| 1 — Discovery | `/yoke:discover` | idea → `prd.md` |
| 2 — Tech Spec | `/yoke:tech-spec` | PRD → `tech-spec.md` |
| 3 — Acceptance Contract | `/yoke:acceptance-contract` | PRD + Tech Spec → binding contract |
| 4 — Runtime | `/yoke:implement` | spawns Implementation + Validation Agents |
| 5 — Canonization | `/yoke:canonize` | working memory → canonical-memory PRs |
| 6 — Drift sensing | `/yoke:drift-sense` | continuous (out of lifecycle) |

Plus `/yoke:bootstrap`, `/yoke:ask`, `/yoke:status` as support skills.

## Five human triggers

1. PRD approval (Phase 1 gate)
2. Tech Spec approval (Phase 2 gate)
3. Acceptance Contract ratification (Phase 3 gate, binding)
4. Divergence arbitration (Phase 4, only on irreconcilable conflict or hard bound)
5. Canonization ratification (Phase 5, Model C — auto-merge / veto window / sync ratify)

## Model C — write authority by impact class

Every canonical-memory write goes through a PR on the substrate repo,
classified by impact. The Orchestrator skill (Canonizer mode) classifies
each candidate keyword-heuristically before invoking
`lib/canonical-memory/propose-write.sh`.

| Impact | Trigger keywords | PR behavior | Decision |
| :--- | :--- | :--- | :--- |
| `regulatory` | regulatory / gdpr / lgpd / pci / hipaa / soc2 / compliance | `auto-merge: never`; routed via CODEOWNERS to Compliance | Compliance ratifies |
| `high` | policy / must / require | `auto-merge: never`; explicit human approval required | Trigger-5 synchronous |
| `medium` | template / convention / naming | Veto window (default 24 h); auto-merge after window closes | Notify-and-apply |
| `low` | (default — no higher-class keyword) | Auto-merge after CI checks | Auto-applied |

Hard bounds + Trigger-4 escalation, full Model C, and progressive
disclosure all ship in v0.6.0. See `patterns/model-c-governance.md`,
`patterns/human-triggers.md`, and `patterns/ralph-loop.md` for the
authoritative contracts.

## Where things live

```
yoke/                              # this plugin repo
├── .claude-plugin/                # plugin manifest
├── skills/                        # /yoke:* slash commands
├── agents/                        # subagent definitions
├── hooks/                         # deterministic checkpoints
├── templates/                     # artifact templates
├── lib/                           # internal scripts (canonical-memory, ralph-loop, sensors)
└── docs/                          # what you're reading

<host project>/.yoke/              # working memory, per project
└── (prd.md, tech-spec.md, acceptance-contract.md, progress.md, contracts.md, query-trace.md)

<canonical-memory repo>/           # external substrate, organization-wide
└── (markdown + frontmatter, queryable via MCP)
```

## Lineage

- **Vibeflow** (<https://github.com/pe-menezes/vibeflow>) — Generator skills (PRD / Tech Spec drafting), forked one-time.
- **Bedrock** (<https://github.com/iurykrieger/claude-bedrock>) — Orchestrator's canonical-memory primitives (read, write, graph), forked one-time.
- Both evolve autonomously inside Yoke from the time of fork. No continuous port.
