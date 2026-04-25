---
name: bootstrap
description: >
  Initial setup for a host project that wants to use Yoke. Creates `.yoke/`
  with a default config, links to or creates the canonical-memory git
  repository, and verifies required dependencies (`gh` CLI, bash 4+).
  Idempotent. Run this once per project before any other `/yoke:*` command.
argument-hint: "[--canonical-memory <url>]"
allowed-tools: Bash, Read, Write, Edit
---

# /yoke:bootstrap — Phase 0 setup

Prepares a host project to use Yoke.

## Objective

Make a project Yoke-ready by:

1. Creating `.yoke/` at the project root with a default `config.yaml`.
2. Linking it to a canonical-memory git repo — an existing URL or one
   freshly created via `gh repo create`.
3. Verifying critical dependencies are installed.
4. Pointing the user at `/yoke:discover` as the next step.

## Pre-conditions

- The current directory is the root of a git repository. Bootstrap aborts otherwise.
- `gh` CLI installed and authenticated. **Hard-fails with install instructions if missing** — there is no degraded mode in v0.1.0 (per `.vibeflow/decisions.md`).
- bash 4 or newer (`hooks/` and `lib/*.sh` depend on it). On macOS, install via `brew install bash`.
- A host `CLAUDE.md` (created from `templates/project-claude-md.md` if absent — never overwritten if present).

## What it does

### Step 1 — verify environment

- Check that the current directory is a git repo (`git rev-parse --git-dir`). Abort with a clear error if not.
- Check `gh --version` succeeds. If not, abort and link to <https://cli.github.com/>.
- Check `bash --version` reports 4 or newer. On macOS, suggest `brew install bash` and ensure bash 4+ is on `$PATH`.

### Step 2 — handle existing `.yoke/`

- If `.yoke/config.yaml` exists, ask: keep / overwrite / abort. Default = keep.
- Idempotency contract: re-running with no flags and an existing config returns "already bootstrapped" and exits 0.

### Step 3 — canonical-memory link

Read from `--canonical-memory <url>` if provided, otherwise prompt the user:

> Where does this project's canonical memory live?
>   `(a)` an existing repo URL → record in config
>   `(b)` create a new one → run `gh repo create <slug>-canonical-memory --private --confirm` and record the URL
>   `(c)` skip / defer → record placeholder; warn that `/yoke:ask`, `/yoke:canonize`, and `/yoke:drift-sense` will not work until this is filled in

Confirm with the user before running `gh repo create`. Never auto-create
without consent.

### Step 4 — write `.yoke/`

Create:

- `.yoke/config.yaml` from `templates/yoke-config.yaml`, substituting:
  - `canonical_memory.url` (from Step 3)
  - `created_at` (today's date, ISO 8601)
  - `yoke_version` (from this plugin's `plugin.json`)
- `.yoke/.gitignore` with one line: `*` (working memory is ephemeral; the host project does not track it in git).

### Step 5 — host `CLAUDE.md`

- If the host project has no `CLAUDE.md`: copy `templates/project-claude-md.md` to `./CLAUDE.md`. The template includes marked sections (`## Testing`, `## Linting`, `## Build`) Yoke parses for sensor discovery in Phase 3.
- If the host has a `CLAUDE.md`: leave it alone. Print a hint that Yoke parses `## Testing`, `## Linting`, `## Build` sections — point at `docs/canonical-memory-setup.md`.

### Step 6 — next steps

Print:

- "Yoke is ready. Run `/yoke:discover \"<your idea>\"` to start your first task."
- A pointer to `docs/quickstart.md`.
- A reminder that v0.1.0 implements only `/yoke:bootstrap` — other slash commands are placeholders until subsequent sprints.

## Output contract

- Exit 0 on success.
- Exit non-zero with a clear, actionable error message on any failure listed above.
- Every file write is idempotent and reversible. The skill never destroys user content.

## Anti-patterns (do NOT do these)

- **Do not auto-create `gh` repos without confirmation.** Always ask.
- **Do not overwrite an existing `CLAUDE.md`.** The host's CLAUDE.md is the user's, not Yoke's.
- **Do not silently degrade if `gh` is missing.** Hard-fail with install instructions per the `.vibeflow/decisions.md` "hard-fail" decision.
- **Do not populate canonical memory at bootstrap time.** That is `/yoke:canonize`'s job (Sprint 5+).
- **Do not write outside `.yoke/`, the host `CLAUDE.md`, and the optional `gh repo create` call.** Bootstrap touches only those surfaces.
