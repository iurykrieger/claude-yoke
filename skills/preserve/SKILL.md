---
name: preserve
description: >
  Single write point to canonical memory. Replaces /yoke:canonize as the
  governed entry for all writes. Accepts structured input (an entity
  list), free-form input (text or a path to .yoke/ working memory), or
  a runtime invocation from the Orchestrator subagent at loop
  termination. Detects entities, classifies into the 8 Zettelkasten
  types, applies Model C impact-class routing, executes the
  confirmation gate, performs bidirectional linking, and commits via
  the configured git strategy.
  Use when: "yoke preserve", "yoke-preserve", "/yoke:preserve",
  "save to canonical memory", "canonize", "ratify",
  or when the runtime Orchestrator hands off `.yoke/` at loop
  termination.
argument-hint: "[--memory <name>] [<text-or-yoke-path>]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Skill
---

# /yoke:preserve — single write point under Model C

> Lineage: copied from `bedrock 1.2.1 /preserve` with the kebab-case
> Yoke namespace rename (`/bedrock:*` → `/yoke:*`, vault → memory) and
> Model C impact-class routing wrapped around bedrock's Phase 3
> confirmation gate. The graphify-merge logic (bedrock Phase 0.2) is
> excluded — graphify integration is deferred to a future Yoke sprint.

You are the **execution agent** for canonical-memory writes. Every
write to canonical memory in Yoke flows through this skill. Other
agents may *propose* writes; only this skill *executes* them.

## Plugin paths

- Entity definitions: `<plugin_dir>/entities/{actor,person,team,concept,topic,discussion,project,fleeting}.md`
- Templates: `<plugin_dir>/templates/canonical/{type}/_template.md`
- Canonization-criteria classifier: `<plugin_dir>/lib/canonical-memory/canonization-criteria.sh`

## Pre-conditions

- A canonical memory is registered. If not, abort:
  *"No memory registered. Run /yoke:memory add <path> or /yoke:bootstrap."*
- `gh` CLI installed and authenticated when the memory's
  `git.strategy` is `commit-push-pr` (the Yoke default). Falls back to
  `commit-push` with a warning when `gh` is missing.

## Phase 0 — Pre-write setup

### 0.1 Resolve the active memory

```bash
source <plugin_dir>/lib/canonical-memory/resolve-memory.sh
yoke_resolve_memory --memory "$EXPLICIT_NAME"   # or no flag
# $YOKE_MEMORY_PATH and $YOKE_MEMORY_NAME are now set
```

`MEMORY_PATH=$YOKE_MEMORY_PATH` is the absolute path used below.

### 0.2 Read the per-memory config

```bash
cat "$MEMORY_PATH/.yoke-memory/config.json" 2>/dev/null
```

Extract `language`, `git.strategy`. Default `git.strategy` is
`commit-push-pr` (Yoke's Model-C-mandated PR-based protocol).

### 0.3 Memory sync

```bash
git -C "$MEMORY_PATH" pull --rebase origin main
```

Failure modes:

- No remote configured → warn "no remote — working locally" and proceed.
- Pull conflict → `git -C "$MEMORY_PATH" rebase --abort` and abort the
  preserve run with a clear diagnostic. Do **not** proceed with a
  conflicted memory.
- Otherwise → proceed.

### 0.4 (Skipped) Graphify merge

Bedrock 1.2.1 Phase 0.2 merges incoming graphify output (`graph.json`,
`obsidian/*.md`, `GRAPH_REPORT.md`) into the memory's `graphify-out/`
directory. **This phase is not implemented in v0** — graphify integration
is anti-scope. If the input includes a `graphify_output_path`, abort
with: *"Graphify integration is deferred to a future Yoke sprint."*

## Phase 1 — Parse input

### 1.1 Structured input

When the caller supplies an explicit entity list, the format is:

```yaml
- type: actor | person | team | concept | topic | discussion | project | fleeting
  name: "canonical entity name"
  action: create | update
  content: "body content"
  relations:
    actors: ["[[slug]]", ...]
    people: ["[[slug]]", ...]
    teams: [...]
    concepts: [...]
    topics: [...]
    discussions: [...]
    projects: [...]
  source: "github | confluence | jira | session | manual | gdoc | csv | runtime"
  metadata: { ... }
  # Yoke rippability (mandatory for new entries)
  ratified_at: "<ISO-8601>"
  model_calibrated_against: "<model id>"
  last_validated: "<ISO-8601>"
  traceability: "<failure or constraint pointer>"
  impact_level: low | medium | high | regulatory
```

Parse and proceed to Phase 2.

### 1.2 Free-form input

When the caller supplies natural text or a path to a `.yoke/` directory
(the Orchestrator's loop-termination handoff), do this:

1. **If the input is a path to a `.yoke/<task-slug>/` directory:** read
   `progress.md` and `contracts.md`. Combine into the analysis blob.
   (The `query-traces/<slug>.md` source was retired in
   ask-source-agnostic-read Part 1.)
2. **Otherwise:** treat as raw text.
3. Identify mentioned entities by name, alias, or reference (people:
   "First Last"; actors: service names / repos; teams: squad names;
   concepts: patterns / principles / techniques / protocols;
   topics: discussion themes / RFCs / features; discussions: meetings /
   decisions; projects: initiatives / migrations).
4. Inferred action per entity: `update` if it already exists in the
   memory; `create` otherwise.
5. Source: infer (`runtime` for `.yoke/` handoffs; `session` for
   conversation; `meeting-notes` for minutes; `manual` for plain text).
6. **Apply Zettelkasten classification.** Consult
   `<plugin_dir>/entities/{type}.md` "Completeness Criteria" and "When
   to create" / "When NOT to create" sections.
7. **Default to `fleeting`** when content does not meet any other
   type's completeness criteria — *"safer to capture as fleeting and
   promote later than to create an incomplete permanent."*

Convert the result into Phase 1.1's structured shape and proceed to
Phase 2.

### 1.3 Graphify output input — anti-scope

If the input is a graphify output directory or a `graph.json`, abort
per Phase 0.4.

## Phase 2 — Match against existing entities

### 2.0 Read entity definitions

Read every `<plugin_dir>/entities/<type>.md` file. Internalize the
"When to create" / "When NOT to create" / "How to distinguish" sections
to drive Phase 1.2's classification.

### 2.1 Collect existing entities

List every file in:

```
$MEMORY_PATH/{actors,people,teams,concepts,topics,discussions,projects,fleeting}/*.md
```

Exclude `_template.md`. Extract `filename`, `name|title`, `aliases` for each.

### 2.2 Textual matching

For each input entity, attempt these matches in priority order:

1. Exact filename match (case-insensitive): `billing-api` == `billing-api`.
2. `name`/`title` frontmatter match.
3. `aliases` frontmatter match.
4. Filename without hyphens vs aliases (case-insensitive).

**Safety rules:**
- Do not match by substrings of 3 characters or fewer.
- Cap at 20 correlations per entity type per run.
- On ambiguity, record all candidates and resolve in Phase 3.

### 2.3 Classify actions

- Match found → `update`
- No match → `create`
- Input-specified action wins.

## Phase 3 — Proposal + Model C routing

### 3.1 Build the proposal

Present to the user (and the calling Orchestrator) the full proposal
table:

```
## /yoke:preserve — proposal

### Entities to create
| # | Type | Name | File | Relations | Impact |
|---|---|---|---|---|---|

### Entities to update
| # | Type | Name | File | Changes | Impact |
|---|---|---|---|---|---|

### Bidirectional links
| Source | Target | Field |
|---|---|---|

Total: N create, M update, P bidirectional links.
Memory: <name> @ <path>
Git strategy: <commit-push | commit-push-pr | commit-only>
```

### 3.2 Determine `impact_level` per write

For each proposed entity, resolve `impact_level` in this order:

1. **Orchestrator handoff** — when invoked with `--from-orchestrator`
   passing a `.yoke/<task-slug>/` path, read the candidate list emitted
   by
   `bash <plugin_dir>/lib/canonical-memory/canonization-criteria.sh --working-memory <task-path>`.
   Each candidate already carries an `impact:` field (one of
   `low | medium | high | regulatory`). Honor it directly.
2. **Explicit input** — when the structured input or the user
   provides an `impact_level`, honor it.
3. **Keyword heuristic** — for free-form / manual writes without an
   explicit class, classify on `tolower(name + " " + content)` using
   the same rules:

   | Impact | Trigger keywords |
   |---|---|
   | `regulatory` | `regulatory`, `gdpr`, `lgpd`, `pci`, `hipaa`, `soc2`, `compliance` |
   | `high` | `policy`, `must` (word-bounded), `require` |
   | `medium` | `template`, `convention`, `naming` |
   | `low` | (default) |

   Higher class wins on overlap.

### 3.3 Model C routing

For each proposed write, route by `impact_level`:

| Impact | Confirmation gate | PR strategy |
|---|---|---|
| `low` | bedrock-style "yes/no/adjust" prompt is the ratification | `commit-push-pr` → PR with `--auto-merge`; `commit-push` allowed for explicitly low-stakes memories; CI checks gate the merge |
| `medium` | bedrock prompt is informational; user must acknowledge the veto window | PR opens with a comment announcing the veto window (default 24h, configurable via the memory's `model_c.veto_window_hours`); auto-merge after window |
| `high` | bedrock prompt is informational; user must acknowledge that human merge is required | PR opens with `--no-auto-merge`; awaits explicit human approval |
| `regulatory` | bedrock prompt is informational; user must acknowledge Compliance routing | PR opens with `--no-auto-merge`; routed to Compliance via CODEOWNERS in the canonical-memory repo |

**Hard rules:**

- `high` and `regulatory` writes **never** auto-merge.
- A `regulatory` write without a CODEOWNERS file in the memory repo
  still opens with `--no-auto-merge` and a warning comment — but
  routing is not guaranteed without CODEOWNERS.
- The user can downgrade impact via `--impact-override <class>` at
  their own risk; the override is recorded in the PR body.

### 3.4 Confirmation

After presenting the proposal table (with impact class + routing per
row), ask:

> Confirm execution? (yes / no / adjust)

- **yes** → Phase 4
- **no** → abort with no writes
- **adjust** → take the user's instructions, modify the proposal,
  re-present

When invoked from the runtime Orchestrator at loop termination
(`--from-orchestrator`), the confirmation prompt becomes
**informational** for `low`-class writes (auto-confirmed under Model C
auto-apply) but **synchronous** for `medium`+ writes — the
Orchestrator pauses the canonize phase until the human responds.

## Phase 4 — Execute writes

### 4.1 Create new entities

For each `create`:

1. Read the matching template: `<plugin_dir>/templates/canonical/<type>/_template.md`.
2. Fill bedrock fields: `type`, `name`/`title`, `aliases` (≥ 1),
   `tags` (`type/<type>` + status/domain/etc.), `updated_at` (today),
   `updated_by` (`preserve@agent` or `<calling-agent>`), relation
   wikilinks.
3. **Fill the five Yoke rippability fields** from the input
   (`ratified_at`, `model_calibrated_against`, `last_validated`,
   `traceability`, `impact_level`). Reject the write if any of the
   five is missing — entry would be unauditable.
4. Fill the four graph-relationship arrays (`depends_on`,
   `supersedes`, `applies_to`, `contradicts_with`) — empty arrays
   if no relations.
5. Body fill from input.
6. Mandatory callouts:
   - `status: deprecated` actor → `> [!warning] Deprecated`
   - `pci: true` actor → `> [!danger] PCI Scope`
7. Save to `$MEMORY_PATH/<directory>/<filename>.md` per the type's
   filename convention (`actors/repo-name.md`, `topics/YYYY-MM-category-slug.md`,
   etc.).

### 4.2 Update existing entities

1. Read the existing file.
2. **Frontmatter:** merge — never delete fields. Always update
   `updated_at` / `updated_by`. Add new wikilinks to existing arrays
   (no duplicates). **Never delete** the five Yoke rippability fields.
3. **Body:**
   - Actors → may modify and merge.
   - People / teams / concepts / topics → **append-only** (never delete
     content from another agent or human).
   - Discussions / projects → append-only for the general body;
     structured fields (`action_items`, `conclusions`) can be updated.
4. **Wikilinks:** add new; never remove.

### 4.3 Update `sources` field (when input has source URL)

Append `{url, type, synced_at}` if URL not yet present; update
`synced_at` in place if it is. Sort `sources` by `synced_at`
descending.

## Phase 5 — Bidirectional linking

For each accepted relation `X → Y`, ensure `Y → X` exists. Linking
graph (same as bedrock):

```
Team ⟷ Person (members / team)
Team ⟷ Actor (actors / team)
Person → Actor (focal_points)
Topic → Person/Actor (people, actors)
Project → Person/Actor/Team/Topic (focal_points, related_*)
Discussion → Actor/Person/Project/Topic/Team (related_*)
```

Idempotency: never add a wikilink that already exists.

Section creation: when the reverse-link target needs a body section
(e.g., `## Discussions` on an actor), add the section in the right
place (before `## Expected Bidirectional Links` or before the last
horizontal rule).

## Phase 6 — Publish

### 6.1 Stage and verify

```bash
git -C "$MEMORY_PATH" add actors/ people/ teams/ concepts/ topics/ \
                          discussions/ projects/ fleeting/
git -C "$MEMORY_PATH" diff --cached --quiet && {
  echo "Nothing to commit."
  exit 0
}
```

### 6.2 Dispatch by git strategy

**`commit-push` (low-stakes only):**

```bash
git -C "$MEMORY_PATH" commit -m "<message>"
git -C "$MEMORY_PATH" push origin main
```

On conflict: `git pull --rebase`, retry once. After 2 attempts: stop
and report.

**`commit-push-pr` (default):**

Verify `gh` is available; if not, fall back to `commit-push` with a
warning.

```bash
branch="vault/<YYYY-MM-DD>-<slug>"
git -C "$MEMORY_PATH" checkout -b "$branch"
git -C "$MEMORY_PATH" commit -m "<message>"
git -C "$MEMORY_PATH" push origin "$branch"

# PR strategy depends on impact:
case "$IMPACT" in
  low)    gh pr create --base main --body "<body>" --title "<title>"
          gh pr merge --auto --squash ;;
  medium) gh pr create --base main --body "<body + veto window note>"
          # auto-merge configured by an external scheduler / CI; not gated by gh --auto here
          ;;
  high|regulatory)
          gh pr create --base main --body "<body + impact warning>"
          # NO auto-merge; human merge only
          ;;
esac

git -C "$MEMORY_PATH" checkout main
```

**`commit-only`:**

```bash
git -C "$MEMORY_PATH" commit -m "<message>"
# Do not push.
```

### 6.3 Commit message convention

Single entity:
```
yoke(<type>): <verb> <name> [source: <source>] [impact: <class>]
```

Multiple entities:
```
yoke: preserves N entities [source: <sources>] [impact: <highest-class>]
```

Verbs: `creates`, `updates`, `links`, `compresses`.

## Phase 7 — Report

```
## /yoke:preserve — report

### Entities created
| Type | Name | File | Source | Impact |

### Entities updated
| Type | Name | File | Changes | Impact |

### Bidirectional links applied
| Source | Target | Type |

### Sources consulted
- ✅ Local memory
- ✅ / ❌ Atlassian MCP (when invoked from /yoke:teach)
- ✅ / ❌ GitHub MCP

### Git
- Strategy: <commit-push | commit-push-pr | commit-only>
- Branch: <branch-or-main>
- PR: <url-or-none>
- Auto-merge: <configured | scheduled | never>

### Warnings
- [orphan wikilinks, ambiguous entities, MCP unavailable, etc.]
```

## Critical rules

| # | Rule |
|---|---|
| 1 | NEVER write to canonical memory outside this skill — `/yoke:preserve` is the single write point |
| 2 | NEVER delete content written by another agent or human (except the explicit "Recent Activity" merge case in actors) |
| 3 | NEVER overwrite frontmatter — only merge new fields. NEVER delete existing fields. The five Yoke rippability fields are protected. |
| 4 | NEVER auto-merge `high` or `regulatory` writes — Model C demands synchronous ratification or Compliance |
| 5 | ALWAYS resolve `MEMORY_PATH` via Part 1's `resolve-memory.sh` |
| 6 | ALWAYS pull-rebase before writing; abort on conflict |
| 7 | ALWAYS confirm the proposal before executing — except when invoked by the Orchestrator at loop termination, where `low` writes auto-confirm |
| 8 | ALWAYS update `updated_at` and `updated_by` on every touched entity |
| 9 | ALWAYS use kebab-case lowercase filenames |
| 10 | ALWAYS follow the templates from `templates/canonical/<type>/_template.md` for new entities |
| 11 | ALWAYS populate the five Yoke rippability fields on create — reject the write otherwise |
| 12 | NEVER commit secrets (PAN / CVV / tokens / credentials) |
| 13 | Git operations use `git -C "$MEMORY_PATH"` — never assume CWD is the memory |
| 14 | Bare wikilinks (`[[name]]`, never `[[dir/name]]`) |
| 15 | Hierarchical tags (`type/actor`, never `actor`) |

## Anti-patterns

- Bypassing this skill to write canonical memory directly — bypass.
- Auto-merging `high` or `regulatory` PRs — Model C violation.
- Mid-loop writes from the runtime Orchestrator — canonization fires
  only at loop termination per `.vibeflow/patterns/memory-model.md`.
- Updating an entity without bumping `updated_at` — silent breakage.
- Creating an entity without populating the five rippability fields —
  unauditable entry.

## See also

- `.vibeflow/patterns/memory-model.md` — single write point invariant.
- `.vibeflow/patterns/model-c-governance.md` — impact classes + PR
  protocol.
- `agents/orchestrator.md` — runtime canonize-mode invocation.
- `lib/canonical-memory/canonization-criteria.sh` — Model C classifier
  (repurposed in Phase 3.2).
- `lib/canonical-memory/resolve-memory.sh` — Part 1 resolution lib.
- `templates/canonical/<type>/_template.md` — bedrock entity templates
  with Yoke rippability extension.
