#!/usr/bin/env bash
# criterion: AC-001-1
# criterion: AC-001-2
# criterion: AC-001-3
# criterion: AC-001-4
# criterion: FR-2
# criterion: FR-4
#
# Anchored AC bodies (verbatim, from
# .yoke/acceptance-criteria/2026-05-05-cycle-counter-reset-on-sprint-advance.md):
#
#   AC-001-1: Given the runtime directory does not exist, when
#     wm_reset_cycle_counter is called, then .yoke/runtime/.cycle-counter
#     exists afterwards and reads exactly the byte `0` (no trailing newline,
#     no whitespace).
#   AC-001-2: Given .yoke/runtime/.cycle-counter already contains the
#     integer `0`, when wm_reset_cycle_counter is called, then the file
#     still reads exactly `0` — i.e. the helper is idempotent.
#   AC-001-3: Given .yoke/runtime/.cycle-counter contains a non-zero
#     integer (e.g. `7`), when wm_reset_cycle_counter is called, then
#     the file is overwritten and reads exactly `0`.
#   AC-001-4: The helper is contained — calling it does not write to
#     progress.md, does not invoke any canonical-memory verb, and does
#     not modify any file outside wm_cycle_counter_path().
#   FR-2: No file under .yoke/runtime/ is written by new code outside
#     the existing wm_cycle_counter_path() target.
#   FR-4: Plugin structure preserved — helper lives inside paths.sh's
#     `# --- runtime paths ---` region, no new file under lib/working-memory/.

set -euo pipefail

# Internal watchdog (per CLAUDE.md :: ## Testing).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

# Resolve repo root from the location of this file.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"

# shellcheck source=/dev/null
source "$REPO_ROOT/tests/lib/harness.sh"

PATHS_SH="$REPO_ROOT/lib/working-memory/paths.sh"

# ---------------------------------------------------------------------------
# Pre-condition: lib/working-memory/paths.sh must exist (FR-4 anchor).
# ---------------------------------------------------------------------------
if [[ ! -f "$PATHS_SH" ]]; then
  err "lib/working-memory/paths.sh missing — Sr Eng deliverable absent"
  harness::summary
fi

# ---------------------------------------------------------------------------
# Static check: helper is defined in paths.sh inside the runtime-paths region
# (FR-4 / DoD US-001).
# ---------------------------------------------------------------------------
if grep -qE '^wm_reset_cycle_counter\(\)' "$PATHS_SH"; then
  pass "(static) wm_reset_cycle_counter() defined in lib/working-memory/paths.sh"
else
  err "(static) wm_reset_cycle_counter() NOT defined in lib/working-memory/paths.sh"
  harness::summary
fi

# Verify the helper sits in the `# --- runtime paths ---` region — i.e. the
# function definition's line number is greater than the runtime-paths H3
# comment marker and less than the next `# --- ` comment marker. Read both
# anchors and assert ordering.
RUNTIME_REGION_START_LN=$(grep -nE '^# --- runtime paths ---' "$PATHS_SH" | head -1 | cut -d: -f1 || true)
HELPER_LN=$(grep -nE '^wm_reset_cycle_counter\(\)' "$PATHS_SH" | head -1 | cut -d: -f1 || true)
NEXT_REGION_LN=$(awk -v start="$RUNTIME_REGION_START_LN" 'NR > start && /^# --- /{print NR; exit}' "$PATHS_SH" || true)

if [[ -n "$RUNTIME_REGION_START_LN" && -n "$HELPER_LN" ]]; then
  if [[ -n "$NEXT_REGION_LN" ]]; then
    if (( HELPER_LN > RUNTIME_REGION_START_LN && HELPER_LN < NEXT_REGION_LN )); then
      pass "(FR-4) helper lives inside the runtime-paths region (line $HELPER_LN ∈ ($RUNTIME_REGION_START_LN, $NEXT_REGION_LN))"
    else
      err "(FR-4) helper at line $HELPER_LN is OUTSIDE the runtime-paths region ($RUNTIME_REGION_START_LN, $NEXT_REGION_LN)"
    fi
  else
    if (( HELPER_LN > RUNTIME_REGION_START_LN )); then
      pass "(FR-4) helper lives inside the runtime-paths region (line $HELPER_LN, region is the file's last region)"
    else
      err "(FR-4) helper at line $HELPER_LN is BEFORE the runtime-paths region start ($RUNTIME_REGION_START_LN)"
    fi
  fi
else
  err "(FR-4) failed to anchor helper or runtime-paths region (region=$RUNTIME_REGION_START_LN, helper=$HELPER_LN)"
fi

# ---------------------------------------------------------------------------
# Behavior cases — each case runs in an isolated tmp dir (cd-based, since
# WM_RUNTIME_DIR is `readonly` once paths.sh is sourced).
# ---------------------------------------------------------------------------

run_case() {
  local label="$1"
  local case_fn="$2"
  local TMP
  TMP=$(mktemp -d "${TMPDIR:-/tmp}/wm-reset-helper.XXXXXX")
  (
    cd "$TMP"
    # shellcheck source=/dev/null
    source "$PATHS_SH"
    "$case_fn"
  )
  local rc=$?
  rm -rf "$TMP"
  return $rc
}

# ---------------------------------------------------------------------------
# AC-001-1 — runtime dir absent → file is created with exactly the byte `0`.
# ---------------------------------------------------------------------------
case_ac_001_1() {
  # Precondition: runtime dir is absent.
  [[ ! -e ".yoke/runtime" ]] || { echo "precondition violated: runtime exists"; return 1; }
  wm_reset_cycle_counter
  local target
  target="$(wm_cycle_counter_path)"
  [[ -f "$target" ]] || { echo "AC-001-1: file not created at $target"; return 1; }
  local content
  content="$(cat "$target")"
  local size
  size="$(wc -c < "$target" | tr -d ' ')"
  # Exactly the single byte `0`, no newline.
  [[ "$content" == "0" ]] || { echo "AC-001-1: content '$content' != '0'"; return 1; }
  [[ "$size" == "1" ]] || { echo "AC-001-1: size $size != 1 (trailing whitespace?)"; return 1; }
}

if run_case "AC-001-1" case_ac_001_1; then
  pass "AC-001-1: runtime dir absent → file created with exactly the byte '0'"
else
  err "AC-001-1: helper failed to create file or wrote non-canonical content"
fi

# ---------------------------------------------------------------------------
# AC-001-2 — file already at `0` → still `0` (idempotent).
# ---------------------------------------------------------------------------
case_ac_001_2() {
  mkdir -p ".yoke/runtime"
  printf '0' > ".yoke/runtime/.cycle-counter"
  wm_reset_cycle_counter
  local target
  target="$(wm_cycle_counter_path)"
  local content
  content="$(cat "$target")"
  local size
  size="$(wc -c < "$target" | tr -d ' ')"
  [[ "$content" == "0" ]] || { echo "AC-001-2: content '$content' != '0'"; return 1; }
  [[ "$size" == "1" ]] || { echo "AC-001-2: size $size != 1"; return 1; }
}

if run_case "AC-001-2" case_ac_001_2; then
  pass "AC-001-2: file already at '0' → still '0' (idempotent)"
else
  err "AC-001-2: helper not idempotent on a file already at '0'"
fi

# ---------------------------------------------------------------------------
# AC-001-3 — file at non-zero (e.g. `7`) → overwritten to `0`.
# ---------------------------------------------------------------------------
case_ac_001_3() {
  mkdir -p ".yoke/runtime"
  printf '7' > ".yoke/runtime/.cycle-counter"
  wm_reset_cycle_counter
  local target
  target="$(wm_cycle_counter_path)"
  local content
  content="$(cat "$target")"
  local size
  size="$(wc -c < "$target" | tr -d ' ')"
  [[ "$content" == "0" ]] || { echo "AC-001-3: content '$content' != '0'"; return 1; }
  [[ "$size" == "1" ]] || { echo "AC-001-3: size $size != 1"; return 1; }
}

if run_case "AC-001-3" case_ac_001_3; then
  pass "AC-001-3: file at '7' → overwritten to '0'"
else
  err "AC-001-3: helper failed to overwrite non-zero counter to '0'"
fi

# ---------------------------------------------------------------------------
# AC-001-4 / FR-2 — helper is contained: only writes to .cycle-counter.
#
# Strategy: snapshot every file under .yoke/ (including any progress.md or
# coincident artifacts), invoke the helper, snapshot again, and assert that
# the only differential is .yoke/runtime/.cycle-counter.
# ---------------------------------------------------------------------------
case_ac_001_4() {
  mkdir -p ".yoke/runtime"
  # Seed sibling files to detect spurious writes.
  printf '7' > ".yoke/runtime/.cycle-counter"
  printf 'baseline progress\n' > ".yoke/runtime/progress.md"
  mkdir -p ".yoke/runtime/.snapshots"
  printf 'snap\n' > ".yoke/runtime/.snapshots/cycle-0.yaml"
  printf 'baseline ignore\n' > ".yoke/runtime/.gitignore" || true

  # Snapshot before.
  local before after
  before=$(find ".yoke" -type f -exec sh -c 'printf "%s %s\n" "$(md5sum "$1" 2>/dev/null || md5 -q "$1" 2>/dev/null)" "$1"' _ {} \; | sort)

  wm_reset_cycle_counter

  after=$(find ".yoke" -type f -exec sh -c 'printf "%s %s\n" "$(md5sum "$1" 2>/dev/null || md5 -q "$1" 2>/dev/null)" "$1"' _ {} \; | sort)

  # Compute differential (lines that changed).
  local diff_out
  diff_out=$(diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") || true)

  # Every "<" or ">" line should reference only .yoke/runtime/.cycle-counter.
  local offending
  offending=$(printf '%s\n' "$diff_out" \
    | grep -E '^[<>] ' \
    | grep -vE '\.yoke/runtime/\.cycle-counter$' \
    || true)
  if [[ -n "$offending" ]]; then
    echo "AC-001-4: helper wrote to files outside wm_cycle_counter_path():"
    printf '%s\n' "$offending"
    return 1
  fi
  # Sanity: progress.md must be byte-identical to baseline.
  local after_progress
  after_progress="$(cat ".yoke/runtime/progress.md")"
  [[ "$after_progress" == "baseline progress" ]] || {
    echo "AC-001-4: progress.md was modified by the helper"
    return 1
  }
}

if run_case "AC-001-4" case_ac_001_4; then
  pass "AC-001-4 / FR-2: helper writes only to wm_cycle_counter_path() (no progress.md, no sibling file)"
else
  err "AC-001-4 / FR-2: helper wrote outside wm_cycle_counter_path() target"
fi

# ---------------------------------------------------------------------------
# FR-4 (negative) — no NEW file under lib/working-memory/ was added by
# this delivery. We use git to enumerate this delivery's untracked /
# added files in lib/working-memory/; if any new .sh file appeared, that
# is an FR-4 violation. Tolerated when not in a git tree.
# ---------------------------------------------------------------------------
if (cd "$REPO_ROOT" && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
  NEW_LIB_FILES=$(cd "$REPO_ROOT" && git status --porcelain -- lib/working-memory 2>/dev/null \
    | awk '$1 ~ /^(\?\?|A|AM)$/ {print $2}' || true)
  if [[ -z "$NEW_LIB_FILES" ]]; then
    pass "FR-4: no new file under lib/working-memory/ added by this delivery"
  else
    err "FR-4: new file(s) under lib/working-memory/ added by this delivery:"
    printf '    %s\n' $NEW_LIB_FILES >&2
  fi
else
  pass "FR-4: not in a git tree — vacuously satisfied"
fi

harness::summary
