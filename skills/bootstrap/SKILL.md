---
name: bootstrap
description: >
  Initial setup for a host project that wants to use Yoke. At v2.0.0,
  /yoke:bootstrap is the single entry point through which a host project's
  `.yoke/config.yaml :: canonical_memory.provider` lands. Two flows are
  supported: (Flow A) legacy detection and migration — when the project is
  on Yoke v1.x, bootstrap detects either `<plugin_dir>/memories.json` or a
  v1.x-shaped `.yoke/config.yaml` lacking the `provider:` key, preserves
  `url`/`name`/`default_branch` as passthrough keys, defaults the migrated
  provider to `bedrock`, and removes `memories.json` after final
  confirmation; (Flow B) fresh bootstrap — bootstrap reads the curated
  provider list from the plugin's `providers.yaml`, prompts (or
  non-interactively selects via `--provider`), warns when the selected
  provider's `requires.plugin` is not installed, and writes
  `.yoke/config.yaml`. Idempotent. /yoke:bootstrap is the only Yoke skill
  that does NOT source `lib/yoke-prelude.sh` — it is the migration entry
  point.
argument-hint: "[--provider <name>] [--non-interactive] [--canonical-memory <url>]"
allowed-tools: Bash, Read, Write, Edit
---

# /yoke:bootstrap — Phase 0 setup (provider selection + v1.x migration)

Prepares a host project to use Yoke v2.0.0 and ensures
`.yoke/config.yaml :: canonical_memory.provider` is populated. After
this skill returns, every other Yoke skill's hard-break pre-flight
(sourced from `lib/yoke-prelude.sh`) will pass.

## Objective

Make a project Yoke-ready at v2.0.0 by:

1. Verifying environment dependencies (`gh` CLI, bash 4+, git repo).
2. Selecting an active canonical-memory provider — either interactively
   from `providers.yaml` or via the `--provider <name>` flag.
3. Detecting v1.x state (legacy `<plugin_dir>/memories.json` or a
   v1.x-shaped `.yoke/config.yaml`) and migrating to the v2.0.0 schema
   under explicit confirmation, preserving `url`, `name`, and
   `default_branch` as `config_passthrough` keys.
4. Writing `.yoke/config.yaml` from `templates/yoke-config.yaml` with
   the selected provider plus any provider-specified passthrough keys.
5. Creating `.yoke/runtime/` and `.yoke/.gitignore`.
6. Pointing the user at `/yoke:discover` as the next step.

## Pre-conditions

- The current directory is the root of a git repository. Bootstrap
  aborts otherwise.
- `gh` CLI installed and authenticated. **Hard-fails with install
  instructions if missing** — no degraded mode (per
  `concepts/yoke-decision-*` in canonical memory).
- bash 4 or newer. macOS users need `brew install bash`.
- A host `CLAUDE.md` (created from `templates/project-claude-md.md` if
  absent — never overwritten if present).
- `<plugin_dir>/providers.yaml` exists. Bootstrap aborts if the
  curated provider registry is missing or unparseable.

## Argument parsing

- `--provider <name>` — non-interactive override. The value must match
  a key under `providers:` in `<plugin_dir>/providers.yaml`. Aborts
  with a registered-providers listing if not.
- `--non-interactive` — flag. Requires `--provider`. Skips every
  confirmation prompt; aborts on any ambiguity that would otherwise
  prompt the user.
- `--canonical-memory <url>` — optional URL for the per-provider
  passthrough keys (forwarded to the active provider plugin verbatim).
  Equivalent to the legacy v1.x `canonical_memory.url`.

## Pre-flight

Bootstrap is the **only** Yoke skill that does NOT source
`lib/yoke-prelude.sh` — it is the migration entry point. Sourcing the
prelude here would make bootstrap self-defeating on a v1.x project.

Bootstrap *does* source the working-memory paths helper and
`lib/canonical-memory/resolve-provider.sh` for validation only:

```bash
source "$PLUGIN/lib/working-memory/paths.sh"
# resolve-provider.sh is used to validate provider names against
# providers.yaml; it is NOT used to require a provider in
# .yoke/config.yaml (that is the job of every other skill's
# hard-break pre-flight call into the prelude helper).
source "$PLUGIN/lib/canonical-memory/resolve-provider.sh"
```

## What it does

### Step 1 — verify environment

- Check that the current directory is a git repo
  (`git rev-parse --git-dir`). Abort with a clear error if not.
- Check `gh --version` succeeds. If not, abort and link to
  <https://cli.github.com/>.
- Check `bash --version` reports 4 or newer. On macOS, suggest
  `brew install bash`.
- Check `<plugin_dir>/providers.yaml` exists and parses. Abort
  otherwise (this is a packaging error, not a user error).

### Step 2 — detect legacy v1.x state

Compute two markers:

- `legacy_registry` — `[ -f "$PLUGIN/memories.json" ]`. The v1.x
  vault registry that lived in the plugin directory.
- `legacy_config` — `.yoke/config.yaml` exists at the host project
  root, AND the `canonical_memory.provider` key is missing or empty.

If either marker is true, print:

```
wm: legacy Yoke v1.x state detected. Migrating to v2.0.0 schema.
```

…and proceed to **Flow A — legacy migration**. Otherwise, proceed to
**Flow B — fresh bootstrap**.

### Step 3 — Flow A: legacy migration

1. **Read the existing v1.x state.** If `legacy_registry`: read the
   first entry from `<plugin_dir>/memories.json` and extract `url`,
   `name`, `default_branch`. If `legacy_config`: read `.yoke/config.yaml`
   and extract `canonical_memory.url`, `canonical_memory.name`,
   `canonical_memory.default_branch`. Either source provides the same
   three keys.
2. **Default the migrated provider to `bedrock`.** Bedrock was the
   only viable v1.x backend, so the migration default is
   deterministic. If `--provider` was passed with a value other than
   `bedrock`, abort with:
   ```
   wm: --provider <name> conflicts with v1.x migration default (bedrock).
   Re-run without --provider, or use --provider bedrock to be explicit.
   ```
   The user can always re-bootstrap after the migration to switch
   providers.
3. **Confirm interactively** (skipped under `--non-interactive`):
   ```
   Migrating Yoke v1.x → v2.0.0:
     provider: bedrock
     passthrough: url=<...>, name=<...>, default_branch=<...>
   This will:
     - write .yoke/config.yaml with canonical_memory.provider: bedrock
     - remove <plugin_dir>/memories.json (after the config write
       succeeds)
   Proceed? [y/N]
   ```
   On `n` reply, abort without modifying any files. On `y` reply,
   continue.
4. **Write `.yoke/config.yaml`** from `templates/yoke-config.yaml`
   substituting:
   - `canonical_memory_provider` → `bedrock`
   - `canonical_memory_url` → captured `url`
   - the captured `name` and `default_branch` go under
     `canonical_memory:` as additional keys (per `providers.yaml`
     `bedrock.config_passthrough: [url, name, default_branch]`)
   - `created_at` (today's ISO 8601 date)
   - `yoke_version` (from this plugin's `plugin.json`)
   - `host_project_name`, `host_actor_name` (from the working-memory
     `host-actor` helper)
5. **Create `.yoke/runtime/`** (idempotent — no-op if it exists) and
   `.yoke/.gitignore` containing exactly the line `runtime/`.
6. **Verify the new config**, then **delete the legacy
   `memories.json`** if it existed. Order is strict:
   `write new config → verify provider key parses → delete
   memories.json`. The legacy file is never deleted before the new
   config is in place.

### Step 4 — Flow B: fresh bootstrap

1. **Read available providers** from `<plugin_dir>/providers.yaml`.
2. **Select the active provider:**
   - If `--provider <name>` was passed: validate it against the
     `providers:` keys; abort with the available-providers list on
     mismatch.
   - Else if `--non-interactive` was passed: abort with
     `--non-interactive requires --provider`.
   - Else if there is exactly one provider entry: select it
     automatically (with a one-line note to the user).
   - Else (multiple providers, interactive mode): prompt the user
     with the list, e.g.:
     ```
     Available canonical-memory providers:
       1) bedrock — Markdown frontmatter graph in a separate git repo
                    (requires plugin: claude-bedrock ≥ 0.1.0)
       2) <other> — <description>
     Select a provider [1-N]:
     ```
3. **Warn if `requires.plugin` is not installed.** When the chosen
   provider entry sets `requires.plugin`, check whether the named
   peer plugin is installed (Claude Code's plugin list — exact
   detection mechanism is the framework's responsibility, not the
   skill's). If not, print a warning but continue:
   ```
   warning: provider 'bedrock' requires the 'claude-bedrock' plugin (>=0.1.0).
   It does not appear to be installed. Install it via
       claude plugin install claude-bedrock
   before invoking /yoke:search-canonical-memory or /yoke:canonize.
   ```
   This is a warning, not an abort, because the user may install the
   peer plugin between bootstrap and first use.
4. **Prompt for `config_passthrough` keys** named in the provider's
   entry. For each key in `providers.<name>.config_passthrough` that
   is not already provided via flag (e.g. `--canonical-memory`):
   ```
   <key> [<default-or-empty>]:
   ```
   Skipped under `--non-interactive`; defaults are used.
5. **Write `.yoke/config.yaml`** from `templates/yoke-config.yaml`
   substituting the selected provider into
   `canonical_memory.provider` plus the captured passthrough values.
6. **Create `.yoke/runtime/`** and `.yoke/.gitignore` (line:
   `runtime/`).

### Step 5 — re-bootstrap detection

If `.yoke/config.yaml` already exists AND has a non-empty
`canonical_memory.provider` key (i.e. it's already on the v2.0.0
schema):

- In interactive mode, ask `re-bootstrap? overwrite existing config? [y/N]`.
  Default = `n` (no-op exit 0). On `n`, abort without touching any
  file.
- Under `--non-interactive`, abort with exit 0 and a short
  `already-bootstrapped` message — never overwrite an existing v2.0.0
  config without explicit user consent.

### Step 6 — host `CLAUDE.md`

- If the host has no `CLAUDE.md`: copy `templates/project-claude-md.md`
  to `./CLAUDE.md`.
- If the host has a `CLAUDE.md`: leave it alone. Print a hint that
  Yoke parses `## Testing`, `## Linting`, `## Build` sections — point
  at `docs/canonical-memory-setup.md`.

### Step 7 — next steps

Print:

- "Yoke is ready. Run `/yoke:discover \"<your idea>\"` to start your
  first task."
- A pointer to `docs/quickstart.md`.
- The selected provider name and a one-line summary of the
  passthrough keys captured.

## Output contract

- Exit 0 on success.
- Exit non-zero with a clear, actionable error message on any failure
  listed above.
- File writes are idempotent and reversible. The skill never destroys
  user content without explicit confirmation.
- Migration ordering is strict: **write new config → verify provider
  key parses → delete `memories.json`**. The legacy registry file is
  never deleted before the new config write succeeds.
- Re-bootstrap on an existing v2.0.0 config requires explicit `y`
  consent (interactive) or aborts with `already-bootstrapped`
  (non-interactive). Never overwrite silently.

## Anti-patterns (do NOT do these)

- **Do not source `lib/yoke-prelude.sh`.** Bootstrap is the migration
  entry point — sourcing the prelude on a v1.x project would make
  this skill self-defeating. The audit grep
  (`prelude-source-line-audit` sensor) explicitly asserts that this
  file does NOT contain the prelude helper-function name.
- **Do not silently default a missing provider.** Always select via
  `--provider <name>`, an interactive prompt, or the
  single-entry-only fallback. The PRD invariant says: hard break is
  preferable to silent default.
- **Do not delete `<plugin_dir>/memories.json` before the new
  `.yoke/config.yaml` is in place and verified.** Migration must be
  safe under partial failure.
- **Do not overwrite an existing v2.0.0 `.yoke/config.yaml` without
  explicit user consent.** Re-bootstrap is a `y/N` prompt, never a
  default `y`.
- **Do not auto-create `gh` repos without confirmation.** Always ask.
- **Do not overwrite an existing `CLAUDE.md`.** The host's CLAUDE.md
  is the user's, not Yoke's.
- **Do not silently degrade if `gh` is missing.** Hard-fail.
- **Do not write outside `.yoke/`, the host `CLAUDE.md`, the
  registered memory's checkout path (when applicable), the registry
  file, and the optional `gh repo create` call.** Bootstrap touches
  only those surfaces.
