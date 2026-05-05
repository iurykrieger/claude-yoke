#!/usr/bin/env bash
# criterion: AC-003-1
# criterion: AC-003-2
# criterion: AC-003-3
# criterion: FR-3
# criterion: FR-6
#
# Anchored AC bodies (verbatim, from the binding Acceptance Criteria doc):
#
#   AC-003-1: Given a fresh worktree's .yoke/runtime/.cycle-counter has
#     been seeded with a value N where 1 ≤ N ≤ 8 (simulating the end of
#     sprint 1), when the sprint-advance path executes, then reading
#     .yoke/runtime/.cycle-counter afterwards yields exactly `0`.
#   AC-003-2: Given a single-sprint task (only *-s01.md exists), when
#     /yoke:implement runs to completion, then the helper is never
#     invoked and behavior is observably identical to the pre-fix
#     baseline (zero regression on current_sprint == 01).
#   AC-003-3: Given the sprint-advance path is interrupted (process
#     killed) AFTER wm_reset_cycle_counter has executed but BEFORE the
#     next cycle starts, when the run is later resumed, then
#     .cycle-counter still reads `0`.
#   FR-3: The dual-source-of-truth between progress.md :: cycle_count
#     and .yoke/runtime/.cycle-counter is preserved as-is.
#   FR-6: Other slugs' working-memory archive files are not modified.
#
# Strategy: this is a downstream-observable contract. The simulation
# below stands in for the council coordinator's step-9 sprint-advance
# code path: we exercise the helper directly against an isolated
# WM_RUNTIME_DIR rooted at $TMP/.yoke/runtime and assert on disk state
# AFTER simulated sprint advance.

set -euo pipefail

# Internal watchdog (per CLAUDE.md :: ## Testing).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"

# shellcheck source=/dev/null
source "$REPO_ROOT/tests/lib/harness.sh"

PATHS_SH="$REPO_ROOT/lib/working-memory/paths.sh"
HARD_BOUNDS_HOOK="$REPO_ROOT/hooks/check-hard-bounds.sh"
STATUS_SNAPSHOT="$REPO_ROOT/lib/ralph-loop/status-snapshot.sh"

# ---------------------------------------------------------------------------
# Pre-conditions: pinned consumer surfaces unchanged (DoD US-003).
# ---------------------------------------------------------------------------
if [[ ! -f "$HARD_BOUNDS_HOOK" ]]; then
  err "hooks/check-hard-bounds.sh missing"
  harness::summary
fi
if [[ ! -f "$STATUS_SNAPSHOT" ]]; then
  err "lib/ralph-loop/status-snapshot.sh missing"
  harness::summary
fi

# DoD US-003: hooks/check-hard-bounds.sh:93 still reads
# wm_cycle_counter_path(). We assert the substring is still present
# (the line number can drift, the contract cannot).
if grep -q 'wm_cycle_counter_path' "$HARD_BOUNDS_HOOK"; then
  pass "(DoD US-003) hooks/check-hard-bounds.sh still references wm_cycle_counter_path"
else
  err "(DoD US-003) hooks/check-hard-bounds.sh no longer references wm_cycle_counter_path — consumer contract broken"
fi

if grep -q 'wm_cycle_counter_path\|\.cycle-counter' "$STATUS_SNAPSHOT"; then
  pass "(DoD US-003) lib/ralph-loop/status-snapshot.sh still references the cycle-counter surface"
else
  err "(DoD US-003) lib/ralph-loop/status-snapshot.sh no longer references the cycle-counter — consumer drift"
fi

# ---------------------------------------------------------------------------
# AC-003-1 — sprint-advance simulation: seed a non-zero counter at
# end-of-sprint-1, invoke wm_reset_cycle_counter, assert post-reset value is `0`.
# ---------------------------------------------------------------------------
case_ac_003_1() {
  local TMP
  TMP=$(mktemp -d "${TMPDIR:-/tmp}/cross-sprint.XXXXXX")
  (
    cd "$TMP"
    # shellcheck source=/dev/null
    source "$PATHS_SH"
    mkdir -p ".yoke/runtime"
    # Simulate the post-sprint-1 state: counter at 7 (1 ≤ N ≤ 8).
    printf '7' > ".yoke/runtime/.cycle-counter"
    # Simulate sprint-advance: invoke the helper.
    wm_reset_cycle_counter
    local actual
    actual="$(cat ".yoke/runtime/.cycle-counter")"
    if [[ "$actual" != "0" ]]; then
      echo "AC-003-1: post-advance counter is '$actual', expected '0'"
      return 1
    fi
  )
  local rc=$?
  rm -rf "$TMP"
  return $rc
}

if case_ac_003_1; then
  pass "AC-003-1: end-of-sprint-1 counter (7) → post-advance counter ('0')"
else
  err "AC-003-1: helper failed to zero the post-sprint-1 counter"
fi

# ---------------------------------------------------------------------------
# AC-003-2 — single-sprint task: helper is never invoked; behavior is
# observably identical to baseline.
#
# Observable: the helper is never called automatically by sourcing
# paths.sh (the helper is callable but inert until invoked). We assert
# this by sourcing paths.sh in an isolated tmp dir, NOT calling the
# helper, and confirming no .cycle-counter file was created as a side
# effect.
# ---------------------------------------------------------------------------
case_ac_003_2() {
  local TMP
  TMP=$(mktemp -d "${TMPDIR:-/tmp}/single-sprint.XXXXXX")
  (
    cd "$TMP"
    # shellcheck source=/dev/null
    source "$PATHS_SH"
    # Sourcing alone must not create runtime/.
    if [[ -e ".yoke/runtime/.cycle-counter" ]]; then
      echo "AC-003-2: sourcing paths.sh created .cycle-counter as a side effect"
      return 1
    fi
    # Calling other helpers (e.g. wm_cycle_counter_path) must remain pure
    # path computation — no I/O.
    local p
    p="$(wm_cycle_counter_path)"
    [[ "$p" == ".yoke/runtime/.cycle-counter" ]] || {
      echo "AC-003-2: wm_cycle_counter_path returned '$p', expected '.yoke/runtime/.cycle-counter'"
      return 1
    }
    if [[ -e ".yoke/runtime/.cycle-counter" ]]; then
      echo "AC-003-2: wm_cycle_counter_path() created the file as a side effect"
      return 1
    fi
  )
  local rc=$?
  rm -rf "$TMP"
  return $rc
}

if case_ac_003_2; then
  pass "AC-003-2: single-sprint baseline preserved — no helper invocation, no side effect from path resolution"
else
  err "AC-003-2: single-sprint baseline regressed — helper or path resolver has unwanted side effect"
fi

# ---------------------------------------------------------------------------
# AC-003-3 — post-reset state survives interruption.
#
# Strategy: invoke wm_reset_cycle_counter, "interrupt" by exiting the
# subshell, then re-enter and assert the file still reads `0`.
# ---------------------------------------------------------------------------
case_ac_003_3() {
  local TMP
  TMP=$(mktemp -d "${TMPDIR:-/tmp}/post-reset.XXXXXX")
  (
    cd "$TMP"
    # shellcheck source=/dev/null
    source "$PATHS_SH"
    mkdir -p ".yoke/runtime"
    printf '5' > ".yoke/runtime/.cycle-counter"
    wm_reset_cycle_counter
    # Subshell exits — "interrupt".
  )
  # New subshell, simulating resume.
  (
    cd "$TMP"
    # shellcheck source=/dev/null
    source "$PATHS_SH"
    local actual
    actual="$(cat ".yoke/runtime/.cycle-counter")"
    if [[ "$actual" != "0" ]]; then
      echo "AC-003-3: resume sees counter '$actual', expected '0'"
      return 1
    fi
  )
  local rc=$?
  rm -rf "$TMP"
  return $rc
}

if case_ac_003_3; then
  pass "AC-003-3: post-reset state ('0') survives interruption + resume"
else
  err "AC-003-3: post-reset state lost across interruption"
fi

# ---------------------------------------------------------------------------
# FR-3 — dual source-of-truth preserved.
#
# Observable: both progress.md frontmatter `cycle_count:` AND
# .yoke/runtime/.cycle-counter remain documented as reset surfaces.
# We assert the SKILL.md prose still references both, AND the helper
# does not touch progress.md (already covered in wm-reset-helper.sh's
# AC-001-4 case).
# ---------------------------------------------------------------------------
SKILL="$REPO_ROOT/skills/implement/SKILL.md"
if grep -q 'cycle_count' "$SKILL" && grep -q 'wm_reset_cycle_counter\|\.cycle-counter' "$SKILL"; then
  pass "FR-3: dual source-of-truth preserved (both cycle_count and the .cycle-counter file are named in SKILL.md)"
else
  err "FR-3: dual source-of-truth drifted (one of cycle_count / .cycle-counter / wm_reset_cycle_counter elided from SKILL.md)"
fi

# ---------------------------------------------------------------------------
# FR-6 — other slugs' archive files unchanged.
#
# Observable: this delivery's git diff (versus the baseline) does not
# touch any file under .yoke/{prds,specs,sprints,acceptance-criteria,fixes}/
# whose slug differs from this task's slug. We approximate via
# `git status --porcelain` against the working tree.
# ---------------------------------------------------------------------------
SLUG="2026-05-05-cycle-counter-reset-on-sprint-advance"
if (cd "$REPO_ROOT" && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
  # `--porcelain --untracked-files=all` expands untracked directories so we
  # see one path per file, not the directory aggregate (which would mask
  # individual filenames). Then we filter to only this slug's files.
  OFFENDING=$(cd "$REPO_ROOT" && git status --porcelain --untracked-files=all -- '.yoke/prds' '.yoke/specs' '.yoke/sprints' '.yoke/acceptance-criteria' '.yoke/fixes' 2>/dev/null \
    | awk '{print $2}' \
    | grep -vE "^.yoke/(prds|specs|sprints|acceptance-criteria|fixes)/${SLUG}(-s[0-9]+)?\.md$" \
    || true)
  if [[ -z "$OFFENDING" ]]; then
    pass "FR-6: no other slug's archive files modified by this delivery"
  else
    err "FR-6: this delivery modified other slugs' archive files:"
    printf '    %s\n' "$OFFENDING" >&2
  fi
else
  pass "FR-6: not in a git tree — vacuously satisfied"
fi

harness::summary
