# Yoke quickstart

This guide takes a fresh project from zero to a merged Yoke task on
**v2.0.0**.

## 0. Install

See [`installation.md`](installation.md). At v2.0.0, Yoke depends on
a peer canonical-memory provider plugin — install
[`claude-bedrock`](https://github.com/iurykrieger/claude-bedrock)
(the reference provider) alongside Yoke before running
`/yoke:bootstrap`. Other providers can ship as alternative peer
plugins; see [`canonical-memory-setup.md`](canonical-memory-setup.md).

## 1. Bootstrap

In a project repo (clean working tree recommended):

```
/yoke:bootstrap
```

Bootstrap will:

- Verify dependencies (`gh`, bash 4+).
- Select the active canonical-memory provider — interactively from
  `providers.yaml`, or via `--provider <name>`.
- Detect any v1.x state (`<plugin_dir>/memories.json` or a
  `.yoke/config.yaml` lacking `canonical_memory.provider`) and
  migrate it to the v2.0.0 schema, preserving `url`, `name`, and
  `default_branch` as `config_passthrough` keys.
- Create `.yoke/config.yaml` at the project root.
- Add a starter `CLAUDE.md` if your project doesn't have one (with
  `## Testing`, `## Linting`, `## Build` sections that Yoke parses
  for sensor discovery).

If you already have a Yoke v1.x project, run the same command — it
auto-detects v1.x state and migrates the schema. See
[`migration-v1-to-v2.md`](migration-v1-to-v2.md) for the full upgrade
runbook.

## 2. Discovery — Phase 1

Describe a task in natural language:

```
/yoke:discover "I want a payment-reversal service"
```

The Generator will ask clarifying questions, draft a PRD, and pause for your
approval. The PRD lands in `.yoke/prds/<slug>.md`.

## 3. Subsequent phases

Once the PRD is approved, walk through the remaining commands in
order:

```
/yoke:tech-spec              # Phase 2 — Tech Spec from approved PRD
/yoke:acceptance-criteria    # Phase 3 — binding contract
/yoke:implement              # Phase 4 — adversarial ralph loop with hard bounds
/yoke:canonize               # Phase 5 — propose canonical-memory writes
/yoke:drift-sense            # Phase 6 — continuous drift sensing
```

Plus support skills:

```
/yoke:search-canonical-memory "<query>"   # provider-agnostic canonical-memory read
/yoke:status                              # current task state
```

`/yoke:search-canonical-memory` and `/yoke:canonize` are the only two
verbs your code or agents should reference for canonical-memory
access. They resolve the active provider via `providers.yaml` plus
`.yoke/config.yaml :: canonical_memory.provider`, then dispatch
verbatim to the provider's pinned skill (e.g. `/bedrock:ask`,
`/bedrock:canonize`). The previous v1.x canonical-memory verbs are
gone from the Yoke namespace — they live under the provider's namespace
now (e.g. `/bedrock:ask`, `/bedrock:canonize` for the Bedrock provider).

## 4. Architecture overview

See [`architecture.md`](architecture.md) for the 1-page summary, the
v2.0.0 dispatch-path diagram, and the runtime topology, or read the
full manifesto at <https://github.com/iurykrieger/yoke/blob/main/yoke.md>.
