# PRD: Runtime cleanup post-implementation

> Generated via /vibeflow:discover on 2026-04-27

## Problem

Yoke-managed projects are leaking `.yoke/runtime/` artifacts into pull
requests. The folder holds ephemeral working state for the ralph loop —
per-cycle judge verdicts, sensor snapshots, deferred-sensor queues,
cycle counters, status snapshots, the spawn log — that has zero value
after the canonize handoff has lifted the durable signal into canonical
memory. When this content rides along into a PR, reviewers see noise
that obscures the real change set, and the host repository accretes
ephemeral state forever.

The leak has two root causes:

1. **Gitignore not effective in the host project.** Bootstrap *does*
   write `.yoke/.gitignore` with `runtime/` excluded
   (`skills/bootstrap/SKILL.md:115-119`), but projects that adopted
   Yoke before that gitignore existed — or that already staged
   `runtime/` files manually — keep tracking them; `.gitignore` does
   not untrack already-tracked paths.
2. **No automatic cleanup at loop termination.** `/yoke:implement`
   exits and hands off to a canonize call, but never deletes the
   runtime working set. The user's manual commit/PR step then sweeps
   the leftover files into the PR.

Today the user is expected to remember to `rm -rf .yoke/runtime/`
before opening a PR. They do not, and the artifacts ship.

## Target Audience

Developers using Yoke in a host project — i.e. anyone who runs
`/yoke:implement` and then commits + opens a PR (manually or via a
commit/PR skill). Plugin maintainers feel the same pain when running
smoke tests against fixture projects.

## Proposed Solution

Two coordinated interventions, both inside `/yoke:implement` and
`/yoke:bootstrap` — no new commands, no new agents.

1. **Cleanup at termination.** After the canonize handoff completes
   on a MERGE-READY exit, `/yoke:implement` deletes the contents of
   `.yoke/runtime/` for the active task. The directory itself stays
   (`mkdir -p` is idempotent on the next run); only its content is
   wiped. Cleanup runs only after a *successful* canonize call —
   if canonize fails, runtime is preserved so the user can re-run.
2. **Gitignore self-heal.** When `/yoke:implement` starts, it checks
   that `.yoke/.gitignore` exists and contains `runtime/` and
   `.current`. If absent or incomplete, the skill writes/repairs it
   and prints a one-line notice. If `.yoke/runtime/` is *already
   tracked* in git (`git ls-files --error-unmatch .yoke/runtime`
   succeeds), the skill prints a remediation hint pointing at
   `git rm -r --cached .yoke/runtime` — but does not run it
   automatically (untracking a path is the user's call, not the
   skill's).

The cleanup is unconditional on MERGE-READY: if the canonization
process is the durable handoff (it is — that is the whole Phase-5
contract), runtime files have no remaining purpose.

## Success Criteria

- After a MERGE-READY `/yoke:implement` run on a host project,
  `git status` shows no `.yoke/runtime/` paths.
- A subsequent `git add -A` in the host project does not stage any
  `.yoke/runtime/` content.
- A host project bootstrapped *before* the gitignore feature can
  upgrade and run `/yoke:implement` once; afterwards the gitignore
  is self-repaired and the user has been told (in a single line of
  output) what to run to untrack legacy files.
- Smoke test (added under `tests/`) drives `/yoke:implement` to
  MERGE-READY in a fixture project, then asserts the runtime/
  directory is empty and not staged.

## Scope v0

- Cleanup of `.yoke/runtime/` contents inside `/yoke:implement`,
  fired only on MERGE-READY, and only after the canonize handoff
  returns success.
- Gitignore self-heal at the start of `/yoke:implement`: write or
  repair `.yoke/.gitignore` if missing/incomplete; print a one-line
  remediation hint if `.yoke/runtime/` is already tracked.
- Smoke test asserting both behaviors.
- Documentation update: anti-pattern note in `skills/implement/SKILL.md`
  ("do not skip the cleanup; do not run it on non-MERGE-READY exits");
  one line in `templates/project-claude-md.md` clarifying that
  `.yoke/runtime/` is ephemeral.

## Anti-scope

- **No deletion on paused exits** (Trigger-4 divergence, hard-bound,
  infeasibility, contract-conflict). Those are arbitration pauses,
  not terminations; the user must be able to resume the loop with
  full cycle history. See Open Questions for the case to revisit
  this later.
- **No new "cleanup-runtime" command.** This is a behavior of
  `/yoke:implement`, not a user-facing skill. The user already
  invokes implement; they should not also have to invoke a sweeper.
- **No archiving of runtime to a `.yoke/archive/`** or similar
  long-term store. The canonize handoff is the durable record; if
  something needed to be kept, it should already be in canonical
  memory.
- **No automatic `git rm -r --cached .yoke/runtime`.** Untracking a
  user's tracked files without consent is destructive. The skill
  prints the command; the user runs it.
- **No retroactive cleanup of already-tracked files.** v0 only
  prevents *future* leakage and writes the gitignore. Files already
  in the user's git history stay there until the user removes them.
- **No change to the canonize handoff itself.** Canonization stays
  as today; cleanup is a *post-canonize* step inside
  `/yoke:implement`, not a new responsibility for the Orchestrator.
- **No change to `/yoke:preserve`'s ability to be invoked manually
  later.** Re-canonization workflows that require old runtime/
  files are explicitly out of scope (see Open Questions).

## Technical Context

Relevant facts gathered from `.vibeflow/` and the codebase:

- Bootstrap already declares the runtime/ + `.current` ignore
  pattern (`skills/bootstrap/SKILL.md:115-119`,
  `tests/bootstrap.test.sh:67`,
  `tests/working-memory.test.sh:59`). The pattern is correct; the
  problem is that pre-existing projects do not have it.
- `/yoke:implement` already has a deterministic preflight section
  (`skills/implement/SKILL.md` §1) and a deterministic termination
  step (§3 → §4) — both are the right insertion points. No new
  agentic call needed; this is a deterministic node, fits the
  "blueprints wrapping agentic nodes" invariant in the manifesto.
- Runtime paths are computed via `lib/working-memory/paths.sh`
  (`wm_runtime_dir`) — cleanup must use that helper, not hardcode
  `.yoke/runtime/`. Pattern hygiene per `.vibeflow/conventions.md`.
- The canonize handoff is foreground (`SKILL.md` §3) and returns
  inline; checking its exit before cleanup is straightforward.
- Smoke tests live under `tests/smoke/sprint-N.test.sh` and use
  external `timeout 600` (per CLAUDE.md). The new smoke fits the
  same shape.
- Manifesto invariant **"Environment designers, not code writers"**:
  this PRD treats the leak as an environment-design fix (gitignore
  + automatic sweep) rather than asking the user to remember a
  manual step.

## Open Questions

1. **Paused-exit cleanup.** Is there a future need to clean up
   runtime/ on Trigger-4 / hard-bound / infeasibility *after* the
   user has finished arbitration and decided not to resume? If yes,
   the right shape is a separate, explicit user action (e.g. a
   `/yoke:implement --abandon` flag or a small `/yoke:cleanup`
   skill), not auto-cleanup on paused exits. Out of scope for v0.
2. **Manual re-canonization.** `skills/implement/SKILL.md:310`
   advertises that `/yoke:preserve` can be re-invoked manually to
   re-canonize stale working memory (e.g. after a model upgrade).
   Auto-deleting runtime on MERGE-READY breaks this. Two options:
   (a) accept the trade-off — re-canonization is a niche workflow,
   the canonical memory itself is the right re-canonization target;
   (b) gate cleanup behind an opt-out config field (e.g.
   `runtime.preserve_after_canonize: true` in `.yoke/config.yaml`)
   for users who need the niche workflow. Recommend (a) for v0;
   revisit if a real user surfaces the need.
3. **`.current` cleanup.** The active-task pointer is also
   gitignored. Should `/yoke:implement` clear it on MERGE-READY,
   or leave it for the next `/yoke:discover` to overwrite? Leaning
   leave-it (no harm, signals "this was the last task touched").
   Confirm during gen-spec.
