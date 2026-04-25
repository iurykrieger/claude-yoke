---
name: ask
description: >
  Read-only canonical-memory query. Calls lib/canonical-memory/query.sh
  directly and writes the query, result count, and invoker to
  .yoke/query-trace.md for audit and bypass detection. Returns matching
  entries (text grep in v0.5.0; subgraph traversal in Sprint 6).
  Spec-phase skills (`/yoke:discover`, `/yoke:tech-spec`,
  `/yoke:acceptance-contract`) and the runtime Orchestrator subagent
  must use this skill — never read the canonical-memory repo directly.
argument-hint: "<term>"
allowed-tools: Bash, Read, Write
---

# /yoke:ask — canonical-memory query (thin skill, v1.1.0)

Read-only access to canonical memory. **Spec-phase skills must use
this skill — never read the canonical-memory repo directly.**

> **v1.1.0 refresh.** Earlier versions routed this skill through the
> Orchestrator-skill in mediator mode. With Orchestrator promoted to a
> runtime subagent (consult mode handles canonical-memory reads during
> the loop), `/yoke:ask` becomes a thin direct-call skill: it invokes
> `lib/canonical-memory/query.sh` and writes the query trace itself.
> The "Orchestrator skill in mediator mode" concept is retired.

## Pre-conditions

- `.yoke/config.yaml` exists with a populated `canonical_memory.url`.
- The canonical-memory repo exists at the URL.

## Process

### 1. Trace mode declaration

Print on stdout (also written to `.yoke/query-trace.md`):

```
[ask] query="<term>" subgraph_depth=1
```

Subgraph depth in v1.1.0 is implicitly 1 (no graph traversal yet —
text grep only). Sprint 6 makes this configurable.

### 2. Locate canonical memory

- Read `canonical_memory.url` from `.yoke/config.yaml`.
- If empty: emit `"Canonical memory not configured."` and exit 0.
  Append a `[ask] not-configured` line to the trace.
- Clone or update the cached repo at
  `~/.cache/yoke/canonical/<slug>/`.

### 3. Run text grep with deterministic trace writing

Invoke
`lib/canonical-memory/query.sh --trace .yoke/query-trace.md --invoker "<calling-skill-or-agent>" "<term>"`.

The script:

- Performs the text grep over the canonical repo (≤ 20 matches).
- Writes a YAML trace entry to `.yoke/query-trace.md` capturing
  timestamp, mode, query, match count, capping flag, and invoker.
- Returns matches as `<file>:<line>:<excerpt>`.

If `.yoke/query-trace.md` doesn't exist, the script initializes it
with a `# Query trace` header.

### 4. Empty-state UX

- Canonical memory empty (no `*.md` files): return
  > "Canonical memory has no entries yet. `/yoke:canonize` will populate
  > it as tasks complete."
  Trace entry still written (matches: 0, notes: "empty-memory").
- Canonical memory has entries but no matches: return
  > "No matches for `<term>` across N entries."
  Trace entry written.

### 5. Output

- Print matches in the format `- <file>:<line> — <excerpt>` (one per
  line).
- Cap output at 20 matches by default. Append a truncation note if
  more.

## Detecting bypass attempts

Every legitimate canonical-memory read writes a trace entry to
`.yoke/query-trace.md`. Absence of a trace entry for a claimed read
is the bypass signal:

- If a spec-phase skill or the Orchestrator subagent claims to have
  consulted canonical memory but no `[ask]` or
  `[orchestrator:consult]` trace entry exists for that query, that
  is a bypass.
- A future audit hook (Sprint 8) will scan the trace for
  inconsistencies.

## Anti-patterns

- Do NOT skip the trace write. Trace absence is how bypass is
  detected.
- Do NOT load the entire canonical memory into context. The grep is
  bounded; results are capped at 20.
- Do NOT bypass `/yoke:ask` to read the substrate directly. That
  violates `.vibeflow/conventions.md` and triggers a `bypass: true`
  flag in audits.

## See also

- `.vibeflow/patterns/memory-model.md`.
- `.vibeflow/patterns/model-c-governance.md`.
- `agents/orchestrator.md` — runtime canonical-memory access (consult
  mode).
- `lib/canonical-memory/query.sh`.
