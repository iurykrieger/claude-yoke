---
tags: [memory, working-memory, canonical-memory, two-tier, lifetime, frontmatter, graph]
modules: []
applies_to: [agents, memory-files, mcp, canonization]
confidence: validated
---
# Pattern: Two-Tier Memory Model

<!-- vibeflow:auto:start -->
## What
Yoke distinguishes two memory layers with disjoint lifetimes, authorities and
purposes. **Working memory** is per-task, free-write for the agents that own
the artifact, lives in the project repo. **Canonical memory** is permanent,
versioned, written only by the Orchestrator under Model C, and lives in an
external substrate accessed over MCP.

The split centralizes **canonization**, not memory. Agents write freely to
working memory; only what survives as organizational doctrine goes through
the Orchestrator.

## Where
Working memory is materialized as a fixed set of files in the project repo,
one set per task. Canonical memory is materialized as markdown files with
YAML frontmatter forming a graph in an external repo (e.g., Claude Bedrock
substrate); MCP exposes it for read access.

## The Pattern

### Working memory (ephemeral, per-task)

| File | Writer | Readers | Purpose |
| :--- | :--- | :--- | :--- |
| `prd.md` | Generator | all | Phase 1 ratified artifact |
| `tech-spec.md` | Generator | all | Phase 2 ratified artifact |
| `acceptance-contract.md` | Validator | all | Phase 3 binding artifact |
| `progress.md` | Implementation Agent | Validation Agent, Orchestrator | implementation state across cycles |
| `contracts.md` | both Agents (jointly) | both + Orchestrator | accumulated sprint contracts |
| free notes | any agent | any agent | rough context, no schema |

Lifetime: task / sprint / PR scope. May extend until Orchestrator
consolidation. Location: project repo (gitignored or in a `.yoke/` folder by
convention — to be decided).

### Canonical memory (permanent, organization-wide)

- Writer: only the Orchestrator (Model C applied).
- Readers: every agent, but always **mediated** by the Orchestrator (progressive disclosure).
- Lifetime: permanent, versioned (git-native via the substrate repo).
- Location: external substrate (Claude Bedrock or any MCP-accessible equivalent).

#### Per-item format
- Body: markdown.
- Mandatory frontmatter:
  - `ratified_at: <date>`
  - `model_calibrated_against: <model id>`
  - `last_validated: <date>`
  - `traceability: <link to failure or constraint>`
  - `impact_level: low | medium | high | regulatory`
- Relationship frontmatter (graph edges):
  - `depends_on: [...]`
  - `supersedes: [...]`
  - `applies_to: [...]`
  - `contradicts_with: [...]`

The graph is what makes progressive disclosure operationally viable — the
Orchestrator loads only the relevant subgraph per phase/task.

#### Scope of content (non-exhaustive)
Ratified policies (RFC 2119, semver), consolidated domain specs, harness
templates by topology, resolved divergence patterns, structured ADRs, skills
and how-tos, sensor calibrations (known false positives/negatives), state
and trajectory of business projects.

The scope is intentionally open. **Governance does not filter what may be
proposed; it filters when and how each proposition becomes doctrine.**
Model C applies by impact class of the write, not by content type.

## Rules
- No agent except the Orchestrator writes to canonical memory. Ever.
- No agent reads canonical memory directly. Reads are always mediated by the Orchestrator.
- Working memory files are write-owned by the role that produces the artifact (table above). Other roles only read.
- Every canonical-memory item carries the mandatory metadata frontmatter. Items without traceability are pruning candidates.
- Canonical memory writes go through PRs on the substrate repo. Rollback is `git revert`.
- Working memory is free-write within its files — no Model C, no veto windows. The blast radius is one task.

## Examples from this codebase
> Repository is empty. Expected canonical-memory item layout:

```markdown
---
ratified_at: 2026-04-15
model_calibrated_against: claude-opus-4-7
last_validated: 2026-04-22
traceability: incidents/2026-03/payment-reversal-pii-leak.md
impact_level: regulatory
depends_on: [policies/lgpd-art-46.md]
supersedes: []
applies_to: [services/payments/, services/refunds/]
contradicts_with: []
---
# Policy: PII redaction in reversal logs

> RFC 2119: MUST

When persisting a reversal event, the implementation MUST redact PII fields
listed in `policies/pii-fields.md` before writing the log line.

## Rationale
2026-03 incident: ...
```

Working-memory layout for a task:

```
.yoke/tasks/2026-04-24-payment-reversal/
├── prd.md
├── tech-spec.md
├── acceptance-contract.md
├── progress.md
├── contracts.md
└── notes/
```

<!-- vibeflow:auto:end -->

## Anti-patterns
- Persisting any agent learning directly to canonical memory — bypasses Model C, accumulates noise.
- Loading canonical memory in full into an agent's context — defeats progressive disclosure.
- Reusing working memory across tasks — corrupts isolation; ephemeral by definition.
- Canonical-memory items without `traceability` — undeletable junk over time.
- Working memory in a different repo than the project — recovery and audit become harder, no benefit.

## Implementation Mapping

From `yoke-implementation-plan.md` (2026-04-24) — concrete locations:

**Working memory** — directory `.yoke/` at the host project root, created by
`/yoke:bootstrap`:
- `.yoke/prd.md`, `.yoke/tech-spec.md`, `.yoke/acceptance-contract.md`, `.yoke/progress.md`, `.yoke/contracts.md`
- `.yoke/query-trace.md` — log of every mediated canonical-memory query (Sprint 5+)
- `.yoke/config.yaml` — per-project Yoke config (hard-bound overrides, canonical-repo URL)

**Canonical memory** — a **separate git repository** created or pointed-to
during bootstrap. Substrate is git-native (PR-based ratification, Decision
2026-04-24 git-native protocol). It is NOT a submodule of the project repo.
The bootstrap skill offers `gh repo create` if the canonical repo does not
yet exist.

**Plugin templates** for both layers live in `templates/`:
- `templates/canonical-entry-frontmatter.yaml` — mandatory rippability metadata (Decision 2026-04-24 rippability) + relationship edges (`depends_on`, `supersedes`, `applies_to`, `contradicts_with`).
