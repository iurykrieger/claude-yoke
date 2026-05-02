# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> Instructions for Claude Code when operating *this* repository (the Yoke
> plugin source). For users *of* Yoke working in their own project, see
> `templates/project-claude-md.md` (which `/yoke:bootstrap` copies into
> their repo).

## Language policy (non-negotiable)

**All content added to this repository MUST be written in English (en-US).**
This applies without exception to:

- Source code, identifiers, and inline comments
- Markdown files (CLAUDE.md, READMEs, docs/, templates/, manifesto, plan)
- PRDs, Tech Specs, Acceptance Contracts, sprint contracts, and any
  artifact under `.yoke/` (prds, specs, tasks, acceptance-contracts,
  contracts, sensors, runtime artifacts)
- Skill definitions, agent prompts, hooks, sensor scripts, templates
- Commit messages, PR titles and descriptions, issue text
- Test names, test fixtures, log lines, error messages, user-facing strings
- Canonical-memory entities authored from this repo (frontmatter and body)

**Never write Portuguese or any other language into repository files.**
If a user message arrives in another language, translate the user's intent
into English before producing any file content. Conversational replies in
chat may follow the user's preferred language, but anything that lands on
disk in this repo is en-US only.

When editing existing files that contain non-English text, do not introduce
new non-English content; if the task is to fix the language, replace the
non-English text with an accurate English equivalent.

## Project status

Yoke is being built sprint by sprint. **v1.1.x is the current shipped
state**; v1.2 dogfood is in flight — the framework's own design
doctrine (patterns, decisions, conventions, audits) has been canonized
into the registered Bedrock vault under `tags: [yoke-framework]` per
the 2026-04-27 doctrine-canonization PRD. Project state lives in
canonical memory at `projects/claude-yoke`; query it via `/yoke:search-canonical-memory`
to see the current sprint, version, and active action items.

The manifesto (`yoke.md`) and the implementation plan
(`yoke-implementation-plan.md`) remain the design source of truth.
**Before proposing any file, module or command, query
`/yoke:search-canonical-memory "what does Yoke decide about <topic>?"`** — the canonized
decision history (`concepts/yoke-decision-*`) is the authoritative
record. The manifesto is the original design intent; canonical memory
is the lived doctrine.

## Where things live

- **Canonical memory** (registered Bedrock vault behind the
  `bedrock` provider entry in `providers.yaml`; reads dispatch through
  `/yoke:search-canonical-memory`, writes dispatch through
  `/yoke:canonize` at loop termination):
  - `projects/claude-yoke` — project entity (status, version, action items)
  - `actors/yoke-framework` — the framework as an actor
  - `concepts/yoke-pattern-*` — pattern doctrine (9 entities)
  - `concepts/yoke-decision-*` — decision log (30 entities, with bidirectional supersession)
  - `concepts/yoke-conventions` — the MUST/MUST-NOT policy
  - `discussions/yoke-audit-*` — after-action audit reports (52 entities)
  - `fleeting/2026-04-27-yoke-*` — recent dogfood findings pending ratification
- **`.yoke/`** — per-task working memory (versioned archives + gitignored runtime).
  - `.yoke/prds/<slug>.md` — historical and current PRDs (one file per task)
  - `.yoke/specs/<slug>.md` — historical and current Specs
  - `.yoke/tasks/<slug>-s*-t*.md` — per-task technical implementations
  - `.yoke/acceptance-contracts/<slug>.md` — binding contracts
  - `.yoke/contracts/<slug>.md` — sprint contracts (refinements within the binding envelope)
  - `.yoke/sensors/<sensor-id>.md` — per-sensor working artifacts
  - `.yoke/runtime/` — gitignored: progress.md, snapshots, judge verdicts
- `.claude-plugin/` — plugin manifest (`plugin.json`, `marketplace.json`).
- `skills/`, `agents/`, `hooks/`, `templates/`, `lib/`, `docs/`, `tests/`, `examples/` — query `/yoke:search-canonical-memory "describe the yoke plugin-structure pattern"` for the full layout.

## Working on this repo

1. Query `/yoke:search-canonical-memory "what is the claude-yoke project?"` for current project state before any non-trivial change.
2. Follow `concepts/yoke-conventions` (canonical memory) exactly — the Don'ts list is non-negotiable. Query via `/yoke:search-canonical-memory` for the live version.
3. Pattern docs at `concepts/yoke-pattern-*` (canonical memory) are the source of truth for HOW to implement each component. Query via `/yoke:search-canonical-memory`.
4. Decisions already fixed in `concepts/yoke-decision-*` (canonical memory) or the manifesto are not re-decided in code — only refined. Query via `/yoke:search-canonical-memory` for any specific decision.
5. New trade-offs become input for canonical memory via Model C, not unilateral decisions.

## Sprint discipline

- Sprint specs live at `.yoke/specs/<YYYY-MM-DD>-<slug>.md` (working memory archive). Past sprints retain git history; current sprints append.
- Use `/yoke:implement <spec>` to drive Phase 4 (the runtime ralph loop).
- Use `/yoke:tech-spec` for Phase 2 spec generation; `/yoke:acceptance-contract` for Phase 3 ratification.
- Each sprint produces an installable plugin version (1.0.0 → 1.x → 2.0.0).
- The manifesto and the plan are the architect's input; this file is the coding agent's runtime guidance.

## Testing

<!-- Yoke parses this section to discover available sensors when Yoke is run on Yoke. -->

- **Tests validate behavior, not specific implementations.** Test files are named for the behavior they assert (e.g., `tests/smoke/working-memory-migration.test.sh`, `tests/smoke/ralph-loop-sprint-walk.test.sh`). The legacy `tests/smoke/sprint-N.test.sh` convention is retired — sprint numbers are an implementation detail, behaviors are the binding contract.
- Sensor self-tests live under `tests/sensors/<sensor-id>.test.sh`.
- Smoke tests must use an internal watchdog (`sleep 600 && kill -TERM $$ &`) to guard against ralph-loop iterations or background subagents without hard bounds.
- `tests/` runs in CI on every PR (workflow `.github/workflows/tests.yml`).

## Linting

<!-- Yoke parses this section to discover available sensors. -->

- Bash scripts target bash 4+. Use `shellcheck` if available.
- Markdown follows the conventions documented in `concepts/yoke-conventions` (canonical memory).

## Build

<!-- Yoke parses this section to discover available sensors. -->

This is a plugin, not a compiled artifact. "Build" = the directory layout must
match `concepts/yoke-pattern-plugin-structure` exactly (canonical memory).
Sprint 8 adds a CI gate that enforces this. The
`lib/sensors/no-vibeflow-refs.sh` sensor pins the legacy-doctrine-directory
invariant — any reintroduction of the legacy doctrine directory in framework
files trips the sensor.

---

## What Yoke is

A framework for software development with AI agents. It runs an **agent council** at Phase 4 — three persona subagents (Sr Eng, Sr QA, Sr Staff) spawned in parallel each cycle behind a deterministic sync barrier — inside the envelope of a binding human contract (Acceptance Contract). A contradiction-detection arbiter mediates Phase B; the Orchestrator subagent survives in canonize-only mode for the canonical-memory write handoff at full-run termination. Distributed as a single self-contained package with embedded skills (Vibeflow for spec generation; pluggable canonical-memory providers via the v2.0.0 facade, e.g. Claude Bedrock as the reference provider).

## Architecture — council protocol, two memory tiers, one user

**Three council personas at Phase 4** — each with a distinct lens and a distinct anti-scope. They write per-persona slices in parallel; nobody owns the whole truth.

- **Sr Eng** (`agents/sr-eng.md`) — Senior Engineer persona. Writes production code targeting the next failing Acceptance Contract criterion; ships unit tests; never authors acceptance tests.
- **Sr QA** (`agents/sr-qa.md`) — Senior QA persona. Writes contract-anchored acceptance tests under `tests/acceptance/<contract-slug>/`, each carrying `# criterion: <id>`; never modifies production code.
- **Sr Staff** (`agents/sr-staff.md`) — Senior Staff persona. Invokes the configured `review-skill` (default `/review`), consults canonical memory via `/yoke:search-canonical-memory`, and emits a `### Review output` subsection; never invokes `/ultrareview` autonomously.

**Per-cycle phase machine** (driven by `/yoke:implement` and `lib/runtime/{cycle.sh,council.sh,sync-barrier.sh,council-merge.sh,trigger-4.sh}`):

- **Phase A — parallel persona spawn behind the sync barrier.** `cycle.sh pre-spawn` clears stale Phase-A markers and runs `persona-loader.sh validate-all`. The coordinator spawns one Task per persona in a single concurrent batch. Each persona writes its slice at `.yoke/runtime/cycles/<N>/<persona>.md` and its marker at `.yoke/runtime/.phase-a-done.<persona>` before exit. `cycle.sh post-spawn` defensively waits on every marker; `council-merge.sh` produces a byte-deterministic merged view ordered alphabetically by persona name.
- **Phase B — bounded council loop with the contradiction-detection arbiter.** `council.sh phase-b` runs up to `overrides.runtime.council_rounds_max` réplica rounds (default 3, configurable via `.yoke/config.yaml :: overrides.runtime`). Quiescence (zero new réplicas in a round) is detected deterministically and ends the loop with consensus. Rounds that produced réplicas spawn `agents/council-arbiter.md`, which emits a structured JSON verdict (`{round, consensus, contradictions[], tone_only_pairs[]}`) classifying each pairwise disagreement as direct contradiction, importance disagreement, or tone-only.
- **Phase C — consensus or Trigger 4.** On consensus, the cycle ends and the next cycle opens. On cap-exhausted divergence, `lib/runtime/trigger-4.sh render` produces the user-facing escalation message naming every flagged persona pair (e.g. `sr-eng × sr-qa`, `sr-qa × sr-staff`) and `lib/ralph-loop/escalate.sh --reason divergence` emits the Trigger-4 packet. Trigger 4 is the **generalized** divergence escape hatch — same human gate, more pairwise edges than the binary v2.x loop.

**The Orchestrator survives in canonize-only mode.** At full-run termination (every sprint complete; coordinator exit reason `merge-ready`), `/yoke:implement` issues one final foreground Task call to `agents/orchestrator.md` with `mode=canonize`. The Orchestrator invokes `/yoke:canonize` via the Skill tool; the canonize skill applies the five-criterion cascade, classifies Model C impact, and dispatches to the active provider. The legacy `consult` and `monitor` modes are retired in v3.0.0 — per-cycle canonical-memory reads are issued by the council personas themselves; divergence detection is owned by the sync barrier plus the arbiter.

**Memory — two tiers with different lifetimes and authorities:**

| Tier | Location | Who writes | Lifetime |
| :---- | :---- | :---- | :---- |
| Working memory | host project's `.yoke/` (`prds/<slug>.md`, `specs/<slug>.md`, `sprints/<slug>-s*.md`, `acceptance-contracts/<slug>.md`, `runtime/progress.md`, `contracts/<slug>.md`, `runtime/cycles/<N>/<persona>.md`) | council personas write their own slices; coordinator writes `progress.md`; Sr QA + Sr Eng share `contracts/<slug>.md` on consensus | task/sprint |
| Canonical memory | external substrate via the active provider behind `providers.yaml` (reference provider: `claude-bedrock`) | only Orchestrator (canonize-only), under Model C | permanent, versioned |

The separation exists because the blast radius is asymmetric: corrupted working memory affects one task; corrupted canonical memory affects the organization.

## Six-phase flow

Per-task (sequential, with a human gate between each):

1. **Discovery** → approved `prd.md`
2. **Tech Spec** → approved `tech-spec.md`
3. **Acceptance Contract** → approved `acceptance-contract.md` (binding)
4. **Runtime** — agent council (Phase A → Phase B → Phase C) per cycle; sprint-walks to convergence; produces `progress.md` + `contracts.md` + per-cycle persona slices under `.yoke/runtime/cycles/<N>/`
5. **Canonization** — Orchestrator (canonize-only mode) proposes writes to canonical memory at full-run termination

Continuous: **Drift sensing** over codebase, canonical memory and historical traces.

## Five human-in-the-loop triggers (do not conflate)

1. PRD approval (blocks Phase 2)
2. Tech Spec approval (blocks Phase 3)
3. Acceptance Contract approval (blocks Phase 4)
4. Council divergence arbitration — fires when Phase B exhausts the round cap with unresolved contradictions; the rendered message names every flagged persona pair (generalized from the v2.x binary-loop arbitration; blocks runtime until the user resolves)
5. Canonization ratification (non-blocking; Model C decides auto-apply / notify-and-apply / synchronous)

## Non-negotiable invariants

These are architectural properties — code that violates them is wrong, even when it looks simpler.

- **Binding spec.** The approved Acceptance Contract operationally defines what "done" means. Changes during implementation require new ratification.
- **Adversarial loop with hard bounds.** The three council personas hold opposing lenses (build / verify / govern). Convergence → cycle ends. Cap-exhausted divergence → Trigger 4. Hard bound reached (≤8 cycles per sprint / 2-4h / budget) → escalation. **Never an infinite loop.**
- **Sprint contracts ⊂ Acceptance Contract.** Agreements emerging between agents at runtime cannot contradict the binding contract. Attempted contradiction = Trigger 4.
- **Governed canonical memory.** Only the Orchestrator writes. Git-native protocol (PRs). Every write traceable to a past failure or hard constraint — items without traceability are pruning candidates.
- **Progressive disclosure.** No persona receives the full canonical memory; each council persona issues `/yoke:search-canonical-memory` calls bounded by progressive disclosure (≤15 entity reads, one wikilink hop) for the question at hand.
- **Blueprints wrapping agentic nodes.** LLM only where judgment is genuinely necessary; the rest is a deterministic node (sensors, persistence, cycle counting, non-contradiction verification).
- **Structured sensor output.** Sensor output without precise violation identification + location + correction instruction is treated as a sensor bug, not as valid output.
- **Rippability.** Every canonical-memory item carries frontmatter with ratification date, calibrated model, last validation, traceability, impact. Adopted principle: *every rule gets periodically re-tested against the current model.*
- **Environment designers, not code writers.** Every failure is a diagnosis of the environment, not of the agent. The answer becomes canonical memory, a template, or a fixture.

## Model C — contextual authority by write class

Operational summary (see Section 10 of the manifesto for the full table):

- Divergence patterns (low impact) → Orchestrator auto-applies via PR with auto-merge
- Template refinement (medium impact) → notify-and-apply with veto window
- New MUST policies (high impact) → mandatory synchronous human ratification
- Regulatory MUST policies → only Compliance ratifies; Orchestrator never writes directly

## Embedded skills vs. external substrate

- **Embedded** (one-time copy at creation, evolve autonomously inside Yoke):
  - Vibeflow (<https://github.com/pe-menezes/vibeflow>) — Generator skills (PRD / Tech Spec drafting).
  - Bedrock (<https://github.com/iurykrieger/claude-bedrock>) — Orchestrator's canonical-memory operations.
  There is no continuous port with upstream.
- **External**: the canonical substrate (organizational content). Yoke embeds the **access**, not the **content**.

## Threat model — silent failures to watch

The manifesto enumerates eight failure modes (Section 16). The most load-bearing for daily decisions:

- **Canonical memory drift** (16.1) — sub-optimal pattern canonized becomes doctrine and self-reinforces.
- **Persona over-constraining** (16.3) — too many guides degrade performance (ETH Zurich evidence: LLM-generated AGENTS.md cost +20% tokens and degrade output). Mitigation: utilization metric as pruning trigger, mandatory traceability; council personas inherit the same risk if their `objective` and `sensor-toolkit` keys grow unboundedly.
- **Human ratification fatigue** (16.4) — approvals become rubber-stamp. Signal: human never edits proposals.
- **Orchestrator as SPOF** (13.4 / 16.7) — failure interrupts Phase 4 coordination. Mitigation: checkpointing + resumption via `progress.md` and `contracts.md`.

## When working in this repo

1. Read the manifesto before proposing code structure.
2. Decisions already fixed in the manifesto are not re-decided in code — only refined.
3. New trade-offs become input for canonical memory via Model C, not unilateral decisions.
4. Do not introduce components that dilute the Sr Eng / Sr QA / Sr Staff persona separation, the canonize-only Orchestrator boundary, or the named human gates.
5. Yoke v1.0 is built **without** running Yoke on itself (manual bootstrap — see `concepts/yoke-decision-*` in canonical memory for the full decision history). v1.1 dogfooded the framework on itself for the first time on 2026-04-27; see the Migration history section below.

## Migration history

- **2026-04-27** — First end-to-end self-canonization run of Yoke on Yoke. The legacy `.vi`+`beflow/` directory was retired: 9 patterns migrated to `concepts/yoke-pattern-*`, 30 decisions split into individual `concepts/yoke-decision-*` entities (with bidirectional supersession), 1 conventions doc to `concepts/yoke-conventions`, 52 audit reports to `discussions/yoke-audit-*`, 12 PRDs and 53 specs migrated to `.yoke/prds/` and `.yoke/specs/` with date-prefixed slugs. The dogfood run surfaced 9 framework signals (8 captured during the loop, 1 surfaced during canonize-time cascade); 5 framework bug fixes shipped in the same change. Source PRD: `.yoke/prds/2026-04-27-yoke-doctrine-canonization.md`. Canonical-memory PR: `iurykrieger/brain#1` (merged at `fe0c24f`).
- **2026-04-30 (v2.0.0)** — **Pluggable canonical-memory providers.** The single-vendor canonical-memory implementation that was forked from Bedrock at Sprint 5 (seven skills + lib + entities + canonical templates) was extracted out of `claude-yoke` into the standalone `claude-bedrock` peer plugin. Yoke v2.0.0 ships a curated provider registry at `providers.yaml` and two provider-agnostic facade verbs: `/yoke:search-canonical-memory` (read) and `/yoke:canonize` (write). Every Yoke skill except `/yoke:bootstrap` sources `lib/yoke-prelude.sh` and runs a hard-break pre-flight that refuses to run on a project whose `.yoke/config.yaml` lacks `canonical_memory.provider`. `/yoke:bootstrap` was rewritten to handle interactive provider selection, the `--provider` flag, and v1.x → v2.0.0 migration (preserves `url`/`name`/`default_branch` as `config_passthrough` keys; removes `<plugin_dir>/memories.json` after final confirmation). Plugin version bumped from `1.1.0` to `2.0.0`; description now mentions "pluggable canonical-memory". See `docs/migration-v1-to-v2.md` for the upgrade runbook and `docs/architecture.md` for the v2.0.0 dispatch-path diagram. Source PRD: `.yoke/prds/2026-04-30-pluggable-canonical-memory.md`. Source Spec: `.yoke/specs/2026-04-30-pluggable-canonical-memory.md`. Acceptance Contract: `.yoke/acceptance-contracts/2026-04-30-pluggable-canonical-memory.md`.
- **2026-05-01 (v3.0.0)** — **Council cutover.** The binary v2.x runtime loop (Implementation Agent ↔ Validation Agent with the Orchestrator brokering canonical-memory reads in `consult` mode and divergence in `monitor` mode) is replaced by a three-persona **agent council** (`agents/sr-eng.md`, `agents/sr-qa.md`, `agents/sr-staff.md`) spawned in parallel each cycle behind a deterministic file-marker sync barrier. Per-cycle phases are now Phase A (parallel persona spawn + barrier wait + deterministic merge), Phase B (bounded council loop with quiescence detection plus the `agents/council-arbiter.md` contradiction-detection LLM emitting a structured JSON verdict), Phase C (consensus advances; cap-exhausted divergence escalates Trigger 4 with every flagged persona pair named). Trigger 4 is generalized from the binary-pair arbitration to a multi-edge persona-pair arbitration. The Orchestrator subagent survives in **canonize-only** mode for the canonical-memory write handoff at full-run termination; its legacy `consult` and `monitor` modes are retired (per-cycle reads are issued by the personas themselves; divergence is owned by the sync barrier plus the arbiter). New runtime helpers under `lib/runtime/`: `cycle.sh`, `council.sh`, `council-merge.sh`, `sync-barrier.sh`, `persona-loader.sh`, `trigger-4.sh`. Plugin version bumped from `2.0.0` to `3.0.0`; description now mentions "agent council". See `docs/migration-v2-to-v3.md` for the one-line migration note and `docs/architecture.md :: ## Council protocol` for the cycle diagram. Source PRD: `.yoke/prds/2026-05-01-agent-council.md`. Source Spec: `.yoke/specs/2026-05-01-agent-council.md`. Acceptance Contract: `.yoke/acceptance-contracts/2026-05-01-agent-council.md`.
