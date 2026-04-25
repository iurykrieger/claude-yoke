# PRD: Bedrock-style canonical-memory port

> Generated via /vibeflow:discover on 2026-04-25

## Problem

Yoke's canonical memory is currently accessed by cloning (or pulling) the
configured substrate repository into `~/.cache/yoke/canonical/<slug>/` on
**every** invocation of `lib/canonical-memory/query.sh`. This is wasteful,
slow, and architecturally wrong — the manifesto explicitly lists
"agents reading canonical memory by `cat`/`grep`/cloning the substrate"
as an anti-pattern under `.vibeflow/patterns/memory-model.md` (it bypasses
progressive disclosure and bypass detection).

A second, larger gap: the existing canonization path (`/yoke:canonize` +
`lib/canonical-memory/propose-write.sh`) only covers the runtime
Orchestrator's loop-termination flow. It has no entity model, no
classification, no bidirectional linking, no alignment maintenance, no
external ingestion. Bedrock has solved each of these for the Second
Brain use case; Yoke is reinventing them poorly. There is also no
multi-substrate support — `.yoke/config.yaml` holds a single
`canonical_memory.url` and that's the only knob.

## Target Audience

- **Yoke users** running spec-phase skills (`/yoke:discover`,
  `/yoke:tech-spec`, `/yoke:acceptance-contract`) and runtime
  (`/yoke:implement`) — they pay the latency tax on every clone.
- **The runtime Orchestrator subagent** — calls `query.sh` in consult
  mode every cycle. After this work it invokes `/yoke:preserve` at loop
  termination and reads through the cached registered memory.
- **The human gatekeeper at Trigger 5** (canonization ratification) —
  receives proposals from `/yoke:preserve` instead of from
  `/yoke:canonize`'s ad-hoc proposer.

## Proposed Solution

Port bedrock's canonical-memory mechanics into Yoke, adapted to Yoke's
vocabulary and governance:

1. **Registered local checkouts, not clone-each-time.** A plugin-level
   registry at `<plugin_dir>/memories.json` (same location bedrock uses
   for `vaults.json`) maps memory names to absolute paths and URLs.
   Operations work directly against the local checkout — clone only
   on registration or when the path is missing.
2. **Five new/refactored skills:**
   - `/yoke:ask` — refactor: replaces `query.sh` clone-each-time with a
     direct read against the registered memory. Adopts bedrock `/ask`'s
     adaptive vault-first search (entity reads + wikilink traversal,
     1-level depth, ≤15 entities). Continues writing to
     `.yoke/query-traces/<slug>.md` for bypass detection.
   - `/yoke:preserve` — new: single write point. Replaces
     `/yoke:canonize` and its `lib/canonical-memory/propose-write.sh`.
     The runtime Orchestrator subagent invokes it at loop termination,
     passing the entire `.yoke/` working-memory directory; `/preserve`
     decides what gets canonized via Zettelkasten classification +
     Model C impact-class routing.
   - `/yoke:teach` — new: ingest external sources (URLs, files) into
     the canonical memory via `/yoke:preserve`.
   - `/yoke:compress` — new: alignment maintenance — broken backlinks,
     fragmentation, duplication, miscategorization. Supports
     `--mode cron` for scheduled runs.
   - `/yoke:memory` — new (this is bedrock's `/vaults` renamed to
     Yoke vocabulary): manages the memory registry — list, set-default,
     remove, add.
3. **Adopt bedrock's 8 entity types verbatim:** Actor, Person, Team,
   Concept, Topic, Discussion, Project, Fleeting. Templates are copied
   from the bedrock plugin at creation time and live under
   `templates/canonical/{type}/_template.md` (per the manifesto's
   "embedded skills, no continuous port" rule).
4. **Keep `.yoke/config.yaml`'s `canonical_memory.url`** as the
   project's source-of-truth pointer. `/yoke:bootstrap` resolves it
   against the registry: registers it on first run if absent, clones to
   the default path if not yet checked out.
5. **Model C lives inside `/yoke:preserve`** as policy logic on the
   proposal — impact-class routing (auto-apply / notify-and-apply /
   synchronous ratification) wraps bedrock's confirmation gate, it does
   not replace it.

## Success Criteria

1. A second `/yoke:ask` invocation against the same memory does **not**
   re-clone or re-pull — verifiable by inspecting `~/.cache/yoke/`
   absence or `git -C <path> reflog` showing no fetch.
2. `/yoke:preserve` accepts a `.yoke/` working-memory directory as
   input, classifies its contents into the 8 entity types, applies
   Model C impact-class routing, and writes via the same git workflow
   as bedrock (commit-push / commit-push-pr / commit-only).
3. The runtime Orchestrator subagent at loop termination invokes
   `/yoke:preserve` instead of writing canonical memory directly —
   verifiable via `agents/orchestrator.md` and the Sprint 5 hooks.
4. `/yoke:teach <url>` ingests an external source (Confluence, GDoc,
   GitHub, or any docling-supported file) into the canonical memory,
   producing entities through `/yoke:preserve`'s confirmation gate.
5. `/yoke:compress` resolves at least the same alignment issues
   bedrock does (broken backlinks, duplicated entities, misnamed
   entities, fragmentation, miscategorization). Supports
   `--mode cron`.
6. `/yoke:memory` lists, sets-default, and removes registered
   memories. A user with two memories registered can target either
   via `--memory <name>` on any of the five skills.
7. Existing `.yoke/config.yaml` files with a populated
   `canonical_memory.url` continue to work after upgrade — first
   `/yoke:bootstrap` post-upgrade migrates by registering the URL into
   `memories.json`.
8. The manifesto invariants survive: every canonical-memory item still
   carries the rippability frontmatter (`ratified_at`,
   `model_calibrated_against`, `last_validated`, `traceability`,
   `impact_level`), every read still emits a trace entry to
   `.yoke/query-traces/<slug>.md`, every write still goes through
   exactly one path (`/yoke:preserve`).

## Scope v0

- **Skills:** `/yoke:ask` (refactor), `/yoke:preserve` (new — replaces
  `/yoke:canonize`), `/yoke:teach` (new — copied verbatim from
  bedrock 1.2.1 with Yoke-namespace renames), `/yoke:compress` (new —
  copied verbatim), `/yoke:memory` (new — copied from bedrock
  `/vaults` with rename), `/yoke:bootstrap` (refactor for registry +
  migration), `/yoke:status` (refactor — absorbs bedrock's
  `/healthcheck`).
- **Internal helper skills copied from bedrock 1.2.1 verbatim** to
  back `/yoke:teach`'s adapter coverage:
  `skills/confluence-to-markdown/` and `skills/gdoc-to-markdown/`.
  Pulls in bedrock's full `/teach` adapter surface — Atlassian MCP
  preferred, REST/basic-auth fallback, browser-DOM last resort for
  Confluence; GDoc/Sheets equivalent; GitHub repo ingestion via the
  GitHub MCP; remote URLs via `WebFetch`; local files via docling
  (DOCX, PPTX, XLSX, PDF, HTML, EPUB, images, Markdown).
- **Removal:** `/yoke:canonize` and `lib/canonical-memory/propose-write.sh`
  are retired. `lib/canonical-memory/query.sh` is retired in favor of
  direct reads from `/yoke:ask`.
- **Registry:** `<plugin_dir>/memories.json` — same location bedrock
  uses for `vaults.json`. Schema mirrors bedrock's
  (`{name, path, url, default}`). Caveat inherited from bedrock: on
  plugin reinstall, the registry file is lost; checked-out memory
  repos on disk are unaffected. Recovery is `/yoke:memory add` for
  each one.
- **`/yoke:memory add` semantics:** requires a user-supplied path. If
  the path is an existing git repo, register it as-is. If the path
  does not exist (or is empty), create a new git repo there with the
  Yoke canonical-memory scaffold (entity directories,
  `_template.md`s, `.yoke-memory/config.json`).
- **Per-memory config:** `<memory>/.yoke-memory/config.json` — language,
  `git.strategy`, `query.max_subgraph_calls`. Distinct path from the
  project-level `.yoke/` to avoid name collision.
- **Entity types:** Actor, Person, Team, Concept, Topic, Discussion,
  Project, Fleeting. Templates copied from bedrock under
  `templates/canonical/{type}/_template.md`.
- **Model C wiring:** `/yoke:preserve`'s confirmation phase reads the
  proposed write's `impact_level` and routes per
  `.vibeflow/patterns/model-c-governance.md` — `low` auto-applies via
  PR with auto-merge, `medium` notifies-and-applies with veto window,
  `high` blocks on synchronous human ratification, `regulatory`
  refuses without explicit Compliance ratification.
- **Git strategies:** all three from bedrock — `commit-push` (default),
  `commit-push-pr` (mandatory for `high` / `regulatory` impact),
  `commit-only`.
- **Migration:** `/yoke:bootstrap` detects pre-existing
  `canonical_memory.url`, registers it with a derived name, deletes
  `~/.cache/yoke/canonical/<slug>/`, and updates `.yoke/config.yaml`
  with `canonical_memory.name`.
- **Patterns updated:** `.vibeflow/patterns/memory-model.md` rewritten
  to reflect the registered-checkout model and the
  preserve-as-single-write-point invariant.

## Anti-scope

- **No graphify integration in v0.** No `code` entity type, no
  `graph.json` merging in `/yoke:preserve` Phase 0.2, no
  `/yoke:graphify` skill. *Deferred to a future sprint, not killed —
  the entity model and `/preserve` proposal pipeline must remain
  forward-compatible with bedrock's graphify integration so the work
  is additive when graphify lands.*
- **No `/yoke:sync`.** Bedrock's people/PR sync from GitHub is out of
  scope for v0.
- **No standalone `/yoke:healthcheck`.** Healthcheck folds into
  `/yoke:status` — they are the same skill in Yoke. The existing
  `/yoke:status` is extended to cover bedrock's healthcheck surface
  (graphify-out integrity, setup verification, orphan entities,
  dangling content, old content >15 days) for the active memory.
- **No standalone `/yoke:setup`.** Vault initialization is owned by
  `/yoke:bootstrap` for working memory and by `/yoke:memory add` for
  canonical memory.
- **No fleeting-to-permanent promotion.** `/yoke:ask` flags candidates
  with a callout; promotion stays manual.
- **No bedrock-namespace coexistence.** A memory registered under Yoke
  is not also addressable as a bedrock vault — `.yoke-memory/config.json`
  is the config file, not `.bedrock/config.json`.
- **No replacement of Model C with a simple gate.** The bedrock-style
  "Confirm execution? (yes/no/adjust)" prompt is the *low-impact*
  case; high-impact and regulatory writes still block per Model C.

## Technical Context

**What already exists in this repo:**

- `lib/canonical-memory/{query,propose-write,graph,canonization-criteria,staleness-check}.sh`
  — to be retired or repurposed (`graph.sh` may live on inside
  `/yoke:ask`'s subgraph traversal; `canonization-criteria.sh` and
  `staleness-check.sh` move into `/yoke:preserve` and
  `/yoke:compress`).
- `lib/working-memory/paths.sh` — `wm_query_trace_path` keeps working
  as the trace-path resolver.
- `skills/{ask,canonize,bootstrap}/SKILL.md` — `ask` and `bootstrap`
  are refactored, `canonize` is removed.
- `agents/orchestrator.md` — runtime canonical-memory authority. Its
  consult mode now reads from the registered local path; its canonize
  mode invokes `/yoke:preserve`.
- `.vibeflow/patterns/memory-model.md` and `model-c-governance.md` —
  source of truth, must be updated to reflect the new model.

**Patterns to follow:**

- Progressive disclosure: `/yoke:ask`'s adaptive search caps at
  15 entities. No "load the whole memory" path.
- Traceability: every write goes through `/yoke:preserve` and produces
  a git commit. Every read goes through `/yoke:ask` (or the
  Orchestrator's consult mode) and writes a trace entry.
- Rippability frontmatter: bedrock's entity templates do **not** carry
  Yoke's rippability fields. The Yoke-side templates extend each
  bedrock template with the mandatory five (`ratified_at`,
  `model_calibrated_against`, `last_validated`, `traceability`,
  `impact_level`).

**Constraints:**

- bash 4+. macOS bootstrap continues to require Homebrew bash.
- `gh` CLI required for `commit-push-pr` strategy (already a v0.5+
  dependency for canonization).
- `python3` for graphify-merge code is **not** required (graphify is
  out of scope).
- Bedrock plugin source available at
  `~/.claude/plugins/cache/claude-bedrock/bedrock/1.2.1/` for one-time
  copy of skill bodies and entity definitions. After copy, Yoke's
  versions evolve independently.

**Decision pre-baked in `.vibeflow/decisions.md`:**

- "Embedded skills, no continuous port" — copy at creation, evolve
  inside Yoke. This work materializes that decision for Bedrock.

## Open Questions

1. **Sprint slotting / version bump.** Naming the sprint number and
   version is a tech-spec concern, not a PRD concern — flagged for
   the next phase.

### Resolved during discovery (2026-04-25)

- **Memory registry location** → `<plugin_dir>/memories.json`
  (bedrock parity). Caveat: lost on plugin reinstall; recovery via
  `/yoke:memory add` per memory.
- **Default checkout path** → user-supplied via `/yoke:memory add
  <path>`. If the path does not exist or is empty, create a new git
  repo with the Yoke canonical-memory scaffold.
- **`code` entity type** → not in v0. Reserved for the future
  graphify-integration sprint; entity model and `/preserve` pipeline
  must stay forward-compatible.
- **Healthcheck** → folded into `/yoke:status`. Same skill, no
  separate `/yoke:healthcheck`.
- **`/yoke:teach` adapter coverage** → copy bedrock 1.2.1 verbatim,
  including the Atlassian/GitHub MCP integrations and the
  `confluence-to-markdown` / `gdoc-to-markdown` internal helpers, and
  docling support for local files.

---

When you're ready to advance to the technical spec, run:
`/vibeflow:gen-spec .vibeflow/prds/bedrock-canonical-memory-port.md`
