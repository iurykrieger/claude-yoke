# Sprint 05 of 06: Bedrock canonical-memory port

> Migrated from: # Spec: Bedrock canonical-memory port — Part 5: `/yoke:teach` + Confluence/GDoc helpers


> Generated via /vibeflow:gen-spec on 2026-04-25
> Source PRD: `.vibeflow/prds/bedrock-canonical-memory-port.md`

## Objective

Ship `/yoke:teach` for ingesting external sources into canonical
memory, copied verbatim from bedrock 1.2.1 — including the
`confluence-to-markdown` and `gdoc-to-markdown` helpers, Atlassian and
GitHub MCP integration, and docling local-file support.

## Context

Yoke today has no ingestion path — canonical memory only grows via
canonization at runtime termination (Part 4). Per PRD resolution,
`/yoke:teach` is copied verbatim from bedrock 1.2.1, dragging in its
full adapter surface so users can ingest Confluence pages, Google
Docs/Sheets, GitHub repos, remote URLs, and local files (DOCX, PPTX,
XLSX, PDF, HTML, EPUB, images, Markdown). Ingestion produces structured
entity input that flows through `/yoke:preserve` (Part 4).

## Definition of Done

1. `skills/teach/SKILL.md` ships, copied verbatim from bedrock 1.2.1
   with namespace renames (`/bedrock:*` → `/yoke:*`, vault → memory)
   and `--memory` flag wiring (matching the Part 1 resolution lib).
2. `skills/confluence-to-markdown/SKILL.md` and
   `skills/gdoc-to-markdown/SKILL.md` ship as internal helper skills,
   copied verbatim from bedrock 1.2.1. Both keep bedrock's adapter
   chain — Atlassian MCP / GDoc API preferred, REST/basic-auth
   fallback, browser DOM extraction last resort.
3. `/yoke:teach <url-or-path>` ingests the source, classifies extracted
   content into the 8 entity types using `entities/{type}.md` (Part 1),
   then delegates to `/yoke:preserve` (Part 4) for the actual write.
   The user sees one confirmation gate (preserve's Phase 3 with
   Model C routing), not two.
4. Local-file ingestion via docling works against an explicit path or
   directory: `/yoke:teach ./roadmap.docx`,
   `/yoke:teach ./reports/*.pdf`. Supported formats: DOCX, PPTX,
   XLSX, PDF, HTML, EPUB, images (PNG/JPG), Markdown.
5. **Quality gate:** lineage entry in `docs/lineage.md` lists all
   three skills (`teach`, `confluence-to-markdown`,
   `gdoc-to-markdown`) with bedrock 1.2.1 as origin. Smoke test
   `tests/smoke/teach-ingest.test.sh` ingests one local Markdown file
   and one remote public GitHub README end-to-end without human
   intervention (auto-confirms in test mode); wraps with `timeout 600`
   per pre-Sprint-6 conventions.

## Scope

- 3 skills (`teach`, `confluence-to-markdown`, `gdoc-to-markdown`).
- Lineage update in `docs/lineage.md`.
- Smoke test for file + URL ingestion.
- `docs/installation.md` updated to document the optional MCP servers
  (Atlassian, GitHub) and docling install.

## Anti-scope

- No `/yoke:sync` (deferred — bedrock's people/PR sync from GitHub
  is out of scope per PRD).
- No new entity types beyond the 8 from Part 1.
- No write logic — that lives in `/yoke:preserve` (Part 4). `/teach`
  builds structured input and hands off; it does not commit.
- No automatic scheduling of `/yoke:teach` runs — users invoke
  manually or via `/loop`/`/schedule` skills outside this work.
- No bedrock plugin → Yoke continuous port. Future bedrock changes
  are explicit decisions, not auto-synced.

## Technical Decisions

- **Verbatim copy from bedrock 1.2.1.** Per PRD resolution, no
  adaptation beyond namespace renames. Future divergence is acceptable
  per `.vibeflow/decisions.md` ("embedded skills, no continuous port").
- **MCP servers optional, not required.** Atlassian MCP enables
  Confluence ingestion; GitHub MCP enables repository ingestion;
  without either, the helpers fall through to REST then DOM
  extraction. Failure modes are documented in `docs/installation.md`.
- **docling is a runtime dependency for local-file ingestion only.**
  Lazy-imported inside the helper — no docling install required for
  URL-only ingestion. Documented in `docs/installation.md`.
- **`--memory` flag wiring.** All three skills accept `--memory <name>`
  to target a non-default memory; resolution uses Part 1's lib.

## Applicable Patterns

- `.vibeflow/patterns/memory-model.md` — `/yoke:teach` is a write path
  that routes through `/yoke:preserve`, preserving the
  single-write-point invariant from Part 4.
- `.vibeflow/patterns/model-c-governance.md` — every entity ingested
  via `/teach` goes through preserve's Phase 3 Model C routing.
  Ingested content is most often `low` impact (template-refinement-class)
  but the user can override via the entity's `impact_level`
  frontmatter.

## Risks

- **R-5.1 — MCP unavailability.** Atlassian/GitHub MCP not installed
  → ingestion falls back to REST/DOM, which may need credentials.
  *Mitigation:* bedrock's existing fallback chain is preserved
  verbatim; `docs/installation.md` documents auth requirements per
  fallback level.
- **R-5.2 — docling install footprint.** docling pulls heavy ML
  dependencies. *Mitigation:* lazy-import — only invoked when
  local-file ingestion is requested. Document expected install size
  in `docs/installation.md`.
- **R-5.3 — Bedrock helper drift.** The helpers reference bedrock's
  internal `entities/*.md`; once copied to Yoke, they reference
  Yoke's `entities/*.md` instead. *Mitigation:* renames during copy
  (Part 5 task) point at `<base_dir>/../../entities/`, which resolves
  to the Yoke plugin root after copy — bedrock's path discipline
  carries over without code changes.

## Dependencies

- `.vibeflow/specs/bedrock-canonical-memory-port-part-1.md`
- `.vibeflow/specs/bedrock-canonical-memory-port-part-4.md`
