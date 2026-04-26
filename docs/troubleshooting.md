# Troubleshooting

Common issues and their fixes. If your problem isn't here, open an
issue at <https://github.com/iurykrieger/yoke/issues> with the output
of `/yoke:status` and the relevant `.yoke/*.md` files.

## Installation

### `/plugin install yoke@yoke-marketplace` fails

- **Confirm Claude Code is up to date.** Yoke v1.0 targets the
  marketplace schema as of `vibeflow-claude` 1.10 and `claude-bedrock`
  1.2. If your Claude Code is older than that, upgrade first.
- **Confirm `gh` CLI is installed and authenticated.** Yoke depends on
  `gh` from Sprint-5 onward (canonical-memory PRs). Run `gh auth
  status`. If unauthenticated, run `gh auth login`.
- **bash 4 on macOS.** macOS ships bash 3 by default. Yoke's hooks and
  lib scripts target bash 4+. Install via Homebrew: `brew install
  bash`. Make sure the new bash is on your `$PATH` before
  `/usr/bin/bash`.

### `/yoke:bootstrap` aborts with "git not a repo"

- The host project must be a git repository. Run `git init` first.

### `/yoke:bootstrap` says "gh not authenticated"

- Run `gh auth login`. Yoke does not have a degraded mode in v1.0 (per
  `.vibeflow/decisions.md`); `gh` is hard-required.

## Phase 1 / Phase 2

### Generator never asks a clarifying question

- Check that you ran the skill from the project root (where
  `.yoke/config.yaml` lives).
- The Generator's persona instructs it to ask at least one clarifying
  question. If the model is silent, your idea may be flagged as "fully
  clear" — re-run with intentionally vague input to confirm.

### `/yoke:tech-spec` aborts with "PRD missing or unapproved"

- Run `/yoke:discover` first and explicitly `approve` the PRD.
- If you ran `/yoke:discover` but the artifact says `Status: draft`,
  the approval step did not complete. Re-run and follow through to the
  `approve` prompt.

## Phase 3

### `/yoke:acceptance-contract` says "no sensors discovered"

- Add `## Testing`, `## Linting`, and `## Build` sections to the host
  project's `CLAUDE.md` with bullet lines whose first backticked
  segment is the runnable command. See
  `examples/greenfield-payment-service/CLAUDE.md` for a worked example.
- `/yoke:bootstrap` creates a starter `CLAUDE.md` if your project
  doesn't have one — but only with placeholder commands. Replace them
  with your real ones.

### Validator refuses to ratify with "vague acceptance criterion"

- The Validator insists every BDD scenario have a fixture or a sensor.
  Replace any "works correctly" / "looks good" criteria with binary,
  observable ones.

## Phase 4

### `/yoke:implement` runs forever (pre-Sprint-6)

- This shouldn't happen in v1.0+ — `hooks/check-hard-bounds.sh`
  enforces N cycles + timeout + token budget, and reaching any bound
  fires the Trigger-4 packet and pauses the loop.
- If running an old branch (v0.4.0 or v0.5.0), wrap the smoke command
  in `timeout 600`.

### Trigger-4 packet emitted with `divergence_category: hard-bound-cycles`

- Hard bound reached: the loop hit `cycles_max` (default 8) without
  converging. Read the packet at `.yoke/.trigger4-packet.yaml`. Options:
  raise `overrides.hard_bounds.cycles_max` in `.yoke/config.yaml`,
  reformulate the Tech Spec, or accept the trade-off.

### "Sprint contract contradicts Acceptance Contract"

- A sprint contract proposed during Phase 4 used a verb like `relax`,
  `remove`, `skip`, `disable`, `bypass`, or `ignore` referring to a
  Contract criterion. The loop pauses for arbitration. Reformulate the
  Acceptance Contract via `/yoke:acceptance-contract` (re-ratification
  required) if the change is genuinely needed.

## Phase 5

### `/yoke:canonize` opens no PRs

- Most likely your `.yoke/contracts.md` has no qualifying contract
  (none recur enough, all have contradictory `decision:` text, or all
  are already canonized).
- Tune `.yoke/config.yaml` `overrides.canonization.repeatability_min`
  downward (default 3 → try 2) for more sensitive canonization.
- Verify `/yoke:ask` works against your canonical-memory repo
  (`/yoke:ask "anything"` should return entries or a clean empty-state
  message).

### `propose-write.sh` fails with "gh CLI not found"

- See installation troubleshooting above.

### Medium-impact PR's auto-merge never fires

- Configure auto-merge on the canonical-memory repo: Settings →
  General → Pull Requests → "Allow auto-merge".
- Verify branch protection rules don't conflict (e.g., requiring an
  approval that auto-merge alone can't satisfy).

## Phase 6

### Drift-sense workflow opens an issue every day

- The workflow is **idempotent only when findings are unchanged**. If
  your canonical memory genuinely accumulates new findings every day,
  that's working as designed — but tune the thresholds in
  `.yoke/config.yaml` `overrides.drift_sense.*` to reduce noise.
- Common cause of repeated issues: many entries with `last_validated`
  in the past triggering rolling staleness. Bulk-update
  `last_validated` to today after a manual review pass.

### Drift-sense workflow fails with "no `yoke-drift-sense` label"

- The workflow logs a warning but still creates the issue. To remove
  the warning, run once: `gh label create "yoke-drift-sense" --color FFB000`
  on the host repo.

### `/yoke:drift-sense --target codebase` finds nothing

- Add a dead-code detector to your host `CLAUDE.md` under `## Dead code`,
  `## Linting`, or `## Build`. Examples: `npm run unimported`, `ts-prune`,
  `dead_code_analyzer ./src`.

## Generic

### "skill X is missing canonical-memory access"

- All canonical-memory access goes through `/yoke:ask` invoked via the
  Skill tool. The skill is source-agnostic — any caller (Generator,
  Validator, Orchestrator, spec-phase skill, or ad-hoc human query)
  can invoke it without an active task. If you suspect a subagent is
  bypassing it, the v0 detection is declarative — the rule is stated
  in each subagent's prompt; review during code-review.
- Verify `/yoke:ask` resolves the active memory by running
  `bash lib/canonical-memory/resolve-memory.sh --memory <name>` (or
  with no flag for CWD/default resolution). The output is
  `<name>\t<path>` on success.

### Where do I find the canonical-memory repo?

- Path: registered in `<plugin_dir>/memories.json` (one entry per
  registered memory). Use `/yoke:memory list` to see all registered
  memories; the entry's `path` field is the absolute filesystem path.
  No clone cache exists — the resolution lib reads the registered path
  directly.

### How do I reset Yoke for a clean test?

```bash
rm -rf .yoke/                                    # working memory
/yoke:bootstrap                                  # re-init
```

The canonical-memory repo at the registered path is **not** managed
by Yoke — manage it with regular git.

### `/yoke:status` shows nothing

- Run from the project root. The status skill reads `.yoke/`; if you're
  in a subdirectory, it won't find anything.
