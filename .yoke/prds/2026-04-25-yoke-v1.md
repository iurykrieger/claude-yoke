# PRD: Yoke v1.0 — A Claude Code Plugin for Governed Adversarial AI-Agent Development

> Generated via /vibeflow:discover on 2026-04-24
> Sources: `~/Downloads/yoke.md` (manifesto v1.0), `~/Downloads/yoke-implementation-plan.md` (Tech Spec v1.0)

## Problem

AI agents for code today fail in predictable, repeated ways. They write
code that passes its own test but doesn't do what the user wanted. They
accumulate silent "AI slop" in the codebase. They lose context between
sessions. They repeat the same mistakes because no learning persists.
They evaluate their own output with positive bias (self-evaluation bias
documented by Milvus). They break architectures by ignoring invariants
that aren't explicit. They iterate forever when the task moves outside
the regime where they're reliable.

The harness-engineering discipline (Böckeler, OpenAI, Stripe, Anthropic,
HumanLayer, LangChain, 2025–2026) has identified these as structural
failures of the **environment around the agent**, not of the model. But
the community has not produced a coherent operational answer that
integrates guides, sensors, rules files, hooks and skills as a single
system. There is also no named pattern for end-to-end flow with explicit
human gates, no binding pre-runtime contract artifact (only post-hoc
Anthropic-style sprint contracts), no governance model with contextual
write authority for canonical memory, and no inverse-rule discipline
that re-tests guides against the current model (rippability).

A developer using Claude Code who hits any of these failure modes today
has no installable, opinionated framework that fixes the environment.
They either accept the failures, or hand-build per-project guardrails
that don't compose.

## Target Audience

**Primary.** Software developers using Claude Code (CLI / web / IDE
extensions) on real codebases — typically with strong typing, clear
modular boundaries, and well-trodden frameworks (the manifesto's
"harnessable" codebases, §7.3). They have already experienced AI-agent
failures and are looking for a structural fix rather than per-task
workarounds.

**Secondary.** Harness engineers and platform / DevEx teams responsible
for organization-wide AI-agent quality. They will own the
canonical-memory substrate, ratify high-impact policies, and tune Model
C thresholds.

**Out of audience for v1.0.** Users on legacy codebases with high
technical debt (manifesto §7.3 — Yoke amplifies harnessability rather
than creating it). Organizations without a Git-native review workflow
(the canonical-memory protocol depends on it).

## Proposed Solution

**Yoke v1.0**, distributed as a single Claude Code plugin
(`/plugin install yoke@yoke-marketplace`), shipping the three pillars of
the manifesto:

1. **Binding spec.** Three sequential artifacts (PRD, Tech Spec,
   Acceptance Contract) produced by separate agents (Generator and
   Validator), each gated by an explicit human approval. The Acceptance
   Contract is binding — once ratified, it operationally defines "done"
   and cannot be changed inside the runtime loop.

2. **Adversarial loop.** A ralph loop that coordinates an Implementation
   Agent and a Validation Agent with disjoint prompts and contexts,
   structured as a blueprint of deterministic and agentic nodes, with
   hard bounds (N cycles, timeout, budget) that guarantee termination
   and human-escalate when reached.

3. **Governed memory.** A two-tier memory model: working memory in
   `.yoke/` per project for ephemeral artifacts, and canonical memory in
   a separate Git repository with markdown + frontmatter + graph (over
   MCP). All canonical-memory writes go through the Orchestrator under
   Model C — contextual authority by impact class, executed as PRs on
   the substrate repo.

The plugin exposes the flow through nine slash commands
(`/yoke:bootstrap`, `/yoke:discover`, `/yoke:tech-spec`,
`/yoke:acceptance-contract`, `/yoke:implement`, `/yoke:canonize`,
`/yoke:drift-sense`, `/yoke:ask`, `/yoke:status`), four deterministic
hooks, three shell-script libraries (`canonical-memory/`, `ralph-loop/`,
`sensors/`), and a set of artifact templates. Phase 6 (drift sensing)
runs continuously via GitHub Actions outside the change lifecycle. Yoke
is bootstrapped manually for v1.0; v1.1+ may dogfood Yoke on itself.

## Success Criteria

**Hard gates for shipping v1.0:**

1. `/plugin marketplace add iurykrieger/yoke` and
   `/plugin install yoke@yoke-marketplace` succeed against a clean
   Claude Code install.
2. End-to-end CI smoke test passes: a clean test repo runs
   `/yoke:bootstrap → /yoke:discover → /yoke:tech-spec →
   /yoke:acceptance-contract → /yoke:implement → /yoke:canonize` and
   produces merge-ready code plus at least one canonical-memory PR.
3. The full flow completes within 30 minutes for the
   `examples/greenfield-payment-service/` example (manifesto's
   harnessability sweet spot).
4. Hard bounds are respected: the ralph loop terminates within N cycles,
   timeout, or budget — never iterates past a bound without human
   escalation.
5. Five distinct human triggers fire with distinguishable, non-coalesced
   messages.

**Validating signals (post-ship):**

- At least one external user (not Iury) runs the full flow on a real
  task and merges the result.
- At least three canonical-memory PRs from real usage are auto-merged at
  low impact, and at least one medium-impact veto window is exercised.
- Phase-6 drift sensing detects a known synthetic regression
  (intentional dead code + intentional canonical-memory contradiction)
  within the first scheduled run.

## Scope v0

The full implementation plan, organized as 8 sprints. Each sprint ships
an installable, exercisable plugin version (manifesto convention:
"installable per sprint").

- **Sprint 1** — plugin scaffolding + `/yoke:bootstrap`. Plugin
  installable from marketplace. Bootstrap creates `.yoke/` and the
  canonical-memory repo. Validates plugin format against Claude Code's
  current schema.
- **Sprint 2** — `/yoke:discover` + `/yoke:tech-spec` + Generator
  subagent + minimal `/yoke:ask` (text grep, no progressive disclosure
  yet).
- **Sprint 3** — `/yoke:acceptance-contract` + Validator subagent +
  sensor discovery from host `CLAUDE.md` + `verify-acceptance.sh`.
- **Sprint 4** — basic ralph loop + Implementation and Validation
  Agents + `progress.md` + `contracts.md`. No hard bounds yet — smoke
  tests guarded by external `timeout`.
- **Sprint 5** — Orchestrator (as a skill, see Technical Context) +
  canonization + low-impact Model C path + git-native protocol via
  `gh` CLI.
- **Sprint 6** — full Model C (medium + high impact) + hard bounds +
  five named triggers + progressive disclosure (subgraph queries).
- **Sprint 7** — Phase 6 drift sensing + GitHub Actions scheduling +
  staleness / contradiction / dead-code detection.
- **Sprint 8** — `examples/greenfield-payment-service/` + complete docs +
  CI workflow + marketplace publication + v1.0.0 release + lineage doc.

End state: Yoke v1.0 published in the Claude Code marketplace, with a
working end-to-end example, full documentation, and CI smoke tests for
every sprint.

## Anti-scope

Drawn from manifesto §7.2, §16 and implementation plan §16. Explicitly
**NOT in v1.0**:

- **Recursive bootstrap (Yoke building Yoke).** v1.0 is built manually.
  Dogfooding starts at v1.1.
- **Functional correctness outside the Acceptance Contract.** The
  behaviour-harness problem remains open in the discipline; Yoke does
  not pretend to solve it.
- **Levels 4–5 verifiability** (Deer Valley scale — creative / ethical /
  strategic). Yoke ships at Levels 1–3.
- **Multi-organization shared canonical memory.** Each Yoke install has
  its own substrate.
- **Migration tooling between Yoke versions.** When Yoke v2 changes the
  frontmatter format, migration is not v1.0's problem.
- **Performance for codebases > 100k LOC.** Acceptance criteria assume
  small-to-medium projects.
- **Telemetry / analytics infrastructure for the §18 health metrics.**
  Metrics are defined; collection infra is post-v1.
- **Internationalization beyond English.** Source language is English.
- **Adversarial canonical-memory audit (manifesto §17).** Declared as a
  planned extension, not part of v1.0.
- **Post-deploy observation (production logs / SLOs / incidents).** Also
  a planned extension (§17).
- **Org-wide policy bundles seeded with the substrate.** Substrate is
  created empty; content is the org's responsibility (manifesto §5.2).
- **A continuous upstream port from Vibeflow / Bedrock.** Skills are
  embedded as a one-time fork at creation; lineage is documented but
  evolution is autonomous.

## Technical Context

Bootstrapped from `.vibeflow/`:

**Patterns the implementation must follow** (all in `.vibeflow/patterns/`):

- `roles.md` — agent roles with explicit read/write authority (with the
  v0 amendment below).
- `phase-flow.md` — five sequential per-task phases + continuous
  Phase 6.
- `ralph-loop.md` — blueprint of deterministic + agentic nodes, hard
  bounds, sprint contracts, four divergence categories.
- `acceptance-contract.md` — binding pre-runtime artifact, BDD +
  fixtures + policies + sensors.
- `memory-model.md` — `.yoke/` for working memory, separate Git repo for
  canonical memory, mandatory frontmatter (rippability metadata +
  relationship edges).
- `model-c-governance.md` — contextual authority by impact class,
  git-native PR-based ratification.
- `human-triggers.md` — five distinct, non-coalesced triggers.
- `sensors.md` — computational + inferential, structured output,
  calibration metadata.
- `plugin-structure.md` — target repo layout + manifesto-component →
  artifact mapping.

**Conventions:** see `.vibeflow/conventions.md` — cross-cutting
principles (shift-feedback-left, back-pressure, blueprint wrapping, hard
bounds, sensor output for LLM consumption, progressive disclosure,
sprint contracts, minimalist canonical memory with traceability,
environment-designers-not-code-writers) plus implementation-process
conventions (vertical-slice sequencing, installable per sprint, smoke
test per sprint, manual bootstrap, bash 4+, lineage honesty).

**Decision log:** `.vibeflow/decisions.md` — 20 architectural decisions,
all dated 2026-04-24.

### v0 amendment to the architecture (resolved during this discovery)

**Orchestrator becomes a skill, not a subagent.** Risk R1 from the
implementation plan (Claude Code subagent depth: can a subagent spawn
other subagents?) is sidestepped by making the Orchestrator a skill that
invokes the four agent subagents (Generator, Validator, Implementation,
Validation) via the Task tool. This:

- Drops R1 from the risk register entirely — no more "what if subagent
  depth is unsupported?".
- Reduces the subagent count from five to four. The Orchestrator's
  three responsibilities (mediator, runtime coordinator, canonizer) are
  expressed as skill modes or as sibling skills under
  `skills/orchestrator/` (resolved in the Tech Spec).
- Preserves every other invariant: Model C still applies, progressive
  disclosure still mediates reads, the Orchestrator is still the only
  writer of canonical memory.
- Updates the "Five subagents as distinct entities" decision recorded
  earlier today: it becomes "Four agent subagents + Orchestrator as a
  skill". This delta needs ratification into `.vibeflow/decisions.md`
  (and the `roles.md`, `plugin-structure.md`, `model-c-governance.md`
  pattern docs) via `/vibeflow:teach` before `/vibeflow:gen-spec`
  consumes this PRD.

**Critical platform dependencies:**

- **Claude Code** must support skills invoking subagents via the Task
  tool, plus the plugin marketplace. Validated in Sprint 1 against the
  current schema.
- **`gh` CLI** from Sprint 5 onwards (canonical-memory PRs).
- **bash 4+** (`hooks/`, `lib/`). macOS users need bash 4 via Homebrew.
- **External canonical-memory Git repository**, created during
  `/yoke:bootstrap`.

## Open Questions

These are explicit TODOs the Tech Spec must resolve before runtime
sprints (4+) can be planned in detail:

1. **Where does the Orchestrator-as-skill live in the repo layout?**
   Single skill at `skills/orchestrator/SKILL.md`, or split across
   phase-owning skills (each phase skill calls into a shared
   `lib/orchestrator/`)? `plugin-structure.md` must be updated either
   way.
2. **Sprint-contract negotiation primitive.** When Implementation and
   Validation reach consensus on a sub-objective, what is the
   deterministic protocol that turns that consensus into a
   `contracts.md` entry without an LLM-judgement step in the middle?
3. **Inferential-sensor calibration UX.** How is calibration produced —
   by hand for v1.0, or via a calibration skill? If by hand, where in
   the docs is the walkthrough?
4. **Hard-bound defaults across organizations.** N = 5–8 cycles, 2–4 h
   timeout — but Risk R3 (calibrated wrong on non-trivial projects)
   stands. Does v1.0 ship one default profile, or three (small / medium
   / large task class)?
5. **`gh` CLI fallback.** What happens if `gh` is missing or
   unauthenticated during `/yoke:bootstrap`? Hard fail with
   instructions, or degraded mode that defers canonical-memory writes?
6. **Phase-6 scheduling on non-GitHub remotes.** GitHub Actions is the
   recommendation. Is there a documented fallback (cron, daemon) for
   users on GitLab / self-hosted?
7. **Bootstrap UX bar (Risk R7).** Is the v1.0 bar "bootstrap succeeds
   for someone reading only `docs/quickstart.md`" or "bootstrap is
   interactive and walks the user through every step"? Different
   Sprint-1 effort.
8. **Health-metric collection in v1.0.** Anti-scope says no telemetry
   infra, but the §18 manifesto metrics are how we'd know the system is
   working post-ship. Is there a minimal local-only collection for the
   reference example, or zero collection until v1.1?
9. **Canonical-memory bootstrap content.** Manifesto §14.3 says
   "canonical memory is populated by the upstream framework before Yoke
   goes into operation". `/yoke:bootstrap` creates the substrate empty.
   Does v1.0 ship a starter pack (template ADRs, default sensor
   calibrations, baseline policies) or strictly empty? Affects "first
   run produces zero `/yoke:ask` results" UX.
10. **`/yoke:status` scope.** Listed in the plugin surface but not
    expanded. Minimum: shows current task phase, working-memory
    presence, last canonization PR. Stretch: also shows hard-bound
    consumption, query trace, Phase-6 last-run summary. Tech Spec must
    pick a level.
