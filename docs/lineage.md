# Lineage

Yoke embeds skills derived from two upstream projects, **forked one-time
at the start of the relevant sprint**. From the time of fork, those
skills evolve autonomously inside Yoke. There is no continuous port from
upstream — by design, per `.vibeflow/decisions.md` ("Embed upstream
skills as a single fork at creation time").

This document records the per-skill mapping and what was adapted.

## Upstream sources

| Source | URL | Purpose in Yoke |
| :--- | :--- | :--- |
| **Vibeflow** | <https://github.com/pe-menezes/vibeflow> | Generator's spec-drafting skills (PRD + Tech Spec) |
| **Bedrock** | <https://github.com/iurykrieger/claude-bedrock> | Orchestrator's canonical-memory primitives (read / write / graph) |

Fork dates:

- **Vibeflow** → forked at **Sprint 2** (2026-04-25). Reference upstream
  version: `1.10.0`.
- **Bedrock** → forked at **Sprint 5** (2026-04-25). Reference upstream
  version: `1.2.1`.

## Per-skill mapping

### `skills/discover/SKILL.md`

- **Source:** `vibeflow:discover` (upstream version 1.10.0).
- **Adaptations:**
  - Renamed namespace from `/vibeflow:*` to `/yoke:*`.
  - Switched output shape from Vibeflow's PRD format (problem / audience
    / solution) to Yoke's PRD format (product invariants / business
    context / known constraints / risks / open questions, per
    manifesto §11.1).
  - Wired the Generator subagent (`agents/generator.md`) as the LLM
    driver, replacing Vibeflow's direct-LLM dialogue.
  - Routes any canonical-memory queries through `/yoke:ask` (mediated)
    rather than reading directly.
  - Added explicit Trigger-1 prompt with `approve` / `revise <feedback>`
    / `restart` options.

### `skills/tech-spec/SKILL.md`

- **Source:** `vibeflow:gen-spec` (upstream version 1.10.0).
- **Adaptations:**
  - Renamed namespace.
  - Switched output shape to Yoke's Tech Spec format (sprints with
    delivery objectives + use-case tasks + per-task acceptance criteria
    + contracts/interfaces + dependencies, per manifesto §11.1).
  - Aborts on missing/unapproved PRD (Yoke-specific binding-spec rule).
  - Wired the Generator subagent.
  - Trigger-2 prompt with `approve` / `revise <feedback>` / `back to PRD`.

### `lib/canonical-memory/query.sh`

- **Source:** Bedrock's read primitives (upstream version 1.2.1).
- **Adaptations:**
  - Added `--trace <path> --invoker <name>` flags for deterministic
    audit-trail writing to `.yoke/query-trace.md` (Yoke-specific
    Mediator-mode requirement; see `skills/orchestrator/SKILL.md`).
  - Added `--subgraph-depth N` flag for progressive disclosure (Sprint
    6); delegates to `lib/canonical-memory/graph.sh` for traversal.
  - Bounded output (cap at 20 flat matches / 10 subgraph entries).
  - Empty-state UX (`"no entries yet"` / `"no matches"` / `"not configured"`).

### `lib/canonical-memory/graph.sh`

- **Source:** Bedrock's graph primitives (upstream version 1.2.1).
- **Adaptations:**
  - Pure Bash implementation (no Python dependency).
  - Two subcommands: `list-edges` and `subgraph` (BFS, depth-bounded).
  - Understands the four Yoke-specific edges (`depends_on`, `supersedes`,
    `applies_to`, `contradicts_with`) per `patterns/memory-model.md`.

### `lib/canonical-memory/propose-write.sh`

- **Source:** Yoke-original (no upstream). Composed on top of Bedrock's
  write primitives via `gh` CLI.
- **Note:** the per-impact-class behavior (low auto-merge / medium veto
  window / high sync / regulatory CODEOWNERS) is Yoke-specific and
  implements Model C from the manifesto (§10). Bedrock's upstream lacks
  this governance layer.

### `skills/orchestrator/SKILL.md`

- **Source:** Yoke-native (no upstream). The Orchestrator role is one
  of Yoke's distinctive contributions — see manifesto §13 and §19.5
  contribution #3 ("Orchestrator as multi-function role with Model C
  governance").
- **Note:** the PRD's v0 amendment makes Orchestrator a **skill** rather
  than a subagent (sidesteps Risk R1, Claude Code subagent depth). See
  `decisions.md` for the rationale.

### `skills/canonize/SKILL.md`

- **Source:** Yoke-original. Five-criteria cascade
  (`canonization-criteria.sh`) is from manifesto §14.4.

### `skills/acceptance-contract/SKILL.md`

- **Source:** Yoke-original. The binding pre-runtime Acceptance Contract
  is one of Yoke's distinctive contributions — see manifesto §8.3 and
  §19.5 contribution #2.

### `skills/implement/SKILL.md`

- **Source:** Yoke-original. The runtime ralph-loop coordinator is
  inspired by Anthropic's sprint-contracts pattern but extended with
  hard bounds + Model C escalation.

### `agents/generator.md`, `agents/validator.md`, `agents/implementation.md`, `agents/validation.md`

- **Source:** Yoke-native subagent definitions. The four-subagent
  separation (Generator vs Implementation Agent at runtime; Validator
  vs Validation Agent at runtime) is one of Yoke's distinctive
  contributions — see `.vibeflow/decisions.md` ("Five subagents as
  distinct entities" — amended to four after the Orchestrator-as-skill
  decision).

### `skills/drift-sense/SKILL.md`, `lib/canonical-memory/staleness-check.sh`, `lib/canonical-memory/trace-analyzer.sh`

- **Source:** Yoke-original. Phase 6 (continuous drift sensing across
  three observation targets) is one of Yoke's distinctive contributions
  — see manifesto §8.6.

## Honesty statement

This is a complete inventory of where Yoke's skills come from. Where a
file is forked from upstream, the adaptation list above is intended to
be exhaustive — no claim of creation ex nihilo for adapted material.

Where a file is Yoke-native, the manifesto reference shows where the
design comes from (always Iury Krieger's manifesto in this repo).

If you find a Yoke skill that mirrors upstream more than this document
acknowledges, please open an issue or PR.

## Crediting

- **Vibeflow** — Pedro Menezes, MIT License. Used with credit.
- **Bedrock** — Iury Krieger, MIT License. Used with credit.

Both upstream projects are credited in `README.md` at the repo root.
