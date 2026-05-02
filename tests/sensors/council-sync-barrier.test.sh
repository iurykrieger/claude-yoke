#!/usr/bin/env bash
# shellcheck shell=bash
#
# council-sync-barrier.test.sh — Sprint 01 / Task t05 / Acceptance
# Contract Scenario 5 + FR-2 (sensor: sync-barrier-mtime-ordering).
#
# Sensor that asserts mtime ordering between the per-cycle persona slice
# files (`.yoke/runtime/cycles/<N>/<persona>.md`) and the Phase-A
# completion markers (`.yoke/runtime/.phase-a-done.<persona>`). The
# binding rule, drawn from the Acceptance Contract Scenario 5 / FR-2
# Validation block:
#
#   For every persona slice in the cycle directory, the slice file's
#   mtime MUST be ≥ the latest Phase-A marker's mtime. Phase B opens
#   only after every Phase-A persona has produced its marker; reading a
#   slice that mutated AFTER the latest marker is therefore safe, but
#   reading a slice that was last mutated BEFORE the latest marker means
#   Phase B observed a stale write.
#
# Cites `concepts/yoke-conventions` for the deterministic-sensor-output
# contract: any violation surfaces a `wm: sync-barrier violation:`
# stderr line naming the offending slice, and the sensor exits non-zero.
#
# This file is both:
#   (a) the sensor itself — when invoked with a fixture directory as
#       its first argument, it inspects that directory and exits 0 on
#       pass / non-zero on fail with the documented stderr line.
#   (b) the test driver — when invoked with no arguments, it engineers
#       a pass fixture and a fail fixture under the directories
#       `tests/runtime/fixtures/sync-barrier-pass/` and
#       `tests/runtime/fixtures/sync-barrier-fail/`, runs itself
#       recursively against each, and asserts the documented behaviour
#       (pass exits 0 silently; fail exits non-zero with the
#       `wm: sync-barrier violation:` stderr line naming the offending
#       slice file).
#
# Test contract (binding for the driver mode):
#   - exit 0 when both fixtures behave as specified.
#   - exit non-zero with a `wm: council-sync-barrier-test violation:`-
#     prefixed stderr line naming the failing case otherwise.
#
# Discovery: this sensor is enumerated by Sprint 01 Task t05's
# `**Acceptance criterion:**` line and by Acceptance Contract Scenario 5's
# `Then` clause. Sensor id: `sync-barrier-mtime-ordering` (per the
# Sprint 01 sensors block).

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
PASS_FIXTURE_DIR="${REPO_ROOT}/tests/runtime/fixtures/sync-barrier-pass"
FAIL_FIXTURE_DIR="${REPO_ROOT}/tests/runtime/fixtures/sync-barrier-fail"

# --- portable mtime in epoch seconds ---------------------------------------

# `stat` differs between BSD (macOS) and GNU (Linux). The sensor needs
# integer epoch seconds so the comparison is portable across both.
_yoke_sb_mtime_epoch() {
  local file="$1"
  if stat -f '%m' "$file" >/dev/null 2>&1; then
    stat -f '%m' "$file"
  else
    stat -c '%Y' "$file"
  fi
}

# --- sensor mode -----------------------------------------------------------

# _yoke_sb_run_sensor <cycle-dir>
#   <cycle-dir> contains:
#     - one or more `.phase-a-done.<persona>` marker files (the writer
#       side of the barrier).
#     - a `slices/` subdirectory holding one `<persona>.md` slice per
#       persona that produced a marker.
#   For every slice, the sensor asserts slice.mtime ≥ max(marker.mtime).
#   On any violation, emits a `wm: sync-barrier violation:` stderr line
#   per offending slice and returns non-zero.
_yoke_sb_run_sensor() {
  local cycle_dir="$1"
  if [[ ! -d "$cycle_dir" ]]; then
    printf 'wm: sync-barrier violation: cycle directory not found: %s\n' "$cycle_dir" >&2
    return 1
  fi
  local slices_dir="$cycle_dir/slices"
  if [[ ! -d "$slices_dir" ]]; then
    printf 'wm: sync-barrier violation: slices subdir not found under %s\n' "$cycle_dir" >&2
    return 1
  fi

  # Collect every marker file's mtime; track the max.
  local latest_marker_mtime=0
  local latest_marker_file=""
  local saw_marker=0
  local f mtime
  shopt -s nullglob
  for f in "$cycle_dir"/.phase-a-done.*; do
    saw_marker=1
    mtime="$(_yoke_sb_mtime_epoch "$f")"
    if [[ "$mtime" -gt "$latest_marker_mtime" ]]; then
      latest_marker_mtime="$mtime"
      latest_marker_file="$f"
    fi
  done
  shopt -u nullglob

  if [[ "$saw_marker" -eq 0 ]]; then
    printf 'wm: sync-barrier violation: no Phase-A markers under %s\n' "$cycle_dir" >&2
    return 1
  fi

  local rc=0
  shopt -s nullglob
  for f in "$slices_dir"/*.md; do
    mtime="$(_yoke_sb_mtime_epoch "$f")"
    if [[ "$mtime" -lt "$latest_marker_mtime" ]]; then
      printf 'wm: sync-barrier violation: slice %s (mtime %s) predates latest marker %s (mtime %s)\n' \
        "$f" "$mtime" "$latest_marker_file" "$latest_marker_mtime" >&2
      rc=1
    fi
  done
  shopt -u nullglob

  return "$rc"
}

# --- driver mode -----------------------------------------------------------

# Driver-mode helpers print to stderr with a distinct prefix so the
# driver's failures are not confused with the sensor's `wm: sync-barrier
# violation:` lines.
_yoke_sb_driver_violation() {
  printf 'wm: council-sync-barrier-test violation: %s\n' "$1" >&2
  exit 1
}

# _yoke_sb_seed_cycle <cycle-dir> <pass|fail>
#   Builds an engineered cycle directory under <cycle-dir> with three
#   personas (sr-eng, sr-qa, sr-staff). For the `pass` mode every slice
#   mtime is later than the latest marker mtime; for the `fail` mode
#   one slice (sr-qa.md) is rewound to BEFORE the latest marker.
_yoke_sb_seed_cycle() {
  local cycle_dir="$1"
  local mode="$2"
  rm -rf "$cycle_dir"
  mkdir -p "$cycle_dir/slices"

  # Marker mtimes: 2024-06-01 10:00, 10:01, 10:02 (latest = 10:02).
  : >"$cycle_dir/.phase-a-done.sr-eng"
  touch -t 202406011000 "$cycle_dir/.phase-a-done.sr-eng"
  : >"$cycle_dir/.phase-a-done.sr-qa"
  touch -t 202406011001 "$cycle_dir/.phase-a-done.sr-qa"
  : >"$cycle_dir/.phase-a-done.sr-staff"
  touch -t 202406011002 "$cycle_dir/.phase-a-done.sr-staff"

  # Slice contents — one line per slice is enough; the sensor only
  # cares about mtimes, not bodies.
  printf 'sr-eng phase-a body\n' >"$cycle_dir/slices/sr-eng.md"
  printf 'sr-qa phase-a body\n' >"$cycle_dir/slices/sr-qa.md"
  printf 'sr-staff phase-a body\n' >"$cycle_dir/slices/sr-staff.md"

  if [[ "$mode" == "pass" ]]; then
    # Every slice mtime is 2024-06-01 10:05 — strictly after the latest
    # marker's 10:02.
    touch -t 202406011005 "$cycle_dir/slices/sr-eng.md"
    touch -t 202406011005 "$cycle_dir/slices/sr-qa.md"
    touch -t 202406011005 "$cycle_dir/slices/sr-staff.md"
  elif [[ "$mode" == "fail" ]]; then
    # sr-eng + sr-staff are post-marker; sr-qa is rewound to 09:30,
    # i.e. BEFORE the earliest marker — sensor must flag it.
    touch -t 202406011005 "$cycle_dir/slices/sr-eng.md"
    touch -t 202406010930 "$cycle_dir/slices/sr-qa.md"
    touch -t 202406011005 "$cycle_dir/slices/sr-staff.md"
  else
    _yoke_sb_driver_violation "_yoke_sb_seed_cycle: unknown mode '$mode'"
  fi
}

_yoke_sb_run_driver() {
  # Seed both fixtures under the static directories.
  _yoke_sb_seed_cycle "$PASS_FIXTURE_DIR" pass
  _yoke_sb_seed_cycle "$FAIL_FIXTURE_DIR" fail

  # Pass fixture: sensor should exit 0 silently.
  local pass_stderr
  pass_stderr="$(mktemp)"
  local rc=0
  bash "${BASH_SOURCE[0]}" "$PASS_FIXTURE_DIR" 2>"$pass_stderr" >/dev/null || rc=$?
  if [[ "$rc" != "0" ]]; then
    rm -f "$pass_stderr"
    _yoke_sb_driver_violation "sensor on pass fixture returned ${rc}; expected 0"
  fi
  if [[ -s "$pass_stderr" ]]; then
    local body
    body="$(tr '\n' ' ' < "$pass_stderr")"
    rm -f "$pass_stderr"
    _yoke_sb_driver_violation "sensor on pass fixture wrote to stderr; expected silent pass (stderr: ${body})"
  fi
  rm -f "$pass_stderr"

  # Fail fixture: sensor should exit non-zero with `wm: sync-barrier
  # violation:` line naming sr-qa.md.
  local fail_stderr
  fail_stderr="$(mktemp)"
  rc=0
  bash "${BASH_SOURCE[0]}" "$FAIL_FIXTURE_DIR" 2>"$fail_stderr" >/dev/null || rc=$?
  if [[ "$rc" == "0" ]]; then
    rm -f "$fail_stderr"
    _yoke_sb_driver_violation "sensor on fail fixture returned 0; expected non-zero"
  fi
  if ! grep -q '^wm: sync-barrier violation:' "$fail_stderr"; then
    local body
    body="$(tr '\n' ' ' < "$fail_stderr")"
    rm -f "$fail_stderr"
    _yoke_sb_driver_violation "sensor on fail fixture stderr is not 'wm: sync-barrier violation:'-prefixed (got: ${body})"
  fi
  if ! grep -q 'sr-qa\.md' "$fail_stderr"; then
    local body
    body="$(tr '\n' ' ' < "$fail_stderr")"
    rm -f "$fail_stderr"
    _yoke_sb_driver_violation "sensor on fail fixture stderr does not name the offending slice 'sr-qa.md' (got: ${body})"
  fi
  rm -f "$fail_stderr"

  exit 0
}

# --- dispatch --------------------------------------------------------------

if [[ $# -ge 1 ]]; then
  # Sensor mode — argument is the cycle directory to inspect.
  _yoke_sb_run_sensor "$1"
  exit "$?"
else
  # Driver mode — engineer pass + fail fixtures and self-test.
  _yoke_sb_run_driver
fi
