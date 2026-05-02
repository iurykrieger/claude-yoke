#!/usr/bin/env bash
# shellcheck shell=bash
#
# cycle.sh — Sprint 02 / Task t01 / Acceptance Contract Scenario 6 + FR-2.
#
# Phase A orchestration helpers consumed by `/yoke:implement` at the
# top of every council cycle. The persona Tasks themselves are spawned
# by the SKILL.md-level orchestration (Claude Code's Task tool issued in
# a single assistant turn, one Task per persona, run in background).
# This helper covers the deterministic pre- and post-spawn bookkeeping:
#
#   pre-spawn  <slug> <cycle>   — clear stale Phase-A markers; validate
#                                 every council persona file via
#                                 lib/runtime/persona-loader.sh
#                                 validate-all <agents-dir>; print the
#                                 sorted persona-name list to stdout
#                                 (one per line) so the caller can issue
#                                 one Task per persona without re-parsing
#                                 the agents/ directory.
#
#   post-spawn <slug> <cycle>   — defensive guard after the SKILL.md
#                                 layer has waited on every Task call's
#                                 completion notification: invoke
#                                 lib/runtime/sync-barrier.sh wait-all
#                                 with the persona list resolved by the
#                                 same logic as pre-spawn. Failures here
#                                 are sensor-bug or harness-bug, not
#                                 normal flow; the wait-all timeout
#                                 emits a `wm:`-prefixed stderr line.
#
# Cites concepts/yoke-pattern-ralph-loop for the per-cycle deterministic
# node contract (SKILL.md's outer loop spawns three persona Tasks in
# parallel; this helper wraps the deterministic portions).
# Cites concepts/yoke-pattern-roles for the persona contract (Sr Eng,
# Sr QA, Sr Staff are the v3.0 council personas — the persona-list
# resolver picks every `agents/sr-*.md` file by default).
#
# Discovery: this helper is sourced by `skills/implement/SKILL.md`'s
# Phase A block (Sprint 2 cutover). It is intentionally side-effect-light
# so the orchestration is testable without spawning real Claude Code
# Tasks (the test driver under tests/runtime/phase-a-orchestration.test.sh
# stubs the Task spawn but exercises pre-spawn + post-spawn for real).

set -euo pipefail

if [[ -z "${_YOKE_CYCLE_LOADED:-}" ]]; then
  readonly _YOKE_CYCLE_LOADED=1

  # _yoke_cycle_violation <message>
  _yoke_cycle_violation() {
    printf 'wm: %s\n' "$1" >&2
  }

  # _yoke_cycle_repo_root
  #   echoes the absolute path to the repo root that hosts this script.
  #   Cycle.sh is shipped under <plugin>/lib/runtime/; the repo root is
  #   two levels up from this file. Tests source the helper from a
  #   scratch directory; the helper resolves its companions via the
  #   absolute path so cwd never matters.
  _yoke_cycle_repo_root() {
    local script_dir
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    cd -- "${script_dir}/../.." && pwd
  }

  # _yoke_cycle_agents_dir
  #   echoes the agents directory the persona-loader walks. Defaults to
  #   <repo-root>/agents and is overridable via YOKE_AGENTS_DIR for tests.
  _yoke_cycle_agents_dir() {
    if [[ -n "${YOKE_AGENTS_DIR:-}" ]]; then
      printf '%s' "${YOKE_AGENTS_DIR}"
    else
      printf '%s/agents' "$(_yoke_cycle_repo_root)"
    fi
  }

  # _yoke_cycle_persona_list
  #   echoes one persona name per line, alphabetically sorted, by
  #   walking <agents-dir>/sr-*.md and basenaming each. The persona
  #   convention follows concepts/yoke-pattern-roles — the v3.0 council
  #   ships sr-eng, sr-qa, sr-staff; host overrides under
  #   .claude/agents/sr-*.md are intentionally NOT picked up here (the
  #   council runtime resolves council personas from the plugin's
  #   shipped defaults; host overrides go through the persona-loader's
  #   validate-all path).
  _yoke_cycle_persona_list() {
    local dir
    dir="$(_yoke_cycle_agents_dir)"
    if [[ ! -d "$dir" ]]; then
      _yoke_cycle_violation "cycle: agents directory not found: '$dir'"
      return 1
    fi
    (
      shopt -s nullglob
      local f
      for f in "$dir"/sr-*.md; do
        basename "$f" .md
      done
    ) | LC_ALL=C sort
  }

  # _yoke_cycle_validate_personas
  #   delegates to lib/runtime/persona-loader.sh validate-all <agents-dir>.
  #   Returns 0 only when every persona file is well-formed; on any
  #   violation the loader has already emitted the `wm:`-prefixed stderr
  #   diagnostic naming the offending file plus key.
  _yoke_cycle_validate_personas() {
    local loader dir
    loader="$(_yoke_cycle_repo_root)/lib/runtime/persona-loader.sh"
    dir="$(_yoke_cycle_agents_dir)"
    if [[ ! -f "$loader" ]]; then
      _yoke_cycle_violation "cycle: persona-loader missing at '$loader'"
      return 1
    fi
    bash "$loader" validate-all "$dir"
  }

  # _yoke_cycle_clear_markers <slug> <cycle>
  #   delegates to lib/runtime/sync-barrier.sh clear-markers; honors
  #   YOKE_MARKER_DIR for tests (the sync-barrier helper itself reads
  #   the env var directly).
  _yoke_cycle_clear_markers() {
    local barrier
    barrier="$(_yoke_cycle_repo_root)/lib/runtime/sync-barrier.sh"
    if [[ ! -f "$barrier" ]]; then
      _yoke_cycle_violation "cycle: sync-barrier helper missing at '$barrier'"
      return 1
    fi
    bash "$barrier" clear-markers "$1" "$2"
  }

  # _yoke_cycle_wait_all <slug> <cycle> <persona> [<persona> ...]
  _yoke_cycle_wait_all() {
    local barrier
    barrier="$(_yoke_cycle_repo_root)/lib/runtime/sync-barrier.sh"
    if [[ ! -f "$barrier" ]]; then
      _yoke_cycle_violation "cycle: sync-barrier helper missing at '$barrier'"
      return 1
    fi
    bash "$barrier" wait-all "$@"
  }

  # _yoke_cycle_pre_spawn <slug> <cycle>
  #   1. clear stale Phase-A markers (idempotent),
  #   2. validate every council persona file,
  #   3. print the persona name list to stdout (one per line, sorted).
  _yoke_cycle_pre_spawn() {
    if [[ $# -ne 2 ]]; then
      _yoke_cycle_violation "cycle: pre-spawn requires <slug> <cycle>"
      return 2
    fi
    local slug="$1"
    local cycle="$2"
    if [[ -z "$slug" || -z "$cycle" ]]; then
      _yoke_cycle_violation "cycle: pre-spawn requires non-empty <slug> <cycle>"
      return 2
    fi
    if [[ ! "$cycle" =~ ^[0-9]+$ ]]; then
      _yoke_cycle_violation "cycle: invalid cycle '$cycle' (expected non-negative integer)"
      return 2
    fi
    _yoke_cycle_clear_markers "$slug" "$cycle" || return 1
    _yoke_cycle_validate_personas || return 1
    _yoke_cycle_persona_list
  }

  # _yoke_cycle_post_spawn <slug> <cycle>
  #   defensive wait-all on every council persona's Phase-A marker.
  _yoke_cycle_post_spawn() {
    if [[ $# -ne 2 ]]; then
      _yoke_cycle_violation "cycle: post-spawn requires <slug> <cycle>"
      return 2
    fi
    local slug="$1"
    local cycle="$2"
    if [[ -z "$slug" || -z "$cycle" ]]; then
      _yoke_cycle_violation "cycle: post-spawn requires non-empty <slug> <cycle>"
      return 2
    fi
    if [[ ! "$cycle" =~ ^[0-9]+$ ]]; then
      _yoke_cycle_violation "cycle: invalid cycle '$cycle' (expected non-negative integer)"
      return 2
    fi
    local personas=()
    local persona
    while IFS= read -r persona; do
      [[ -n "$persona" ]] || continue
      personas+=("$persona")
    done < <(_yoke_cycle_persona_list || true)
    if [[ ${#personas[@]} -eq 0 ]]; then
      _yoke_cycle_violation "cycle: post-spawn found zero council personas under '$(_yoke_cycle_agents_dir)'"
      return 1
    fi
    _yoke_cycle_wait_all "$slug" "$cycle" "${personas[@]}"
  }
fi

# --- CLI dispatch -----------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    pre-spawn)
      shift
      _yoke_cycle_pre_spawn "$@"
      exit "$?"
      ;;
    post-spawn)
      shift
      _yoke_cycle_post_spawn "$@"
      exit "$?"
      ;;
    persona-list)
      _yoke_cycle_persona_list
      exit "$?"
      ;;
    ""|-h|--help|help)
      cat <<'EOF'
cycle.sh — Phase A orchestration helpers for /yoke:implement.

Usage:
  cycle.sh pre-spawn    <slug> <cycle>   # clear markers + validate personas + print list
  cycle.sh post-spawn   <slug> <cycle>   # defensive wait-all on every persona's marker
  cycle.sh persona-list                  # print the sorted persona name list to stdout

Environment:
  YOKE_AGENTS_DIR              override the default <repo-root>/agents directory.
  YOKE_MARKER_DIR              passed through to lib/runtime/sync-barrier.sh.
  YOKE_BARRIER_POLL_INTERVAL   passed through to lib/runtime/sync-barrier.sh.
  YOKE_BARRIER_TIMEOUT_SECONDS passed through to lib/runtime/sync-barrier.sh.

Exit codes:
  0  every step succeeded.
  1  at least one step failed; a `wm:`-prefixed stderr line names the failure.
  2  CLI usage error.
EOF
      exit 0
      ;;
    *)
      _yoke_cycle_violation "cycle: unknown subcommand: '${1}'"
      exit 2
      ;;
  esac
fi
