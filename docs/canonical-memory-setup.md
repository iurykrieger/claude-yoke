# Canonical memory — setup

Yoke separates **working memory** (per-task, ephemeral, lives in your
project's `.yoke/`) from **canonical memory** (organization-wide,
permanent, versioned, owned by an external substrate). Yoke v2.0.0 does
not implement a canonical-memory backend itself — it dispatches every
read and every write through two provider-agnostic facade verbs that
resolve the active provider via the plugin's `providers.yaml` and the
host project's `.yoke/config.yaml`.

This document covers the v2.0.0 setup surface end-to-end: what canonical
memory is, how to choose a provider, how to install the reference
provider plugin (`claude-bedrock`), how to run `/yoke:bootstrap`, and
how to use the facade verbs in day-to-day work.

If you are upgrading an existing project from Yoke v1.x, read
[`migration-v1-to-v2.md`](migration-v1-to-v2.md) first.

## What canonical memory is

- Ratified policies (RFC 2119, semver-tracked)
- Consolidated domain specs
- Harness templates by topology
- Resolved divergence patterns
- Structured ADRs
- Sensor calibrations (known false positives/negatives)
- State and trajectory of business projects

The scope is intentionally open. Yoke's governance — Model C — decides
**when and how** each proposition becomes doctrine, not what may be
proposed. The substrate that physically stores entities and serves
queries is the **provider's** concern, not Yoke's.

## Choosing a provider

A canonical-memory provider is a peer Claude Code plugin that:

- Implements the working-memory contract documented in
  [`canonical-memory-provider-contract.md`](canonical-memory-provider-contract.md)
  (`contract_version: 1`).
- Exposes two skills under its own namespace — one that satisfies
  the read shape (single string query in, retrieved entities out),
  and one that satisfies the write shape (`--working-memory <abs-path>`
  in, Model-C-classified canonical-memory writes out, `canonize:
  created=<N> updated=<M> skipped=<K>` exit summary on stdout).

Yoke v2.0.0 ships with one curated provider entry — `bedrock` —
backed by the `claude-bedrock` peer plugin. Additional providers are
trivial to land: a 4–6 line YAML entry in `providers.yaml` plus the
peer plugin itself. There is no dynamic discovery, no convention-based
scanning, and no local override; the curated list in `providers.yaml`
is the single source of truth.

To inspect the curated providers:

```bash
yq '.providers' /path/to/claude-yoke/providers.yaml
```

To select a provider for a host project, run `/yoke:bootstrap` (see
below) and either pick interactively or pass `--provider <name>`.

## Installing the Bedrock provider plugin

`claude-bedrock` is a peer plugin distributed independently of Yoke.
Install it from the Claude Code marketplace before running
`/yoke:bootstrap` against any project that will use the `bedrock`
provider entry:

```bash
# From the Claude Code marketplace UI:
#   /plugins → search "claude-bedrock" → install
#
# Or via the CLI:
#   claude plugin install claude-bedrock
```

Verify the registered Bedrock skills are available — `/bedrock:ask`
and `/bedrock:canonize` are the two the Yoke facade dispatches against;
`/bedrock:teach`, `/bedrock:preserve`, `/bedrock:compress`,
`/bedrock:vaults`, `/bedrock:confluence-to-markdown`, and
`/bedrock:gdoc-to-markdown` are also part of the plugin and remain
available for direct use when you specifically want a Bedrock-only
flow.

If you are using a non-Bedrock provider, install that provider's
plugin instead and adjust the provider key during bootstrap.

## Running `/yoke:bootstrap`

Inside any host project (clean working tree recommended):

```bash
/yoke:bootstrap                 # interactive — prompts for provider selection
```

Or non-interactively:

```bash
/yoke:bootstrap --provider bedrock --non-interactive
```

`/yoke:bootstrap` does five things, in order:

1. **Verifies the environment.** The host directory must be a git
   repo. `gh` CLI must be installed and authenticated. bash 4+ must
   be on `$PATH`.
2. **Selects the active provider.** Reads the curated entries from
   `providers.yaml`. With `--provider <name>`, picks that entry
   directly (and aborts if it is not registered). Without flags, lists
   the available entries and prompts for a selection. Warns if the
   selected provider's `requires.plugin` is set and the named peer
   plugin is not installed.
3. **Detects v1.x state.** If `<plugin_dir>/memories.json` exists or
   `.yoke/config.yaml` is present but lacks
   `canonical_memory.provider`, bootstrap prints
   `wm: legacy Yoke v1.x state detected. Migrating to v2.0.0 schema.`
   and switches into the migration flow (preserves `url`/`name`/
   `default_branch` as passthrough keys; defaults provider to
   `bedrock`; removes `memories.json` after a final confirmation).
4. **Writes `.yoke/config.yaml`** from `templates/yoke-config.yaml`,
   substituting the selected provider into `canonical_memory.provider`
   plus any provider-specified `config_passthrough` keys.
5. **Creates `.yoke/runtime/` and `.yoke/.gitignore`.** The archive
   categories (`prds/`, `specs/`, `sprints/`, `acceptance-contracts/`,
   `contracts/`, `sensors/`) are versioned by the host project; only
   `runtime/` is gitignored.

After bootstrap completes, `.yoke/` contains exactly `config.yaml`,
`.gitignore`, and `runtime/`. Archive categories are created lazily by
downstream skills (`/yoke:discover`, `/yoke:tech-spec`, etc.) on first
use.

## Day-to-day usage

After bootstrap, use the two facade verbs for every canonical-memory
read and every canonical-memory write:

```bash
/yoke:search-canonical-memory "what does Yoke decide about model C governance?"
/yoke:canonize       # at the end of a converged ralph loop, or manually
```

`/yoke:search-canonical-memory` resolves the active provider and
dispatches to the provider's pinned `skills.search` (e.g. for the
Bedrock provider, this is `/bedrock:ask`). The response is byte-
equivalent to invoking the provider skill directly. The facade writes
nothing on disk.

`/yoke:canonize` resolves the active provider and dispatches to the
provider's pinned `skills.canonize` (e.g. `/bedrock:canonize`) with
`--working-memory <abs-path-to-.yoke>`. The provider applies Model C
governance (low / medium / high / regulatory) and returns a
`canonize: created=<N> updated=<M> skipped=<K>` line. The facade
appends a single `canonize:` line to `.yoke/runtime/progress.md`
recording the dispatch.

Every other Yoke skill (`/yoke:discover`, `/yoke:tech-spec`,
`/yoke:acceptance-contract`, `/yoke:implement`, `/yoke:drift-sense`,
`/yoke:status`, `/yoke:ack-sensors`) runs a hard-break pre-flight at
its top: it sources `lib/yoke-prelude.sh`, calls `yoke_require_provider`,
and aborts non-zero with the binding stderr literal
`wm: canonical_memory.provider not configured. Run /yoke:bootstrap to
migrate.` if `.yoke/config.yaml` lacks the provider key. Only
`/yoke:bootstrap` skips the pre-flight — it is the migration entry
point.

## Provider-specific deep dives

### Bedrock — markdown frontmatter graph in a separate git repo

The Bedrock provider stores entities as markdown files with YAML
frontmatter, organized into a small set of entity types (actors,
people, teams, concepts, topics, discussions, projects, fleeting). The
graph is the union of every entity's `depends_on`, `supersedes`,
`applies_to`, and `contradicts_with` edges. `/bedrock:ask` walks that
graph; `/bedrock:canonize` writes new entities under Model C and
opens PRs on the substrate repo.

Bedrock-specific configuration (vault path, vault registry, etc.) is
managed by the `claude-bedrock` plugin itself — see its README for
the per-vault setup. Yoke does not touch Bedrock's vault registry
directly; it only forwards `url`, `name`, and `default_branch` as
opaque passthrough keys when bootstrapping the Bedrock provider.

### Other providers

Any plugin that implements the working-memory contract documented in
[`canonical-memory-provider-contract.md`](canonical-memory-provider-contract.md)
qualifies. To add a new provider, open a PR against `claude-yoke`
that appends an entry to `providers.yaml` (schema version 1 is
frozen for v2.0.0):

```yaml
providers:
  <provider-name>:
    description: "<one-line description>"
    requires:
      plugin: <plugin-id-on-marketplace>
      min_version: "<semver>"
    skills:
      search: "<plugin>:<skill>"
      canonize: "<plugin>:<skill>"
    config_passthrough:
      - <key-in-canonical_memory-block>
```

Provider-specific UX (vault listing, healthcheck dashboards, sync
behaviors, etc.) lives inside the provider plugin and is out of
scope for `claude-yoke`.

## Host-project `CLAUDE.md` integration

Yoke parses your project's `CLAUDE.md` to discover available sensors.
Use these conventions:

```markdown
## Testing
- `npm test` — run unit tests
- `pytest tests/` — run Python tests

## Linting
- `npm run lint` — run linter
- `mypy --strict` — strict type checking

## Build
- `npm run build` — production build
- `cargo build --release` — release build
```

**Parser rule.** The Validator (`lib/sensors/discover-from-claude-md.sh`)
matches headings case-insensitively (`## Testing`, `## testing`, `## Build`,
…) and walks bullet lines under each section. **The first backticked
segment in each bullet is treated as the runnable command.** Anything
before or after the backticks is ignored — it can be free prose
(e.g. "— run unit tests"). Bullets without a backticked segment are
skipped silently.

If `CLAUDE.md` is missing or has no recognized sections, the Validator
asks you directly which commands the project uses (and you can paste
them into `CLAUDE.md` afterwards so they're discoverable next time).

**Anti-patterns.** Avoid putting multiple commands in one bullet — only
the first backticked segment is captured. Avoid backticked segments
that are not commands (e.g. flag descriptions); the parser doesn't
distinguish.

## Write protocol — Model C

Canonical-memory writes are **always** PRs on the substrate repo, and
the provider is the agent that opens them. Ratification is the merge
itself. Yoke surfaces Model C only as the impact-class taxonomy
applied at `/yoke:canonize` invocation; the actual gating, CODEOWNERS
routing, and merge behavior live inside the provider.

| Impact | PR behavior |
| :--- | :--- |
| Low | Auto-merge after CI checks |
| Medium | Veto window (default 24h, configurable via `.yoke/config.yaml` `overrides.model_c.veto_window_hours`) before auto-merge |
| High | `auto-merge: never` — explicit human approval |
| Regulatory | `auto-merge: never`; routed to Compliance via `CODEOWNERS` |

Rollback is `git revert` on the substrate repo.

### CODEOWNERS for regulatory routing

Regulatory-impact propositions require Compliance review. The
provider's substrate repo must declare ownership rules in a
`CODEOWNERS` file (one of `CODEOWNERS`, `.github/CODEOWNERS`, or
`docs/CODEOWNERS`) to route reviews automatically. Recommended
skeleton:

```
# Compliance owns all regulatory-impact entries
/policies/regulatory/   @your-org/compliance
/policies/pci/          @your-org/compliance
/policies/lgpd/         @your-org/compliance
/policies/gdpr/         @your-org/compliance
/policies/hipaa/        @your-org/compliance

# Default: any harness engineer can review low/medium/high
*                       @your-org/harness-engineers
```

When CODEOWNERS is absent, the provider should still open the PR with
`auto-merge: never` plus a warning comment — but routing is not
guaranteed.

## What canonical memory is **not**

- Not a knowledge graph for arbitrary org content (that's the provider
  plugin's substrate of choice — Bedrock vault, or whatever your team
  already uses).
- Not a substitute for ADRs in the project repo (project ADRs cover
  decisions scoped to one project; canonical memory captures
  cross-project doctrine).
- Not a free-write store — every entry traces back to a specific
  failure or hard external constraint, or it's a candidate for
  pruning.

## See also

- [`migration-v1-to-v2.md`](migration-v1-to-v2.md) — upgrade runbook
  from Yoke v1.x.
- [`canonical-memory-provider-contract.md`](canonical-memory-provider-contract.md)
  — the contract any provider plugin must implement.
- [`architecture.md`](architecture.md) — the v2.0.0 dispatch-path
  diagram and the three-subagent runtime topology.
- [`troubleshooting.md`](troubleshooting.md) — common errors and
  fixes, including the v2.0.0 hard-break path.
