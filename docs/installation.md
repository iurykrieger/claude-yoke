# Installing Yoke

## Pre-requisites

- **Claude Code** with marketplace support and subagent / Task-tool support.
- **`gh` CLI**, authenticated against your GitHub account. Yoke uses it for canonical-memory PR-based ratification. Install: <https://cli.github.com/>.
- **bash 4 or newer.** macOS ships bash 3 by default — install bash 4 via Homebrew: `brew install bash`.
- **git 2.0+**.

## Install

```
/plugin marketplace add iurykrieger/yoke
/plugin install yoke@yoke-marketplace
```

After install, the `/yoke:` slash commands appear in Claude Code.

## Verify

In any project repository:

```
/yoke:bootstrap
```

If everything is wired up, bootstrap will ask about your canonical-memory
location and create `.yoke/config.yaml`. Run `/yoke:discover "<idea>"` to
start your first task.

## Troubleshooting

- **`gh` not found.** Bootstrap hard-fails by design (no degraded mode in v0.1.0). Install `gh` and re-run.
- **bash 3 detected on macOS.** `brew install bash`; ensure bash 4+ is on your `$PATH`.
- **Plugin install fails.** Confirm Claude Code is up to date with the current marketplace schema. Yoke mirrors the schema used by `vibeflow-claude` and `claude-bedrock`.

See [`quickstart.md`](quickstart.md) for the first-task walkthrough.
