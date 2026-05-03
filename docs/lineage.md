# Lineage

Yoke embeds skills derived from two upstream projects, **forked one-time
at the start of the relevant sprint**. From the time of fork, those
skills evolve autonomously inside Yoke. There is no continuous port from
upstream — by design (canonized in `concepts/yoke-decision-*` —
"Embed upstream skills as a single fork at creation time").

This document records the per-skill mapping and what was adapted, plus
the v2.0.0 extraction event in which Bedrock-derived material was
factored back out of Yoke into the standalone `claude-bedrock` peer
plugin.

## Upstream sources

| Source | URL | Purpose in Yoke |
| :--- | :--- | :--- |
| **Vibeflow** | <https://github.com/pe-menezes/vibeflow> | Generator's spec-drafting skills (PRD + Tech Spec) |
| **Bedrock** | <https://github.com/iurykrieger/claude-bedrock> | Canonical-memory primitives (read / write / graph) — extracted back into a standalone peer plugin in v2.0.0 |

Fork dates:

- **Vibeflow** → forked at **Sprint 2** (2026-04-25). Reference upstream
  version: `1.10.0`.
- **Bedrock** → forked at **Sprint 5** (2026-04-25). Reference upstream
  version: `1.2.1`. **Extracted from Yoke at v2.0.0** (2026-04-30) into
  the standalone `claude-bedrock` peer plugin.

## Per-skill mapping

### `skills/discover/SKILL.md`

- **Source:** vibeflow's discover skill (upstream version 1.10.0).
- **Adaptations:**
  - Renamed namespace from the vibeflow namespace to `/yoke:*`.
  - Switched output shape from Vibeflow's PRD format (problem / audience
    / solution) to Yoke's PRD format (product invariants / business
    context / known constraints / risks / open questions, per
    manifesto §11.1).
  - Wired the Generator subagent (`agents/generator.md`) as the LLM
    driver, replacing Vibeflow's direct-LLM dialogue.
  - Routes any canonical-memory queries through the v2.0.0
    `/yoke:search-canonical-memory` facade rather than reading
    directly. (In v1.x this was the `/yoke:` legacy read verb — same
    structural rule, different verb.)
  - Added explicit Trigger-1 prompt with `approve` / `revise <feedback>`
    / `restart` options.
  - **Persona rebalance (2026-04-25):** renamed the inline persona
    from the umbrella "Generator persona: senior product engineer" to
    a literal "Product Manager persona" (CPO-style); dialogue questions
    tightened to product-only framing (problem / audience / success /
    scope / anti-scope). Implementation-shape language was removed —
    that deliberation belongs to `/yoke:tech-spec`. See
    `concepts/yoke-decision-*` (canonical memory) for "Discover
    persona = Product Manager".

### `skills/tech-spec/SKILL.md`

- **Source:** vibeflow's gen-spec skill (upstream version 1.10.0).
- **Adaptations:**
  - Renamed namespace.
  - Switched output shape to Yoke's Tech Spec format (sprints with
    delivery objectives + use-case tasks + per-task acceptance criteria
    + contracts/interfaces + dependencies, per manifesto §11.1).
  - Aborts on missing/unapproved PRD (Yoke-specific binding-spec rule).
  - Wired the Generator subagent.
  - Trigger-2 prompt with `approve` / `revise <feedback>` / `back to PRD`.
  - **Persona rebalance (2026-04-25):** renamed the inline persona
    from the umbrella "Generator persona: senior product engineer" to
    a literal "Senior Engineer persona" (CTO-style); replaced the
    clarity-evaluation block in step 3 with three engineering checks
    (stack fit against canonical-memory pattern entries, framework /
    library choices named with trade-offs, sprint partitionability
    with binary acceptance criterion per task), replacing the prior
    product-shaped trio (use-cases / constraints / sprint-partition).
    Step 4's sprint + use-case-task + binary-acceptance-criterion
    mandate is preserved; the binary-acceptance-criterion bullet was
    hoisted to the top of the bullet list as the load-bearing
    requirement. See `concepts/yoke-decision-*` (canonical memory)
    for "Tech-spec persona = Senior Engineer / CTO".

### v2.0.0 extraction — Bedrock-derived material → `claude-bedrock` peer plugin

At v2.0.0 (PRD `2026-04-30-pluggable-canonical-memory`), the
canonical-memory implementation that Yoke had absorbed from Bedrock
during the Part 1–6 port (Sprint 5) was extracted back out into a
standalone peer plugin named `claude-bedrock`. The motivation was
pluggability: the Yoke framework should not be wedded to a single
canonical-memory backend. Yoke v2.0.0 dispatches every read through
`/yoke:search-canonical-memory` and every write through `/yoke:canonize`,
both of which resolve the active provider via the curated
`providers.yaml` and the host project's
`.yoke/config.yaml :: canonical_memory.provider`.

What moved out of Yoke at v2.0.0:

- The seven Bedrock-derived skills under the legacy `/yoke:` namespace
  (the read verb, the write verb, the teach verb, the compress verb,
  the memory-management verb, and the two source-fetch verbs) — now
  exposed under the `/bedrock:` namespace by the peer plugin.
- The eight Bedrock-specific scripts under `lib/canonical-memory/`
  (everything except `resolve-provider.sh`, which is the Yoke-native
  facade resolver) — now in `claude-bedrock/lib/canonical-memory/`.
- The eight entity-type definitions under `entities/` and the eight
  per-type templates under `templates/canonical/` — now in
  `claude-bedrock/entities/` and `claude-bedrock/templates/canonical/`.
- Bedrock-specific config templates (`templates/yoke-memory-config.json`,
  `templates/canonical-entry-frontmatter.yaml`) — replaced by
  `claude-bedrock/templates/bedrock-memory-config.json`.

What stayed in Yoke at v2.0.0:

- The two facade skills (`skills/search-canonical-memory/`,
  `skills/canonize/`) — Yoke-native dispatch surface.
- `lib/canonical-memory/resolve-provider.sh` — the only resolver
  Yoke needs at runtime.
- `lib/yoke-prelude.sh` — the hard-break pre-flight helper sourced
  by every eligible skill.
- `providers.yaml` — the curated provider registry.
- `templates/yoke-config.yaml` — bumped to require
  `canonical_memory.provider`.
- The Generator / Validator / Orchestrator subagents and the
  `/yoke:implement` ralph loop — all unchanged in shape, but their
  canonical-memory access path now goes through the facades.

The v2.0.0 PR + spec at `.yoke/prds/2026-04-30-pluggable-canonical-memory.md`
and `.yoke/specs/2026-04-30-pluggable-canonical-memory.md` document
the extraction sprint by sprint. The pre-extraction lineage entries
below are retained for historical accuracy but no longer reflect
files that live in Yoke today; consult the `claude-bedrock` plugin
for the live versions of any Bedrock-derived skill.

### `lib/canonical-memory/query.sh` (retired in v1.1)

This primitive was retired in Part 3 of the bedrock canonical-memory
port; the legacy v1.x read verb resolved the active memory via
`lib/canonical-memory/resolve-memory.sh` and read the local
filesystem directly. The audit-trail / query-trace contract that
originally lived there was retired in the source-agnostic-read
sprint (Part 1 of that work) — the read verb became a pure read
that emits no trace.

- **Source:** Bedrock's read primitives (upstream version 1.2.1).
- **Historical adaptations** (no longer in effect):
  - `--trace <path> --invoker <name>` flags for deterministic
    audit-trail writing (retired with the trace contract itself).
  - `--subgraph-depth N` flag for progressive disclosure — superseded
    by the read-skill's built-in 15-entity cap and 1-level wikilink
    hop.
  - Bounded output (cap at 20 flat matches / 10 subgraph entries).
  - Empty-state UX.

The whole script (and the read skill that wrapped it) moved to
`claude-bedrock` at v2.0.0.

### `lib/canonical-memory/graph.sh` (extracted in v2.0.0)

- **Source:** Bedrock's graph primitives (upstream version 1.2.1).
- **Adaptations:**
  - Pure Bash implementation (no Python dependency).
  - Two subcommands: `list-edges` and `subgraph` (BFS, depth-bounded).
  - Understands the four Yoke-specific edges (`depends_on`, `supersedes`,
    `applies_to`, `contradicts_with`) per
    `concepts/yoke-pattern-memory-model` (canonical memory).
- Lives in `claude-bedrock/lib/canonical-memory/graph.sh` from v2.0.0
  onward.

### `lib/canonical-memory/propose-write.sh` (extracted in v2.0.0)

- **Source:** Yoke-original (no upstream). Composed on top of Bedrock's
  write primitives via `gh` CLI.
- **Note:** the per-impact-class behavior (low auto-merge / medium veto
  window / high sync / regulatory CODEOWNERS) is Yoke-specific and
  implements Model C from the manifesto (§10). Bedrock's upstream lacks
  this governance layer.
- Lives in `claude-bedrock/lib/canonical-memory/propose-write.sh` from
  v2.0.0 onward; the Model-C wrapping logic moved with it. Yoke
  surfaces Model C only as the impact-class taxonomy applied at
  `/yoke:canonize` invocation; the actual gating runs inside the
  provider.

### `agents/orchestrator.md` (v1.1+)

- **Source:** Yoke-native (no upstream). The Orchestrator role is one
  of Yoke's distinctive contributions — see manifesto §13 and §19.5
  contribution #3 ("Orchestrator as multi-function role with Model C
  governance").
- **Note (v1.1):** Orchestrator is a **runtime subagent** with three
  modes (consult / monitor / canonize). The earlier
  Orchestrator-as-skill amendment is reversed — `/yoke:implement` is a
  *skill* that spawns three subagents in one turn, so the original
  Risk R1 (Claude Code subagent depth) does not apply. See
  `concepts/yoke-decision-*` (canonical memory) entries for the
  rationale.
- **Note (v2.0.0):** the Orchestrator's canonical-memory access path
  now goes through `/yoke:search-canonical-memory` (consult mode) and
  `/yoke:canonize` (canonize mode), both of which dispatch to the
  active provider. The Orchestrator does not bind to any specific
  provider plugin.

### `skills/canonize/SKILL.md`

- **Source:** Yoke-original. Five-criteria cascade
  (`canonization-criteria.sh`) is from manifesto §14.4.
- **Note (v2.0.0):** repositioned as a thin facade — resolves the
  active provider via `lib/canonical-memory/resolve-provider.sh` and
  dispatches to the provider's pinned canonize skill with
  `--working-memory <abs-path-to-.yoke>`. The Model-C classification
  + write-PR logic moved into the provider plugin.

### `skills/acceptance-contract/SKILL.md`

- **Source:** Yoke-original. The binding pre-runtime Acceptance Contract
  is one of Yoke's distinctive contributions — see manifesto §8.3 and
  §19.5 contribution #2.

### `skills/generate-sprints/SKILL.md` and `lib/generate-sprints/`

- **Lineage:** native (no upstream). Introduced by PRD
  `.yoke/prds/2026-05-03-generate-sprints-skill.md` (approved
  2026-05-03) to decouple sprint generation from `/yoke:tech-spec`
  (Phase 2 / architecture-only) and from `/yoke:acceptance-criteria`
  (Phase 3 / binding criteria). The skill is the Phase 2.5 producer
  of `.yoke/sprints/<slug>-s<NN>.md` runtime bundles; it sits between
  Phase 3 ratification and Phase 4 council protocol invocation. The
  producer split was a deliberate refactor — sprint partitioning is
  conceptually the synthesis of (architecture + use cases) into
  delivery units, not a downstream artifact of either single input.
  No fork from Vibeflow or any other upstream applies; the
  canonical-memory facade and the approval-menu template are reused
  unchanged. The doctrine entry
  `concepts/yoke-pattern-sprint-synthesis` is staged at full-run
  termination via `.yoke/runtime/.preserve-packet.md` for the
  Orchestrator's canonize handoff.

  Companion deterministic helpers under `lib/generate-sprints/`
  (`parse-inputs.sh`, `synthesize.sh`, `partition.sh`,
  `render-bundle.sh`, `plan-io.sh`, `legacy-detect.sh`) are also
  Yoke-native; they bracket the LLM synthesis stage with strict input
  parsing and deterministic output generation. The legacy-task
  rejection branch in `legacy-detect.sh` realizes Decision 6A of the
  parent PRD — no automatic migration of legacy tasks; the cut-over
  is coexistence-only.

### `skills/implement/SKILL.md`

- **Source:** Yoke-original. The runtime ralph-loop coordinator is
  inspired by Anthropic's sprint-contracts pattern but extended with
  hard bounds + Model C escalation.

### `agents/generator.md`, `agents/validator.md`, `agents/orchestrator.md` (v1.1+)

- **Source:** Yoke-native subagent definitions. The three runtime
  subagents materialize Yoke's adversarial Generator/Validator
  separation at runtime, plus the Orchestrator as sole writer of
  canonical memory. Spec-phase Generator/Validator subagent
  instances (which the v1.0 layout had as separate files) are
  eliminated in v1.1 — their personas live inline in
  `/yoke:discover`, `/yoke:tech-spec`, `/yoke:acceptance-criteria`.
  See `concepts/yoke-decision-*` (canonical memory) "Three runtime
  subagents only" (2026-04-25, supersedes 2026-04-24 "Five
  subagents").

### `agents/generator.md` — Senior Developer persona import (2026-04-25)

- **Source:** vibeflow's implement skill (upstream version 1.10.0),
  specifically the `## Role: Coding Agent` block.
- **What was ported:** The Senior Developer / Coding-Agent persona —
  role definition (receives the approved PRD, Tech Spec, and binding
  Acceptance Contract; executes against them; does not redesign the
  system) plus the must-do / must-not / stop-and-surface discipline
  rules (follow patterns exactly, follow conventions, minimum change,
  treat upstream artifacts as constraints, no architectural decisions,
  no questioning of upstream artifacts at runtime, no scope creep, no
  while-I'm-here refactors, new dependencies require justification,
  and on ambiguity write the diagnosis to `.yoke/runtime/progress.md`
  for Orchestrator-detected Trigger 4 escalation). Materialized as a
  rewritten `## Persona` section plus a new `## Discipline` subsection
  inserted between `## Persona` and `## Behaviors`.
- **What was deliberately NOT ported:** Vibeflow's 7-phase
  orchestration (find spec → extract guardrails → load patterns →
  plan → implement → test → self-verify). Yoke's ralph loop in
  `skills/implement/SKILL.md` already owns cycle orchestration
  deterministically; importing the 7-phase shape would create two
  competing orchestration models inside the same cycle (an
  anti-pattern in `concepts/yoke-pattern-roles` and
  `concepts/yoke-pattern-ralph-loop` in canonical memory). Also not
  ported: vibeflow's budget enforcement, test-runner detection
  heuristics, and audit-suggestion footer — those belong to a
  single-agent pipeline; Yoke's equivalents are
  `hooks/check-hard-bounds.sh` plus the Acceptance Contract sensors
  invoked by `hooks/verify-acceptance.sh`.
- See `concepts/yoke-decision-*` (canonical memory) "Generator
  subagent persona = Senior Developer (Coding-Agent discipline)".

### `skills/drift-sense/SKILL.md`, `lib/canonical-memory/staleness-check.sh`, `lib/canonical-memory/trace-analyzer.sh`

- **Source:** Yoke-original. Phase 6 (continuous drift sensing across
  three observation targets) is one of Yoke's distinctive contributions
  — see manifesto §8.6.
- **Note (v2.0.0):** the helper libs that sat under
  `lib/canonical-memory/` and were Bedrock-derived moved to
  `claude-bedrock`; `trace-analyzer.sh` remains in Yoke because it
  reads `.yoke/contracts/<slug>.md` (Yoke working memory), not
  canonical memory.

### Bedrock canonical-memory port — Part 1 (Foundation, 2026-04-25; extracted at v2.0.0)

Originally imported from **bedrock 1.2.1**. Substrate for the larger
six-part port. Part 1 shipped the entity model and registry plumbing.
At v2.0.0 the entire Part 1–6 surface moved out of Yoke into the
peer plugin; the entries below are the historical record of what was
in Yoke between Sprint 5 and Sprint 3 of the v2.0.0 PRD.

#### Entity templates (8) — `claude-bedrock/templates/canonical/{type}/_template.md`

Mapped from bedrock's `templates/<plural>/_template.md`:

| Yoke path (pre-v2) → claude-bedrock path | Bedrock source |
| :--- | :--- |
| `templates/canonical/actor/_template.md` → same | `templates/actors/_template.md` |
| `templates/canonical/person/_template.md` → same | `templates/people/_template.md` |
| `templates/canonical/team/_template.md` → same | `templates/teams/_template.md` |
| `templates/canonical/concept/_template.md` → same | `templates/concepts/_template.md` |
| `templates/canonical/topic/_template.md` → same | `templates/topics/_template.md` |
| `templates/canonical/discussion/_template.md` → same | `templates/discussions/_template.md` |
| `templates/canonical/project/_template.md` → same | `templates/projects/_template.md` |
| `templates/canonical/fleeting/_template.md` → same | `templates/fleeting/_template.md` |

Each template extends bedrock's frontmatter with the five mandatory
**Yoke rippability fields** (`ratified_at`,
`model_calibrated_against`, `last_validated`, `traceability`,
`impact_level`) plus the four graph-relationship fields (`depends_on`,
`supersedes`, `applies_to`, `contradicts_with`). Bedrock-defined
fields are preserved verbatim — the rippability extension is additive.

#### Entity definitions (8) — `claude-bedrock/entities/{type}.md`

Mapped from bedrock's `entities/{type}.md` with these adaptations:

- Namespace renames: bedrock's namespaced verbs were renamed to the
  legacy `/yoke:` namespace at Sprint 5. At v2.0.0 they moved back to
  the `/bedrock:` namespace inside the peer plugin.
- Vocabulary renames: "Second Brain" / "vault" → "canonical memory".
- New `## Yoke Update Rules` section per entity, explicitly forbidding
  deletion of the five rippability fields on update.
- New `## Yoke rippability` section after the required-fields table.

#### Excluded from Part 1 (deferred)

- `entities/code.md` and `_template_node.md` — graphify-dependent;
  reserved for a future graphify-integration sprint.
- `entities/sources-field.md` — folded into the per-entity update rules.

#### New Yoke-native libraries (no upstream)

- `lib/canonical-memory/registry.sh` — managed the plugin-level
  registry in v1.x. Extracted to `claude-bedrock` at v2.0.0; Yoke
  itself no longer maintains a vault registry.
- `lib/canonical-memory/resolve-memory.sh` — 3-step memory resolution
  (`--memory <name>` → CWD → default → error). Extracted to
  `claude-bedrock` at v2.0.0; Yoke uses
  `lib/canonical-memory/resolve-provider.sh` instead.
- `lib/canonical-memory/scaffold-memory.sh` — initialized a fresh
  canonical-memory repo with the 8-entity scaffold. Extracted to
  `claude-bedrock` at v2.0.0.
- `templates/yoke-memory-config.json` — per-memory config schema.
  Replaced by `claude-bedrock/templates/bedrock-memory-config.json`
  at v2.0.0.

These libraries were introduced by Part 1 to support the registered
local checkout model that replaced clone-each-time. They were not
ports from bedrock — bedrock's vault registry uses the same conceptual
shape but lives at a different file path and uses different
field names.

### Bedrock canonical-memory port — Part 3 (Ask refactor, 2026-04-25; extracted at v2.0.0)

The legacy v1.x read skill was an adaptive 5-phase reader (classify
→ vault-first search → assess → recency → respond) with a 15-entity
cap and a 1-level wikilink hop. **No clone, no pull, no fetch** —
read against the registered local checkout via Part 1's
`resolve-memory.sh`. Bedrock's Phase 3-G/3-T (graphify / teach
escalation) was stubbed: emit a callout, continue with vault-only
content. Skill body was deleted in Yoke at v2.0.0; the equivalent
behavior lives in `claude-bedrock/skills/ask/SKILL.md`. Yoke v2.0.0
dispatches reads through `/yoke:search-canonical-memory`, which
forwards verbatim to the provider's pinned read verb.

### Bedrock canonical-memory port — Part 4 (Preserve replaces canonize, 2026-04-25; extracted at v2.0.0)

The legacy v1.x write skill was a streamlined 7-phase flow (sync →
parse → match → propose → execute → link → publish → report). Phase
3 wrapped bedrock's confirmation gate with **Model C impact-class
routing**, invoking `lib/canonical-memory/canonization-criteria.sh`
as the classifier. Phase 0.2 (graphify-merge) replaced with a
deferred-sprint abort. Skill body was deleted in Yoke at v2.0.0;
`claude-bedrock/skills/canonize/SKILL.md` is the live successor. Yoke
v2.0.0's `skills/canonize/SKILL.md` is a thin dispatcher that
resolves the provider and forwards `--working-memory <abs-path>`.

### Bedrock canonical-memory port — Part 6 (Compress + status extension, 2026-04-25; extracted at v2.0.0)

The compress skill (verbatim copy with namespace renames; detected
bedrock's 5 misalignment classes — broken backlinks, fragmentation,
miscategorization, duplicated entities, misnamed entities; all writes
delegated to the v1.x write skill; supported `--mode cron`) was
extracted to `claude-bedrock/skills/compress/SKILL.md` at v2.0.0.

`skills/status/SKILL.md` (extension): the Sprint-8 placeholder was
replaced with a full read-only diagnostic. Section 1 (working memory)
is Yoke-original. Section 2 (canonical-memory health) absorbed
bedrock's 5 healthcheck checks: setup verification, graphify-out
integrity, orphan entities, dangling content, stale content
(>15 days). Bedrock's standalone healthcheck skill is **not** copied
into Yoke; `/yoke:status --canonical` is the single entry point. At
v2.0.0, `/yoke:status` continues to read the host project's
`.yoke/`; the canonical-memory section delegates per-provider checks
through the facade-resolved provider name.

`lib/canonical-memory/staleness-check.sh` was retired in v1.1 — its
rippability re-validation logic was folded into
`/yoke:status --canonical` Section 2.5.

### Bedrock canonical-memory port — Part 5 (Teach + helpers, 2026-04-25; extracted at v2.0.0)

| Pre-v2 Yoke path → claude-bedrock path | Bedrock source | Adaptation |
| :--- | :--- | :--- |
| `skills/teach/SKILL.md` → `claude-bedrock/skills/teach/SKILL.md` | `skills/teach/SKILL.md` (1.2.1) | Streamlined for the no-graphify scope. Bedrock Phases 4–5 (graphify extraction + per-run output merge) replaced with direct Zettelkasten classification using `entities/{type}.md`. Ingestion ends by delegating to the write skill (single write point). All other phases preserved. |
| `skills/confluence-to-markdown/SKILL.md` → `claude-bedrock/skills/confluence-to-markdown/SKILL.md` | same (1.2.1) | Verbatim copy with namespace renames; vocabulary "vault" → "canonical memory". 3-layer fallback (MCP → REST → browser DOM) preserved. DOM-extraction `scripts/extract.js` copied unchanged. |
| `skills/gdoc-to-markdown/SKILL.md` → `claude-bedrock/skills/gdoc-to-markdown/SKILL.md` | same (1.2.1) | Verbatim copy with namespace renames. Preserves the GDoc / Sheets adapter chain. DOM-extraction `scripts/extract.js` copied unchanged. |

**Excluded from Part 5:**

- A graphify skill — graphify integration is deferred. The `code`
  entity type is reserved for that sprint.
- Bedrock's sync skill — out of scope for v0.

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
- **Bedrock** — Iury Krieger, MIT License. Used with credit. Now
  shipping as the standalone `claude-bedrock` peer plugin.

Both upstream projects are credited in `README.md` at the repo root.
