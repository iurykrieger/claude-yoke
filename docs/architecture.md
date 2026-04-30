# Yoke architecture — 1-page summary

> This is a working summary for plugin contributors. The authoritative
> source is `yoke.md` (the manifesto). When in doubt, read the manifesto.
>
> **Refreshed for v2.0.0** — pluggable canonical-memory providers
> (PRD `2026-04-30-pluggable-canonical-memory`). The single-vendor
> canonical-memory implementation that lived under `/yoke:` in v1.x has
> been extracted into a peer plugin (`claude-bedrock`); Yoke now
> dispatches reads and writes through two provider-agnostic facade
> verbs.

## Three pillars

1. **Binding spec.** Three sequential artifacts (PRD, Tech Spec, Acceptance Contract) produced by **skills** with embedded persona prompts (Generator persona in `/yoke:discover` and `/yoke:tech-spec`; Validator persona in `/yoke:acceptance-contract`). The Acceptance Contract is binding: once ratified at Trigger 3, "done" is operationally "passes every Contract criterion".

2. **Adversarial loop.** Three runtime subagents — **Generator**, **Validator**, **Orchestrator** — spawned by `/yoke:implement` in a **single concurrent Task batch per cycle**. Generator and Validator are functionally adversarial; Orchestrator consults canonical memory live and owns the canonization handoff at termination. Hard bounds (N cycles, timeout, budget) guarantee termination — no infinite loops.

3. **Governed memory through pluggable providers.** Two tiers. Working memory in `.yoke/` per project. Canonical memory lives behind a curated provider entry (`providers.yaml`) that maps the abstract notion of "canonical memory" to a concrete peer plugin. Yoke does not implement a backend itself — it dispatches reads through `/yoke:search-canonical-memory` and writes through `/yoke:canonize`. Only the Orchestrator subagent invokes `/yoke:canonize`, and only in **canonize mode at loop termination**, under Model C (contextual authority by impact class).

## Three runtime subagents (v1.1+)

- **Generator** (`agents/generator.md`) — runtime subagent. Iterates over the Tech Spec, writes code targeting the next failing Acceptance Contract criterion, persists `.yoke/progress.md` every cycle.
- **Validator** (`agents/validator.md`) — runtime subagent. Runs `hooks/verify-acceptance.sh`, emits structured JSON verdicts per criterion, co-writes `.yoke/contracts.md` on consensus events.
- **Orchestrator** (`agents/orchestrator.md`) — runtime subagent and **sole writer of canonical memory** under Model C. Three modes:
  - **Consult** (per cycle) — invoke `/yoke:search-canonical-memory` via the Skill tool when canonical-memory context is needed; reason over the response in-conversation. The facade is provider-agnostic and writes nothing on disk.
  - **Monitor** (per cycle) — detect Generator↔Validator divergence; escalate via `lib/ralph-loop/escalate.sh` (Trigger 4).
  - **Canonize** (at loop termination) — apply five-criteria filter; classify Model C impact; invoke `/yoke:canonize` which dispatches to the active provider's pinned canonize skill.

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
| 5 — Canonization (manual escape hatch) | `/yoke:canonize` skill (dispatches to the active provider's canonize verb) | re-runs canonization on existing `.yoke/` |
| 6 — Drift sensing | `/yoke:drift-sense` skill | continuous (out of lifecycle) |

Plus support skills: `/yoke:bootstrap` (one-time per project setup +
provider selection + v1.x → v2.0.0 migration),
`/yoke:search-canonical-memory` (provider-agnostic read facade), and
`/yoke:status`.

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
              │   progress.md   contracts.md   /yoke:search-        │
              │                                 canonical-memory    │
              │                                 (Skill, facade)     │
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
                                │ /yoke:canonize │
                                └────────┬───────┘
                                         │
                                         ▼
                              canonical-memory PRs
                              (auto-merge / veto / sync / Compliance)
```

## v2.0.0 dispatch path — facade → providers.yaml → provider skill

Every canonical-memory read and write in v2.0.0 traverses this chain:

```
   ┌───────────────────────────────────────┐
   │ caller                                │
   │ (Generator | Validator | Orchestrator │
   │  | spec-phase skill | ad-hoc human)   │
   └───────────────────┬───────────────────┘
                       │ Skill tool
            ┌──────────┴──────────┐
            ▼                     ▼
   ┌──────────────────┐ ┌──────────────────┐
   │/yoke:search-     │ │/yoke:canonize    │
   │ canonical-memory │ │                  │
   │ (read facade)    │ │ (write facade)   │
   └────────┬─────────┘ └────────┬─────────┘
            │                    │
            └────────┬───────────┘
                     ▼
   ┌─────────────────────────────────────────────┐
   │ lib/canonical-memory/resolve-provider.sh    │
   │  • read .yoke/config.yaml ::                │
   │       canonical_memory.provider             │
   │  • read providers.yaml :: providers.<name>  │
   │  • export YOKE_PROVIDER_NAME                │
   │           YOKE_PROVIDER_SEARCH_SKILL        │
   │           YOKE_PROVIDER_CANONIZE_SKILL      │
   │           YOKE_PROVIDER_CONFIG_PASSTHROUGH  │
   └─────────────────────┬───────────────────────┘
                         │
                         ▼
   ┌─────────────────────────────────────────────┐
   │ Skill dispatch via the provider's verb      │
   │   read:  /<provider>:<search-skill>         │
   │   write: /<provider>:<canonize-skill> \     │
   │            --working-memory <abs .yoke path>│
   │ (e.g. /bedrock:ask, /bedrock:canonize)      │
   └─────────────────────┬───────────────────────┘
                         │
                         ▼
              provider plugin owns the substrate
              (Bedrock vault | other provider)
```

`providers.yaml` is the single source of truth for provider selection
and skill-verb pinning. `lib/canonical-memory/resolve-provider.sh`
is the only resolver — every facade sources it, exports the four
`YOKE_PROVIDER_*` variables, and dispatches against the resolved
verb. There is no fallback path: if `.yoke/config.yaml` lacks
`canonical_memory.provider`, the hard-break pre-flight in
`lib/yoke-prelude.sh` aborts the skill with the binding stderr literal
`wm: canonical_memory.provider not configured. Run /yoke:bootstrap to
migrate.` (skipped only by `/yoke:bootstrap` itself).

## Model C — write authority by impact class

Every canonical-memory write goes through a PR on the provider's
substrate repo, classified by impact. The Orchestrator subagent
(canonize mode) classifies each candidate keyword-heuristically before
invoking `/yoke:canonize`, which dispatches to the active provider.
The provider opens the PR with the appropriate auto-merge / veto /
CODEOWNERS routing.

| Impact | Trigger keywords | PR behavior | Decision |
| :--- | :--- | :--- | :--- |
| `regulatory` | regulatory / gdpr / lgpd / pci / hipaa / soc2 / compliance | `auto-merge: never`; routed via CODEOWNERS to Compliance | Compliance ratifies |
| `high` | policy / must / require | `auto-merge: never`; explicit human approval required | Trigger-5 synchronous |
| `medium` | template / convention / naming | Veto window (default 24 h); auto-merge after window closes | Notify-and-apply |
| `low` | (default — no higher-class keyword) | Auto-merge after CI checks | Auto-applied |

Mid-loop canonical-memory writes are forbidden — only the
termination handoff invokes `/yoke:canonize`.

See `concepts/yoke-pattern-model-c-governance`,
`concepts/yoke-pattern-human-triggers`, and
`concepts/yoke-pattern-ralph-loop` (canonical memory) for the
authoritative contracts.

## Where things live

```
yoke/                              # this plugin repo
├── .claude-plugin/                # plugin manifest (v2.0.0)
├── providers.yaml                 # curated canonical-memory provider registry
├── skills/                        # /yoke:* slash commands
│   ├── bootstrap/                 # provider selection + legacy migration
│   ├── search-canonical-memory/   # read facade
│   ├── canonize/                  # write facade
│   ├── discover/  tech-spec/  acceptance-contract/  implement/
│   ├── drift-sense/  status/  ack-sensors/
├── agents/                        # 3 runtime subagents (generator, validator, orchestrator)
├── hooks/                         # deterministic checkpoints
├── lib/
│   ├── yoke-prelude.sh            # hard-break pre-flight helper
│   └── canonical-memory/
│       └── resolve-provider.sh    # the only facade resolver
├── templates/                     # artifact templates
└── docs/                          # what you're reading

claude-bedrock/                    # peer plugin (separate marketplace install)
├── skills/                        # /bedrock:ask, /bedrock:canonize, /bedrock:teach, …
├── lib/canonical-memory/          # Bedrock-specific lib (vault registry, etc.)
├── entities/                      # canonical entity-type definitions
└── templates/canonical/           # canonical entry frontmatter templates

<host project>/.yoke/              # working memory, per project
└── (config.yaml with canonical_memory.provider, prds/, specs/,
     sprints/, acceptance-contracts/, contracts/, sensors/, runtime/)

<provider's substrate>/            # provider-owned (e.g. Bedrock vault)
└── (markdown + frontmatter, queryable via the provider's read skill,
     write-only by Orchestrator at canonize-mode termination)
```

## Lineage

- **Vibeflow** (<https://github.com/pe-menezes/vibeflow>) — structural source for `/yoke:discover`, `/yoke:tech-spec` skill prompts (forked Sprint 2; refreshed v1.1 to drive dialogue inline).
- **Bedrock** (<https://github.com/iurykrieger/claude-bedrock>) — was forked into Yoke's `lib/canonical-memory/` and `skills/{ask,preserve,teach,…}` at Sprint 5; in v2.0.0 those forked skills + lib + entities were extracted back out into the standalone `claude-bedrock` peer plugin and Yoke now dispatches into them via `/yoke:search-canonical-memory` and `/yoke:canonize`. The Orchestrator subagent is Yoke-native.
