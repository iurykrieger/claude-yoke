# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> Instructions for Claude Code when operating *this* repository (the Yoke
> plugin source). For users *of* Yoke working in their own project, see
> `templates/project-claude-md.md` (which `/yoke:bootstrap` copies into
> their repo).

## Project status

Yoke is being built sprint by sprint. **v0.1.0 (Sprint 1 — scaffolding +
bootstrap) is the current shipped state.** The full plugin layout exists,
but only `/yoke:bootstrap` is functionally implemented; the other eight
slash commands are placeholders. See `.vibeflow/specs/yoke-v1-sprint-{1..8}.md`
for the planned sprint-by-sprint build-out.

The manifesto (`yoke.md`) and the implementation plan (`yoke-implementation-plan.md`)
are the design source of truth. **Before proposing any file, module or command,
check whether the decision is already fixed in the manifesto, the
implementation plan, or `.vibeflow/decisions.md`.**

## Where things live

- `.vibeflow/` — project knowledge: patterns, conventions, decisions, PRDs, specs, audits.
- `.claude-plugin/` — plugin manifest (`plugin.json`, `marketplace.json`).
- `skills/`, `agents/`, `hooks/`, `templates/`, `lib/`, `docs/`, `tests/`, `examples/` — see `.vibeflow/patterns/plugin-structure.md` for the full layout and the manifesto-component → artifact mapping.

## Working on this repo

1. Read `.vibeflow/index.md` for project state before any non-trivial change.
2. Follow `.vibeflow/conventions.md` exactly — the Don'ts list is non-negotiable.
3. Pattern docs in `.vibeflow/patterns/` are the source of truth for HOW to implement each component.
4. Decisions already fixed in `.vibeflow/decisions.md` or the manifesto are not re-decided in code — only refined.
5. New trade-offs become input for canonical memory via Model C, not unilateral decisions.

## Sprint discipline

- Each sprint has a spec at `.vibeflow/specs/yoke-v1-sprint-N.md`.
- Use `/vibeflow:implement <spec>` to implement a sprint.
- Use `/vibeflow:audit <spec>` to verify against DoD.
- Each sprint produces an installable plugin version (0.1.0 → 1.0.0).
- The manifesto and the plan are the architect's input; this file is the coding agent's runtime guidance.

## Testing

<!-- Yoke parses this section to discover available sensors when Yoke is run on Yoke. -->

- Smoke tests live under `tests/smoke/sprint-N.test.sh` (added per sprint).
- Pre-Sprint-6 smoke tests must use external `timeout 600` to guard against ralph-loop iterations without hard bounds.
- Sprint 8 wires `tests/` into a CI workflow that gates every PR.

## Linting

<!-- Yoke parses this section to discover available sensors. -->

- Bash scripts target bash 4+. Use `shellcheck` if available.
- Markdown follows the conventions documented in `.vibeflow/conventions.md`.

## Build

<!-- Yoke parses this section to discover available sensors. -->

This is a plugin, not a compiled artifact. "Build" = the directory layout must
match `.vibeflow/patterns/plugin-structure.md` exactly. Sprint 8 adds a CI gate
that enforces this.

---

## What Yoke is

A framework for software development with AI agents. It couples two adversarial agents (Implementation and Validation) inside an envelope defined by a binding human contract (Acceptance Contract), with a third agent (Orchestrator) mediating canonical-memory queries and canonization of learnings. Distributed as a single self-contained package with embedded skills (Vibeflow for spec generation; Bedrock for canonical-memory access via MCP).

## Architecture — three roles, two memory tiers, one user

**Roles** (each with a distinct functional objective and distinct write protocols):

- **Generator** — produces `prd.md` (Phase 1) and `tech-spec.md` (Phase 2). At runtime, instantiates the **Implementation Agent**.
- **Validator** — produces `acceptance-contract.md` (Phase 3, **binding**). At runtime, instantiates the **Validation Agent**.
- **Orchestrator** — three responsibilities: mediator of canonical queries (upstream), runtime coordinator (Phase 4), canonizer (Phase 5). **Sole agent with write authority to canonical memory**, governed by Model C. **PRD v0 amendment:** the Orchestrator is implemented as a *skill* in `skills/orchestrator/`, not a subagent — it invokes the four agent subagents (Generator, Validator, Implementation, Validation) via the Task tool. Lands in Sprint 5.

**Memory — two tiers with different lifetimes and authorities:**

| Tier | Location | Who writes | Lifetime |
| :---- | :---- | :---- | :---- |
| Working memory | host project's `.yoke/` (`prd.md`, `tech-spec.md`, `acceptance-contract.md`, `progress.md`, `contracts.md`, `query-trace.md`) | Generator/Validator/derived agents freely | task/sprint |
| Canonical memory | external substrate via MCP (reference: Claude Bedrock; replaceable) | only Orchestrator, under Model C | permanent, versioned |

The separation exists because the blast radius is asymmetric: corrupted working memory affects one task; corrupted canonical memory affects the organization.

## Six-phase flow

Per-task (sequential, with a human gate between each):

1. **Discovery** → approved `prd.md`
2. **Tech Spec** → approved `tech-spec.md`
3. **Acceptance Contract** → approved `acceptance-contract.md` (binding)
4. **Runtime** — Implementation↔Validation ralph loop; produces `progress.md` + `contracts.md`
5. **Canonization** — Orchestrator proposes writes to canonical memory

Continuous: **Drift sensing** over codebase, canonical memory and historical traces.

## Five human-in-the-loop triggers (do not conflate)

1. PRD approval (blocks Phase 2)
2. Tech Spec approval (blocks Phase 3)
3. Acceptance Contract approval (blocks Phase 4)
4. Implementation↔Validation divergence arbitration (blocks runtime)
5. Canonization ratification (non-blocking; Model C decides auto-apply / notify-and-apply / synchronous)

## Non-negotiable invariants

These are architectural properties — code that violates them is wrong, even when it looks simpler.

- **Binding spec.** The approved Acceptance Contract operationally defines what "done" means. Changes during implementation require new ratification.
- **Adversarial loop with hard bounds.** Implementation and Validation have opposing objectives. Convergence → merge. Divergence → user arbitrates. Hard bound reached (5-8 cycles / 2-4h / budget) → escalation. **Never an infinite loop.**
- **Sprint contracts ⊂ Acceptance Contract.** Agreements emerging between agents at runtime cannot contradict the binding contract. Attempted contradiction = Trigger 4.
- **Governed canonical memory.** Only the Orchestrator writes. Git-native protocol (PRs). Every write traceable to a past failure or hard constraint — items without traceability are pruning candidates.
- **Progressive disclosure.** No agent receives the full canonical memory; the Orchestrator loads only the relevant subgraph per phase/task.
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
- **Generator over-constraining** (16.3) — too many guides degrade performance (ETH Zurich evidence: LLM-generated AGENTS.md cost +20% tokens and degrade output). Mitigation: utilization metric as pruning trigger, mandatory traceability.
- **Human ratification fatigue** (16.4) — approvals become rubber-stamp. Signal: human never edits proposals.
- **Orchestrator as SPOF** (13.4 / 16.7) — failure interrupts Phase 4 coordination. Mitigation: checkpointing + resumption via `progress.md` and `contracts.md`.

## When working in this repo

1. Read the manifesto before proposing code structure.
2. Decisions already fixed in the manifesto are not re-decided in code — only refined.
3. New trade-offs become input for canonical memory via Model C, not unilateral decisions.
4. Do not introduce components that dilute the Generator/Validator/Orchestrator separation or remove named human gates.
5. Yoke v1.0 is built **without** running Yoke on itself (manual bootstrap — see `.vibeflow/decisions.md`). v1.1+ may dogfood Yoke; that transition is planned but not active in v1.0.
