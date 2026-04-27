---
name: bootstrap
description: >
  Initial setup for a host project that wants to use Yoke. Creates `.yoke/`
  with a default config, links the project to a canonical-memory git
  repository (registered into the plugin-level memory registry), migrates
  any pre-existing `~/.cache/yoke/canonical/<slug>/` clone into the
  registry, and verifies required dependencies (`gh` CLI, bash 4+).
  Idempotent. Run this once per project before any other `/yoke:*` command.
argument-hint: "[--canonical-memory <url>]"
allowed-tools: Bash, Read, Write, Edit
---

# /yoke:bootstrap — Phase 0 setup

Prepares a host project to use Yoke and ensures the canonical memory it
points at is registered with the Yoke plugin (no more
clone-on-every-read).

## Objective

Make a project Yoke-ready by:

1. Creating `.yoke/` at the project root with a default `config.yaml`.
2. Linking it to a canonical-memory git repo — an existing URL or one
   freshly created via `gh repo create` — and **registering** it in
   `<plugin_dir>/memories.json` so subsequent reads use the local
   checkout.
3. Migrating any pre-existing `~/.cache/yoke/canonical/<slug>/` clone
   into the registry (XDG path).
4. Verifying critical dependencies are installed.
5. Pointing the user at `/yoke:discover` as the next step.

## Pre-conditions

- The current directory is the root of a git repository. Bootstrap aborts otherwise.
- `gh` CLI installed and authenticated. **Hard-fails with install instructions if missing** — no degraded mode (per `.vibeflow/decisions.md`).
- bash 4 or newer. macOS users need `brew install bash`.
- A host `CLAUDE.md` (created from `templates/project-claude-md.md` if absent — never overwritten if present).

## What it does

### Step 1 — verify environment

- Check that the current directory is a git repo (`git rev-parse --git-dir`). Abort with a clear error if not.
- Check `gh --version` succeeds. If not, abort and link to <https://cli.github.com/>.
- Check `bash --version` reports 4 or newer. On macOS, suggest `brew install bash`.

### Step 2 — handle existing `.yoke/`

- If `.yoke/config.yaml` exists, ask: keep / overwrite / abort. Default = keep.
- Idempotency contract: re-running with no flags and an existing config plus a registered memory returns "already bootstrapped" and exits 0.

### Step 3 — canonical-memory link

Read from `--canonical-memory <url>` if provided, otherwise prompt:

> Where does this project's canonical memory live?
>   `(a)` an existing repo URL → record in config
>   `(b)` create a new one → run `gh repo create <slug>-canonical-memory --private --confirm` and record the URL
>   `(c)` skip / defer → record placeholder; warn that `/yoke:ask`, `/yoke:preserve`, `/yoke:teach`, and `/yoke:compress` will not work until this is filled in

Confirm with the user before running `gh repo create`. Never auto-create
without consent.

### Step 4 — register the memory

Resolve the registry path: `<plugin_dir>/memories.json`. The plugin dir is
the directory where Yoke is installed (parent of `skills/`). The
canonical-memory libs handle this resolution; pass `YOKE_PLUGIN_DIR` if
needed.

For a populated `canonical_memory.url`:

1. **Check if the URL is already registered.** Run:
   ```bash
   bash "$PLUGIN/lib/canonical-memory/registry.sh" has-url "$URL"
   ```
   If the answer is `yes`, skip to Step 5 — already migrated.
2. **Detect a legacy clone.** If `~/.cache/yoke/canonical/<derived-slug>/`
   exists (where `<derived-slug>` is `basename "$URL" | sed 's/\.git$//'`):
   - Treat it as a migration candidate.
3. **Pick the local path.** XDG default for migrated installs:
   `~/.local/share/yoke/canonical/<derived-slug>/`. If a fresh path is
   needed, create the parent and `git clone "$URL"` into the target.
   For migrated clones, copy the legacy cache contents (or `git clone
   "$URL"`) into the XDG path.
4. **Register.** Run:
   ```bash
   bash "$PLUGIN/lib/canonical-memory/registry.sh" add "<slug>" "$XDG_TARGET" "$URL"
   ```
   On success the entry is in `memories.json`. On duplicate-name (e.g.
   re-running after a partial migration), surface the message — the
   user can rename via `/yoke:memory remove <slug> && /yoke:memory add ...`.
5. **Verify, then delete the legacy cache.** This order is mandatory:
   `register → verify (test -d on registered path) → delete cache`.
   Cache deletion is the last step.
   ```bash
   if [ -d "$LEGACY_CACHE" ] && [ -d "$XDG_TARGET" ]; then
     rm -rf "$LEGACY_CACHE"
   fi
   ```

If the user chose `(c)` (defer), skip Step 4 entirely — no registration.

### Step 5 — write `.yoke/`

Create:

- `.yoke/config.yaml` from `templates/yoke-config.yaml`, substituting:
  - `canonical_memory.url` (from Step 3)
  - `canonical_memory.name` (from Step 4 — registered slug, or empty if deferred)
  - `created_at` (today's date, ISO 8601)
  - `yoke_version` (from this plugin's `plugin.json`)
- `.yoke/.gitignore` with exactly one line:
  ```
  runtime/
  ```
  Rationale: archive categories (`prds/`, `specs/`, `tasks/`, `acceptance-contracts/`, `contracts/`) are versioned by the host project. The runtime working directory (`runtime/`) is the single ephemeral surface — the per-worktree active-task pointer lives at `runtime/.current`, so one ignore rule covers all per-worktree state. See `lib/working-memory/paths.sh`.

Do **not** pre-create archive category folders or any flat working-memory files (`prd.md`, `tech-spec.md`, etc.) — those are created lazily by `/yoke:discover` and downstream skills. After bootstrap completes, `.yoke/` contains exactly `config.yaml` and `.gitignore`.

### Step 6 — host `CLAUDE.md`

- If the host has no `CLAUDE.md`: copy `templates/project-claude-md.md` to `./CLAUDE.md`.
- If the host has a `CLAUDE.md`: leave it alone. Print a hint that Yoke parses `## Testing`, `## Linting`, `## Build` sections — point at `docs/canonical-memory-setup.md`.

### Step 7 — next steps

Print:

- "Yoke is ready. Run `/yoke:discover \"<your idea>\"` to start your first task."
- A pointer to `docs/quickstart.md`.
- The registered memory name (or the deferred-state warning).

## Output contract

- Exit 0 on success.
- Exit non-zero with a clear, actionable error message on any failure listed above.
- File writes are idempotent and reversible. The skill never destroys user content.
- Migration ordering is strict: register → verify → delete cache. Cache is never deleted before the registry write succeeds and the path is verified.

## Anti-patterns (do NOT do these)

- **Do not auto-create `gh` repos without confirmation.** Always ask.
- **Do not overwrite an existing `CLAUDE.md`.** The host's CLAUDE.md is the user's, not Yoke's.
- **Do not silently degrade if `gh` is missing.** Hard-fail.
- **Do not populate canonical memory at bootstrap time.** That is `/yoke:preserve`'s job (Part 4).
- **Do not delete the legacy cache before the registry write succeeds.** Migration must be safe under partial failure.
- **Do not write outside `.yoke/`, the host `CLAUDE.md`, the registered memory's checkout path, the registry file, and the optional `gh repo create` call.** Bootstrap touches only those surfaces.
