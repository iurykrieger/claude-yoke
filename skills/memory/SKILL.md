---
name: memory
description: >
  Manage the Yoke canonical-memory registry. List registered memories,
  add a new one (registers an existing repo or scaffolds a fresh one),
  set the default, or remove an entry. The registry lives at
  `<plugin_dir>/memories.json` and maps memory names to filesystem paths
  and git URLs.
  Use when: "yoke memory", "yoke-memory", "/yoke:memory", "list memories",
  "add memory", "set default memory", "remove memory", "scaffold memory",
  or whenever a user wants to manage their canonical-memory registrations.
argument-hint: "[list | add <path> [--url <url>] [--name <name>] | set-default <name> | remove <name>]"
allowed-tools: Bash, Read, Write
---

# /yoke:memory — Canonical-Memory Registry Management

## Plugin paths

Yoke's memory registry lives at `<plugin_dir>/memories.json`. The libs
that read and write it are at:

- `<plugin_dir>/lib/canonical-memory/registry.sh` — registry CRUD
- `<plugin_dir>/lib/canonical-memory/scaffold-memory.sh` — fresh-memory init

Use the "Base directory for this skill" provided at invocation to
resolve `<plugin_dir>` (the plugin root is the parent of `skills/`).

---

## Overview

This skill is the user-facing CLI for the registry. It does **not**
read, write, or otherwise touch entity content inside any registered
memory. It only manages the registry file itself plus, on `add`, the
optional initial scaffold of a fresh memory directory.

You are a management agent. Pure registry operations + scaffold.

---

## Phase 0 — Parse input

Match the user's input to one of these modes:

| Input | Mode | Variables |
| :--- | :--- | :--- |
| empty / `list` | **list** | — |
| `add <path> [--url <url>] [--name <name>]` | **add** | `PATH`, `URL?`, `NAME?` |
| `set-default <name>` | **set-default** | `NAME` |
| `remove <name>` | **remove** | `NAME` |

If the input doesn't match any pattern, default to **list**.

---

## Phase 1 — List

```bash
bash "$(plugin_dir)/lib/canonical-memory/registry.sh" list
```

Print the result. The script handles the empty-state case.

If any registered path no longer exists on disk, append a warning:

```
> Some memories have paths that no longer exist on disk. Run
> /yoke:memory remove <name> to clean up, or re-create the memory at
> the registered path.
```

---

## Phase 2 — Add

Validate inputs:

1. `<path>` is required. Convert to absolute (`realpath -m <path>`).
2. `--name <name>` is optional; if omitted, derive from the URL slug
   (basename minus `.git`) when `--url` is given, otherwise from the
   path basename.
3. Names are kebab-case lowercase. Reject mixed-case or whitespace.

Decide the action by inspecting the path:

- **Existing populated memory** (`.git` present): register as-is. Run:
  ```bash
  bash "$(plugin_dir)/lib/canonical-memory/registry.sh" add "$NAME" "$PATH" "$URL"
  ```
- **Non-existent or empty directory**: scaffold first, then register.
  ```bash
  bash "$(plugin_dir)/lib/canonical-memory/scaffold-memory.sh" "$PATH"
  bash "$(plugin_dir)/lib/canonical-memory/registry.sh" add "$NAME" "$PATH" "$URL"
  ```
- **Existing non-empty directory without `.git`**: refuse with
  `"Path exists but is not a git repo and is not empty. Move or delete it, then re-run."`

Duplicate handling — the registry library rejects duplicate names and
duplicate URLs (exit code 4). When that happens, surface the error
and point the user at `/yoke:memory list`.

Print on success:

```
Memory '<name>' registered at <path>.
URL: <url-or-(none)>
Default: yes (this is the only memory) | no
```

---

## Phase 3 — Set-default

Validate that `<name>` exists in the registry, then run:

```bash
bash "$(plugin_dir)/lib/canonical-memory/registry.sh" set-default "$NAME"
```

The library marks the named memory as default and clears the flag on
all others. Print:

```
Default memory set to '<name>' (<path>).
```

If the name is not found, the library exits 5 — surface the error and
list the available memories.

---

## Phase 4 — Remove

Validate that `<name>` exists, then run:

```bash
bash "$(plugin_dir)/lib/canonical-memory/registry.sh" remove "$NAME"
```

Print:

```
Memory '<name>' removed from the registry.
Files on disk were NOT deleted (path: <path>).
```

If the removed memory was the default and other memories remain, no
default is auto-assigned — the next `/yoke:ask`, `/yoke:preserve`, etc.
will prompt the user to set one. Bedrock's auto-fallback is
deliberately not carried over: explicit > implicit for governance
clarity.

---

## Critical rules

| # | Rule |
|---|---|
| 1 | NEVER modify entity content inside a memory — this skill only touches `memories.json` and (on add) the initial scaffold |
| 2 | NEVER run git operations on registered memories — `add` may run `git init` via the scaffold helper, but never `pull`, `push`, `commit`, or `clone` against existing repos |
| 3 | NEVER delete files on disk via `remove` — the registry entry is removed; on-disk files stay |
| 4 | ALWAYS validate that the name exists before set-default and remove |
| 5 | Names are kebab-case lowercase only; reject anything else |
| 6 | The registry lives at `<plugin_dir>/memories.json` — never anywhere else |
| 7 | Plugin reinstall loses the registry. Recovery is `/yoke:memory add <path>` per memory; document this clearly when the registry is empty |
