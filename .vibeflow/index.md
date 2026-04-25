# Project: claude-yoke
> Analyzed: 2026-04-24 (manual bootstrap from `yoke.md` v1.0 + `yoke-implementation-plan.md` v1.0)
> Stack: Claude Code plugin (skills + subagents + bash 4+ hooks), distributed via `/plugin install`
> Type: AI-agent development framework, packaged as a single Claude Code plugin (strategy "a")
> Suggested budget: ≤ 4 files per task (minimum; revise upward as the codebase grows)

## Structure

The repository is currently empty (only `LICENSE`). Yoke is distributed as a
single Claude Code plugin: skills, subagents, hooks, templates and helper
scripts live inside this one repo, and the plugin installs via
`/plugin install`. Layout follows `vibeflow-claude` and `claude-bedrock`.

Target final layout (Sprint 1 Task 1.2 creates skeletons; subsequent sprints
fill them in — see `patterns/plugin-structure.md`):

- `.claude-plugin/` — `plugin.json` + `marketplace.json`
- `skills/` — one folder per skill, each with `SKILL.md` (`/yoke:discover`, `/yoke:tech-spec`, `/yoke:acceptance-contract`, `/yoke:implement`, `/yoke:canonize`, `/yoke:drift-sense`, `/yoke:ask`, `/yoke:bootstrap`, `/yoke:status`)
- `agents/` — five subagents: `generator.md`, `validator.md`, `orchestrator.md`, `implementation.md`, `validation.md`
- `hooks/` — bash scripts: `pre-implementation.sh`, `post-iteration.sh`, `verify-acceptance.sh`, `check-hard-bounds.sh`
- `templates/` — artifact templates (`prd.md`, `tech-spec.md`, `acceptance-contract.md`, `progress.md`, `contracts.md`, `canonical-entry-frontmatter.yaml`)
- `lib/` — internal helpers grouped by purpose: `canonical-memory/`, `ralph-loop/`, `sensors/`
- `docs/` — plugin docs (NOT the manifesto): `installation.md`, `quickstart.md`, `architecture.md`, `canonical-memory-setup.md`
- `examples/`, `tests/`, `CHANGELOG.md`, `CLAUDE.md`, `README.md`, `LICENSE`

Working memory (`.yoke/` per-project) and canonical memory (separate git repo)
are external to this plugin — created by `/yoke:bootstrap` in the host project.

## Structural Units

Five subagents materialized as separate files in `agents/`. The
Generator/Implementation and Validator/Validation distinctions are
**structural**, not runtime modes (decision 2026-04-24 — Five subagents):

- **Generator** (`agents/generator.md`) — produces PRD and Tech Spec; never writes to canonical memory
- **Validator** (`agents/validator.md`) — produces Acceptance Contract; never writes to canonical memory
- **Orchestrator** (`agents/orchestrator.md`) — sole writer of canonical memory; mediates reads, coordinates runtime, canonizes learnings
- **Implementation Agent** (`agents/implementation.md`) — runtime instance; iterates over Tech Spec; writes `.yoke/progress.md`
- **Validation Agent** (`agents/validation.md`) — runtime instance; runs sensors via `hooks/verify-acceptance.sh`; emits structured JSON verdicts

## Pattern Registry

<!-- vibeflow:patterns:start -->
patterns:
  - file: patterns/roles.md
    tags: [agents, generator, validator, orchestrator, write-authority]
    modules: []
  - file: patterns/phase-flow.md
    tags: [workflow, phases, gates, per-task, drift-sensing]
    modules: []
  - file: patterns/ralph-loop.md
    tags: [runtime, blueprint, hard-bounds, sprint-contracts, terminating]
    modules: []
  - file: patterns/acceptance-contract.md
    tags: [contract, binding, pre-runtime, bdd, fixtures, policies]
    modules: []
  - file: patterns/memory-model.md
    tags: [memory, working-memory, canonical-memory, two-tier, lifetime]
    modules: []
  - file: patterns/model-c-governance.md
    tags: [governance, authority, ratification, git-native, impact-class]
    modules: []
  - file: patterns/human-triggers.md
    tags: [hitl, gates, approval, arbitration, ratification]
    modules: []
  - file: patterns/sensors.md
    tags: [sensors, shift-left, computational, inferential, structured-output]
    modules: []
  - file: patterns/plugin-structure.md
    tags: [plugin, repo-structure, claude-code, distribution, packaging]
    modules: []
<!-- vibeflow:patterns:end -->

## Pattern Docs Available

- [`patterns/roles.md`](patterns/roles.md) — The five agent roles and their read/write authorities
- [`patterns/phase-flow.md`](patterns/phase-flow.md) — Five per-task phases + continuous Phase 6 (drift sensing)
- [`patterns/ralph-loop.md`](patterns/ralph-loop.md) — Implementation↔Validation loop, sprint contracts, hard bounds
- [`patterns/acceptance-contract.md`](patterns/acceptance-contract.md) — Binding pre-runtime artifact
- [`patterns/memory-model.md`](patterns/memory-model.md) — Working memory (`.yoke/`) vs canonical memory (separate git repo)
- [`patterns/model-c-governance.md`](patterns/model-c-governance.md) — Contextual authority by impact class + git-native protocol
- [`patterns/human-triggers.md`](patterns/human-triggers.md) — Five distinct human-in-the-loop triggers
- [`patterns/sensors.md`](patterns/sensors.md) — Computational and inferential sensors with structured output
- [`patterns/plugin-structure.md`](patterns/plugin-structure.md) — Target plugin repo layout + manifesto-to-artifact mapping

## Key Files

- `LICENSE` — MIT License (Iury Krieger, 2026)
- `yoke.md` (in `~/Downloads/`, outside the repo) — manifesto v1.0, the framework's design doctrine
- `yoke-implementation-plan.md` (in `~/Downloads/`, outside the repo) — Tech Spec v1.0, the 8-sprint construction plan

## Dependencies (critical only)

- **Claude Code** — must support plugin marketplace + subagents that spawn other subagents. Verified in Sprint 1 (Risk R1).
- **Vibeflow skills** — embedded at creation time as scaffolding. Generator uses them as reference for PRD / Tech Spec / Acceptance Contract. No continuous upstream port.
- **Bedrock skills** — embedded at creation time. Orchestrator uses them to write to canonical memory; Generator/Validator use them (via Orchestrator) to read.
- **External canonical-memory substrate** — a separate git repo created by `/yoke:bootstrap`. Reference implementation is Claude Bedrock; replaceable by any MCP-accessible equivalent.
- **`gh` CLI** — required from Sprint 5 onward for git-native canonical-memory protocol.
- **bash 4+** — `hooks/` and `lib/*.sh` target bash 4. macOS users need bash 4 via Homebrew.

## Known Issues / Tech Debt

- Repository is empty: no code yet. Every claim here comes from the manifesto and the implementation plan, not from real code.
- `.vibeflow/` was bootstrapped manually. Re-run `/vibeflow:analyze` once code exists to validate and refine patterns against the real implementation.

## Known Gaps

- Phase-6 background agents (drift sensing) and adversarial auditing of canonical memory are declared as planned extensions (manifesto Section 17), with the Sprint-7 plan recommending GitHub Actions as the initial scheduling surface.
- Cross-cutting principles (progressive disclosure, traceability, rippability) are consolidated in `conventions.md`. Once code exists they may graduate into their own pattern docs if there is concrete mechanics to document.
- `examples/greenfield-payment-service/` (Sprint-8) is the canonical end-to-end example but does not yet exist.

## Risks Tracked (from implementation plan, Section 13)

- **R1** — Claude Code may limit subagent depth; verify in Sprint 1 before Sprint 4.
- **R2** — Progressive-disclosure query latency at canonical-memory scale; measure with synthetic data in Sprint 5.
- **R3** — Hard-bound defaults may need per-project tuning; documented in Sprint 6, exemplified in Sprint 8.
- **R4** — Sprint-contract contradictions may evade detection; v1 ships a basic detector, refinement post-1.0.
- **R5** — Pre-Sprint-6 ralph loops have no hard bounds; smoke tests use external `timeout`.
- **R6** — Plugin marketplace format may change; track Vibeflow / Bedrock as references.
- **R7** — Bootstrap UX is multi-step; Sprint 1 Task 1.3 prioritizes good error output.

## Scoped Analyses

- 2026-04-24 — Manual bootstrap from `yoke.md` (manifesto), 8 patterns + conventions + 10 decisions seeded.
- 2026-04-24 — `/vibeflow:teach` against `yoke-implementation-plan.md`: +10 decisions, +1 pattern (`plugin-structure.md`), +8 implementation-mapping addenda, +`Implementation Plan Conventions` section.
