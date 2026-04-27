# Sprint 01 of 02: Move `.yoke/.current` into `.yoke/runtime/`

> Migrated from: # Spec: Move `.yoke/.current` into `.yoke/runtime/` — Part 1 (functional)


> Generated via /vibeflow:gen-spec on 2026-04-27. Atomic functional cut
> + all impacted tests. Budget revised to ≤ 8 files for atomicity (the
> alternative is a CI-red intermediate state, which violates the
> implementation-plan convention "every sprint ships an installable
> plugin"). Index.md "≤ 4 files per task (minimum; revise upward as the
> codebase grows)" expressly allows the upward revision.

## Objective

Consolidate the active-task pointer (`.yoke/.current`) into
`.yoke/runtime/.current` so the host project has a single ephemeral
working-memory directory instead of two adjacent ignored paths.

## Context

Today `.yoke/` carries two gitignored items at the root:
`.yoke/.current` (per-worktree active-task pointer, 1 file) and
`.yoke/runtime/` (cycle artifacts, many files). Both have the same
lifetime ("task / sprint / PR scope" per `patterns/memory-model.md`)
and the same blast radius (per-worktree, never shared, never durable).
Splitting them across two locations means:

- Two gitignore rules instead of one (`.current` + `runtime/`).
- `wm_runtime_cleanup` (just landed in `runtime-cleanup`) only
  reclaims `runtime/`, leaving `.current` to dangle until
  `/yoke:discover` overwrites it.
- The bootstrap `.gitignore` template, four downstream skill SKILL.md
  files, four test files, and one hook comment all carry the
  `.yoke/.current` literal.

Folding `.current` into `runtime/` collapses the layout: one ignore
rule (`runtime/`), one cleanup primitive (`wm_runtime_cleanup`
already wipes everything inside), one ephemeral directory.
Side-effect: on MERGE-READY + canonize-success, the active-task
pointer is also cleared. That is the desired behavior — the next
`/yoke:discover` writes a fresh pointer, and "last task touched"
state is genuinely ephemeral.

This is a *deliberate revision* of the runtime-cleanup spec's
anti-scope ("No change to `/yoke:bootstrap`. Its existing gitignore
write is correct.") — that anti-scope is now superseded; bootstrap's
gitignore literal must drop the `.current` line.

## Definition of Done

1. `lib/working-memory/paths.sh` defines `WM_CURRENT_FILE` as
   `${WM_RUNTIME_DIR}/.current`; `wm_active_slug`, `wm_set_active`,
   and `wm_clear_active` operate on the new path; `wm_set_active`
   ensures `${WM_RUNTIME_DIR}` exists (`mkdir -p`) before writing
   so first-discover on a fresh repo succeeds.
2. `lib/working-memory/cleanup.sh` `_WM_GITIGNORE_CONTENT` is
   exactly `runtime/` (single line, no `.current`); the self-heal
   notice text is updated to mention only `runtime/`.
3. `skills/bootstrap/SKILL.md` Step 5 declares the new gitignore
   content (single line `runtime/`) and updates the rationale prose
   accordingly.
4. `hooks/verify-acceptance.sh` comment block referencing
   `.yoke/.current` reflects the new path.
5. All four impacted test files
   (`tests/working-memory.test.sh`, `tests/bootstrap.test.sh`,
   `tests/perf-quickwins-part-1.test.sh`,
   `tests/ack-sensors-inferential.test.sh`) read/write `.current`
   at the new location and assert the new gitignore content. Every
   test file PASSes after the change.
6. **(craftsmanship)** Zero hardcoded `.yoke/.current` strings remain
   in `lib/`, `hooks/`, or `skills/bootstrap/SKILL.md`; downstream
   skill SKILL.md prose (covered in Part 2) is the only place the
   literal still appears, and that is intentional. No conventions.md
   Don'ts violated.
7. **(integration smoke)** Running `wm_runtime_cleanup "merge-ready"
   "0"` on a populated runtime/ directory wipes `.current` along
   with cycle artifacts; the runtime-cleanup smoke (cases f/g) still
   passes because the wipe primitive (`wm_wipe_runtime`) is
   path-agnostic.

## Scope

- `lib/working-memory/paths.sh`:
  - Change `readonly WM_CURRENT_FILE="${WM_ROOT}/.current"` to
    `readonly WM_CURRENT_FILE="${WM_RUNTIME_DIR}/.current"`. The
    constant ordering already declares `WM_RUNTIME_DIR` before
    `WM_CURRENT_FILE` (line 50 vs 49 today — re-order if needed
    so the new declaration sees `WM_RUNTIME_DIR`).
  - In `wm_set_active`, replace `mkdir -p "$WM_ROOT"` with
    `mkdir -p "$WM_RUNTIME_DIR"`. The runtime dir is the new home
    for `.current`; the parent `.yoke/` is implicitly created by
    `mkdir -p`.
  - Update the layout-doc comment block at the top of paths.sh
    (lines 8-22) to show `.current` under `runtime/`.
- `lib/working-memory/cleanup.sh`:
  - Change `_WM_GITIGNORE_CONTENT` from `$'.current\nruntime/'` to
    `'runtime/'` (single line).
  - Update the notice string in `wm_gitignore_self_heal` from
    `repaired .yoke/.gitignore (wrote: .current, runtime/)` to
    `repaired .yoke/.gitignore (wrote: runtime/)`.
- `skills/bootstrap/SKILL.md`:
  - Step 5 (lines 115-120 today): change the embedded code block
    from two lines to one (`runtime/`); update the rationale prose
    to reflect that `runtime/` now also covers `.current` because
    `.current` lives inside it.
- `hooks/verify-acceptance.sh`:
  - Update the comment at line 24 from `.yoke/.current` to
    `.yoke/runtime/.current`.
- `tests/working-memory.test.sh`:
  - The `.gitignore` setup at line 59:
    `printf 'runtime/\n' > .yoke/.gitignore`.
  - The allowed-location whitelist (around line 88) replaces
    `.yoke/.current)` with `.yoke/runtime/.current)`.
  - Assertion (d) gitignore-content expectation: change from
    `$'.current\nruntime/'` to `'runtime/'`. Header comment in the
    file (line 13) updates to match.
  - Assertion (e) `.current` size check: read from
    `.yoke/runtime/.current` instead of `.yoke/.current`.
  - Cleanup-helper smoke (h): the `expected_gi_full` constant
    becomes `'runtime/'`; the incomplete-content fixture used to
    trigger repair stays as a plausible incomplete-state seed (e.g.
    empty file, or a stray `runtime`-without-slash) — pick whatever
    plausibly exercises the "needs repair" branch.
- `tests/bootstrap.test.sh`:
  - The `.gitignore` write at line 67:
    `printf 'runtime/\n' > .yoke/.gitignore`.
  - The expectation at line 84:
    `expected=$'runtime/'`.
  - Header comment (line 6) and any other prose mentioning
    `.current\nruntime/` updates.
- `tests/perf-quickwins-part-1.test.sh`:
  - Line 146: replace
    `echo -n "$slug" > .yoke/.current` with
    `mkdir -p .yoke/runtime && echo -n "$slug" > .yoke/runtime/.current`.
- `tests/ack-sensors-inferential.test.sh`:
  - Line 255: replace
    `echo 2026-04-26-test-slug > "$helper_tmp/.yoke/.current"` with
    `mkdir -p "$helper_tmp/.yoke/runtime" && echo 2026-04-26-test-slug > "$helper_tmp/.yoke/runtime/.current"`.

## Anti-scope

- **No change to skill SKILL.md prose** in `discover`, `status`,
  `tech-spec`, `acceptance-contract`, `implement`. Doc-only edits
  ship as Part 2 — they don't affect runtime correctness, so
  splitting them out keeps Part 1 focused.
- **No transition shim / dual-write.** Yoke is pre-1.0 (manifesto +
  CLAUDE.md). No backwards-compat constraint with old `.yoke/.current`
  layouts. Cut over atomically.
- **No new helper functions.** `wm_active_slug`, `wm_set_active`,
  `wm_clear_active` retain their signatures; only the file path
  they read/write changes.
- **No changes to `wm_runtime_cleanup` semantics.** The wipe
  helper already deletes `find $WM_RUNTIME_DIR -mindepth 1` —
  `.current` simply joins the set of files wiped. No new gating,
  no new args.
- **No change to canonize handoff or `/yoke:preserve`.**
- **No deprecation warning for old `.yoke/.current` paths.**
  Tests own the breakage signal; users who upgrade in place will
  see `wm_active_slug` print "no active task" because the old file
  is no longer read. They can run `/yoke:discover` to recover. A
  one-line note in the eventual release CHANGELOG covers this; not
  in this spec.
- **No `.yoke/.current` migration script.** Pre-1.0 + manual
  bootstrap convention says no.

## Technical Decisions

### 1. New path is `${WM_RUNTIME_DIR}/.current`, not `${WM_RUNTIME_DIR}/current`

Keep the leading dot. Rationale:
- Preserves the "hidden ephemeral state" semantic that justified the
  dot in the original location.
- Matches sibling files inside `runtime/`: `.cycle-counter`,
  `.snapshots/`, `.judge-verdicts/`, `.task-spawn-log`,
  `.trigger4-packet.yaml`, `.merge-ready-snapshot.yaml`,
  `.deferred-sensors.json`. The dot prefix is the established
  convention for runtime internals.
- No naming collision risk with archive directories (which are
  versioned and live as siblings of `runtime/`, not inside it).

### 2. Re-order constants in paths.sh so `WM_RUNTIME_DIR` declares first

`WM_CURRENT_FILE` will reference `WM_RUNTIME_DIR`. Bash `readonly`
declarations are evaluated top-to-bottom; the dependent constant
must follow its dependency. Today the order is `WM_CURRENT_FILE`
(line 49) then `WM_RUNTIME_DIR` (line 50). Swap.

### 3. `wm_set_active` mkdir-s `WM_RUNTIME_DIR`, not `WM_ROOT`

First `/yoke:discover` runs in a freshly-bootstrapped `.yoke/` that
has only `config.yaml` and `.gitignore` — no `runtime/`. The set-
active call must succeed without prior `wm_wipe_runtime` or
implement-preflight `mkdir`. `mkdir -p "$WM_RUNTIME_DIR"` creates
both `.yoke/` and `.yoke/runtime/` if absent (mkdir is recursive
under `-p`).

### 4. Side-effect: `wm_runtime_cleanup` clears `.current`

Documented intent. The helper's spec'd behavior (DoD #1 of
runtime-cleanup) is "delete contents of `$WM_RUNTIME_DIR`" —
`.current` is a content of that directory after this spec lands.
No special-casing. Open Question #3 of the runtime-cleanup PRD
("`.current` cleanup. Leaning leave-it") is hereby resolved
against leave-it: clear it on MERGE-READY, let `/yoke:discover`
write a fresh pointer for the next task. Trade-off accepted: the
"last task touched" signal is lost on MERGE-READY exit. Mitigation:
the host project's git history retains the last task's PR.

### 5. Header comment in paths.sh becomes the canonical layout doc

The block at lines 8-22 of `paths.sh` is the single source of truth
for the working-memory tree shape. Update it to show `.current`
under `runtime/`. Skill SKILL.md prose can drift; paths.sh cannot.

## Applicable Patterns

- **`patterns/memory-model.md`** — working-memory lifetime ("task /
  sprint / PR scope"). Consolidating two ephemeral surfaces into
  one strengthens the lifetime claim. Pattern itself unchanged.
- **`patterns/ralph-loop.md`** — termination semantics. Cleanup
  behavior at MERGE-READY now also covers `.current` as a natural
  consequence; no new code path, no new branch.
- **`patterns/plugin-structure.md`** — repo layout discipline. The
  paths.sh layout-doc comment block is the canonical declaration;
  this spec keeps it accurate.
- **conventions.md "Environment designers, not code writers"** —
  the simplification (one ephemeral dir, one ignore rule) reduces
  the number of failure modes a user can hit. No new sensors, no
  new agentic surface.
- **conventions.md "Back-pressure: success silent, failures
  verbose"** — `wm_gitignore_self_heal`'s notice line shrinks to
  match the simpler content; silent on correct still holds.

## Risks

- **R1 — Tests outside the listed four also reference
  `.yoke/.current` indirectly.** Mitigation: re-grep the codebase
  during implementation (`grep -rn "\.yoke/\.current\|WM_CURRENT_FILE"
  lib/ skills/ hooks/ tests/ agents/`) before declaring DoD #5
  complete. The grep done during gen-spec found exactly the four
  test files in scope; if a fifth shows up, expand DoD #5 to cover
  it.
- **R2 — `wm_set_active` race on first run.** If two
  `/yoke:discover` invocations race to write `.current`, both could
  attempt `mkdir -p` and one of the writes could clobber the other.
  Mitigation: not a regression — same race exists today against
  `.yoke/.current`. No new exposure.
- **R3 — Open repos with `.yoke/.current` already present.**
  Existing host projects upgrading in place will have a stale
  `.yoke/.current` (now ignored by code) and no
  `.yoke/runtime/.current`. `wm_active_slug` returns "no active
  task". Recovery: `/yoke:discover` (continue or new). Acceptable
  for pre-1.0; a one-line note in the next release notes is
  enough. Not in this spec's scope.
- **R4 — Tests asserting `.gitignore` line count fail
  unexpectedly.** Some tests assert the exact two-line content.
  All four listed test files have been audited and updated in the
  scope above. Re-grep R1 catches stragglers.
- **R5 — `wm_runtime_cleanup` clearing `.current` surprises a
  user mid-debug.** They MERGE-READY a task, then try to inspect
  what task was last active and find no pointer. Mitigation: the
  exit summary already prints the slug + PR URLs (via the canonize
  handoff in `skills/implement/SKILL.md` §3), so the information
  is on stdout. The `.current` file is not the source of truth
  for "what was the last task" — git/PR history is.

## Files touched (≤ 8, atomicity revision)

1. `lib/working-memory/paths.sh` — constant reorder + path change
   + `wm_set_active` mkdir target + layout-doc update.
2. `lib/working-memory/cleanup.sh` — gitignore literal + notice text.
3. `skills/bootstrap/SKILL.md` — Step 5 gitignore literal +
   rationale prose.
4. `hooks/verify-acceptance.sh` — comment line 24.
5. `tests/working-memory.test.sh` — `.gitignore` literal,
   allowed-location whitelist, assertion (d) expectation, assertion
   (e) path, helper-smoke (h) `expected_gi_full`.
6. `tests/bootstrap.test.sh` — `.gitignore` literal + expected
   constant + header comment.
7. `tests/perf-quickwins-part-1.test.sh` — `.current` write path.
8. `tests/ack-sensors-inferential.test.sh` — `.current` write path.
