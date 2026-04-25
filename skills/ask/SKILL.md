---
name: ask
description: >
  Mediated query against canonical memory (Orchestrator skill in Mediator
  mode). Every query writes to `.yoke/query-trace.md` for audit and future
  canonization signal. Returns matching entries (text grep in v0.5.0;
  subgraph traversal in Sprint 6). Generator and Validator subagents must
  use this skill — never read the canonical-memory repo directly.
argument-hint: "<term>"
allowed-tools: Bash, Read, Write
---

# /yoke:ask — mediated canonical-memory query (v0.5.0)

Read-only access to canonical memory, mediated by the Orchestrator skill
in Mediator mode. **Generator and Validator must use this skill — never
read the canonical-memory repo directly.**

> **Sprint-5 amendment.** Sprint 2 shipped a basic text-grep version of
> this skill that wrote nothing to working memory. Sprint 5 routes the
> read through the Orchestrator (Mediator mode) and writes a query trace
> to `.yoke/query-trace.md`. Sprint 6 will add subgraph traversal
> (progressive disclosure).

## Pre-conditions

- `.yoke/config.yaml` exists with a populated `canonical_memory.url`.
- The canonical-memory repo exists at the URL.

## Process

### 1. Mode declaration

Print on stdout (also written to `.yoke/query-trace.md`):

```
[orchestrator:mediator] query="<term>" subgraph_depth=1
```

Subgraph depth in v0.5.0 is implicitly 1 (no graph traversal yet — text
grep only). Sprint 6 makes this configurable.

### 2. Locate canonical memory

- Read `canonical_memory.url` from `.yoke/config.yaml`.
- If empty: emit `"Canonical memory not configured."` and exit 0.
  Append a `[orchestrator:mediator] not-configured` line to the trace.
- Clone or update the cached repo at `~/.cache/yoke/canonical/<slug>/`.

### 3. Run text grep with deterministic trace writing

Invoke
`lib/canonical-memory/query.sh --trace .yoke/query-trace.md --invoker "<calling-skill-or-agent>" "<term>"`.

The script:

- Performs the text grep over the canonical repo (≤ 20 matches).
- Writes a YAML trace entry to `.yoke/query-trace.md` capturing
  timestamp, mode, query, match count, capping flag, and invoker.
- Returns matches as `<file>:<line>:<excerpt>`.

If `.yoke/query-trace.md` doesn't exist, the script initializes it with
a `# Query trace` header.

### 4. Empty-state UX

- Canonical memory empty (no `*.md` files): return
  > "Canonical memory has no entries yet. `/yoke:canonize` will populate
  > it as tasks complete."
  Trace entry still written (matches: 0, notes: "empty-memory").
- Canonical memory has entries but no matches: return
  > "No matches for `<term>` across N entries."
  Trace entry written.

### 5. Output

- Print matches in the format `- <file>:<line> — <excerpt>` (one per line).
- Cap output at 20 matches by default. Append a truncation note if more.

## Detecting bypass attempts

Bypass detection in v0.5.0 is conservative:

- Every legitimate query through `/yoke:ask` writes a trace entry.
- If a Generator/Validator claims to have consulted canonical memory
  but no `[orchestrator:mediator]` trace entry exists for that query,
  that is a bypass.
- A future audit hook (Sprint 8) will scan the trace for inconsistencies.

## Anti-patterns

- Do NOT skip the trace write. Trace absence is how bypass is detected.
- Do NOT load the entire canonical memory into context. The grep is
  bounded; results are capped at 20.
- Do NOT bypass `/yoke:ask` to read the substrate directly. That
  violates `.vibeflow/conventions.md` and triggers a `bypass: true`
  flag in audits.

## See also

- `.vibeflow/patterns/memory-model.md`.
- `.vibeflow/patterns/model-c-governance.md`.
- `skills/orchestrator/SKILL.md` — Mediator mode.
- `lib/canonical-memory/query.sh`.
