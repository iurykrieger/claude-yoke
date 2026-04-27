# PRD: Runtime-only agents — skills deliberate, subagents adapt

> Generated via /vibeflow:discover on 2026-04-25
> Status: draft (awaiting Trigger-1 approval)

## Problem

Yoke v1.0.0 ships with five subagents (`generator`, `validator`,
`implementation`, `validation` in `agents/`, plus an Orchestrator that
was already demoted from subagent to skill via the "PRD v0 amendment"
in the implement / orchestrator skills). In practice, this layout has
four overlapping failure modes:

1. **Skill→Task→Subagent depth is fragile.** The spec-phase skills
   (`/yoke:discover`, `/yoke:tech-spec`, `/yoke:acceptance-contract`)
   all spawn a subagent via the Task tool to drive dialogue with the
   user. Claude Code's Task tool is request/response — the subagent
   answers once and exits. Multi-round dialogue routed through a Task
   spawn loses control flow, makes Trigger 1/2/3 harder to surface,
   and forces the skill to re-spawn the subagent every revise round.
2. **Spec-phase subagents add no rigor.** The Generator subagent's
   "senior product engineer" persona and the Validator subagent's
   "senior QA engineer" persona are largely re-statements of what
   their invoking skill prompts already say. The actual adversariality
   at spec phase comes from the **human review at Triggers 1/2/3**,
   not from a separate subagent's prompt.
3. **Naming collision.** "Generator" denotes both the spec-drafting
   subagent and the code-writing runtime instance (via the
   `Generator` ↔ `Implementation Agent` mapping). Same for "Validator"
   ↔ `Validation Agent`. Users — and the model itself, when reading
   `agents/` files — confuse which is which. The five-files-for-two-
   roles split also dilutes the role identity.
4. **No Orchestrator presence at runtime.** v1.0.0 demoted the
   Orchestrator to a skill, which means there is no runtime peer to
   the Implementation / Validation Agents that can consult canonical
   memory in-context, monitor for divergence, and own the
   canonization handoff. `/yoke:canonize` runs cold after the loop
   ends — context has decayed, query traces are stale, and
   canonization candidates have to be re-derived from `.yoke/`
   archaeology rather than observed live.

The unifying insight: **skills handle deliberation on text artifacts
(low-stakes, human-driven, deterministic dialogue); subagents handle
adaptation at runtime (when code reality diverges from the plan, when
canonical memory needs to be consulted live, or when fresh
canonization signal is best harvested at loop completion).** v1.0
mixes the two — v1.1 separates them cleanly.

## Target Audience

- **Primary**: Yoke maintainers refactoring v1.0.0 → v1.1.0.
- **Secondary**: Developers who will adopt Yoke once v1.1 ships
  (v1.0 has no active host-project users — confirmed —
  so backward compatibility is not a constraint).

This PRD targets a v1.1.0 architectural refactor, not a v2 redesign.

## Proposed Solution

Restructure Yoke around two distinct execution modes:

### Pre-runtime (Phases 1–3) — skills only, no subagents

- `/yoke:discover`, `/yoke:tech-spec`, `/yoke:acceptance-contract`
  drive their dialogues directly. The persona and behavioral rules
  are embedded in the skill prompt itself, modeled on Vibeflow's
  `discover` / `gen-spec` skills and Ralph's autonomous-agent
  conventions, while keeping Yoke's framework characteristics
  (Triggers 1/2/3, `.yoke/` artifact paths, `/yoke:ask` routing,
  Acceptance Contract shape, sensor discovery from host
  `CLAUDE.md`). The user-facing Claude executes the dialogue.
  Triggers 1/2/3 surface natively in the same conversation.
- `/yoke:ask` becomes a thin skill that performs canonical-memory
  reads directly via `lib/canonical-memory/query.sh` — the same
  primitive the runtime Orchestrator subagent uses. The
  "Orchestrator skill in mediator mode" concept is retired.

### Runtime (Phase 4) — three subagents, spawned in parallel

- `/yoke:implement` (a skill) issues a single orchestration turn that
  spawns three Task calls concurrently per cycle:
  - **Generator** (renamed from Implementation Agent) — writes code
    targeting the next failing acceptance criterion.
  - **Validator** (renamed from Validation Agent) — runs
    `hooks/verify-acceptance.sh`, emits structured JSON verdicts.
  - **Orchestrator** (promoted back to a proper subagent) —
    consults canonical memory live during cycles, monitors for
    Generator↔Validator divergence, and owns the canonization
    handoff at loop termination.
- The three subagents communicate via working-memory files only:
  `.yoke/progress.md`, `.yoke/contracts.md`,
  `hooks/verify-acceptance.sh` output, `.yoke/query-trace.md`. No
  direct IPC between subagents.
- "Parallel" means **same orchestration turn, three concurrent Task
  calls per cycle, each operating on the freshest snapshot of
  working memory**. It is not cross-cycle pipelining and not
  long-lived persistent agents (Claude Code's Task tool is
  request/response).

### Canonization model

Canonical memory is **consulted live during the loop** (Orchestrator
subagent reads via `lib/canonical-memory/query.sh`, surfaces relevant
patterns into `.yoke/query-trace.md` for Generator/Validator
consumption). It is **written to only at loop completion**: when the
loop terminates (criteria pass or hard bound hit), `/yoke:implement`
signals the Orchestrator subagent's final invocation as the
canonization phase. The Orchestrator reads `.yoke/progress.md`,
`.yoke/contracts.md`, and `.yoke/query-trace.md`, applies the
five-criteria filter, classifies impact under Model C, and proposes
writes via `lib/canonical-memory/propose-write.sh`. Mid-loop
canonization is **out of scope** — only consultation runs live.

`/yoke:canonize` is preserved as a manual escape hatch (re-run
canonization on an existing `.yoke/` if the auto-run failed or the
user wants to re-evaluate), but the primary canonization path lives
inside the Orchestrator subagent.

### Subagent-depth concern, resolved

The original PRD-v0 amendment demoted Orchestrator to a skill because
of risk R1 (Claude Code subagent depth). That risk does not apply
here: `/yoke:implement` is a **skill** spawning three subagents in
one turn. **No subagent spawns another subagent.** Orchestrator can
therefore be a proper subagent again.

## Success Criteria

1. A single `/yoke:implement` invocation issues three parallel Task
   calls per cycle (verifiable via the assistant turn structure
   captured in `.yoke/.snapshots/cycle-N.yaml`).
2. `/yoke:discover`, `/yoke:tech-spec`, `/yoke:acceptance-contract`
   complete dialogue + artifact production **without invoking the
   Task tool** (verifiable: their `allowed-tools` no longer include
   `Task`).
3. The Orchestrator subagent's canonization phase fires
   automatically at `/yoke:implement` loop completion, reading
   `.yoke/progress.md`, `.yoke/contracts.md`, `.yoke/query-trace.md`
   and proposing at least one Model C write on a successful
   dogfooding smoke test (against a test canonical-memory repo).
4. `agents/` contains exactly three files after the refactor:
   `generator.md`, `validator.md`, `orchestrator.md`. The five-file
   layout is gone.
5. `/yoke:ask` is a thin skill that calls
   `lib/canonical-memory/query.sh` directly, with no subagent
   involvement.
6. Spec-phase skill prompts (`skills/discover/`, `skills/tech-spec/`,
   `skills/acceptance-contract/`) embed persona + behavioral rules
   inline, structurally modeled on Vibeflow's `discover`/`gen-spec`
   and Ralph conventions, while preserving Yoke-specific elements
   (Trigger 1/2/3 prompts, `.yoke/*.md` paths, `/yoke:ask`
   routing for canonical reads, Acceptance Contract shape, sensor
   discovery).
7. `.vibeflow/decisions.md` records the supersession of the
   "Five subagents" 2026-04-24 decision and the reaffirmation of
   "Three agentified roles" with the new instantiation model.
8. The manifesto (`yoke.md`) §10 (Model C), §13 (architecture), and
   `.vibeflow/patterns/roles.md` reflect the new role count and
   the consult-live / write-on-termination canonization stance.
9. The architecture diagram in `docs/` is refreshed to show the new
   topology (3 runtime subagents, skills-only spec phase).
10. All existing smoke tests (`tests/smoke/sprint-{1..4}.test.sh`)
    pass after the refactor — they may need updates to reflect
    renamed files but their semantic assertions still hold.
11. CHANGELOG documents v1.1.0; no migration path is needed (no
    active host-project users).

## Scope v0

The minimum closed set of changes that delivers the success criteria:

**`agents/` reshape**

- Delete `agents/generator.md` (spec-phase variant).
- Delete `agents/validator.md` (spec-phase variant).
- Rename `agents/implementation.md` → `agents/generator.md`. Drop
  the "distinct from Generator" disclaimers (no longer needed); keep
  the runtime-instance behaviors (writes `progress.md`, co-writes
  `contracts.md`, never modifies upstream artifacts).
- Rename `agents/validation.md` → `agents/validator.md`. Same
  cleanup.
- Promote Orchestrator from skill to subagent: create
  `agents/orchestrator.md` with a focused runtime prompt covering:
  - Consult mode during cycles (read canonical memory via
    `lib/canonical-memory/query.sh`, append to
    `.yoke/query-trace.md`, surface relevant patterns for
    Generator/Validator).
  - Monitor mode (detect Generator↔Validator divergence, escalate
    via `lib/ralph-loop/escalate.sh` per existing Trigger-4 schema).
  - Canonize mode at termination (read working memory, apply
    five-criteria filter, classify impact, propose Model C writes).

**`skills/` rewrites**

- `skills/discover/SKILL.md`: drop the Task spawn of `generator`.
  Embed persona + behavioral rules inline using Vibeflow's
  `discover` skill structure as the base, layered with Yoke
  framework elements (Trigger-1 prompt verbatim, `.yoke/prd.md`
  output path, `/yoke:ask` routing). Remove `Task` from
  `allowed-tools`.
- `skills/tech-spec/SKILL.md`: drop Task spawn; embed persona +
  rules using Vibeflow's `gen-spec` skill structure as the base,
  with Yoke's sprint/use-case Tech Spec shape and Trigger-2 prompt.
- `skills/acceptance-contract/SKILL.md`: drop Task spawn; embed
  senior-QA persona + rules inline. Sensor discovery via
  `lib/sensors/discover-from-claude-md.sh` stays. Trigger-3 binding
  statement printed verbatim.
- `skills/implement/SKILL.md`: rewrite cycle loop to spawn
  `generator`, `validator`, `orchestrator` in a single concurrent
  Task batch per cycle. Document the freshest-snapshot semantics.
  At loop termination, issue a final Orchestrator Task call with
  a `canonize=true` parameter (or equivalent) that triggers the
  canonization phase.
- `skills/orchestrator/SKILL.md`: delete or collapse to a stub. The
  three modes move into `agents/orchestrator.md`. `/yoke:ask` no
  longer routes through this skill.
- `skills/ask/SKILL.md`: rewrite as a thin skill that calls
  `lib/canonical-memory/query.sh` directly and writes to
  `.yoke/query-trace.md`. No subagent spawn.
- `skills/canonize/SKILL.md`: keep as a manual escape hatch — it
  invokes the Orchestrator subagent's canonize mode against an
  existing `.yoke/` directory.

**Documentation and decisions**

- Append a new entry to `.vibeflow/decisions.md` dated 2026-04-25
  superseding the 2026-04-24 "Five subagents" decision.
- Append a second entry reaffirming "Three agentified roles" with
  the new "instantiated only at runtime" clause.
- Append a third entry establishing the
  *Skills deliberate; subagents adapt* invariant.
- Append a fourth entry establishing the
  *Consult live, canonize on termination* canonization stance.
- Update `yoke.md` §10 (Model C — note that propositions are
  generated only at loop termination), §13 (architecture diagram +
  role count), and any other §s touching agent topology.
- Update `.vibeflow/patterns/roles.md` to remove the spec-phase
  Generator/Validator instances; update
  `.vibeflow/patterns/ralph-loop.md` to describe parallel-spawn
  cycle semantics + termination canonization.
- Refresh the architecture diagram in `docs/` (whatever current
  format — Mermaid, PNG, etc.) to show the 3-subagent runtime
  topology and skills-only spec phase.

**Versioning and tests**

- Bump `.claude-plugin/plugin.json` version to `1.1.0`.
- CHANGELOG entry under `## [1.1.0]` describing the refactor.
- Update `tests/smoke/sprint-{2..4}.test.sh` for renamed agent files
  and Task-call removal in spec-phase skills.
- Add a new smoke test that verifies the three-agent parallel spawn
  in `/yoke:implement` (counts Task calls in a single turn against
  a fixture acceptance contract).
- Add a smoke test that verifies the Orchestrator's termination
  canonization fires (against a test canonical-memory repo or
  `--dry-run`).

## Anti-scope

Explicit non-goals — these are **out** of v1.1.0:

- **Not redesigning the binding contract.** Acceptance Contract
  semantics, Triggers 1/2/3, Phase 4 envelope discipline are
  unchanged.
- **Not changing Model C.** Impact classes (low / medium / high /
  regulatory) and per-class PR behavior are preserved.
- **Not introducing mid-loop canonization writes.** Canonical memory
  is read live, written only at loop termination.
- **Not changing the canonical-memory substrate.** Still git-native
  via Bedrock primitives.
- **Not introducing IPC between subagents.** They communicate via
  files. No sockets, no shared memory, no message queues.
- **Not supporting long-lived persistent subagents.** Each cycle's
  Task call is request/response. Cross-cycle state lives in
  working-memory files.
- **Not building cross-cycle pipelining.** Generator working on
  cycle N+1 while Validator validates cycle N is explicitly
  deferred.
- **Not removing `/yoke:canonize`.** It remains as a manual
  escape hatch for re-running canonization on an existing `.yoke/`.
- **Not maintaining backward compatibility.** No active host-project
  users; v1.0 → v1.1 is a clean break. No migration script needed.
- **Not changing `/yoke:bootstrap` semantics.** The `.yoke/`
  directory layout and config schema are unchanged. Only the
  plugin-side `agents/` and `skills/` change.
- **Not redesigning the manifesto's six-phase flow.** Phases stay.
  Only agent topology changes.

## Technical Context

**Existing patterns to follow**

- Plugin layout per `.vibeflow/patterns/plugin-structure.md` is
  unchanged. Files move within the existing directory shape.
- YAML frontmatter conventions for agents per
  `.vibeflow/patterns/roles.md`. The new `agents/orchestrator.md`
  follows the same shape as the renamed `generator.md` /
  `validator.md`.
- `verify-acceptance.sh` output format and structured JSON verdict
  format are preserved.
- Hard bounds (5–8 cycles, timeout, budget) and Trigger-4 escalation
  packets are preserved (`hooks/check-hard-bounds.sh`,
  `lib/ralph-loop/escalate.sh`).
- The canonization five-criteria filter, Model C impact
  classification, and `propose-write.sh` PR primitive are preserved.
- Lineage notes: spec-phase skills credit Vibeflow's
  `discover`/`gen-spec` for prompt structure (one-time fork at
  Sprint 2, now refreshed for v1.1) plus Ralph conventions where
  applicable. Canonical-memory primitives in `lib/canonical-memory/`
  retain their Bedrock lineage.

**Decisions being touched**

- 2026-04-24 "Five subagents (Generator, Validator, Orchestrator,
  Implementation, Validation) as distinct entities" — **superseded**.
  New decision retains adversarial Generator/Validator separation
  *at runtime*; eliminates spec-phase subagent instances entirely.
- 2026-04-24 "Three agentified roles (Generator, Validator,
  Orchestrator)" — **reaffirmed and clarified**. Three roles, each
  instantiated exactly once at runtime; spec-phase work is performed
  by skills with embedded persona, with the human as the adversary
  via Triggers 1/2/3.
- PRD-v0 amendment "Orchestrator is a skill, not a subagent" —
  **reversed**. Risk R1 (subagent depth) does not apply: a *skill*
  spawns three subagents in one turn; no subagent spawns another.
- New invariant: *Skills deliberate; subagents adapt.*
- New invariant: *Canonical memory is consulted live during runtime;
  canonization writes happen only at loop termination.*

**Constraints**

- Bash 4+ for any new helper scripts (per `CLAUDE.md` and
  `.vibeflow/conventions.md`).
- Markdown lint per `.vibeflow/conventions.md`.
- The plugin "build" is the directory layout matching
  `.vibeflow/patterns/plugin-structure.md` exactly. Sprint 8's CI
  gate must continue to pass.

## Open Questions

None. All five questions raised during discovery were resolved:

- **Q1** (canonization timing) → consult live during the loop,
  canonize only at termination. Mid-loop writes out of scope.
- **Q2** (migration) → no active users; clean v1.0 → v1.1 break.
- **Q3** (mediator-mode location) → `/yoke:ask` becomes a thin
  skill calling `query.sh` directly; the "Orchestrator skill in
  mediator mode" concept is retired.
- **Q4** (skill-prompt persona depth) → model on Vibeflow's
  `discover`/`gen-spec` and Ralph conventions; preserve Yoke
  framework characteristics (Triggers, paths, Acceptance Contract,
  sensor discovery).
- **Q5** (diagram update) → in scope; refresh the architecture
  diagram in `docs/`.
