---
tags: [memory, working-memory, canonical-memory, two-tier, lifetime, frontmatter, graph]
modules: []
applies_to: [agents, memory-files, mcp, canonization]
confidence: validated
---
# Pattern: Two-Tier Memory Model

<!-- vibeflow:auto:start -->
## What
Yoke distinguishes two memory layers with disjoint lifetimes,
authorities and purposes. **Working memory** is per-task, free-write
for the agents that own the artifact, lives in the project repo.
**Canonical memory** is permanent, versioned, written only by the
Orchestrator subagent (in canonize mode at loop termination) under
Model C, and lives in an external substrate accessed over MCP.

The split centralizes **canonization**, not memory. Agents write
freely to working memory; only what survives as organizational
doctrine goes through the Orchestrator.

## Where
Working memory is materialized as a fixed set of files in the
project repo, one set per task. Canonical memory is materialized as
markdown files with YAML frontmatter forming a graph in an external
repo (e.g., Claude Bedrock substrate); MCP exposes it for read
access.

## The Pattern

### Working memory (ephemeral, per-task)

| File | Writer | Readers | Purpose |
| :--- | :--- | :--- | :--- |
| `prd.md` | `/yoke:discover` skill (Generator persona) | all | Phase 1 ratified artifact |
| `tech-spec.md` | `/yoke:tech-spec` skill (Generator persona) | all | Phase 2 ratified artifact |
| `acceptance-contract.md` | `/yoke:acceptance-contract` skill (Validator persona) | all | Phase 3 binding artifact |
| `progress.md` | Generator (runtime subagent) | Validator + Orchestrator | implementation state across cycles |
| `contracts.md` | Generator + Validator (jointly, on consensus) | both + Orchestrator | accumulated sprint contracts |
| free notes | any agent | any agent | rough context, no schema |

Canonical-memory reads are **not** materialized as working-memory
artifacts. `/yoke:ask` is a pure read invoked on demand via the Skill
tool; it produces only the conversational response and writes nothing
on disk.

Lifetime: task / sprint / PR scope. Location: `.yoke/` in the host
project repo, created by `/yoke:bootstrap`.

### Canonical memory (permanent, organization-wide)

- Writer: **`/yoke:preserve`** is the single write path. The runtime
  Orchestrator subagent invokes it in canonize mode at loop termination
  (Model C applied inside `/yoke:preserve` Phase 3).
- Readers: every agent, but always **mediated** via `/yoke:ask`:
  - Spec phases (1–3) invoke `/yoke:ask`.
  - Runtime (Phase 4) invokes `/yoke:ask` from the Orchestrator
    subagent's consult mode.
  - `/yoke:ask` resolves the active memory through
    `lib/canonical-memory/resolve-memory.sh` and reads the local
    filesystem directly — no clone, no pull. (Part 3 of the bedrock
    canonical-memory port retired `query.sh`.)
- Lifetime: permanent, versioned (git-native via the substrate repo).
- Location: external substrate registered in
  `<plugin_dir>/memories.json`. Reference implementation: Claude
  Bedrock; replaceable by any git-backed equivalent.

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

The graph is what makes progressive disclosure operationally viable
— the Orchestrator loads only the relevant subgraph per phase/task.

#### Scope of content (non-exhaustive)
Ratified policies (RFC 2119, semver), consolidated domain specs,
harness templates by topology, resolved divergence patterns,
structured ADRs, skills and how-tos, sensor calibrations (known
false positives/negatives), state and trajectory of business
projects.

The scope is intentionally open. **Governance does not filter what
may be proposed; it filters when and how each proposition becomes
doctrine.** Model C applies by impact class of the write, not by
content type.

### Canonical-memory access timing
- **Consult (live, during runtime).** Any runtime subagent — Generator,
  Validator, or Orchestrator — invokes `/yoke:ask` via the Skill tool
  on demand and reasons over the response in-conversation. The skill
  is source-agnostic and writes nothing on disk; each invocation is
  independent.
- **Canonize (write, at loop termination only).** The
  Orchestrator's canonize mode is the only canonical-memory write
  path. Mid-loop writes are forbidden — they would bypass Model C
  governance windows.

## Rules
- **`/yoke:preserve` is the single write entry to canonical memory.**
  No agent or skill writes outside it. The Orchestrator subagent
  invokes `/yoke:preserve` (canonize mode) at loop termination; no
  subagent calls `git -C <memory> commit` directly.
- No agent reads canonical memory directly. Reads are always
  mediated — via `/yoke:ask` (the Orchestrator subagent invokes the
  same skill from consult mode).
- Working memory files are write-owned by the role that produces
  the artifact (table above). Other roles only read.
- Every canonical-memory item carries the mandatory rippability
  frontmatter (`ratified_at`, `model_calibrated_against`,
  `last_validated`, `traceability`, `impact_level`). Items without
  traceability are pruning candidates. The five fields are protected
  on update — `/yoke:preserve` rejects writes that drop them.
- Canonical memory writes go through PRs on the substrate repo
  (Yoke default `git.strategy: commit-push-pr`). Rollback is
  `git revert`.
- Working memory is free-write within its files — no Model C, no
  veto windows. The blast radius is one task.
- Mid-loop canonical-memory writes are forbidden. Canonization
  fires only at `/yoke:implement` loop termination via the
  Orchestrator's canonize-mode invocation of `/yoke:preserve`.

## Examples from this codebase
> Expected canonical-memory item layout:

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
.yoke/
├── prd.md
├── tech-spec.md
├── acceptance-contract.md
├── progress.md
├── contracts.md
├── config.yaml
└── .snapshots/
    └── cycle-N.yaml
```

<!-- vibeflow:auto:end -->

## Anti-patterns
- Persisting any agent learning directly to canonical memory — bypasses Model C, accumulates noise.
- Loading canonical memory in full into an agent's context — defeats progressive disclosure.
- Reusing working memory across tasks — corrupts isolation; ephemeral by definition.
- Canonical-memory items without `traceability` — undeletable junk over time.
- Working memory in a different repo than the project — recovery and audit become harder, no benefit.
- Mid-loop canonical-memory writes — bypasses Model C governance windows.
- Agents reading canonical memory by `cat`/`grep`/cloning the substrate — bypasses progressive disclosure and the `/yoke:ask` mediation contract.

## Implementation Mapping

From `yoke-implementation-plan.md` (2026-04-24, refreshed 2026-04-25
— see `.vibeflow/decisions.md` "Consult live, canonize on
termination") — concrete locations:

**Working memory** — directory `.yoke/` at the host project root,
created by `/yoke:bootstrap`:

- `.yoke/prd.md`, `.yoke/tech-spec.md`,
  `.yoke/acceptance-contract.md`, `.yoke/progress.md`,
  `.yoke/contracts.md`
- Canonical-memory reads do not materialize a working-memory
  artifact — `/yoke:ask` is a pure read invoked on demand via the
  Skill tool by any subagent or skill that needs canonical context.
- `.yoke/config.yaml` — per-project Yoke config (hard-bound
  overrides, canonical-repo URL)
- `.yoke/.snapshots/cycle-N.yaml` — per-cycle
  `verify-acceptance.sh` snapshots

**Canonical memory** — a **separate git repository** created or
pointed-to during bootstrap. Substrate is git-native (PR-based
ratification, Decision 2026-04-24 git-native protocol). It is NOT a
submodule of the project repo. The bootstrap skill offers
`gh repo create` if the canonical repo does not yet exist.

**Plugin templates** for both layers live in `templates/`:

- `templates/canonical-entry-frontmatter.yaml` — mandatory
  rippability metadata (Decision 2026-04-24 rippability) +
  relationship edges (`depends_on`, `supersedes`, `applies_to`,
  `contradicts_with`).
