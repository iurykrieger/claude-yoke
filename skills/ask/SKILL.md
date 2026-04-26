---
name: ask
description: >
  Source-agnostic read against the registered canonical memory. Resolves
  the active memory via lib/canonical-memory/resolve-memory.sh (--memory
  flag → CWD detection → default), then reads the local filesystem
  directly — never `git clone`, never `git pull`, never `git fetch`.
  Classifies the question, globs/greps entity files, follows wikilinks
  one level, sorts by recency, composes the response. Caps total entity
  reads at 15. Pure read — writes nothing on disk and does not depend on
  any active task.
argument-hint: "[--memory <name>] <question>"
allowed-tools: Bash, Read, Glob, Grep
---

# /yoke:ask — Canonical-memory adaptive reader

You are a **read-only adaptive context orchestrator**. You do not write,
edit, or delete files anywhere — not inside the canonical memory, not in
the host project's `.yoke/`, not on the plugin. The skill is a pure read.

`/yoke:ask` is callable from any source: the runtime Generator, Validator
and Orchestrator subagents; the spec-phase skills (`/yoke:discover`,
`/yoke:tech-spec`, `/yoke:acceptance-contract`); and ad-hoc human queries.
There is no active-task pre-condition.

If a query reveals outdated or missing information, suggest
`/yoke:teach <url>` or `/yoke:preserve` — never attempt the write yourself.

## Plugin paths

Entity definitions live in the plugin directory, not in any memory:

- Entity definitions: `<plugin_dir>/entities/{actor,person,team,concept,topic,discussion,project,fleeting}.md`
- Templates: `<plugin_dir>/templates/canonical/{type}/_template.md`

`<plugin_dir>` is the parent of `skills/`. Use the "Base directory for
this skill" provided at invocation to resolve.

## Pre-conditions

- A canonical memory is registered in `<plugin_dir>/memories.json`. If
  not, abort with:
  *"No memory registered. Run /yoke:memory add <path> or re-run /yoke:bootstrap."*

There is no other pre-condition. The skill is independent of host-project
working-memory state and is callable from any directory.

## Phase 0 — Resolve the active memory

```bash
source <plugin_dir>/lib/canonical-memory/resolve-memory.sh
yoke_resolve_memory --memory "$EXPLICIT_NAME"   # or no flag
```

After this returns 0:

- `$YOKE_MEMORY_NAME` — the resolved memory's name
- `$YOKE_MEMORY_PATH` — the absolute path on disk

Exit codes:

- `3` — registry missing → emit the "no memory registered" message and exit 0
- `5` — no resolution (registry empty / CWD outside / no default) →
  print the registry listing per the resolver, exit 0
- `0` — resolved → continue

`MEMORY_PATH=$YOKE_MEMORY_PATH` is the **only** path used below. No
`git clone`, no `git pull`, no `git fetch`.

### Read per-memory config (optional)

```bash
cat "$MEMORY_PATH/.yoke-memory/config.json" 2>/dev/null
```

Extract `language` and other relevant fields. If the file is absent,
defaults apply.

## Phase 1 — Classify the question

For the user's question, identify:

1. **Mentioned entities** — names of systems, people, teams, topics,
   projects, concepts, discussions. May appear as exact filename, human-readable
   name, alias, or contextual reference.
2. **Relevant domain(s)** — payments / notifications / orders / etc.
   when inferrable.
3. **Type of information sought:**
   - status / overview ("what is X?", "status of X")
   - architecture / stack ("how does X work?")
   - people / teams ("who owns X?")
   - history / decisions ("what was decided about X?")
   - relationships ("what depends on X?")
   - deprecation ("what is being deprecated?")

If the question is too ambiguous to produce a targeted search
("tell me everything", "how does the system work?"), ask once for
clarification:

> "Your question is broad. Can you specify a system, team, or topic?"

If the question is clearly outside the canonical memory's scope (something
personal, unrelated tech), reply: "I didn't find anything in the canonical
memory about this."

Output of Phase 1 — store as variables:

- `search_terms`: list of names/aliases/keywords
- `domains`: list of relevant domains (may be empty)
- `info_type`: classification
- `explicit_entities`: directly mentioned entities

## Phase 2 — Filesystem-first search

This phase always runs. Direct reads against `$MEMORY_PATH`. **Never**
load full directories; targeted Glob/Grep then read.

### 2.1 Read relevant entity definitions

Read only the definitions matching the question:

- system / API → `<plugin_dir>/entities/actor.md`
- person → `<plugin_dir>/entities/person.md`
- team → `<plugin_dir>/entities/team.md`
- topic / deprecation → `<plugin_dir>/entities/topic.md`
- meeting / decision → `<plugin_dir>/entities/discussion.md`
- project / initiative → `<plugin_dir>/entities/project.md`
- pattern / principle / protocol → `<plugin_dir>/entities/concept.md`
- raw / vague mention → `<plugin_dir>/entities/fleeting.md`

If unsure, read `concept.md` and `topic.md` first (most general).

### 2.2 Search entities by name and alias

For each search term:

1. **Filename match (Glob):**
   ```
   $MEMORY_PATH/actors/<term>*.md
   $MEMORY_PATH/people/<term>*.md
   $MEMORY_PATH/teams/<term>*.md
   $MEMORY_PATH/concepts/<term>*.md
   $MEMORY_PATH/topics/*<term>*.md
   $MEMORY_PATH/discussions/*<term>*.md
   $MEMORY_PATH/projects/<term>*.md
   $MEMORY_PATH/fleeting/*<term>*.md
   ```
2. **Alias frontmatter match (Grep, case-insensitive):**
   `pattern="aliases:.*<term>"` in those directories.
3. **Name / title frontmatter match (Grep, case-insensitive):**
   `pattern="(name|title):.*<term>"`.
4. **Body fallback (Grep, case-insensitive):** if 1–3 didn't return enough.

### 2.3 Filter by domain (when known)

`Grep: pattern="domain/<domain>"` against the matched files. Keep all
results but rank domain-matching ones first.

### 2.4 Read found entities

For each entity found (limit: 15 entities total across 2.4 + 2.5):

1. Read frontmatter first (~first 30 lines) to confirm relevance.
2. If relevant: read the full file.
3. If not: discard (false positive from Grep).

Record per entity: filename, type, name, wikilinks (frontmatter and
body), external URLs in body, explicit date in filename.

### 2.5 Follow wikilinks (1 level)

For each wikilink relevant to the question:

```
Glob: $MEMORY_PATH/actors/<name>.md, $MEMORY_PATH/people/<name>.md, ...
```

Read the matched file (frontmatter + body). **Do not follow wikilinks
from the second-level entity** — stop here to avoid context explosion.

Relevance criteria for follow:

- relationships question → follow all
- status / overview → follow team, people (focal points)
- history → follow related discussions, topics
- architecture → follow dependent actors

Total entity reads (2.4 + 2.5) **must not exceed 15**. If the limit is
reached, prioritize entities directly mentioned in the question.

## Phase 3 — Self-assessment + escalation hints

After Phase 2, evaluate:

- **`vault_sufficient`** — entities directly answer the question. Skip
  to Phase 4.
- **`needs_remote_content`** — relevant entities reference external
  URLs (Confluence, GDoc, GitHub) not yet ingested. Suggest
  `/yoke:teach <url>` in the response (Phase 5). **Do not** invoke
  `/yoke:teach` automatically — the v0 skill does not escalate.
- **`needs_graphify`** — emit a `> [!warning]` callout (graphify is not
  available in v0; graphify pipeline lands in a future sprint).
  Continue with vault-only content.

Priority when multiple apply: `needs_remote_content` >
`needs_graphify` > `vault_sufficient`.

## Phase 4 — Recency

For discussions and topics, extract the date from the filename:

- `YYYY-MM-DD-slug.md` → full date
- `YYYY-MM-slug.md` → assume day 01

For consolidated entities (actors, people, teams, projects, concepts):
treat as up-to-date — no temporal ranking.

When the response involves multiple dated entities, sort descending
(most recent first). For "what happened lately" / "latest decisions",
limit to the last 30 days.

## Phase 5 — Compose response

1. **Language:** the memory's configured language (from
   `.yoke-memory/config.json`); technical terms in English are accepted
   regardless.
2. **Structure:** open with a direct answer (1-3 sentences). Expand by
   topic if needed. Headers (`##`, `###`) only if response > 5 paragraphs.
   Tables for comparative / inventory information.
3. **Entity citations:** bare wikilinks (`[[name]]`, never `[[dir/name]]`).
   Group at the end if many; inline when natural.
4. **Escalation transparency:**
   - If `needs_remote_content`: "I found references to external URLs —
     run `/yoke:teach <url>` to ingest them."
   - If `needs_graphify`: emit the `> [!warning]` callout.
   - Vault-only: no special note.
5. **Nothing found:** "I didn't find information about [X] in the
   canonical memory." Suggest `/yoke:teach <url>` if relevant URLs are
   known. **NEVER fabricate.**
6. **Weight by Zettelkasten role:**
   - permanent (actors, people, teams, concepts) — highest weight.
   - bridge (topics, discussions) — high weight; most recent first.
   - index (projects) — medium weight; point to detail sources.
   - fleeting — lowest weight; **always** flag with
     `(source: fleeting note — unconsolidated)`.
7. **Fleeting promotion detection:** if a fleeting note is referenced
   and meets promotion criteria from `entities/fleeting.md`, append:
   `> [!info] Promotion suggested: [[fleeting-note-name]] can be
   promoted to permanent/bridge` (does not promote automatically).

## Critical rules

| # | Rule |
|---|---|
| 1 | NEVER `git clone`, `git pull`, or `git fetch` against the registered memory. Reads are filesystem-only. |
| 2 | NEVER write inside the registered memory — `/ask` is read-only against canonical memory. |
| 3 | NEVER write anywhere on disk — `/ask` is a pure read; the skill produces only the conversational response. |
| 4 | NEVER load full canonical memory into context — cap at 15 entities total. |
| 5 | ALWAYS use bare wikilinks (`[[name]]`, never `[[dir/name]]`). |
| 6 | ALWAYS resolve `MEMORY_PATH` via `lib/canonical-memory/resolve-memory.sh` — never assume CWD is the memory. |
| 7 | NEVER fabricate information not found in the memory. |
| 8 | Fleeting notes ALWAYS carry the `(source: fleeting note — unconsolidated)` disclaimer. |
| 9 | Self-assessment outcomes route through Phase 5 messaging only — `/teach` and graphify are NOT invoked from this skill in v0. |
| 10 | NEVER require an active task. The skill is source-agnostic and works regardless of host-project working-memory state. |

## Anti-patterns

- Cloning or pulling the substrate on read.
- Following more than 1 wikilink hop — context explosion.
- Returning more than 15 entity reads — context budget violation.
- Inventing facts to fill gaps — fabrication.
- Aborting because no active task is set — `/yoke:ask` is source-agnostic.
- Writing any file as a side-effect of the read — the skill is pure.

## See also

- `.vibeflow/patterns/memory-model.md` — the read-mediator role.
- `.vibeflow/patterns/roles.md` — the canonical-memory read contract.
- `lib/canonical-memory/resolve-memory.sh` — memory resolution.
