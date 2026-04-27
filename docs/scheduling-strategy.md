# Scheduling strategy — Phase 6 drift sensing

Phase 6 (drift sensing) is the only Yoke phase that runs **outside the
change lifecycle**. Per `concepts/yoke-pattern-phase-flow`, it observes
three targets continuously: the host project's codebase, canonical
memory, and historical working-memory traces. This document records the
v1.0 scheduling decision and the documented fallback paths.

## Decision (v0.7.0): GitHub Actions

The default scheduler is **GitHub Actions**, configured at
`.github/workflows/yoke-drift-sense.yml`. The workflow runs daily at
06:00 UTC and on manual `workflow_dispatch`. Findings are posted as a
GitHub issue **only when they differ from the last run** (idempotent
via SHA-256 signature comparison stored at
`.yoke/.drift-sense-last-signature`).

### Rationale

- **Already git-native.** Canonical memory is a git repo; ratification
  is PR-based. Drift sensing fits the same surface naturally.
- **Familiar audit trail.** Every team using Yoke already understands
  Actions logs, issue notifications, and `gh` CLI permissions.
- **No daemon to operate.** Local cron + daemons add per-machine
  failure modes the team has to support.
- **Cheap.** A daily cron run typically completes within a few minutes.

### Trade-offs accepted

- Requires GitHub. GitLab CI / Jenkins / self-hosted runners all
  support equivalent cron + issue-creation semantics, but the
  reference workflow ships only the GitHub-Actions form. Adapt
  `yoke-drift-sense.yml` to your runner format if you're elsewhere.
- Workflow output is bounded by GitHub Actions runtime (`timeout-minutes: 15`
  in the reference workflow). For very large canonical-memory repos
  (>10 000 entries), consider raising the timeout or sharding the
  invocation by target.
- Daily cadence is the recommended default. Hourly is too noisy for
  drift-sensing signals; weekly is too coarse for stale-rule
  detection. Adjust the `cron:` field to your operational appetite.

## Credentials walkthrough

`.github/workflows/yoke-drift-sense.yml` declares two permissions:

```yaml
permissions:
  contents: read
  issues: write
```

These are the minimum needed to:

1. Check out the host repo (read).
2. Open issues with the findings (write).

The `${{ secrets.GITHUB_TOKEN }}` provided automatically by Actions has
both permissions by default. **No manual secret configuration is
required for the default flow.**

If the host project also wants drift-sense to operate against the
**canonical-memory repo** (when it's separate from the host), supply a
`YOKE_CANONICAL_TOKEN` secret with `repo` scope and reference it in the
workflow's `env:` section (an extension shipped in v1.0+).

## Issue label setup

The workflow applies the `yoke-drift-sense` label to every issue it
creates. Configure this label once per repo:

```bash
gh label create "yoke-drift-sense" --color FFB000 --description "Drift findings from Yoke Phase-6 sensing"
```

Without the label the workflow logs a warning but still creates the
issue (no hard failure).

## Fallback backends (documented, not implemented in v1.0)

These remain on the table for future versions or for users who can't
run GitHub Actions in their environment. v1.0 does not ship them.

### (a) Local cron + plugin CLI

```cron
# /etc/cron.daily/yoke-drift-sense
0 6 * * * /usr/bin/env bash $YOKE_ROOT/lib/canonical-memory/staleness-check.sh > /var/log/yoke/drift-$(date +\%F).yaml
0 6 * * * /usr/bin/env bash $YOKE_ROOT/lib/canonical-memory/trace-analyzer.sh >> /var/log/yoke/drift-$(date +\%F).yaml
```

Pros: no GitHub dependency. Cons: per-machine, not collaborative, no
issue tracker integration, no idempotency built in.

### (b) Local daemon

A long-running process at `~/.yoke/daemon` that wakes on a configurable
schedule and writes findings into `.yoke/drift/`. Pros: scriptable and
extensible. Cons: process supervision is the user's problem; harder to
debug across teammates.

### (c) Other CI providers

GitLab CI / Jenkins / CircleCI all support equivalent cron + artifact
+ issue-creation flows. Adapt the reference workflow's three steps
(checkout → run drift-sense → post issue if changed) to the target
provider's syntax. The library scripts (`staleness-check.sh`,
`trace-analyzer.sh`) are provider-agnostic.

## Operational notes

- The workflow is **read-only with respect to canonical memory**. Drift-sense
  never writes to the canonical-memory repo — findings can become
  Model-C deprecation propositions later, but that's a separate
  `/yoke:canonize` invocation.
- Drift-sense issue tracker noise → tighten thresholds in
  `.yoke/config.yaml` `overrides.drift_sense:` (`staleness_max_days`,
  `recurrence_min`).
- Workflow failures should be loud — any `::error::` in the logs is
  worth investigating, not silently ignored.
- Findings older than two weeks should be pruned manually if not
  acted on (drift-sense isn't a backlog tool).
