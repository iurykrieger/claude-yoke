# Project: claude-yoke
> Analyzed: 2026-04-24 (manual bootstrap from `yoke.md` v1.0 + `yoke-implementation-plan.md` v1.0); refreshed 2026-04-25 (v1.1 runtime-only-agents refactor)
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
- `agents/` — three runtime subagents: `generator.md`, `validator.md`, `orchestrator.md`
- `hooks/` — bash scripts: `pre-implementation.sh`, `post-iteration.sh`, `verify-acceptance.sh`, `check-hard-bounds.sh`
- `templates/` — artifact templates (`prd.md`, `tech-spec.md`, `acceptance-contract.md`, `progress.md`, `contracts.md`, `canonical-entry-frontmatter.yaml`)
- `lib/` — internal helpers grouped by purpose: `canonical-memory/`, `ralph-loop/`, `sensors/`
- `docs/` — plugin docs (NOT the manifesto): `installation.md`, `quickstart.md`, `architecture.md`, `canonical-memory-setup.md`
- `examples/`, `tests/`, `CHANGELOG.md`, `CLAUDE.md`, `README.md`, `LICENSE`

Working memory (`.yoke/` per-project) and canonical memory (separate git repo)
are external to this plugin — created by `/yoke:bootstrap` in the host project.

## Structural Units

Three runtime subagents materialized as separate files in `agents/`
(decision 2026-04-25 — Three runtime subagents only; supersedes
2026-04-24 — Five subagents). Spec-phase personas (Generator,
Validator) are embedded **inline** in their respective skills, not
materialized as separate subagent files. *Skills deliberate;
subagents adapt.*

- **Generator** (`agents/generator.md`) — runtime subagent. Iterates
  over the Tech Spec, writes code, persists `.yoke/progress.md` every
  cycle. Spawned in parallel by `/yoke:implement` alongside Validator
  and Orchestrator.
- **Validator** (`agents/validator.md`) — runtime subagent. Runs
  sensors via `hooks/verify-acceptance.sh`; emits structured JSON
  verdicts; co-writes `.yoke/contracts.md` on consensus. Spawned in
  parallel each cycle.
- **Orchestrator** (`agents/orchestrator.md`) — runtime subagent and
  sole writer of canonical memory under Model C. Three modes:
  consult (read canonical memory live during cycles, append to
  `.yoke/query-trace.md`), monitor (detect divergence, escalate via
  `lib/ralph-loop/escalate.sh`), canonize (at loop termination,
  apply five-criteria filter, propose writes via
  `lib/canonical-memory/propose-write.sh`).

Spec-phase work (Phases 1–3) is performed by skills with embedded
persona prompts:

- **Generator persona** lives inline in `skills/discover/SKILL.md`
  and `skills/tech-spec/SKILL.md`.
- **Validator persona** lives inline in
  `skills/acceptance-contract/SKILL.md`.

Skills do not spawn subagents at spec phase. The human is the
adversary via Triggers 1/2/3.

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
    tags: [runtime, blueprint, hard-bounds, sprint-contracts, terminating, parallel-spawn]
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

- [`patterns/roles.md`](patterns/roles.md) — Three runtime subagents (Generator, Validator, Orchestrator) and their read/write authorities; spec-phase personas inline in skills
- [`patterns/phase-flow.md`](patterns/phase-flow.md) — Five per-task phases + continuous Phase 6 (drift sensing); skills drive 1–3, subagents drive Phase 4 + auto-canonize
- [`patterns/ralph-loop.md`](patterns/ralph-loop.md) — Parallel-spawn 3-subagent loop, sprint contracts, hard bounds, termination canonization handoff
- [`patterns/acceptance-contract.md`](patterns/acceptance-contract.md) — Binding pre-runtime artifact
- [`patterns/memory-model.md`](patterns/memory-model.md) — Working memory (`.yoke/`) vs canonical memory (separate git repo); consult-live / canonize-at-termination access timing
- [`patterns/model-c-governance.md`](patterns/model-c-governance.md) — Contextual authority by impact class + git-native protocol
- [`patterns/human-triggers.md`](patterns/human-triggers.md) — Five distinct human-in-the-loop triggers
- [`patterns/sensors.md`](patterns/sensors.md) — Computational and inferential sensors with structured output
- [`patterns/plugin-structure.md`](patterns/plugin-structure.md) — Target plugin repo layout + manifesto-to-artifact mapping

## Key Files

- `LICENSE` — MIT License (Iury Krieger, 2026)
- `yoke.md` (in `~/Downloads/`, outside the repo) — manifesto v1.0, the framework's design doctrine
- `yoke-implementation-plan.md` (in `~/Downloads/`, outside the repo) — Tech Spec v1.0, the 8-sprint construction plan

## Dependencies (critical only)

- **Claude Code** — must support plugin marketplace + parallel-spawn from skills (one assistant turn, multiple Task tool-use blocks). Verified in Sprint 1 (Risk R1).
- **Vibeflow skills** — embedded at creation time as scaffolding. Spec-phase skills (`/yoke:discover`, `/yoke:tech-spec`, `/yoke:acceptance-contract`) follow Vibeflow's structural shape with Yoke-specific framework characteristics.
- **Bedrock skills** — embedded at creation time. Orchestrator subagent uses `lib/canonical-memory/*.sh` to read (consult mode) and write (canonize mode) canonical memory.
- **External canonical-memory substrate** — a separate git repo created by `/yoke:bootstrap`. Reference implementation is Claude Bedrock; replaceable by any MCP-accessible equivalent.
- **`gh` CLI** — required from Sprint 5 onward for git-native canonical-memory protocol.
- **bash 4+** — `hooks/` and `lib/*.sh` target bash 4. macOS users need bash 4 via Homebrew.

## Known Issues / Tech Debt

- `.vibeflow/` was bootstrapped manually. Re-run `/vibeflow:analyze` once code exists to validate and refine patterns against the real implementation.

## Known Gaps

- Phase-6 background agents (drift sensing) and adversarial auditing of canonical memory are declared as planned extensions (manifesto Section 17), with the Sprint-7 plan recommending GitHub Actions as the initial scheduling surface.
- Cross-cutting principles (progressive disclosure, traceability, rippability) are consolidated in `conventions.md`. Once code exists they may graduate into their own pattern docs if there is concrete mechanics to document.
- `examples/greenfield-payment-service/` (Sprint-8) is the canonical end-to-end example but does not yet exist.

## Risks Tracked (from implementation plan, Section 13)

- **R1** — Claude Code may limit parallel Task spawning depth from skills; verified in Sprint 1 before Sprint 4.
- **R2** — Progressive-disclosure query latency at canonical-memory scale; measure with synthetic data in Sprint 5.
- **R3** — Hard-bound defaults may need per-project tuning; documented in Sprint 6, exemplified in Sprint 8.
- **R4** — Sprint-contract contradictions may evade detection; v1 ships a basic detector, refinement post-1.0.
- **R5** — Pre-Sprint-6 ralph loops have no hard bounds; smoke tests use external `timeout`.
- **R6** — Plugin marketplace format may change; track Vibeflow / Bedrock as references.
- **R7** — Bootstrap UX is multi-step; Sprint 1 Task 1.3 prioritizes good error output.

## Scoped Analyses

- 2026-04-24 — Manual bootstrap from `yoke.md` (manifesto), 8 patterns + conventions + 10 decisions seeded.
- 2026-04-24 — `/vibeflow:teach` against `yoke-implementation-plan.md`: +10 decisions, +1 pattern (`plugin-structure.md`), +8 implementation-mapping addenda, +`Implementation Plan Conventions` section.
- 2026-04-25 — runtime-only-agents v1.1 refactor: collapsed `agents/` from 5 to 3 (runtime-only); spec-phase personas embedded inline in skills; Orchestrator promoted back to subagent; +4 decisions; rewrote `roles.md`, `ralph-loop.md`; updated `memory-model.md`, `plugin-structure.md`, `phase-flow.md`, `index.md`.
