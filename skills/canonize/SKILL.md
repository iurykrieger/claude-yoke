---
name: canonize
description: >
  Provider-agnostic facade for the canonical-memory write hand-off. When
  /yoke:implement terminates and the working memory under .yoke/
  carries the freshest signal the framework will ever have, this skill
  is the single verb that hands the active task's diff to the configured
  canonical-memory provider. Resolves the provider via
  lib/canonical-memory/resolve-provider.sh, stages the active task's
  archive files into a fresh tmp directory (per issue #40 — historical
  PRDs / specs / sprints / acceptance documents are NOT re-fed),
  dispatches to the provider's pinned canonize skill (e.g. /bedrock:teach
  for the bedrock provider per providers.yaml), removes the stage on
  exit, and appends a single canonize: line to .yoke/runtime/progress.md.
  Never bundles, summarizes, or pre-processes inside the staged tree;
  never classifies maturity (provider judgment); never silently swallows
  the provider's exit code.
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

This facade is the single write entry point for every Yoke caller —
the canonize-only Orchestrator subagent at full-run termination, plus
manual re-canonize invocations. The legacy `/yoke:preserve` skill was
retired with the v2.0.0 facade extraction; the substrate-specific
canonize logic now lives inside the active provider plugin (e.g.
`/bedrock:teach` for the bedrock provider per `providers.yaml`).

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

## Phase 1 — Stage the active task's diff

Per issue #40, this facade does NOT hand the provider the full
`.yoke/` directory anymore. Historical PRDs, specs, sprints, and
acceptance documents from prior tasks have already been canonized in
their own runs; re-feeding them every cycle wastes provider tokens
and re-runs entity-matching against a vault that already has those
entries (concrete impact during the v4.0.0 cutover: 138 files in
`.yoke/`, only 8 fresh — re-canonization risked vault pollution and
turned a 5-minute hand-off into a 30+-minute one).

Invoke the active-task staging helper. It reads
`.yoke/runtime/.current` for the slug, copies only the slug's
archive files plus `config.yaml`/`.gitignore`/`runtime/` into a
fresh tmp directory shaped exactly like `.yoke/`, and echoes the
absolute path on stdout:

```bash
stage_dir="$(<plugin_dir>/lib/working-memory/canonize-stage.sh)"
```

Helper exit codes — surface verbatim, do NOT retry:

| Exit | Meaning |
|---|---|
| 0 | Staged; absolute path on stdout |
| 2 | Invalid args, missing `.yoke/`, or unsupported bash |
| 3 | No active slug (`.yoke/runtime/.current` missing) |

`$stage_dir` is the only path passed to the provider. Sensors live
in `.yoke/sensors/<id>.md` (project-scoped, not per-task) and are
explicitly NOT staged — re-feeding them on every canonize is
exactly what the issue rejected.

Per the working-memory provider contract, the directory is read-only
from the provider's perspective; the facade still owns the cleanup.

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

Invoke the provider's pinned canonize skill with the staged absolute
working-memory path produced in Phase 1:

```text
Skill(skill: "${YOKE_PROVIDER_CANONIZE_SKILL}", args: "--working-memory ${stage_dir}")
```

In the seed configuration (`provider: bedrock`),
`$YOKE_PROVIDER_CANONIZE_SKILL == "bedrock:teach"` per
`providers.yaml`, so this resolves to:

```text
Skill(skill: "bedrock:teach", args: "--working-memory <abs-path-to-stage>")
```

Capture the provider's stdout. Capture the provider's exit code in
`$provider_rc`.

## Phase 4 — Append a canonize: line to runtime/progress.md

Append a single line beginning `canonize:` to the host's
`.yoke/runtime/progress.md` (NOT the staged copy — the stage is
ephemeral and is removed in Phase 5) summarizing the dispatch. The
line is a soft convention (per
`docs/canonical-memory-provider-contract.md`'s "Soft exit-summary
convention" section); the provider's stdout MAY include a structured
summary line which the facade forwards verbatim.

```bash
progress="$PWD/.yoke/runtime/progress.md"
mkdir -p "$PWD/.yoke/runtime"
[ -f "$progress" ] || printf '# Progress\n\n' > "$progress"

# If the provider emitted an exit-summary line on stdout, prefer that
# (it's the authoritative count). Otherwise emit a minimal record.
summary_line="$(printf '%s\n' "${provider_stdout:-}" | grep -E '^canonize:' | tail -n 1 || true)"
if [ -z "$summary_line" ]; then
  summary_line="canonize: provider=${YOKE_PROVIDER_NAME} working_memory=${stage_dir} exit=${provider_rc}"
fi
printf '%s\n' "$summary_line" >> "$progress"
```

The line is the **only** write this facade performs against the host
project. The staged tree is read-only from the facade's perspective
(per the provider contract).

## Phase 5 — Cleanup the staged directory + propagate exit

```bash
# Stage was a fresh mktemp -d; remove it unconditionally.
[ -n "${stage_dir:-}" ] && rm -rf "$stage_dir"

exit "$provider_rc"
```

Cleanup runs even on non-zero `$provider_rc` so failed canonize runs
do not leave tmp dirs behind. Never zero out a non-zero provider
exit. Never translate provider exit codes into a normalized scheme.
The caller (the runtime Orchestrator subagent in canonize mode)
reads the exit code as authoritative.

## Critical rules

| # | Rule |
|---|---|
| 1 | NEVER classify maturity, summarize, or otherwise pre-process inside the staged tree. The provider owns canonization decisions; the facade only narrows the input set to the active task (issue #40). |
| 2 | NEVER pass a relative path. The staging helper outputs an absolute path via `mktemp -d`. |
| 3 | NEVER pass the host's `.yoke/` directly. Always pass the staged copy from Phase 1. |
| 4 | NEVER swallow the provider's exit code. Propagate it verbatim. |
| 5 | NEVER write inside the host's `.yoke/` except for the single `canonize:` line appended to `runtime/progress.md` in Phase 4. |
| 6 | NEVER stage `.yoke/sensors/<id>.md` files. They are project-scoped, not per-task; re-feeding them is exactly the bloat issue #40 rejected. |
| 7 | NEVER invoke the provider's canonize skill (e.g. `/bedrock:teach`) directly. Always dispatch through `$YOKE_PROVIDER_CANONIZE_SKILL`. |
| 8 | NEVER skip the Phase 5 stage cleanup. Even on non-zero `$provider_rc`, `rm -rf "$stage_dir"` runs unconditionally. |

## Anti-patterns

- Reading `.yoke/specs/`, `.yoke/sprints/`, `.yoke/contracts/`,
  `.yoke/runtime/` to "decide what's canonization-worthy" before
  invoking the provider. The provider judges; the facade only
  narrows by active-task scope.
- Pre-bundling the staged tree into a tarball or single document.
  The provider expects a directory tree shaped like `.yoke/`.
- Staging the full `.yoke/` (every historical PRD/spec/sprint/AC
  from prior tasks) to "let the provider decide". That is the bug
  issue #40 documented; the active-task scope is the v4.1 fix.
- Branching the dispatch logic on `$YOKE_PROVIDER_NAME`. The whole
  point of the facade is that providers are interchangeable.
- Logging the provider's full stdout to `runtime/progress.md`. Only
  the soft `canonize:` summary line is recorded.
- Leaving `$stage_dir` on disk after the dispatch returns. The
  facade is the only owner of the stage; cleanup is unconditional.

## See also

- `docs/canonical-memory-provider-contract.md` — the working-memory
  contract every provider implements (`contract_version: 1`); the
  "Active-task staging" section documents the diff contract added
  for issue #40.
- `concepts/yoke-pattern-memory-model` — the write-mediator role.
- `lib/canonical-memory/resolve-provider.sh` — provider resolution.
- `lib/working-memory/canonize-stage.sh` — active-task staging
  helper invoked in Phase 1.
- `providers.yaml` — curated provider registry.
