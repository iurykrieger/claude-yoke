# Spec: Runtime cleanup post-implementation

> Generated via /vibeflow:gen-spec on 2026-04-27 from
> `.vibeflow/prds/runtime-cleanup.md`. Budget: ≤ 4 files.

## Objective

Make `/yoke:implement` self-healing for `.yoke/.gitignore` at preflight
and self-cleaning for `.yoke/runtime/` contents on a successful
MERGE-READY exit, so host-project PRs never carry ephemeral cycle
artifacts.

## Context

`.yoke/runtime/` holds per-cycle judge verdicts, sensor snapshots,
deferred-sensor queues, the cycle counter, status snapshots and the
spawn log — all ephemeral per the two-tier memory model
(`patterns/memory-model.md`: lifetime = "task / sprint / PR scope").
`/yoke:bootstrap` already writes `.yoke/.gitignore` with `runtime/` +
`.current` (`skills/bootstrap/SKILL.md:115-119`,
`tests/bootstrap.test.sh:67`). Two real-world failure modes still
ship runtime artifacts into pull requests:

1. Host projects bootstrapped before the gitignore was added keep
   `.yoke/runtime/` files in the index; `.gitignore` does not untrack.
2. `/yoke:implement` exits without sweeping its own working set, so
   the user's manual commit step (or any `git add -A` wrapper) drags
   leftover files into the PR.

The canonize handoff (`skills/implement/SKILL.md` §3) is the durable
hand-off point — once it returns success, the runtime working set has
no remaining purpose. This spec wires that fact into the skill.

## Definition of Done

1. `/yoke:implement` deletes the contents of `wm_runtime_dir` for the
   active task on a MERGE-READY exit, **only after** the canonize
   handoff returns exit 0. The directory itself remains.
2. `/yoke:implement` does **not** delete runtime contents on any
   non-MERGE-READY termination (`divergence`, `contract-conflict`,
   `hard-bound`, `infeasibility`) — those are arbitration pauses; the
   user must be able to resume with full cycle history.
3. `/yoke:implement` writes or repairs `.yoke/.gitignore` at preflight
   when missing or when either `runtime/` or `.current` is absent;
   prints exactly one line of notice when it does, and zero lines
   when the file is already correct.
4. `/yoke:implement` prints a one-line remediation hint pointing at
   `git rm -r --cached .yoke/runtime` when `git ls-files` shows any
   tracked path under `.yoke/runtime/`; never executes the command
   itself.
5. `tests/working-memory.test.sh` asserts (a) `wm_runtime_dir` is
   empty after a simulated MERGE-READY+canonize-success path, (b)
   `wm_runtime_dir` contents are preserved on a simulated paused
   termination, (c) gitignore self-heal repairs a missing/incomplete
   `.yoke/.gitignore`, (d) the tracked-files hint fires without
   modifying git state.
6. **(craftsmanship)** Cleanup and gitignore-heal are deterministic
   bash functions in `lib/working-memory/cleanup.sh`, not agentic
   calls; they reuse `wm_runtime_dir` from
   `lib/working-memory/paths.sh` and contain zero hardcoded
   `.yoke/runtime/` strings. Conforms to "Blueprints wrapping
   agentic nodes" and "Environment designers, not code writers"
   (conventions.md), and violates none of conventions.md Don'ts.

## Scope

- New helper module: `lib/working-memory/cleanup.sh` exposing three
  bash functions:
  - `wm_gitignore_self_heal` — idempotently writes/repairs
    `.yoke/.gitignore` (literal content `.current\nruntime/\n`).
    Single notice line on repair; silent when correct.
  - `wm_check_runtime_tracked` — emits the remediation hint when
    `git ls-files --error-unmatch -- .yoke/runtime` succeeds for
    any path; returns 0 otherwise. Read-only against git state.
  - `wm_runtime_cleanup` — accepts `<termination_reason>` and
    `<canonize_exit_code>`; deletes contents of `wm_runtime_dir`
    (preserving the directory itself) iff reason == `merge-ready`
    and canonize exit == 0. Otherwise no-op.
- Hook the helper into `/yoke:implement`:
  - Preflight (Step 1, after `mkdir -p` of runtime/contracts):
    invoke `wm_gitignore_self_heal` then `wm_check_runtime_tracked`.
  - Termination (Step 4, after the canonize handoff in Step 3
    returns): invoke `wm_runtime_cleanup` with the loop's
    termination reason and the canonize call's exit code. Must run
    before the skill's exit summary line so the cleanup state is
    final at exit.
- Documentation in `skills/implement/SKILL.md`:
  - One sentence in Step 1 noting the gitignore-heal preflight call.
  - One sentence in Step 4 noting the MERGE-READY-only cleanup,
    cross-referenced to the helper function.
  - One bullet under Anti-patterns: "Do NOT call `wm_runtime_cleanup`
    on non-MERGE-READY exits — paused loops require cycle history
    for resumption."
- Tests in `tests/working-memory.test.sh`: extend the existing concept
  test with the four assertions in DoD #5. Use a temp git repo
  fixture; do not invoke the live ralph loop. Each assertion stages
  the input state, calls the helper directly, and asserts on
  filesystem + `git ls-files` output.

## Anti-scope

- **No new skill, no new agent.** Cleanup is a deterministic node of
  `/yoke:implement`, not a user-facing surface.
- **No deletion on paused exits.** Trigger-4 / hard-bound /
  contract-conflict / infeasibility leave runtime untouched.
- **No archival.** Nothing under `.yoke/runtime/` is moved to a
  long-term store. Canonize handoff already captured durable
  signal.
- **No automatic `git rm -r --cached`.** Hint only; the user runs it.
- **No retroactive sweep of historical PRs.** Files already merged
  into the host repo's `main` stay there until the user removes them.
- **No change to `/yoke:bootstrap`.** Its existing gitignore write is
  correct; the self-heal in `/yoke:implement` covers the upgrade
  path for projects bootstrapped before the gitignore landed.
- **No change to canonize handoff or `/yoke:preserve`.** Cleanup runs
  *after* canonize returns — does not alter what canonize does.
- **No new template file.** The two-line gitignore literal is
  duplicated between `skills/bootstrap/SKILL.md` and
  `lib/working-memory/cleanup.sh`. Drift surface is two lines and
  test-asserted in both places (DoD #5 + `tests/bootstrap.test.sh`),
  so a shared template is over-engineered for v0.
- **No config flag.** Cleanup-on-MERGE-READY is unconditional.
  Re-canonization workflows that need stale runtime are explicitly
  deferred (see Risks).

## Technical Decisions

### 1. Helper lives in `lib/working-memory/cleanup.sh`, not `lib/ralph-loop/`

Cleanup operates on working-memory artifacts and reuses
`wm_runtime_dir` from `lib/working-memory/paths.sh`. Co-locating it
with `paths.sh` keeps working-memory hygiene in one module.
`lib/ralph-loop/` owns loop *coordination* (`escalate.sh`,
`status-snapshot.sh`, `orchestrate.sh`); cleanup is a hygiene
concern, not a coordination concern. Trade-off: the helper is
*invoked* from the ralph loop's termination path, so a reader
chasing the cleanup call from `skills/implement/SKILL.md` Step 4 has
to follow one extra hop into `lib/working-memory/`. Acceptable —
the alternative (splitting wm-hygiene across two lib modules) is
worse.

### 2. Gate cleanup on `(reason == merge-ready && canonize_exit == 0)`

Both conditions are necessary:

- Reason gate protects paused exits (DoD #2). Without it, a user
  arbitrating a Trigger-4 divergence would lose cycle history.
- Canonize-success gate protects against the "canonize crashed,
  signal not captured" case. If canonize fails and we still wipe
  runtime, the failure is unrecoverable. Holding runtime intact
  lets the user re-invoke `/yoke:preserve` manually.

This pair is the minimum sufficient guard. A future config opt-out
(see Risk R3) could relax one without breaking the other.

### 3. `wm_runtime_cleanup` deletes contents, not the directory

`rm -rf "$(wm_runtime_dir)"/*` (with dotglob) over `rm -rf` of the
directory itself. Reason: subsequent `/yoke:implement` runs do
`mkdir -p` of `wm_runtime_dir` in preflight (Step 1, line 51 of
existing SKILL.md), so deleting the directory is equivalent — but
keeping the directory means the working-tree shape stays stable
between runs, easier to reason about in tests and debugging.

### 4. Self-heal is silent when correct, single-line when repaired

Convention "Back-pressure: success is silent, failures are verbose"
(conventions.md). Correct gitignore = no output. Repaired gitignore
= one line: `[yoke] repaired .yoke/.gitignore (added: runtime/, .current)`.
Tracked-files hint = one line: `[yoke] .yoke/runtime/ has tracked files. Run: git rm -r --cached .yoke/runtime/`.
Three states, three deterministic outputs.

### 5. Tests use direct helper invocation, not live ralph loop

`tests/working-memory.test.sh` already follows the pattern of staging
filesystem state and asserting on outcomes (`tests/working-memory.test.sh:59-127`).
The new assertions stage `.yoke/runtime/` content + git index state,
call `wm_runtime_cleanup` / `wm_gitignore_self_heal` /
`wm_check_runtime_tracked` directly, then assert. No need to spawn
a real implement run — the helpers are pure filesystem functions and
testing them directly is faster and more deterministic. The
integration-level guarantee that `/yoke:implement` calls them in the
right places is enforced by the SKILL.md prose (DoD #1, #2, #3, #4).

## Applicable Patterns

- **`patterns/ralph-loop.md`** — termination semantics. Cleanup
  attaches to Step 4 ("Termination paths") and respects the existing
  termination-reason taxonomy (`merge-ready` | `divergence` |
  `contract-conflict` | `hard-bound` | `infeasibility`). The five
  termination paths are not changed; cleanup is a *post-canonize*
  step that branches only on reason == `merge-ready`.
- **`patterns/memory-model.md`** — working-memory lifetime is
  declared "task / sprint / PR scope". This spec operationalizes the
  lifetime declaration: at PR-readiness (= MERGE-READY + canonize
  success), runtime contents are reclaimed. No change to the pattern
  itself.
- **conventions.md "Blueprints wrapping agentic nodes"** — cleanup
  is a deterministic node, not an LLM call.
- **conventions.md "Back-pressure: success is silent, failures are
  verbose"** — applied to gitignore-heal and tracked-files hint
  output.
- **Implementation Plan convention "Test file per framework
  concept"** — extends `tests/working-memory.test.sh`; does not
  introduce a new concept file. Working-memory hygiene is the same
  concept as path resolution and bootstrap output.

## Risks

- **R1 — Cleanup runs before canonize PRs are visible.** Canonize
  may open Model C PRs that take seconds to register on GitHub;
  if the user inspects `.yoke/runtime/` immediately after exit,
  it will be empty even if the PRs are still being created.
  *Mitigation:* the skill's exit summary already prints PR URLs
  (`SKILL.md:275-276` "Canonization summary: <count> PRs opened.").
  The user reads URLs from stdout, not from runtime/. Acceptable.
- **R2 — Tracked-files hint fails inside non-git directories.**
  `git ls-files` errors when run outside a repo. *Mitigation:*
  `wm_check_runtime_tracked` short-circuits on `git rev-parse
  --is-inside-work-tree` returning non-zero. No hint, no error.
- **R3 — Manual re-canonization workflow breaks.**
  `skills/implement/SKILL.md:310` advertises `/yoke:preserve` as
  re-invocable for re-canonizing stale working memory after a model
  upgrade. With auto-cleanup, runtime is gone before the user can
  re-canonize. *Mitigation accepted in v0:* canonical memory itself
  is the right re-canonization surface — if a model upgrade should
  re-evaluate stored doctrine, it should re-evaluate canonical
  memory entries directly, not stale working memory. If a real user
  surfaces this need, add `runtime.preserve_after_canonize: true`
  to `.yoke/config.yaml` as an opt-out. Not part of v0.
- **R4 — Ordering bug: cleanup before canonize PR-URL summary
  printed.** If cleanup runs *between* canonize-handoff and the
  exit summary, and the summary references files inside runtime
  (it doesn't today, but a future change might), the summary
  would print stale references. *Mitigation:* DoD #1 specifies
  cleanup runs *after* canonize returns and *before* the exit
  summary. The skill's own contract enforces the order; review
  in CR step.
- **R5 — Test fixture pollution.** Tests staging
  `.yoke/runtime/` content in the repo's tmp dirs may leak into
  commits if the tmp path is wrong. *Mitigation:* follow the
  existing pattern in `tests/working-memory.test.sh:59` of using
  `mktemp -d` per assertion and trapping cleanup in EXIT. Already
  the convention; no new risk.

## Files touched (≤ 4)

1. `lib/working-memory/cleanup.sh` (NEW) — three helper functions.
2. `skills/implement/SKILL.md` (EDIT) — preflight + termination
   integration, anti-pattern bullet.
3. `tests/working-memory.test.sh` (EDIT) — four new assertions.
4. — (held in reserve; v0 does not need a fourth file).
