---
name: teach
description: >
  Ingest an external source into the active canonical memory. Fetches
  from Confluence (via confluence-to-markdown), Google Docs / Sheets
  (via gdoc-to-markdown), GitHub repositories (via the GitHub MCP),
  remote URLs (via WebFetch), or local files (via docling — DOCX,
  PPTX, XLSX, PDF, HTML, EPUB, images, Markdown). Classifies the
  extracted content into Yoke's 8 Zettelkasten entity types and
  delegates persistence to /yoke:preserve under Model C governance.
  Use when: "yoke teach", "yoke-teach", "/yoke:teach", "ingest source",
  "import document", or whenever a user provides a URL or a local file
  path to incorporate into the canonical memory.
argument-hint: "[--memory <name>] <url-or-path>"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Skill, WebFetch, mcp__plugin_github_github__*, mcp__plugin_atlassian_atlassian__*
---

# /yoke:teach — External source ingestion

> Lineage: copied from `bedrock 1.2.1 /teach` with the kebab-case Yoke
> namespace rename and adapted to v0's no-graphify scope. Bedrock's
> graphify extraction pipeline (Phases 4–5 in upstream) is replaced
> with direct entity classification using `entities/{type}.md`.
> Graphify integration is deferred to a future Yoke sprint per
> `.yoke/specs/2026-04-25-bedrock-canonical-memory-port-part-5.md` anti-scope.

You are a **fetcher and classifier**. Your job:

1. Resolve the active memory.
2. Classify the input as a URL or a local path; fetch and convert to
   Markdown.
3. Classify the resulting content into the 8 Zettelkasten entity types.
4. Build structured input and delegate writes to `/yoke:preserve`.
5. Clean up temporary files.

You do **not** write to the canonical memory directly. Every write
goes through `/yoke:preserve` (Part 4's single write entry).

## Plugin paths

- Entity definitions: `<plugin_dir>/entities/{type}.md`
- Templates: `<plugin_dir>/templates/canonical/{type}/_template.md`
- Helper skills: `skills/confluence-to-markdown/`, `skills/gdoc-to-markdown/`

`<plugin_dir>` is the parent of `skills/`.

## Phase 0 — Resolve the active memory

```bash
source <plugin_dir>/lib/canonical-memory/resolve-memory.sh
yoke_resolve_memory --memory "$EXPLICIT_NAME"
```

After this returns 0:

- `$YOKE_MEMORY_PATH` — absolute path to the registered memory
- `$YOKE_MEMORY_NAME` — name to pass to `/yoke:preserve`

If no memory resolved → print the resolver's error and exit 0
(no-op).

## Phase 1 — Classify the input + fetch

### 1.1 Detect input type

| Pattern | Type | Adapter |
|---|---|---|
| `https://*.atlassian.net/wiki/...` | Confluence page | `/yoke:confluence-to-markdown` |
| `https://docs.google.com/document/...` | Google Doc | `/yoke:gdoc-to-markdown` |
| `https://docs.google.com/spreadsheets/...` | Google Sheet | `/yoke:gdoc-to-markdown` |
| `https://github.com/<owner>/<repo>` | GitHub repo | GitHub MCP — read `README.md`, `docs/`, key root files |
| `https://github.com/<owner>/<repo>/blob/...` | GitHub file | GitHub MCP `get_file_contents` |
| `https://*` (other) | Generic remote URL | `WebFetch` |
| `file://...` or absolute path | Local file or directory | docling (lazy-import — install on demand) |

If the input is a directory of local files, iterate one file at a time.

### 1.2 Fetch to a temp directory

```bash
TEACH_TMP=$(mktemp -d -t yoke-teach.XXXXXX)
trap 'rm -rf "$TEACH_TMP"' EXIT
```

For each source, write the fetched Markdown to `$TEACH_TMP/<slug>.md`.
The slug derives from the source URL/filename (kebab-case, lowercase,
no accents).

### 1.3 Per-adapter behavior

- **Confluence:** invoke `/yoke:confluence-to-markdown` via the Skill
  tool. The helper falls through MCP → REST → browser DOM.
- **GDoc / Sheets:** invoke `/yoke:gdoc-to-markdown` via the Skill
  tool. Same fallback chain.
- **GitHub repo:** call
  `mcp__plugin_github_github__get_file_contents` for `README.md`,
  `docs/*`, root `*.md`. If MCP missing, `WebFetch` the raw URL.
- **GitHub file:** `mcp__plugin_github_github__get_file_contents`,
  fallback to `WebFetch` on the `raw.githubusercontent.com` URL.
- **Generic URL:** `WebFetch` — accept Markdown, HTML, text. Convert
  HTML → Markdown via docling.
- **Local file:** docling for non-markdown formats (DOCX, PPTX, XLSX,
  PDF, HTML, EPUB, images). Markdown files copied through
  unchanged.

### 1.4 docling install (lazy)

When a non-markdown local file is encountered:

```bash
if ! python3 -c "import docling" 2>/dev/null; then
  echo "docling is required for local-file ingestion."
  echo "Install with: pip install docling"
  echo "Or skip: re-run /yoke:teach with a Markdown file."
  exit 0
fi
```

Do not auto-install. The user authorizes the dependency explicitly.

## Phase 2 — Classify the extracted content

Read every file in `$TEACH_TMP/`. For each file:

1. Read every entity definition under
   `<plugin_dir>/entities/{type}.md`. Internalize each type's
   "When to create" / "When NOT to create" / "How to distinguish" /
   "Completeness Criteria" sections.
2. Apply Zettelkasten classification per `entities/fleeting.md`'s
   default rule: *"safer to capture as fleeting and promote later
   than to create an incomplete permanent."*
3. Extract:
   - **type**: `actor` / `person` / `team` / `concept` / `topic` /
     `discussion` / `project` / `fleeting`.
   - **name** (or **title** for topics/discussions): kebab-case slug
     for the filename, plus the human-readable display name.
   - **content**: the Markdown body that should land in the entity
     file (truncate if extremely long; 2k tokens max per entity).
   - **relations**: wikilinks to existing memory entities discovered
     in the body (use Glob/Grep against `$YOKE_MEMORY_PATH/<dir>/`).
   - **source**: the original URL or local path.
   - **source_type**: `confluence` / `gdoc` / `github` / `file` /
     `webfetch`.
4. Build the structured input for `/yoke:preserve`:

   ```yaml
   - type: <type>
     name: "<canonical-name>"
     action: create | update     # auto-detected during /preserve Phase 2
     content: "<body>"
     relations: { ... }
     source: <source_type>
     source_url: "<url-or-path>"
     # Yoke rippability — best-effort defaults
     ratified_at: "<today>"
     model_calibrated_against: "claude-opus-4-7"
     last_validated: "<today>"
     traceability: "<source_url>"
     impact_level: "low"          # /preserve will re-classify in Phase 3
   ```

## Phase 3 — Delegate to /yoke:preserve

Invoke `/yoke:preserve` via the Skill tool with the structured entity
list and `--memory $YOKE_MEMORY_NAME`. `/preserve` runs:

- Phase 0: `git pull --rebase` against the registered memory.
- Phase 2: matching against existing entities.
- Phase 3: proposal + Model C routing (the user sees one
  confirmation gate — bedrock's Phase 3 dialog).
- Phase 4-5: write + bidirectional links.
- Phase 6: commit per the memory's `git.strategy`.
- Phase 7: report.

`/yoke:teach` waits for `/preserve` to complete and surfaces its
report verbatim. **Never bypass `/preserve` to write directly.**

## Phase 4 — Cleanup

```bash
rm -rf "$TEACH_TMP"
```

If anything in `/preserve` failed, the temp directory is preserved for
debugging — keep it and emit its path in the error message.

## Output

Print `/preserve`'s Phase 7 report verbatim. Append:

```
Source: <url-or-path>
Adapter: <confluence|gdoc|github|webfetch|docling>
Entities proposed: N (created M, updated K)
Memory: <name> @ <path>
```

## Critical rules

| # | Rule |
|---|---|
| 1 | NEVER write to canonical memory directly — always delegate to `/yoke:preserve` |
| 2 | Best-effort fetching — if a fallback layer fails, try the next; on total failure, abort cleanly |
| 3 | NEVER auto-install docling — guide the user to install it |
| 4 | Default to `fleeting` when content does not meet completeness criteria of any other type |
| 5 | Cap each entity's content at 2k tokens — truncate with `...` and a `> [!info] Truncated content`, not silently |
| 6 | Always populate the 5 Yoke rippability frontmatter fields with sensible defaults — `/preserve` rejects incomplete entries |
| 7 | Always include `source_url` so `/preserve` populates the entity's `sources` field |
| 8 | Cleanup the temp directory on success; preserve and surface its path on failure |
| 9 | Use the Atlassian / GitHub MCP servers when available; fall through to REST / `WebFetch` cleanly when not |
| 10 | Pass `--memory $YOKE_MEMORY_NAME` to `/yoke:preserve` so it targets the same memory `/teach` resolved |

## Anti-patterns

- Bypassing `/yoke:preserve` to write canonical memory directly —
  violates the single-write-point invariant from Part 4.
- Auto-installing docling without consent — surprise side effects.
- Loading the entire fetched corpus into the LLM context — classify
  in Phase 2, then delegate; do not retain bulk text in working
  memory.
- Returning before `/yoke:preserve` finishes — caller assumes
  ingestion completed.
- Creating `code` entities — graphify integration is anti-scope; the
  9th type returns in a future sprint.

## See also

- `concepts/yoke-pattern-memory-model` — `/yoke:preserve` is the
  single write entry; `/yoke:teach` routes through it.
- `concepts/yoke-pattern-model-c-governance` — impact-class routing
  applies to teach-driven writes too.
- `skills/confluence-to-markdown/SKILL.md` — Confluence adapter
  (3-layer fallback: MCP → REST → browser DOM).
- `skills/gdoc-to-markdown/SKILL.md` — GDoc / Sheets adapter.
- `lib/canonical-memory/resolve-memory.sh` — Phase 0 resolution.
- `entities/{type}.md` — classification rules.
