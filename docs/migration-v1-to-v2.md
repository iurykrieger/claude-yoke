# Migrating from Yoke v1.x to v2.0.0

> Source PRD: `.yoke/prds/2026-04-30-pluggable-canonical-memory.md`.
> Source Spec: `.yoke/specs/2026-04-30-pluggable-canonical-memory.md`.
> Acceptance Contract Scenario 11 / 14 / 15.

Yoke v2.0.0 is a **breaking-change** release. The single-vendor
canonical-memory implementation that shipped under the legacy
`/yoke:` namespace in v1.x — seven skills covering read, write
(canonize), teach (ingest), compress (vault alignment), memory
(vault registry management), and the two source-fetch helpers
(Confluence and GDoc converters) — has been extracted into a peer
plugin (`claude-bedrock`). Yoke now dispatches reads and writes
through two provider-agnostic facade verbs:

| v2.0.0 facade verb | What it does |
| :--- | :--- |
| `/yoke:search-canonical-memory "<query>"` | Read against the active provider — replaces the legacy v1.x read verb. |
| `/yoke:canonize` | Write the converged task's working-memory packet through Model C — replaces the legacy v1.x write verb. |

The active provider is selected per host project via
`.yoke/config.yaml :: canonical_memory.provider` and curated in the
plugin's `providers.yaml`. Bedrock is the reference provider; other
providers can ship as peer plugins that implement the
working-memory contract documented at
`docs/canonical-memory-provider-contract.md`.

**Backward compatibility for in-flight tasks is not promised.** Every
project that ran a prior Yoke version must explicitly migrate via
`/yoke:bootstrap` re-run before any other Yoke skill works again.
Hard break is preferable to silent default — see Acceptance Contract
Scenario 12 / FR-6.

---

## What changed

- **Seven legacy skills retired from Yoke.** The directories under
  `claude-yoke/skills/` named `ask`, `preserve`, `teach`, `compress`,
  `memory`, `confluence-to-markdown`, and `gdoc-to-markdown` are
  deleted from the Yoke plugin source. The same skills are exposed
  under the `/bedrock:` namespace by the peer plugin (`/bedrock:ask`,
  `/bedrock:preserve`, `/bedrock:teach`, `/bedrock:compress`,
  `/bedrock:vaults` — note the `memory` rename —
  `/bedrock:confluence-to-markdown`, `/bedrock:gdoc-to-markdown`).
- **Two facade verbs added.** `/yoke:search-canonical-memory` and
  `/yoke:canonize` are the only canonical-memory verbs your code or
  agents should reference. They resolve `canonical_memory.provider`
  from `.yoke/config.yaml`, look up the pinned skill verbs in
  `providers.yaml`, and dispatch verbatim. Provider-agnostic by
  design.
- **`providers.yaml` is the single source of truth.** It curates the
  provider registry: schema version, per-provider plugin requirement,
  pinned `skills.search` / `skills.canonize`, and
  `config_passthrough` keys.
- **Hard-break pre-flight.** Every Yoke skill except `/yoke:bootstrap`
  sources `lib/yoke-prelude.sh` and calls `yoke_require_provider`.
  Skills refuse to run on a project whose `.yoke/config.yaml` lacks
  `canonical_memory.provider` — they print
  `wm: canonical_memory.provider not configured. Run /yoke:bootstrap to migrate.`
  and exit non-zero.
- **`.yoke/config.yaml` schema bumped.** A new required key:
  `canonical_memory.provider`. The legacy `canonical_memory.name` key
  (which keyed into `<plugin_dir>/memories.json`) is retired in
  Yoke; the registry concept moves to the provider plugin.
  `url:` and `default_branch:` survive as
  `config_passthrough` keys forwarded opaquely.
- **`.claude-plugin/plugin.json :: version`** bumped from `1.1.0` to
  `2.0.0`; description now mentions "pluggable canonical-memory".

---

## Pre-upgrade checklist

Before running the upgrade against any host project:

1. **Confirm any in-flight task is at a safe stopping point.** v2.0.0
   does not migrate runtime state mid-cycle. Either let `/yoke:implement`
   converge the active sprint or escalate via Trigger 4 before upgrading.
2. **Locate your canonical-memory vault.** v1.x stored vault metadata
   in `<plugin_dir>/memories.json`. Open the file and note the active
   entry's `url`, `name`, and `default_branch` (you'll re-supply
   them during bootstrap).
3. **Confirm host-project working memory is committed.**
   `.yoke/prds/`, `.yoke/specs/`, `.yoke/sprints/`,
   `.yoke/acceptance-contracts/`, `.yoke/contracts/`,
   `.yoke/sensors/` are versioned archives — check them into git
   before the upgrade so a rollback is just a checkout.
4. **Read `docs/canonical-memory-setup.md`** for the v2.0.0 setup
   surface end-to-end. The runbook below is the upgrade path; the
   setup doc is the steady state.

---

## Step 1: install `claude-bedrock`

Yoke v2.0.0 does not ship the Bedrock canonical-memory implementation
itself. Install the peer plugin from the marketplace (or clone it
locally for development):

```bash
# From the Claude Code marketplace UI:
#   /plugins → search "claude-bedrock" → install
#
# Or via the CLI (one-time):
#   claude plugin install claude-bedrock
#
# Or for development against a local checkout:
#   claude plugin install /path/to/claude-bedrock
```

Verify `claude-bedrock` is installed by listing the registered
skills — `/bedrock:ask`, `/bedrock:canonize`, `/bedrock:teach`,
`/bedrock:preserve`, `/bedrock:compress`, `/bedrock:vaults`,
`/bedrock:confluence-to-markdown`, `/bedrock:gdoc-to-markdown` should
all be present.

If you are using a non-Bedrock canonical-memory provider, install
that provider plugin instead (and adjust the provider key in Step 3
accordingly). Any provider implementing
`docs/canonical-memory-provider-contract.md :: contract_version: 1`
is supported.

---

## Step 2: upgrade Yoke

Pull the v2.0.0 release of the Yoke plugin:

```bash
# From the Claude Code marketplace UI:
#   /plugins → yoke → update
#
# Or via the CLI:
#   claude plugin update yoke
```

Confirm the version bump:

```bash
jq -r '.version' /path/to/claude-yoke/.claude-plugin/plugin.json
# expected: 2.0.0
```

The legacy seven skills are now deleted from the Yoke plugin source.
Calls to the legacy v1.x verbs will be unrecognized in the Yoke
namespace once `claude-bedrock` is installed and the registered verbs
flip to the `/bedrock:` namespace. Use `/yoke:search-canonical-memory`
and `/yoke:canonize` for all reads and writes from this point forward.

---

## Step 3: re-bootstrap each project

For every host project that previously ran Yoke v1.x:

```bash
cd /path/to/host-project
/yoke:bootstrap
```

`/yoke:bootstrap` detects the v1.x state by checking for either:

- a `<plugin_dir>/memories.json` file, or
- a `.yoke/config.yaml` whose `canonical_memory:` block lacks the
  `provider:` key.

On detection, bootstrap prints:

```text
wm: legacy Yoke v1.x state detected. Migrating to v2.0.0 schema.
```

It then:

1. Defaults the migrated provider to `bedrock` (the only viable v1.x
   option). Override with `--provider <name>` only if you are
   migrating to a non-Bedrock peer plugin.
2. Reads the existing `url` / `name` / `default_branch` from the
   v1.x state and preserves them as `config_passthrough` keys under
   `canonical_memory:` in the new `.yoke/config.yaml`.
3. Confirms interactively before any destructive action (skipped
   under `--non-interactive`).
4. Writes `.yoke/config.yaml` with `canonical_memory.provider:
   bedrock` plus the preserved keys.
5. Removes `<plugin_dir>/memories.json` after final confirmation.

Non-interactive flag set, for scripts and CI:

```bash
/yoke:bootstrap --provider bedrock --non-interactive
```

Repeat for every host project that previously used Yoke. Projects
without a `.yoke/` directory don't need migration; they go through the
fresh-bootstrap path on first `/yoke:bootstrap`.

---

## Step 4: verify

After upgrading and re-bootstrapping, confirm the migration succeeded:

```bash
# (a) Plugin version is 2.0.0:
jq -r '.version' /path/to/claude-yoke/.claude-plugin/plugin.json
#   expected: 2.0.0

# (b) Host project's config carries the provider key:
yq -r '.canonical_memory.provider' /path/to/host-project/.yoke/config.yaml
#   expected: bedrock  (or your selected provider)

# (c) Hard-break helper exits 0 from the host project:
cd /path/to/host-project
bash /path/to/claude-yoke/lib/yoke-prelude.sh
#   expected: exit 0, silent stderr

# (d) Reads dispatch through the facade:
/yoke:search-canonical-memory "what is this project?"
#   expected: byte-equivalent to /bedrock:ask "what is this project?"

# (e) Writes dispatch through the facade (after a converged task):
/yoke:canonize
#   expected: a `canonize: created=<N> updated=<M> skipped=<K>` line on
#             stdout and a matching entry appended to
#             .yoke/runtime/progress.md
```

If `(a)` reports `1.1.0`, repeat Step 2. If `(b)` returns null or empty,
repeat Step 3. If `(c)` prints `wm: canonical_memory.provider not
configured. Run /yoke:bootstrap to migrate.`, repeat Step 3 — the
hard-break helper is doing its job.

---

## Common errors

### `wm: canonical_memory.provider not configured. Run /yoke:bootstrap to migrate.`

Expected on every Yoke skill (except `/yoke:bootstrap`) until you
re-bootstrap the project. Run `/yoke:bootstrap` per Step 3.

### `wm: provider 'bedrock' is not registered in providers.yaml.`

Yoke shipped without the `bedrock` entry in `providers.yaml`, or the
file is corrupt. Check
`/path/to/claude-yoke/providers.yaml`. The bedrock entry must declare:

```yaml
schema_version: 1
providers:
  bedrock:
    skills:
      search: bedrock:ask
      canonize: bedrock:canonize
    requires:
      plugin: claude-bedrock
      min_version: "0.1.0"
    config_passthrough:
      - url
      - name
      - default_branch
```

If the file is missing or wrong, reinstall `yoke` (Step 2).

### `Skill /bedrock:ask not found` (or similar)

`claude-bedrock` is not installed, or the `/bedrock:` namespace is
not registered. Repeat Step 1.

### `command not found` for any legacy v1.x canonical-memory verb under the Yoke namespace

Expected — the legacy seven verbs are gone from Yoke at v2.0.0. Use
`/yoke:search-canonical-memory "<query>"` for reads and
`/yoke:canonize` for writes. The facades dispatch to the active
provider's pinned verbs under the hood (e.g. `/bedrock:ask`,
`/bedrock:canonize`).

### `git status` shows `<plugin_dir>/memories.json` as untracked / deleted

Bootstrap removes `memories.json` after confirming the migration.
If you decline the confirmation prompt (`n` answer), bootstrap
aborts without removing the file — re-run with `y` when ready.

---

## Rollback

If the migration goes wrong, you can roll back:

1. **Pin Yoke to v1.1.x.** Reinstall the previous version:

   ```bash
   claude plugin install yoke@1.1.0
   ```

2. **Restore your host project's working memory.** Because
   `.yoke/prds/`, `.yoke/specs/`, `.yoke/sprints/`,
   `.yoke/acceptance-contracts/`, `.yoke/contracts/` and
   `.yoke/sensors/` are versioned archives (per the pre-upgrade
   checklist), `git checkout HEAD~1 -- .yoke/` returns the project to
   the pre-migration state.

3. **Restore `<plugin_dir>/memories.json`** if Step 3 deleted it. The
   file's contents (single entry: `name`, `url`, `default_branch`)
   were captured during bootstrap and are echoed in the bootstrap
   output. If you no longer have those values, recreate the entry
   from the `canonical_memory:` block in your committed
   `.yoke/config.yaml` (the bootstrap migration preserves them
   verbatim as passthrough keys).

4. **File a bug report.** v2.0.0 is a structural refactor; rollback
   should never be necessary in production. If you hit it, capture
   the failure mode in `tests/smoke/` or
   `tests/canonical-memory/` so future migrations don't repeat it.

---

## See also

- `docs/canonical-memory-setup.md` — steady-state setup once the
  migration is complete.
- `docs/canonical-memory-provider-contract.md` — the
  working-memory contract any provider plugin must implement.
- `docs/architecture.md` — the v2.0.0 dispatch-path diagram.
- `CHANGELOG.md` — the breaking-changes block for v2.0.0.
- Acceptance Contract Scenarios 11 (bootstrap), 12 (hard break),
  14 (docs), 15 (templates + version) inside
  `.yoke/acceptance-contracts/2026-04-30-pluggable-canonical-memory.md`.
