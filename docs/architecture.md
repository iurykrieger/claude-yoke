# Yoke architecture — 1-page summary

> This is a working summary for plugin contributors. The authoritative
> source is `yoke.md` (the manifesto). When in doubt, read the manifesto.
>
> **Refreshed for v3.0.0** — agent council protocol
> (PRD `2026-05-01-agent-council`). The v2.x binary loop at Phase 4
> (Generator + Validator + Orchestrator-monitor) is replaced by a
> three-persona council (Sr Eng / Sr QA / Sr Staff) spawned in
> parallel each cycle behind a deterministic sync barrier; a
> contradiction-detection arbiter mediates Phase B; the Orchestrator
> subagent survives in **canonize-only** mode at full-run
> termination. The v2.0.0 pluggable canonical-memory provider
> contract (`/yoke:search-canonical-memory` read facade,
> `/yoke:canonize` write facade, `providers.yaml` registry) is
> unchanged — see the `## v2.0.0 dispatch path` section below for
> the dispatch chain that v3.0 inherits verbatim.

## Three pillars

1. **Binding spec.** Three sequential artifacts (PRD, Tech Spec, **Acceptance Criteria**) produced by **skills** with embedded persona prompts. The Acceptance Criteria document is binding: once ratified at Trigger 3, "done" is operationally "passes every criterion below". The artifact is organised as **User Stories → Definition of Done → Acceptance Criteria → Sensor pool**: DoD is a binary completion checklist per User Story; AC entries are observable QA conditions per User Story; the Sensor pool is a flat list of sensor IDs unclassified at authoring time. Sensor selection per Acceptance Criterion is a runtime council decision — Sr QA and Sr Staff each pick which pool members gate which criterion at Phase 4 (renamed from "Acceptance Contract" in v4.0.0; see `docs/migration-v3-to-v4.md`).

2. **Agent council at Phase 4.** Three persona subagents — **Sr Eng**, **Sr QA**, **Sr Staff** — spawned by `/yoke:implement` in a **single concurrent Task batch per cycle**, behind a deterministic sync barrier. Their lenses are independent and partially adversarial (build / verify / govern); a contradiction-detection arbiter mediates Phase B and emits a structured JSON verdict; the Orchestrator subagent survives in canonize-only mode for the canonical-memory write handoff at full-run termination. Hard bounds (≤8 cycles per sprint, council-round cap, timeout, budget) guarantee termination — no infinite loops.

3. **Governed memory through pluggable providers.** Two tiers. Working memory in `.yoke/` per project. Canonical memory lives behind a curated provider entry (`providers.yaml`) that maps the abstract notion of "canonical memory" to a concrete peer plugin. Yoke does not implement a backend itself — it dispatches reads through `/yoke:search-canonical-memory` and writes through `/yoke:canonize`. Only the Orchestrator subagent invokes `/yoke:canonize`, and only in **canonize mode at full-run loop termination**, under Model C (contextual authority by impact class).

## Three council personas + canonize-only Orchestrator (v3.0)

- **Sr Eng** (`agents/sr-eng.md`) — runtime persona subagent. Writes production code targeting the next failing Acceptance Criterion (or DoD checkpoint); ships unit tests; never authors acceptance-criteria-anchored tests; writes its slice at `.yoke/runtime/cycles/<N>/sr-eng.md` and its sync-barrier marker at `.yoke/runtime/.phase-a-done.sr-eng` before exit.
- **Sr QA** (`agents/sr-qa.md`) — runtime persona subagent. Authors acceptance-criteria-anchored tests under `tests/acceptance/<contract-slug>/`, each carrying a `# criterion: <id>` header that resolves against the binding artifact (AC-<US>-<n> or FR-N); selects which pool sensors gate each criterion at runtime (recorded under `## Sensor selection` in its slice file); never modifies production code; writes its slice at `.yoke/runtime/cycles/<N>/sr-qa.md`.
- **Sr Staff** (`agents/sr-staff.md`) — runtime persona subagent. Invokes the configured `review-skill` (default `/review`), consults canonical memory via `/yoke:search-canonical-memory`, and emits a `### Review output` subsection in its slice; never invokes `/ultrareview` autonomously.
- **Council arbiter** (`agents/council-arbiter.md`) — Phase-B contradiction-detection LLM. Spawned by `lib/runtime/council.sh phase-b` only when a réplica round produced ≥1 réplica. Emits a JSON verdict matching `{round, consensus, contradictions[], tone_only_pairs[]}`; classifies each pairwise disagreement as direct contradiction, importance disagreement, or tone-only.
- **Orchestrator** (`agents/orchestrator.md`) — termination subagent and **sole writer of canonical memory** under Model C. Single surviving mode:
  - **Canonize** (at full-run loop termination) — apply five-criteria filter; classify Model C impact; invoke `/yoke:canonize` which dispatches to the active provider's pinned canonize skill.

The legacy `consult` and `monitor` orchestrator modes are retired in
v3.0; per-cycle canonical-memory reads are issued by the council
personas themselves, and divergence detection is owned by
`lib/runtime/sync-barrier.sh` plus the council-arbiter inside Phase B.

Spec-phase work is performed by skills with embedded persona — no
spec-phase persona subagents exist.
*Skills deliberate; subagents adapt.*

## Council protocol

The v3.0 council protocol drives every `/yoke:implement` cycle
through three named phases. Phase boundaries are reflected in
`.yoke/runtime/progress.md`'s per-cycle entry.

```
                    ┌────────────────────────────────────────┐
                    │ /yoke:implement (deterministic         │
                    │   coordinator; sprint-walk loop)       │
                    └────────────────┬───────────────────────┘
                                     │ per cycle
                                     ▼
   ┌────────────────────────────────────────────────────────────────────┐
   │ Phase A — parallel persona spawn behind the sync barrier           │
   │ ────────────────────────────────────────────────────────────────── │
   │   1. lib/runtime/cycle.sh pre-spawn:                               │
   │      • lib/runtime/sync-barrier.sh clear-markers (idempotent)      │
   │      • lib/runtime/persona-loader.sh validate-all agents/          │
   │      • print sorted council persona names (sr-eng, sr-qa, sr-staff)│
   │   2. Single concurrent Task batch — three persona subagents:       │
   │                                                                    │
   │      ┌──────────┐  ┌──────────┐  ┌──────────┐                      │
   │      │ Sr Eng   │  │ Sr QA    │  │ Sr Staff │  (Task batch)        │
   │      └────┬─────┘  └────┬─────┘  └────┬─────┘                      │
   │           │             │             │                            │
   │           ▼             ▼             ▼                            │
   │   .yoke/runtime/cycles/<N>/sr-eng.md   sr-qa.md   sr-staff.md      │
   │   .yoke/runtime/.phase-a-done.sr-eng   .sr-qa     .sr-staff        │
   │                                                                    │
   │   3. lib/runtime/cycle.sh post-spawn:                              │
   │      • defensive wait on every Phase-A marker (timeout → fail)     │
   │      • lib/runtime/council-merge.sh produces a byte-deterministic  │
   │        merged view ordered alphabetically by persona name          │
   │   4. tests/sensors/council-sync-barrier.test.sh asserts every      │
   │      slice mtime ≥ the latest marker mtime                         │
   └────────────────────────────────┬───────────────────────────────────┘
                                    │ all three slices present and ordered
                                    ▼
   ┌────────────────────────────────────────────────────────────────────┐
   │ Phase B — bounded council loop with contradiction-detection        │
   │ ────────────────────────────────────────────────────────────────── │
   │   lib/runtime/council.sh phase-b runs ≤ council_rounds_max         │
   │   (default 3, configurable via .yoke/config.yaml ::                │
   │   overrides.runtime).                                              │
   │                                                                    │
   │   Round loop:                                                      │
   │     • spawn personas to read merged view + emit replicas (if any)  │
   │     • zero new replicas in a round → quiescence → CONSENSUS, exit  │
   │     • ≥1 replica → spawn agents/council-arbiter.md                 │
   │       JSON verdict: {round, consensus, contradictions[],           │
   │                       tone_only_pairs[]}                           │
   │       • consensus:true → exit (consensus)                          │
   │       • consensus:false → next round                               │
   │     • round-cap reached with consensus:false → exit (trigger-4)    │
   │                                                                    │
   │   progress.md records: round count, per-round réplica count,       │
   │   exit status (consensus | trigger-4)                              │
   └────────────────────────────────┬───────────────────────────────────┘
                                    │
                            ┌───────┴────────┐
                            ▼                ▼
              ┌─────────────────┐  ┌─────────────────────────────┐
              │ Phase C — exit  │  │ Phase C — Trigger 4         │
              │ (consensus)     │  │ (cap-exhausted divergence)  │
              │ ─────────────── │  │ ──────────────────────────  │
              │ next cycle opens│  │ lib/runtime/trigger-4.sh    │
              │ OR sprint-walk  │  │   render → user-facing      │
              │ advances current│  │   message naming every      │
              │ _sprint and     │  │   flagged persona pair      │
              │ resets cycle_   │  │   (e.g. sr-eng × sr-qa,     │
              │ count           │  │   sr-qa × sr-staff)         │
              │                 │  │ lib/ralph-loop/escalate.sh  │
              │                 │  │   --reason divergence       │
              │                 │  │ user replies parsed and     │
              │                 │  │ applied (ratify <persona> | │
              │                 │  │ rework needed: <text>)      │
              └────────┬────────┘  └────────────┬────────────────┘
                       │                        │
                       ▼                        ▼
           sprint-walk loop                  loop pauses; canonize
           advances or terminates            handoff still fires on
                                             eventual termination
```

At full-run termination (every sprint complete; coordinator exit
reason `merge-ready`), `/yoke:implement` issues one final foreground
Task call to `agents/orchestrator.md` with `mode=canonize`. The
Orchestrator invokes `/yoke:canonize` via the Skill tool; the
canonize skill applies the five-criterion cascade, classifies Model
C impact, and dispatches to the active provider (whichever entry in
`providers.yaml` the host's `.yoke/config.yaml ::
canonical_memory.provider` selects). This is the **only** moment
in the `/yoke:implement` lifecycle in which canonical-memory writes
happen.

The legacy v2.x agent files (`agents/generator.md`,
`agents/validator.md`) are deleted in v3.0; the legacy `consult` and
`monitor` Orchestrator modes are removed from
`agents/orchestrator.md`. Reintroduction of any of those names
under `lib/runtime/` or `skills/implement/` trips
`tests/sensors/legacy-agents-removed.test.sh`.

## Phase 2.5 — Sprint synthesis

Phase 2.5 is the post-rename producer split introduced by PRD
`.yoke/prds/2026-05-03-generate-sprints-skill.md` (cut-over date
**2026-05-03**). Sprint files (`.yoke/sprints/<slug>-s<NN>.md`) are
no longer emitted by `/yoke:tech-spec` — that skill now produces
only the architecture spec at `.yoke/specs/<slug>.md`. Sprint
partitioning moved into a dedicated skill,
**`/yoke:generate-sprints`**, that consumes the approved Tech Spec
plus the ratified Acceptance Criteria as inputs and produces the
sprint runtime bundles consumed by `/yoke:implement`.

The new flow chain is:

```
/yoke:discover
    → /yoke:tech-spec        (Phase 2  — architecture only)
    → /yoke:acceptance-criteria  (Phase 3  — binding criteria)
    → /yoke:generate-sprints (Phase 2.5 — sprint synthesis)
    → /yoke:implement        (Phase 4  — council protocol)
```

`/yoke:generate-sprints` is a **blueprint wrapping a single LLM-
driven synthesis stage** bracketed by deterministic Bash:
deterministic pre-flight (provider hard break + active-slug check +
Spec / AC approval grammar checks + legacy-task rejection), LLM
synthesis (turns the parsed AC user-stories array plus the parsed
Spec architecture into a JSON task list), deterministic partition
(connected-component grouping by overlapping `applies_decisions`
plus an 8-task per-sprint cap, ordered by lexical clustering with
placeholder-ordinal tie-break), deterministic render (one
`.yoke/sprints/<slug>-s<NN>.md` per partition entry via
`templates/sprint.md`, with the `(Realizes: US-NNN[, US-MMM])`
clause adjacent to each Story line), and the **Trigger 2.5** gate.

**Trigger 2.5 — Sprint plan ratification (non-binding for criteria).**
After bundle materialization the skill renders the shared approval
menu (`templates/approval-menu.md`) with `artifact_label: "Sprint
plan"` and `next_skill: /yoke:implement`. The gate ratifies the
*partition*, not the *criteria* — Trigger 3 already ratified the AC
envelope and that envelope is preserved verbatim across Trigger 2.5.
On `approve` / `approve_and_continue`, every produced sprint file's
frontmatter flips `status: draft` → `status: approved` atomically.

**Legacy coexistence.** The presence of
`.yoke/acceptance-criteria/<slug>.md` selects the new flow; absence
selects the legacy flow (the legacy ratified envelope under
`.yoke/acceptance-contracts/<slug>.md`, the legacy
`/yoke:tech-spec` stage 3 producing sprint files alongside the
spec). Per Decision 6A of the parent PRD, **no automatic
migration** is performed — re-running `/yoke:generate-sprints`
against a legacy task (detected via either the
`acceptance-contracts/<slug>.md` archive entry or pre-existing
sprint files lacking the new-flow `acceptance-criteria/<slug>.md`
marker in their `traceability:` frontmatter) aborts non-zero with
the literal stderr `wm: legacy task — generate-sprints does not
migrate` and never touches any file under `.yoke/sprints/`. Tasks
created on/after the **2026-05-03 cut-over** date use the new
flow; older tasks finish under the legacy flow.

The new gate state `awaiting:generate-sprints` is surfaced by
`/yoke:status` and refused by `/yoke:implement`'s pre-cycle check
when the active task sits in that state — both consumers source
`lib/working-memory/gate-state.sh :: detect_gate_state` for a
single source of truth on the ladder. The doctrine entry
`concepts/yoke-pattern-sprint-synthesis` is staged for canonical-
memory ratification at full-run termination via
`.yoke/runtime/.preserve-packet.md`.

## Six phases

| Phase | Driver | What it does |
| :--- | :--- | :--- |
| 1 — Discovery | `/yoke:discover` skill (Discovery persona inline) | idea → `prd.md` |
| 2 — Tech Spec | `/yoke:tech-spec` skill (Tech-spec persona inline) | PRD → `tech-spec.md` (architecture only) |
| 2.5 — Sprint synthesis | `/yoke:generate-sprints` skill (Senior Engineer persona inline; LLM synthesis bracketed by deterministic partition + render) | Spec + Acceptance Criteria → sprint runtime bundles |
| 3 — Acceptance Criteria | `/yoke:acceptance-criteria` skill (Senior-QA persona inline; interactive grill + PRD/Tech-Spec resume) | PRD + Tech Spec → binding Acceptance Criteria document (US → DoD → AC → Sensor pool) |
| 4 — Runtime | `/yoke:implement` skill (spawns 3 council personas in parallel each cycle behind the sync barrier; arbiter mediates Phase B) | council protocol with hard bounds |
| 5 — Canonization (auto) | Orchestrator subagent in canonize mode (single Task call from `/yoke:implement` full-run termination) | working memory → canonical-memory PRs |
| 5 — Canonization (manual escape hatch) | `/yoke:canonize` skill (dispatches to the active provider's canonize verb) | re-runs canonization on existing `.yoke/` |
| 6 — Drift sensing | `/yoke:drift-sense` skill | continuous (out of lifecycle) |

Plus support skills: `/yoke:bootstrap` (one-time per project setup +
provider selection + v1.x → v2.0.0 migration),
`/yoke:search-canonical-memory` (provider-agnostic read facade), and
`/yoke:status`.

## Six human triggers

1. PRD approval (Phase 1 gate)
2. Tech Spec approval (Phase 2 gate)
3. Acceptance Criteria ratification (Phase 3 gate, binding)
4. Council divergence arbitration (Phase 4, fired by the round-cap path inside Phase B; the rendered message names every flagged persona pair — generalized from the v2.x binary-loop arbitration)
5. Canonization ratification (Phase 5, Model C — auto-merge / veto window / sync ratify)

Plus the **non-binding** post-rename gate introduced by PRD
`.yoke/prds/2026-05-03-generate-sprints-skill.md`:

- **Trigger 2.5 — Sprint plan ratification.** Phase 2.5 gate; fires
  at the end of `/yoke:generate-sprints` after bundle materialization;
  ratifies the *partition* (delivery objectives + DoD + task list
  shape), not the *criteria* (Trigger 3 already bound those). This
  trigger is **non-binding** for the AC envelope — approving the
  sprint plan does not re-open the Acceptance Criteria document. The
  shared approval menu (`templates/approval-menu.md`) is rendered
  with `artifact_label: "Sprint plan"` and the four-verb prompt
  (`approve_and_continue` / `approve` / `reject` / `revise`).

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
      │(skill,   │ │(skill,   │ │(skill,         │    │
      │ persona  │ │ persona  │ │  persona       │    │
      │ inline)  │ │ inline)  │ │  inline)       │    │
      └────┬─────┘ └────┬─────┘ └────────┬───────┘    │
           │            │                │            │
           └────────────┼────────────────┘            │
                        │                             │
                       prd.md ── tech-spec.md ── acceptance-criteria.md
                        │                             │
                        ▼                             │ Trigger 4 (council divergence,
              ┌──────────────────────────────────────────────────────┐
              │  /yoke:implement   (skill, deterministic coordinator)│
              │  ─────────────────────────────────────────────────── │
              │  Per cycle (council protocol):                       │
              │                                                      │
              │   Phase A — single concurrent Task batch behind      │
              │             the sync barrier:                        │
              │   ┌──────────┐  ┌──────────┐  ┌──────────┐          │
              │   │ Sr Eng   │  │ Sr QA    │  │ Sr Staff │          │
              │   │(persona  │  │(persona  │  │(persona  │          │
              │   │ subagent)│  │ subagent)│  │ subagent)│          │
              │   └────┬─────┘  └────┬─────┘  └────┬─────┘          │
              │        ▼             ▼             ▼                 │
              │   .yoke/runtime/cycles/<N>/{sr-eng,sr-qa,sr-staff}.md│
              │   .yoke/runtime/.phase-a-done.<persona>              │
              │                                                      │
              │   Phase B — bounded council loop (≤ rounds_max):     │
              │             quiescence → consensus                   │
              │             ≥1 réplica → council-arbiter (JSON       │
              │                          verdict)                    │
              │   Phase C — consensus advances OR Trigger 4 escalates│
              │                                                      │
              │   ── deterministic ──> persona-loader / sync-barrier │
              │   ── deterministic ──> verify-acceptance.sh          │
              │   ── deterministic ──> check-hard-bounds.sh          │
              │                                                      │
              │   Loop until criteria pass | divergence | hard bound │
              │                                                      │
              │   ── At full-run termination ──> single Orchestrator │
              │                                  Task (mode=canonize)│
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
│   ├── discover/  tech-spec/  acceptance-criteria/  implement/
│   ├── drift-sense/  status/  ack-sensors/
├── agents/                        # council personas (sr-eng, sr-qa, sr-staff),
│                                  # contradiction-detection arbiter (council-arbiter),
│                                  # canonize-only orchestrator
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
     sprints/, acceptance-criteria/, contracts/, sensors/, runtime/)

<provider's substrate>/            # provider-owned (e.g. Bedrock vault)
└── (markdown + frontmatter, queryable via the provider's read skill,
     write-only by Orchestrator at canonize-mode termination)
```

## Lineage

- **Vibeflow** (<https://github.com/pe-menezes/vibeflow>) — structural source for `/yoke:discover`, `/yoke:tech-spec` skill prompts (forked Sprint 2; refreshed v1.1 to drive dialogue inline).
- **Bedrock** (<https://github.com/iurykrieger/claude-bedrock>) — was forked into Yoke's `lib/canonical-memory/` and `skills/{ask,preserve,teach,…}` at Sprint 5; in v2.0.0 those forked skills + lib + entities were extracted back out into the standalone `claude-bedrock` peer plugin and Yoke now dispatches into them via `/yoke:search-canonical-memory` and `/yoke:canonize`. The Orchestrator subagent is Yoke-native.
