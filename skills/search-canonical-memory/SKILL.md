---
name: search-canonical-memory
description: >
  Provider-agnostic facade for reading the active canonical memory.
  Resolves the configured provider via
  lib/canonical-memory/resolve-provider.sh, then dispatches the user's
  query to the provider's pinned search skill (e.g. /bedrock:ask for
  the bedrock provider) per providers.yaml. Pure read — never writes,
  never caches, never reformats. Source-agnostic: callable from any
  host project regardless of active-task state.
  Use when: "search canonical memory", "ask the vault",
  "/yoke:search-canonical-memory", or whenever a Yoke caller needs a
  read against the configured canonical-memory provider.
argument-hint: "<query>"
allowed-tools: Bash, Skill
---

# /yoke:search-canonical-memory — provider-agnostic canonical-memory read

You are a **dispatcher**. You do not interpret the query, do not parse
the response, do not cache, and do not write any file anywhere. The
skill resolves the configured provider, hands the query off, and
returns the provider's response verbatim.

This facade is the read entry point for every Yoke caller — council
persona subagents (`agents/sr-eng.md`, `agents/sr-qa.md`,
`agents/sr-staff.md`), spec-phase skills, the canonize-only
Orchestrator. There is no legacy direct-read path: the v1.x
`/yoke:ask` skill was retired with the v2.0.0 facade extraction and
the substrate-specific reader now lives inside the active provider
plugin (e.g. `/bedrock:ask` for the bedrock provider).

## Plugin paths

- Working-memory helpers: `<plugin_dir>/lib/working-memory/paths.sh`
- Provider resolver: `<plugin_dir>/lib/canonical-memory/resolve-provider.sh`
- Provider registry: `<plugin_dir>/providers.yaml`

`<plugin_dir>` is the parent of `skills/`. Use the "Base directory for
this skill" provided at invocation to resolve.

## Pre-conditions

There is **no** active-task pre-condition. Canonical-memory queries
are source-agnostic per `concepts/yoke-pattern-memory-model`; the
skill is callable from any host project's working directory.

The required pre-conditions are:

1. The host project has a `.yoke/config.yaml` (created by
   `/yoke:bootstrap`).
2. That config sets `canonical_memory.provider:` to a provider name
   present in the plugin's `providers.yaml`.

Both are enforced by the resolver — non-zero exit codes from
`yoke_resolve_provider` are surfaced verbatim, not retried.

## Phase 0 — Validate input

Read the user-supplied query argument from `$ARGUMENTS` (the entire
positional argument string). If the trimmed query is empty:

```text
wm: query is required
```

Print that literal string to stderr and abort non-zero. Do not invoke
the resolver, do not call any other skill.

## Phase 1 — Resolve the provider

Enforce the v2.0.0 hard break first — if `.yoke/config.yaml` is missing
or lacks `canonical_memory.provider`, abort before invoking the
resolver. The helper writes the documented stderr message
(`wm: canonical_memory.provider not configured. Run /yoke:bootstrap to
migrate.`) on the unmigrated-v1.x path. See Acceptance Contract
Scenario 12 / FR-6.

```bash
source <plugin_dir>/lib/yoke-prelude.sh && yoke_require_provider || exit 1
source <plugin_dir>/lib/working-memory/paths.sh
source <plugin_dir>/lib/canonical-memory/resolve-provider.sh
yoke_resolve_provider
```

`yoke_resolve_provider` exit codes — surface verbatim, do **not** retry:

| Exit | Meaning | Behavior |
|---|---|---|
| 0 | Resolved | Continue to Phase 2 |
| 3 | `.yoke/config.yaml` missing | Surface the resolver's stderr; exit non-zero |
| 4 | `canonical_memory.provider` key missing | Surface the resolver's stderr; exit non-zero |
| 5 | Provider name unknown to `providers.yaml` | Surface the resolver's stderr; exit non-zero |

After exit 0:

- `$YOKE_PROVIDER_NAME` — the resolved provider's name
- `$YOKE_PROVIDER_SEARCH_SKILL` — `<plugin>:<skill>` to dispatch to (the
  read verb)
- `$YOKE_PROVIDER_CANONIZE_SKILL` — set but unused in this facade
- `$YOKE_PROVIDER_CONFIG_PASSTHROUGH` — newline-separated keys from
  `canonical_memory.*` that the provider expects opaquely; the
  facade does not interpret them

## Phase 2 — Dispatch to the provider's search skill

Invoke the provider's pinned search skill **verbatim with the user
query as the argument**:

```text
Skill(skill: "${YOKE_PROVIDER_SEARCH_SKILL}", args: "<query>")
```

In the seed configuration (`provider: bedrock`),
`$YOKE_PROVIDER_SEARCH_SKILL == "bedrock:ask"` per `providers.yaml`,
so this resolves to:

```text
Skill(skill: "bedrock:ask", args: "<query>")
```

Return the provider's response **byte-for-byte** to the caller. Do not
prepend, append, summarize, parse, or transform.

If the provider skill exits non-zero, propagate the exit code and the
provider's stderr unchanged.

## Critical rules

| # | Rule |
|---|---|
| 1 | NEVER write any file as a side-effect. The facade is a pure read. |
| 2 | NEVER reformat, summarize, or post-process the provider response. The contract is byte-equivalence with the underlying read skill. |
| 3 | NEVER cache the response. Each invocation re-dispatches. |
| 4 | NEVER fall back to a hard-coded provider when the resolver fails. Surface exit codes 3/4/5 verbatim. |
| 5 | NEVER require an active task — the skill is source-agnostic. |
| 6 | NEVER invoke the provider's read skill (e.g. `/bedrock:ask`) directly. Always dispatch through `$YOKE_PROVIDER_SEARCH_SKILL` so providers stay swappable via `providers.yaml`. |
| 7 | NEVER `git clone`, `git pull`, or `git fetch` against the canonical memory; that's the provider's responsibility (and the provider's skill enforces it). |

## Anti-patterns

- Trimming whitespace or normalizing the query before dispatch (the
  provider owns query handling).
- Detecting the provider name and branching the dispatch logic by
  hand. The whole point of the facade is that providers are
  interchangeable — branching defeats the abstraction.
- Falling through to a hard-coded provider read skill when
  `yoke_resolve_provider` exits 4 or 5. The resolver's exit code is
  the user's signal to run `/yoke:bootstrap`; silently falling
  through hides the misconfiguration.
- Writing a `search:` log line to `.yoke/runtime/progress.md`. Reads
  are not loggable working-memory events.

## See also

- `concepts/yoke-pattern-memory-model` — the read-mediator role.
- `lib/canonical-memory/resolve-provider.sh` — provider resolution.
- `providers.yaml` — curated provider registry.
- Acceptance Contract Scenario 3 / FR-1.
- Sprint 1 task `2026-04-30-pluggable-canonical-memory-s01-t03`.
