# Canonical memory — setup

Yoke separates **working memory** (per-task, ephemeral, lives in your project's `.yoke/`) from **canonical memory** (organization-wide, permanent, versioned, lives in a dedicated git repo).

This document covers the canonical-memory repo: what it is, how to create it, and how to maintain it.

## What goes in canonical memory

- Ratified policies (RFC 2119, semver-tracked)
- Consolidated domain specs
- Harness templates by topology
- Resolved divergence patterns
- Structured ADRs
- Sensor calibrations (known false positives/negatives)
- State and trajectory of business projects

The scope is intentionally open. Yoke's governance — Model C — decides
**when and how** each proposition becomes doctrine, not what may be proposed.

## Creating the repo

`/yoke:bootstrap` offers to create one for you via `gh repo create`. The
default name is `<project-slug>-canonical-memory` (private). Or supply an
existing URL.

A bare canonical-memory repo has:

```
<repo>/
├── policies/
├── adrs/
├── templates/
├── divergences/
├── sensor-calibrations/
└── README.md
```

Yoke writes into these directories automatically as `/yoke:canonize` proposes
new entries (Sprint 5+).

## Per-entry format

Every canonical-memory file is markdown with mandatory YAML frontmatter:

```yaml
---
ratified_at: 2026-04-15
model_calibrated_against: claude-opus-4-7
last_validated: 2026-04-22
traceability: incidents/2026-03/payment-reversal-pii-leak.md
impact_level: regulatory   # low | medium | high | regulatory
depends_on: [policies/lgpd-art-46.md]
supersedes: []
applies_to: [services/payments/, services/refunds/]
contradicts_with: []
---
```

The relationship edges (`depends_on`, `supersedes`, `applies_to`,
`contradicts_with`) form the graph that powers `/yoke:ask`'s progressive
disclosure (subgraph queries) — shipped in Sprint 6.

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

Canonical-memory writes are **always** PRs on the substrate repo.
Ratification is the merge itself.

| Impact | PR behavior |
| :--- | :--- |
| Low | Auto-merge after CI checks |
| Medium | Veto window (default 24h, configurable via `.yoke/config.yaml` `overrides.model_c.veto_window_hours`) before auto-merge |
| High | `auto-merge: never` — explicit human approval |
| Regulatory | `auto-merge: never`; routed to Compliance via `CODEOWNERS` |

Rollback is `git revert` on the substrate repo.

### CODEOWNERS for regulatory routing (Sprint 6+)

Regulatory-impact propositions require Compliance review. The
canonical-memory repo must declare ownership rules in a `CODEOWNERS`
file (one of `CODEOWNERS`, `.github/CODEOWNERS`, or `docs/CODEOWNERS`)
to route reviews automatically. Recommended skeleton:

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

`propose-write.sh` (Sprint 6+) detects CODEOWNERS presence on regulatory
PRs. When CODEOWNERS is absent, the PR is still opened with
`auto-merge: never` plus a warning comment — but routing is not
guaranteed, so configure CODEOWNERS before regulatory writes are
expected.

## Memory registry

Starting with the canonical-memory port (Part 1+ of the bedrock import,
2026-04-25), Yoke maintains a plugin-level **memory registry** at
`<plugin_dir>/memories.json`. Each entry maps a kebab-case name to an
absolute path on disk and (optionally) the source git URL:

```json
{
  "memories": [
    { "name": "main", "path": "/Users/me/.local/share/yoke/canonical/acme-canonical-memory", "url": "git@github.com:acme/canonical-memory.git", "default": true }
  ]
}
```

Operations like `/yoke:ask`, `/yoke:preserve`, `/yoke:teach`, and
`/yoke:compress` resolve the active memory through this registry — no
more clone-each-time. Resolution chain:

1. `--memory <name>` flag (explicit).
2. CWD detection (longest-prefix match against registered paths).
3. Default-marked registry entry.
4. Error with the registry listing.

### Managing memories — `/yoke:memory`

```
/yoke:memory list                              # show all
/yoke:memory add <path> [--url <url>] [--name <name>]
/yoke:memory set-default <name>
/yoke:memory remove <name>                     # registry only; files on disk are untouched
```

`/yoke:memory add` against an empty or non-existent path scaffolds a
fresh canonical-memory repo (8 entity directories + templates +
`.yoke-memory/config.json`), then registers it.

### Plugin reinstall — recovery

The registry file lives inside the plugin directory. **If you reinstall
the Yoke plugin, `memories.json` is lost.** Files on disk are not
affected.

To recover:

1. Run `/yoke:memory add <path>` for each canonical-memory checkout you
   still have on disk. Use `--url <url>` if you remember the original
   git URL; it's optional but recommended for future re-clones.
2. Run `/yoke:memory set-default <name>` to mark the one you want as
   the default.

`/yoke:bootstrap` also runs an automatic migration on first invocation
after upgrade: if your existing `.yoke/config.yaml` has a populated
`canonical_memory.url` and there's a clone at
`~/.cache/yoke/canonical/<slug>/`, it clones to
`~/.local/share/yoke/canonical/<slug>/`, registers it, and removes the
legacy cache. Order is strict: `register → verify → delete cache`.

## What canonical memory is **not**

- Not a knowledge graph for arbitrary org content (that's vault / Bedrock / whatever your team already uses).
- Not a substitute for ADRs in the project repo (project ADRs cover decisions scoped to one project; canonical memory captures cross-project doctrine).
- Not a free-write store — every entry traces back to a specific failure or hard external constraint, or it's a candidate for pruning.
