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

### `lib/canonical-memory/query.sh` (retired)

This primitive was retired in Part 3 of the bedrock canonical-memory
port; `/yoke:ask` now resolves the active memory via
`lib/canonical-memory/resolve-memory.sh` and reads the local
filesystem directly (no clone, no pull). The audit-trail / query-trace
contract that originally lived here was retired in
ask-source-agnostic-read Part 1 — `/yoke:ask` is now a pure read and
emits no trace. Historical adaptations recorded for lineage:

- **Source:** Bedrock's read primitives (upstream version 1.2.1).
- **Historical adaptations** (no longer in effect):
  - `--trace <path> --invoker <name>` flags for deterministic
    audit-trail writing (retired with the trace contract itself).
  - `--subgraph-depth N` flag for progressive disclosure — superseded
    by `/yoke:ask`'s built-in 15-entity cap and 1-level wikilink hop.
  - Bounded output (cap at 20 flat matches / 10 subgraph entries).
  - Empty-state UX.

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

### `agents/orchestrator.md` (v1.1)

- **Source:** Yoke-native (no upstream). The Orchestrator role is one
  of Yoke's distinctive contributions — see manifesto §13 and §19.5
  contribution #3 ("Orchestrator as multi-function role with Model C
  governance").
- **Note (v1.1):** Orchestrator is a **runtime subagent** with three
  modes (consult / monitor / canonize). The earlier
  Orchestrator-as-skill amendment is reversed — `/yoke:implement` is a
  *skill* that spawns three subagents in one turn, so the original
  Risk R1 (Claude Code subagent depth) does not apply. See
  `.vibeflow/decisions.md` 2026-04-25 entries for the rationale.

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

### `agents/generator.md`, `agents/validator.md`, `agents/orchestrator.md` (v1.1)

- **Source:** Yoke-native subagent definitions. The three runtime
  subagents materialize Yoke's adversarial Generator/Validator
  separation at runtime, plus the Orchestrator as sole writer of
  canonical memory. Spec-phase Generator/Validator subagent
  instances (which the v1.0 layout had as separate files) are
  eliminated in v1.1 — their personas live inline in
  `/yoke:discover`, `/yoke:tech-spec`, `/yoke:acceptance-contract`.
  See `.vibeflow/decisions.md` "Three runtime subagents only"
  (2026-04-25, supersedes 2026-04-24 "Five subagents").

### `skills/drift-sense/SKILL.md`, `lib/canonical-memory/staleness-check.sh`, `lib/canonical-memory/trace-analyzer.sh`

- **Source:** Yoke-original. Phase 6 (continuous drift sensing across
  three observation targets) is one of Yoke's distinctive contributions
  — see manifesto §8.6.

### Bedrock canonical-memory port — Part 1 (Foundation, 2026-04-25)

Imported from **bedrock 1.2.1**. This is the substrate for the larger
six-part port specified in
`.vibeflow/specs/bedrock-canonical-memory-port-part-{1..6}.md`. Part 1
ships the entity model and registry plumbing only; user-facing skills
land in Parts 2–6.

#### Entity templates (8) — `templates/canonical/{type}/_template.md`

Mapped from bedrock's `templates/<plural>/_template.md`:

| Yoke path | Bedrock source |
| :--- | :--- |
| `templates/canonical/actor/_template.md` | `templates/actors/_template.md` |
| `templates/canonical/person/_template.md` | `templates/people/_template.md` |
| `templates/canonical/team/_template.md` | `templates/teams/_template.md` |
| `templates/canonical/concept/_template.md` | `templates/concepts/_template.md` |
| `templates/canonical/topic/_template.md` | `templates/topics/_template.md` |
| `templates/canonical/discussion/_template.md` | `templates/discussions/_template.md` |
| `templates/canonical/project/_template.md` | `templates/projects/_template.md` |
| `templates/canonical/fleeting/_template.md` | `templates/fleeting/_template.md` |

Each template extends bedrock's frontmatter with the five mandatory
**Yoke rippability fields** (`ratified_at`,
`model_calibrated_against`, `last_validated`, `traceability`,
`impact_level`) plus the four graph-relationship fields (`depends_on`,
`supersedes`, `applies_to`, `contradicts_with`) already documented in
`templates/canonical-entry-frontmatter.yaml`. Bedrock-defined fields
are preserved verbatim — the rippability extension is additive.

#### Entity definitions (8) — `entities/{type}.md`

Mapped from bedrock's `entities/{type}.md` with these adaptations:

- Namespace renames: `/teach`, `/preserve`, `/bedrock` → `/yoke:teach`,
  `/yoke:preserve`, `/yoke:ask`.
- Vocabulary renames: "Second Brain" / "vault" → "canonical memory".
- New `## Yoke Update Rules` section per entity, explicitly forbidding
  deletion of the five rippability fields on update.
- New `## Yoke rippability` section after the required-fields table.

#### Excluded from Part 1 (deferred)

- `entities/code.md` and `_template_node.md` — graphify-dependent;
  reserved for a future graphify-integration sprint.
- `entities/sources-field.md` — folded into the per-entity update rules.

#### New Yoke-native libraries (no upstream)

- `lib/canonical-memory/registry.sh` — manages the plugin-level
  `<plugin_dir>/memories.json` registry. Yoke-original.
- `lib/canonical-memory/resolve-memory.sh` — 3-step memory resolution
  (`--memory <name>` → CWD → default → error). Yoke-original.
- `lib/canonical-memory/scaffold-memory.sh` — initializes a fresh
  canonical-memory repo with the 8-entity scaffold. Yoke-original.
- `templates/yoke-memory-config.json` — per-memory config schema.
  Yoke-original.

These libraries are introduced by Part 1 to support the registered
local checkout model that replaces clone-each-time. They are not ports
from bedrock — bedrock's vault registry uses the same conceptual
shape but lives at a different file path and uses different
field names.

### Bedrock canonical-memory port — Part 3 (Ask refactor, 2026-04-25)

| Yoke path | Bedrock source | Adaptation |
| :--- | :--- | :--- |
| `skills/ask/SKILL.md` | `skills/ask/SKILL.md` (1.2.1) | Adaptive 5-phase reader (classify → vault-first search → assess → recency → respond). 15-entity cap; 1-level wikilink hop. **No clone, no pull, no fetch** — reads against the registered local checkout via Part 1's `resolve-memory.sh`. Bedrock's Phase 3-G/3-T (graphify / teach escalation) stubbed: emit a callout, continue with vault-only content. |

`lib/canonical-memory/query.sh` was **deleted** in Part 3 — direct
filesystem reads via the resolution lib replace the clone-each-time path.

### Bedrock canonical-memory port — Part 4 (Preserve replaces canonize, 2026-04-25)

| Yoke path | Bedrock source | Adaptation |
| :--- | :--- | :--- |
| `skills/preserve/SKILL.md` | `skills/preserve/SKILL.md` (1.2.1) | Streamlined 7-phase flow (sync → parse → match → propose → execute → link → publish → report). Phase 3 wraps bedrock's confirmation gate with **Model C impact-class routing**, invoking `lib/canonical-memory/canonization-criteria.sh` as the classifier. Phase 0.2 (graphify-merge) replaced with a deferred-sprint abort. |

`skills/canonize/` and `lib/canonical-memory/propose-write.sh` were
**deleted** in Part 4 — `/yoke:preserve` is now the single write entry
to canonical memory.

### Bedrock canonical-memory port — Part 6 (Compress + status extension, 2026-04-25)

| Yoke path | Bedrock source | Adaptation |
| :--- | :--- | :--- |
| `skills/compress/SKILL.md` | `skills/compress/SKILL.md` (1.2.1) | Verbatim copy with namespace renames (`/bedrock:*` → `/yoke:*`, vault → memory). Detects bedrock's 5 misalignment classes (broken backlinks, fragmentation, miscategorization, duplicated entities, misnamed entities). All writes delegate to `/yoke:preserve`. Supports `--mode cron`. |
| `skills/status/SKILL.md` (extension) | `skills/healthcheck/SKILL.md` (1.2.1) | The Sprint-8 placeholder is replaced with a full read-only diagnostic. Section 1 (working memory) is Yoke-original. Section 2 (canonical-memory health) absorbs bedrock's 5 healthcheck checks: setup verification, graphify-out integrity, orphan entities, dangling content, stale content (>15 days). Bedrock's standalone `/healthcheck` skill is **not** copied — Yoke's `/yoke:status --canonical` is the single entry point. |

`lib/canonical-memory/staleness-check.sh` was **deleted** in Part 6 —
its rippability re-validation logic was folded into
`/yoke:status --canonical` Section 2.5.

### Bedrock canonical-memory port — Part 5 (Teach + helpers, 2026-04-25)

| Yoke path | Bedrock source | Adaptation |
| :--- | :--- | :--- |
| `skills/teach/SKILL.md` | `skills/teach/SKILL.md` (1.2.1) | Streamlined for v0's no-graphify scope. Bedrock Phases 4–5 (graphify extraction + per-run output merge) replaced with direct Zettelkasten classification using `entities/{type}.md`. Ingestion ends by delegating to `/yoke:preserve` (single write point). All other phases preserved. |
| `skills/confluence-to-markdown/SKILL.md` | same (1.2.1) | Verbatim copy with namespace renames (`/bedrock:*` → `/yoke:*`, vault → memory). 3-layer fallback (MCP → REST → browser DOM) preserved. DOM-extraction `scripts/extract.js` copied unchanged. |
| `skills/gdoc-to-markdown/SKILL.md` | same (1.2.1) | Verbatim copy with namespace renames. Preserves the GDoc / Sheets adapter chain. DOM-extraction `scripts/extract.js` copied unchanged. |

**Excluded from Part 5:**

- `/yoke:graphify` skill — graphify integration is deferred. The
  `code` entity type is reserved for that sprint.
- Bedrock's `/sync` — out of scope for v0.

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
