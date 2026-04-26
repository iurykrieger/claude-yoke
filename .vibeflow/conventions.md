# Conventions

> Manual bootstrap from `yoke.md` (manifesto v1.0, 2026-04-24).
> These conventions are framework invariants — they must govern any implementation built inside Yoke.

<!-- vibeflow:auto:start -->

## Origin

These conventions are distilled from manifesto Section 6 (cross-cutting
principles) plus prescriptive rules scattered across the document. They were
not extracted from code — they were extracted from the framework's declared
intent.

## Cross-cutting principles (manifesto Section 6)

### Shift feedback left
Feedback closer to generation reduces cost and increases reliability.
- Computational sensors run inside the ralph loop, not only at the merge boundary.
- The Validator produces the Acceptance Contract before the first line of code is written.
- Human approval happens between phases, not only at the end.

### Back-pressure: success is silent, failures are verbose
- Sensors emit signal only when something must be corrected.
- Error messages are structured for direct agent consumption.
- Include a correction instruction in the message when applicable, not just a description of the failure.
- Generic output ("tests failed") is treated as a sensor bug.

### Blueprints wrapping agentic nodes
LLMs go inside contained boxes, called only where judgment is genuinely required.
- Every flow is an explicit sequence of deterministic nodes (code) and agentic nodes (LLM).
- Each deterministic node saves tokens, reduces errors and guarantees repeatable execution.
- Before adding an agentic node ask: can this be deterministic?

### Hard bounds on autonomous loops
Ralph loops have explicit ceilings: N cycles, timeout, budget.
- Reaching any bound triggers human escalation.
- "Infinite retry" is never accepted, even when agents agree they are "almost there".
- Initial values: N = 5–8 cycles; timeout 2–4 hours; budget tunable per task class.

### Sensor output for LLM consumption
Every sensor produces structured output consumable by an agent:
- Precise identification of the violation
- Location in the code
- Correction instruction when deterministic
- Reference to the policy or fixture that fired

### Progressive disclosure via the Orchestrator
No agent ever receives the full canonical memory in context.
- The Orchestrator mediates every query and loads only the subgraph relevant to the current phase/task.
- Content not in runtime context does not exist for the agent.
- Everything in context competes for scarce attention — minimize it.

### Sprint contracts between agents
Implementation and Validation negotiate ambiguous interpretations and record
consensus in a shared file (`contracts.md`) as it emerges. Sprint contracts
**cannot** contradict the Acceptance Contract — divergence at this boundary
triggers human escalation.

### Minimalist canonical memory with mandatory traceability
Every item persisted in canonical memory traces back to a specific past failure or a hard external constraint.
- Items without traceability are pruning candidates.
- Default is inverted: "remove when in doubt", not "add when in doubt".
- Mandatory metadata per item: ratification date, model it was calibrated against, last validation, traceability, impact level.

### Environment designers, not code writers
The human role inside Yoke is not to write code — it is to design the environment in which agents operate.
- Every failure is a diagnosis: what was missing in the environment that allowed this failure?
- The answer becomes canonical memory, becomes a template, becomes a fixture.

## Artifact-production conventions

### Working memory — canonical files
Every task that enters runtime materializes this minimum tree of ephemeral files:
- `prd.md` — `/yoke:discover` skill writes (Generator persona inline); everyone reads (Phase 1 artifact)
- `tech-spec.md` — `/yoke:tech-spec` skill writes (Generator persona inline); everyone reads (Phase 2 artifact)
- `acceptance-contract.md` — `/yoke:acceptance-contract` skill writes (Validator persona inline); everyone reads (Phase 3 artifact, binding)
- `progress.md` — Generator (runtime subagent) writes; Validator + Orchestrator read
- `contracts.md` — Generator + Validator co-write on consensus; both + Orchestrator read (sprint contracts)

Canonical-memory reads do **not** materialize a working-memory artifact —
`/yoke:ask` is a pure read invoked on demand via the Skill tool by any
caller (Generator, Validator, Orchestrator, spec-phase skills, ad-hoc
human queries).

### Canonical memory — per-item format
- Body in markdown
- Mandatory YAML frontmatter: ratification date, model calibrated against, last validation, traceability link (failure or constraint), impact level
- Relationship frontmatter: `depends_on`, `supersedes`, `applies_to`, `contradicts_with`

### Canonical memory — write protocol
Every write to canonical memory goes through a pull request on the substrate repository.
- Low impact: PR with auto-merge after checks
- Medium impact: PR with veto window (auto-merge after a quiet period)
- High impact: synchronous approval before merge
- Rollback is `git revert`

### Periodic re-test (rippability)
Principle: "every rule gets periodically re-tested against the current model."
- Major upgrades to the underlying model are an explicit trigger to review canonical memory.
- Per-item utilization metrics over time inform pruning.
- The Orchestrator has equivalent authority to add AND deprecate guides.

## Don'ts

- Do NOT allow any agent to read canonical memory directly. All reads route through `/yoke:ask` invoked via the Skill tool — direct filesystem reads of the registered memory (cat, grep, clone, pull) are prohibited.
- Do NOT allow any agent except the Orchestrator to write to canonical memory (and only with Model C applied).
- Do NOT load the entire canonical memory into any agent's context — only the relevant subgraph, via the Orchestrator.
- Do NOT accept generic sensor output ("tests failed", "build broken") — that is a sensor bug.
- Do NOT allow ralph loops without configured hard bounds (N cycles, timeout, budget).
- Do NOT modify the Acceptance Contract during runtime without a fresh human ratification (Trigger 4).
- Do NOT let a sprint contract contradict the Acceptance Contract — pause the loop and escalate.
- Do NOT canonize a pattern without traceability to a specific failure or constraint.
- Do NOT canonize a pattern that contradicts existing canonical memory without human ratification.
- Do NOT treat Trigger 1–5 approvals as rubber-stamps — monitor average review time and modification rate as fatigue signals.
- Do NOT write generic "best practice" guides — every guide traces an origin and an impact.
- Do NOT pin Yoke to a specific upstream version of Vibeflow or Bedrock — those skills were embedded as a single fork at creation time and evolve internally.

<!-- vibeflow:auto:end -->

## Implementation Plan Conventions (2026-04-24)

> Source: `yoke-implementation-plan.md` v1.0. These are operational conventions
> for how Yoke v1 itself is built — they sit outside the auto-generated
> framework invariants above and govern engineering process rather than
> runtime behavior.

### Vertical slice before horizontal completeness
The first useful sprint produces a minimum end-to-end path (idea → PRD →
merged code), even if rough. Subsequent sprints deepen specific phases.
Sprint order: 1–3 vertical, 4–6 horizontal, 7–8 longitudinal.

### Every sprint ships an installable plugin
At the end of every sprint the plugin must install via `/plugin install` and
be exercisable up to the coverage added by that sprint. Each sprint bumps
the plugin version (0.1.0 → 0.2.0 → … → 1.0.0). Distribution failures
surface only when shipped — make every sprint ship.

### Test file per framework concept
Each framework concept (plugin distribution, skills surface, agents
surface, working memory, canonical-memory read, canonical-memory write,
bootstrap, acceptance + sensors, ralph-loop bounds, example project,
docs + lineage) maps to one `tests/<concept>.test.sh` file. Tests assert
present-tense invariants only — no version literals, no release-history
commentary, no chronology. Adding a new framework concept means adding
one file at `tests/`; the CI matrix in `.github/workflows/ci.yml` enumerates
the files explicitly so additions are deliberate signals, not chores.

### Bootstrap manually, not recursively
Yoke v1 is built without running Yoke. Vibeflow and Bedrock may be installed
separately as scaffolding while building, but no v1 artifact depends on a
running Yoke instance. The v1.1+ transition to dogfooding is planned, not
assumed.

### Distribution dependencies are validated in Sprint 1
Plugin format, marketplace integration, subagent depth limits and any
Claude Code platform assumptions are exercised in Sprint 1. Risks R1
(subagent depth) and R6 (plugin marketplace format) live here — failing
fast on these in Sprint 1 prevents Sprint-4 refactors.

### Bash scripts target bash 4+
`hooks/` and `lib/*.sh` assume bash 4 or newer. macOS ships with bash 3 —
users on macOS need bash 4 (via Homebrew) or zsh-compatible scripts.
Documented in `docs/installation.md`.

### Lineage is documented honestly
Skills in Yoke that originate from Vibeflow or Bedrock retain a lineage
note in `docs/lineage.md`. No claim of creation ex nihilo for adapted
material. Crediting Vibeflow and Bedrock in `README.md` is mandatory.
