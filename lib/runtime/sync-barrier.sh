#!/usr/bin/env bash
# shellcheck shell=bash
#
# sync-barrier.sh — Sprint 01 / Task t05 / Acceptance Contract
# Scenario 5 + FR-2.
#
# File-marker-based synchronization barrier between Phase A (parallel
# persona Tasks each writing their own slice file) and Phase B (the
# council reader merging slices). Two callable subcommands:
#
#   wait-all       <slug> <cycle> <persona> [<persona> ...]
#   clear-markers  <slug> <cycle>
#
# Marker convention:
#
#   <marker-dir>/.phase-a-done.<persona>
#
# where `<marker-dir>` defaults to `.yoke/runtime` (the gitignored
# runtime directory) and may be overridden via the `YOKE_MARKER_DIR`
# environment variable for testing. One zero-byte marker file is
# written by each persona's Phase A Task immediately before exiting
# (the writer side of this contract is implemented by `/yoke:implement`
# in Sprint 2; this helper ships the reader side plus its tests).
#
# Behaviour:
#
#   wait-all polls the marker directory at `YOKE_BARRIER_POLL_INTERVAL`
#   (defaults to 0.1s) until every named persona has produced a marker,
#   then returns 0. If the cumulative wait exceeds
#   `YOKE_BARRIER_TIMEOUT_SECONDS` (defaults to 30), the helper emits a
#   `wm: sync-barrier timeout:` line on stderr naming every still-missing
#   marker and returns non-zero.
#
#   clear-markers removes any `.phase-a-done.*` files in the marker
#   directory. The subcommand is idempotent: it is a no-op when no
#   markers exist, and it removes whatever leftovers a prior interrupted
#   cycle left behind. The marker directory itself is created if it
#   does not exist (so the helper is safe to call from a fresh checkout).
#
# Cites `concepts/yoke-pattern-memory-model` for the working-memory
# archive layout invariants — markers are runtime-tier ephemeral working
# memory under `.yoke/runtime/`, not versioned archive.
#
# Cites `concepts/yoke-conventions` for the deterministic-sensor-output
# contract (every error line carries a `wm:`-prefixed message naming
# the offending file or marker).
#
# Discovery: this helper is sourced by `/yoke:implement`'s Phase B
# opener in Sprint 2. Sprint 1 ships the helper plus its tests only.

set -euo pipefail

# Idempotent re-source guard. The helper is also called as a CLI;
# the guard only protects the function definitions, not the dispatch.
if [[ -z "${_YOKE_SYNC_BARRIER_LOADED:-}" ]]; then
  readonly _YOKE_SYNC_BARRIER_LOADED=1

  # Default tunables. Both can be overridden by the caller via env vars
  # (the test driver pushes them down to keep wait-all snappy).
  : "${YOKE_BARRIER_POLL_INTERVAL:=0.1}"
  : "${YOKE_BARRIER_TIMEOUT_SECONDS:=30}"

  # _yoke_sync_barrier_violation <message>
  _yoke_sync_barrier_violation() {
    printf 'wm: %s\n' "$1" >&2
  }

  # _yoke_sync_barrier_marker_dir
  #   echoes the active marker directory. Defaults to `.yoke/runtime`
  #   and is overridable via `YOKE_MARKER_DIR` for tests. The directory
  #   is NOT created here — callers that need the directory to exist
  #   call `mkdir -p` explicitly (clear-markers does so for safety).
  _yoke_sync_barrier_marker_dir() {
    if [[ -n "${YOKE_MARKER_DIR:-}" ]]; then
      printf '%s' "${YOKE_MARKER_DIR}"
    else
      printf '%s' '.yoke/runtime'
    fi
  }

  # _yoke_sync_barrier_marker_path <persona>
  _yoke_sync_barrier_marker_path() {
    local persona="$1"
    local dir
    dir="$(_yoke_sync_barrier_marker_dir)"
    printf '%s/.phase-a-done.%s' "$dir" "$persona"
  }

  # _yoke_sync_barrier_now_seconds
  #   echoes the current epoch seconds. Uses bash's $EPOCHREALTIME when
  #   available (bash 5+, fractional precision); falls back to `date +%s`
  #   when not (bash 4 on macOS). Wait-all only needs second-granularity
  #   for timeout enforcement, but fractional precision lets the test
  #   driver enforce sub-second poll intervals.
  _yoke_sync_barrier_now_seconds() {
    if [[ -n "${EPOCHREALTIME:-}" ]]; then
      printf '%s' "${EPOCHREALTIME%%[!0-9.]*}"
    else
      date +%s
    fi
  }

  # _yoke_sync_barrier_elapsed <start>
  #   echoes the integer-seconds elapsed since <start>. Uses awk for
  #   the subtraction so fractional inputs do not trip bash arithmetic.
  _yoke_sync_barrier_elapsed() {
    local start="$1"
    local now
    now="$(_yoke_sync_barrier_now_seconds)"
    awk -v s="$start" -v n="$now" 'BEGIN { d = n - s; if (d < 0) d = 0; printf "%d", d }'
  }

  # _yoke_sync_barrier_wait_all <slug> <cycle> <persona> [<persona> ...]
  _yoke_sync_barrier_wait_all() {
    if [[ $# -lt 3 ]]; then
      _yoke_sync_barrier_violation "sync-barrier: wait-all requires <slug> <cycle> <persona> [<persona> ...]"
      return 2
    fi
    local slug="$1"
    local cycle="$2"
    shift 2
    # slug + cycle are accepted for parity with the Sprint 2 caller
    # contract but are not used by the helper itself — markers live in
    # the per-runtime directory, one per persona, regardless of slug.
    # The helper still validates that they are non-empty.
    if [[ -z "$slug" || -z "$cycle" ]]; then
      _yoke_sync_barrier_violation "sync-barrier: wait-all requires non-empty <slug> and <cycle>"
      return 2
    fi
    if [[ ! "$cycle" =~ ^[0-9]+$ ]]; then
      _yoke_sync_barrier_violation "sync-barrier: invalid cycle '$cycle' (expected non-negative integer)"
      return 2
    fi
    local personas=("$@")
    local start
    start="$(_yoke_sync_barrier_now_seconds)"
    while :; do
      local missing=()
      local persona marker
      for persona in "${personas[@]}"; do
        marker="$(_yoke_sync_barrier_marker_path "$persona")"
        if [[ ! -f "$marker" ]]; then
          missing+=("$marker")
        fi
      done
      if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
      fi
      local elapsed
      elapsed="$(_yoke_sync_barrier_elapsed "$start")"
      if [[ "$elapsed" -ge "${YOKE_BARRIER_TIMEOUT_SECONDS}" ]]; then
        _yoke_sync_barrier_violation \
          "sync-barrier timeout: cycle ${cycle} of '${slug}' waited ${elapsed}s for markers: ${missing[*]}"
        return 1
      fi
      sleep "${YOKE_BARRIER_POLL_INTERVAL}"
    done
  }

  # _yoke_sync_barrier_clear_markers <slug> <cycle>
  _yoke_sync_barrier_clear_markers() {
    if [[ $# -ne 2 ]]; then
      _yoke_sync_barrier_violation "sync-barrier: clear-markers requires <slug> <cycle>"
      return 2
    fi
    local slug="$1"
    local cycle="$2"
    if [[ -z "$slug" || -z "$cycle" ]]; then
      _yoke_sync_barrier_violation "sync-barrier: clear-markers requires non-empty <slug> and <cycle>"
      return 2
    fi
    if [[ ! "$cycle" =~ ^[0-9]+$ ]]; then
      _yoke_sync_barrier_violation "sync-barrier: invalid cycle '$cycle' (expected non-negative integer)"
      return 2
    fi
    local dir
    dir="$(_yoke_sync_barrier_marker_dir)"
    mkdir -p "$dir"
    # Idempotent removal: nullglob makes the loop a no-op when no
    # markers exist; -f tolerates a marker that vanishes between glob
    # expansion and rm (concurrent cleanup races are not expected, but
    # the contract is "idempotent" per the AC, so we belt-and-suspender).
    (
      shopt -s nullglob
      local f
      for f in "$dir"/.phase-a-done.*; do
        rm -f "$f"
      done
    )
    return 0
  }
fi

# --- CLI dispatch -----------------------------------------------------------

# Only run dispatch when invoked as a script, not when sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    wait-all)
      shift
      _yoke_sync_barrier_wait_all "$@"
      exit "$?"
      ;;
    clear-markers)
      shift
      _yoke_sync_barrier_clear_markers "$@"
      exit "$?"
      ;;
    ""|-h|--help|help)
      cat <<'EOF'
sync-barrier.sh — file-marker-based Phase A → Phase B synchronization.

Usage:
  sync-barrier.sh wait-all       <slug> <cycle> <persona> [<persona> ...]
  sync-barrier.sh clear-markers  <slug> <cycle>

Environment:
  YOKE_MARKER_DIR              override the default `.yoke/runtime` marker dir.
  YOKE_BARRIER_POLL_INTERVAL   sleep between polls (default 0.1s).
  YOKE_BARRIER_TIMEOUT_SECONDS hard wait-all cap (default 30s).

Exit codes:
  0  every named marker is present (wait-all) or every leftover marker
     was removed (clear-markers, including the no-marker no-op case).
  1  wait-all timed out before every marker appeared (a `wm: sync-barrier
     timeout:` stderr line names every still-missing marker).
  2  CLI usage error.
EOF
      exit 0
      ;;
    *)
      _yoke_sync_barrier_violation "sync-barrier: unknown subcommand: '${1}'"
      exit 2
      ;;
  esac
fi
