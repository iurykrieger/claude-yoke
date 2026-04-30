---
name: canonize
description: >
  Provider-agnostic facade for the canonical-memory write hand-off. When
  /yoke:implement terminates and the working memory under .yoke/
  carries the freshest signal the framework will ever have, this skill
  is the single verb that hands the directory to the configured
  canonical-memory provider. Resolves the provider via
  lib/canonical-memory/resolve-provider.sh, dispatches to the provider's
  pinned canonize skill (currently /yoke:teach while Bedrock is the
  in-Yoke seed; rewires to /bedrock:canonize in Sprint 2), and appends
  a single canonize: line to .yoke/runtime/progress.md. Never bundles,
  summarizes, or pre-processes the working memory; never classifies
  maturity (provider judgment); never silently swallows the provider's
  exit code.
  Use when: "canonize", "yoke canonize", "/yoke:canonize", "save working
  memory to canonical memory", or whenever /yoke:implement terminates.
argument-hint: ""
allowed-tools: Bash, Skill
---

# /yoke:canonize — provider-agnostic working-memory hand-off

You are a **dispatcher**. You do not bundle, summarize, classify, or
pre-process the working memory under `.yoke/`. You hand the
configured provider an absolute path and a single argument verb, then
log a one-line `canonize:` entry and propagate the provider's exit
code.

This facade is the single write entry point that every Yoke caller
will be rewritten toward (Sprint 2 task s02-t05). In Sprint 1 the
legacy `/yoke:preserve` continues to work and this facade is purely
additive.

## Plugin paths

- Working-memory helpers: `<plugin_dir>/lib/working-memory/paths.sh`
- Provider resolver: `<plugin_dir>/lib/canonical-memory/resolve-provider.sh`
- Provider registry: `<plugin_dir>/providers.yaml`

`<plugin_dir>` is the parent of `skills/`. Use the "Base directory for
this skill" provided at invocation to resolve.

## Pre-conditions

1. The current working directory contains a `.yoke/` directory. Without
   it, there is no working memory to hand off.
2. `.yoke/config.yaml` exists and sets `canonical_memory.provider:`.
3. The named provider is registered in the plugin's `providers.yaml`.

Conditions 2 and 3 are enforced by `yoke_resolve_provider`'s exit
codes 3, 4, 5 (surfaced verbatim, not retried).

## Phase 0 — Validate working memory is present

Enforce the v2.0.0 hard break first — if `.yoke/config.yaml` is missing
or lacks `canonical_memory.provider`, abort before resolving anything.
The helper writes the documented stderr message
(`wm: canonical_memory.provider not configured. Run /yoke:bootstrap to
migrate.`) on the unmigrated-v1.x path. See Acceptance Contract
Scenario 12 / FR-6.

```bash
source <plugin_dir>/lib/yoke-prelude.sh && yoke_require_provider || exit 1
source <plugin_dir>/lib/working-memory/paths.sh
if [ ! -d "$PWD/.yoke" ]; then
  echo "wm: .yoke/ not found in \$PWD. Run /yoke:bootstrap or /yoke:discover first." >&2
  exit 1
fi
```

No arguments are accepted at v2.0.0. If `$ARGUMENTS` is non-empty,
abort with:

```text
wm: /yoke:canonize takes no arguments at v2.0.0
```

## Phase 1 — Resolve absolute path of `.yoke/`

The provider expects an **absolute** path. Resolve via `cd && pwd`:

```bash
wm_path="$(cd "$PWD/.yoke" && pwd)"
```

`$wm_path` is the only path passed to the provider. Never pass a
relative path; never pass any path other than the resolved
`.yoke/` directory.

## Phase 2 — Resolve the provider

```bash
source <plugin_dir>/lib/canonical-memory/resolve-provider.sh
yoke_resolve_provider
```

`yoke_resolve_provider` exit codes — surface verbatim, do **not** retry:

| Exit | Meaning | Behavior |
|---|---|---|
| 0 | Resolved | Continue to Phase 3 |
| 3 | `.yoke/config.yaml` missing | Surface the resolver's stderr; exit non-zero |
| 4 | `canonical_memory.provider` key missing | Surface the resolver's stderr; exit non-zero |
| 5 | Provider name unknown to `providers.yaml` | Surface the resolver's stderr; exit non-zero |

After exit 0:

- `$YOKE_PROVIDER_NAME` — the resolved provider's name
- `$YOKE_PROVIDER_CANONIZE_SKILL` — `<plugin>:<skill>` to dispatch to
  (the canonize verb)
- `$YOKE_PROVIDER_SEARCH_SKILL` — set but unused in this facade
- `$YOKE_PROVIDER_CONFIG_PASSTHROUGH` — newline-separated keys; the
  facade does not interpret them. The provider may read them directly
  from `.yoke/config.yaml` per the working-memory provider contract.

## Phase 3 — Dispatch to the provider's canonize skill

Invoke the provider's pinned canonize skill with the resolved
absolute working-memory path:

```text
Skill(skill: "${YOKE_PROVIDER_CANONIZE_SKILL}", args: "--working-memory ${wm_path}")
```

In the seed configuration (`provider: bedrock`),
`$YOKE_PROVIDER_CANONIZE_SKILL == "yoke:teach"`, so this resolves to:

```text
Skill(skill: "yoke:teach", args: "--working-memory <abs-path-to-.yoke>")
```

Capture the provider's stdout. Capture the provider's exit code in
`$provider_rc`.

## Phase 4 — Append a canonize: line to runtime/progress.md

Append a single line beginning `canonize:` to
`.yoke/runtime/progress.md` summarizing the dispatch. The line is a
soft convention (per `docs/canonical-memory-provider-contract.md`'s
"Soft exit-summary convention" section); the provider's stdout MAY
include a structured summary line which the facade forwards verbatim.

```bash
progress="$wm_path/runtime/progress.md"
mkdir -p "$wm_path/runtime"
[ -f "$progress" ] || printf '# Progress\n\n' > "$progress"

# If the provider emitted an exit-summary line on stdout, prefer that
# (it's the authoritative count). Otherwise emit a minimal record.
summary_line="$(printf '%s\n' "${provider_stdout:-}" | grep -E '^canonize:' | tail -n 1 || true)"
if [ -z "$summary_line" ]; then
  summary_line="canonize: provider=${YOKE_PROVIDER_NAME} working_memory=${wm_path} exit=${provider_rc}"
fi
printf '%s\n' "$summary_line" >> "$progress"
```

The line is the **only** write this facade performs. The contents of
`.yoke/` are otherwise read-only from the facade's perspective.

## Phase 5 — Propagate the provider's exit code

```bash
exit "$provider_rc"
```

Never zero out a non-zero provider exit. Never translate provider
exit codes into a normalized scheme. The caller (the runtime
Orchestrator subagent in canonize mode) reads the exit code as
authoritative.

## Critical rules

| # | Rule |
|---|---|
| 1 | NEVER bundle, summarize, classify, or pre-process the working memory. The provider owns those decisions. |
| 2 | NEVER pass a relative path. Always resolve to absolute via `cd && pwd`. |
| 3 | NEVER pass any path other than the resolved `.yoke/` directory. |
| 4 | NEVER swallow the provider's exit code. Propagate it verbatim. |
| 5 | NEVER write inside `.yoke/` except for the single `canonize:` line appended to `runtime/progress.md`. |
| 6 | NEVER fall back to the legacy `/yoke:preserve` when the resolver fails. Surface exit codes 3/4/5 verbatim. |
| 7 | NEVER invoke the legacy `/yoke:teach` directly. Always dispatch through `$YOKE_PROVIDER_CANONIZE_SKILL`. |
| 8 | NEVER read or write outside the working memory: provider's responsibility. |

## Anti-patterns

- Reading `.yoke/specs/`, `.yoke/sprints/`, `.yoke/contracts/`,
  `.yoke/runtime/` to "decide what's canonization-worthy" before
  invoking the provider. The provider judges; the facade dispatches.
- Pre-bundling `.yoke/` into a tarball or single document. The
  provider expects a directory tree.
- Branching the dispatch logic on `$YOKE_PROVIDER_NAME`. The whole
  point of the facade is that providers are interchangeable.
- Logging the provider's full stdout to `runtime/progress.md`. Only
  the soft `canonize:` summary line is recorded.

## See also

- `docs/canonical-memory-provider-contract.md` — the working-memory
  contract every provider implements (`contract_version: 1`).
- `concepts/yoke-pattern-memory-model` — the write-mediator role.
- `lib/canonical-memory/resolve-provider.sh` — provider resolution.
- `providers.yaml` — curated provider registry.
- Acceptance Contract Scenario 4 / FR-1 / FR-4.
- Sprint 1 task `2026-04-30-pluggable-canonical-memory-s01-t04`.
