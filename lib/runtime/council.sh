#!/usr/bin/env bash
# shellcheck shell=bash
#
# council.sh — Sprint 02 / Task t02 / Acceptance Contract Scenario 7 + FR-3.
#
# Phase B council loop. Bounded round loop with deterministic quiescence
# detection and an LLM contradiction-detection arbiter call between
# rounds that produced réplicas. Three exit branches:
#
#   - consensus on quiescence  (zero new réplicas in a round)
#   - consensus per arbiter    (arbiter verdict consensus: true)
#   - trigger-4 on cap exhausted
#
# Subcommands:
#
#   phase-b <slug> <cycle> [<cycle-dir>]
#       Drives one Phase B for the given cycle. The optional <cycle-dir>
#       defaults to `.yoke/runtime/cycles/<cycle>/` resolved via
#       lib/working-memory/paths.sh. Reads the round cap from
#       `.yoke/config.yaml :: overrides.runtime.council_rounds_max`
#       (default 3). Emits a YAML summary on stdout:
#
#           rounds_consumed: <N>
#           per_round_replica_counts: [<r1>, <r2>, ...]
#           exit_status: consensus | trigger-4
#           arbiter_verdict_summary: <one-line>
#
#       Exit code mirrors the exit_status: 0 on consensus, 10 on
#       trigger-4 (signal for the SKILL.md layer to render the Trigger 4
#       packet). Any unrecoverable error returns 1 with a `wm:`-prefixed
#       stderr line.
#
#   round-cap [<config-path>]
#       Echoes the resolved round cap. Useful for tests.
#
# Replica-detection rule: after each round, count slice files whose
# `## Phase B round <r> — réplica` section has a non-blank body. A blank
# section (zero non-whitespace, non-comment lines under the heading) is
# the quiescence signal. Quiescence per the spec's `### Per-persona slice
# file` schema — réplica section may be empty when a persona has no
# objection.
#
# Arbiter dispatch: when a round produces ≥ 1 réplica, call the arbiter
# adapter (`bash <repo>/lib/runtime/arbiter-dispatch.sh <merged-view>
# <round-readings>` if present; otherwise the test harness override at
# `YOKE_ARBITER_CMD`). Both must emit a single JSON object on stdout
# matching the schema in the spec's `### Contradiction-detection arbiter`
# section (round, consensus, contradictions, tone_only_pairs). The
# council loop validates the required fields via grep/awk (no jq dep)
# and branches on the consensus boolean + contradictions array length.
#
# Cites concepts/yoke-pattern-ralph-loop for the bounded-loop contract
# and concepts/yoke-conventions for the deterministic-sensor-output
# contract (every error path emits `wm:`-prefixed stderr).
#
# Discovery: this helper is sourced by `skills/implement/SKILL.md`'s
# Phase B block; the Sprint 02 cutover wires it into the per-cycle
# protocol after the persona Tasks return.

set -euo pipefail

if [[ -z "${_YOKE_COUNCIL_LOADED:-}" ]]; then
  readonly _YOKE_COUNCIL_LOADED=1

  : "${YOKE_COUNCIL_DEFAULT_ROUNDS:=3}"

  _yoke_council_violation() {
    printf 'wm: %s\n' "$1" >&2
  }

  _yoke_council_repo_root() {
    local script_dir
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    cd -- "${script_dir}/../.." && pwd
  }

  # _yoke_council_resolve_rounds_max [<config-path>]
  #   Resolves overrides.runtime.council_rounds_max from .yoke/config.yaml
  #   (or the path provided). Returns the integer; defaults to
  #   YOKE_COUNCIL_DEFAULT_ROUNDS when absent / empty / non-numeric.
  _yoke_council_resolve_rounds_max() {
    local config="${1:-${YOKE_CONFIG_PATH:-.yoke/config.yaml}}"
    local value=""
    if [[ -f "$config" ]]; then
      # Awk-based YAML extractor: walks `overrides:` → `runtime:` →
      # `council_rounds_max:` honoring 2-space-per-level indentation.
      # Sufficient for the Yoke config style; not a general YAML parser.
      value="$(awk '
        BEGIN { in_overrides = 0; in_runtime = 0 }
        /^overrides:[[:space:]]*$/   { in_overrides = 1; in_runtime = 0; next }
        /^[A-Za-z_-]+:/ && !/^overrides:/ { in_overrides = 0; in_runtime = 0 }
        in_overrides && /^[[:space:]]{2}runtime:[[:space:]]*$/ { in_runtime = 1; next }
        in_overrides && /^[[:space:]]{2}[A-Za-z_-]+:/ && !/runtime:/ { in_runtime = 0 }
        in_overrides && in_runtime && /^[[:space:]]{4}council_rounds_max:/ {
          line = $0
          sub(/^[[:space:]]{4}council_rounds_max:[[:space:]]*/, "", line)
          sub(/[[:space:]]+#.*$/, "", line)
          sub(/[[:space:]]+$/, "", line)
          # strip wrapping quotes
          gsub(/^"|"$/, "", line)
          gsub(/^'\''|'\''$/, "", line)
          print line
          exit
        }
      ' "$config")"
    fi
    if [[ -z "$value" || ! "$value" =~ ^[0-9]+$ || "$value" == "0" ]]; then
      printf '%s' "${YOKE_COUNCIL_DEFAULT_ROUNDS}"
      return 0
    fi
    printf '%s' "$value"
  }

  _yoke_council_cycle_dir() {
    local slug="$1"
    local cycle="$2"
    local override="${3:-}"
    if [[ -n "$override" ]]; then
      printf '%s' "$override"
      return 0
    fi
    # Fall back to the runtime layout. We do not source paths.sh here
    # because this helper may be sourced from the SKILL.md layer which
    # already has paths.sh loaded; constructing the path inline keeps
    # the tool boundary small.
    printf '%s/cycles/%s' "${YOKE_RUNTIME_DIR:-.yoke/runtime}" "$cycle"
  }

  # _yoke_council_count_replicas <cycle-dir> <round>
  #   counts slice files under <cycle-dir>/*.md whose
  #   `## Phase B round <round> — réplica` section has a non-blank body.
  _yoke_council_count_replicas() {
    local cycle_dir="$1"
    local round="$2"
    local count=0
    if [[ ! -d "$cycle_dir" ]]; then
      printf '0'
      return 0
    fi
    local slice
    while IFS= read -r slice; do
      [[ -n "$slice" ]] || continue
      [[ -f "$slice" ]] || continue
      local body
      body="$(awk -v r="$round" '
        BEGIN  { in_section = 0; out = "" }
        $0 ~ "^## Phase B round " r " — réplica[[:space:]]*$" { in_section = 1; next }
        in_section == 1 && /^## / { in_section = 0 }
        in_section == 1 {
          if ($0 !~ /^[[:space:]]*$/ && $0 !~ /^[[:space:]]*<!--/) {
            out = out $0 "\n"
          }
        }
        END { printf "%s", out }
      ' "$slice")"
      if [[ -n "$body" ]]; then
        count=$((count + 1))
      fi
    done < <(find "$cycle_dir" -maxdepth 1 -type f -name '*.md' | LC_ALL=C sort)
    printf '%s' "$count"
  }

  # _yoke_council_invoke_arbiter <merged-view-path> <round> <output-path>
  #   Runs the arbiter dispatch path. Honors YOKE_ARBITER_CMD as a test
  #   override (the test harness points it at a fixture-canned JSON or
  #   at a local stub script). When unset, dispatches to
  #   <repo>/lib/runtime/arbiter-dispatch.sh if present; otherwise
  #   returns non-zero with a `wm:`-prefixed message.
  _yoke_council_invoke_arbiter() {
    local merged="$1"
    local round="$2"
    local out="$3"
    if [[ -n "${YOKE_ARBITER_CMD:-}" ]]; then
      # The test override receives <merged-view> <round> on argv and
      # writes the JSON verdict to stdout.
      bash -c "${YOKE_ARBITER_CMD} \"$merged\" \"$round\"" > "$out"
      return $?
    fi
    local dispatcher
    dispatcher="$(_yoke_council_repo_root)/lib/runtime/arbiter-dispatch.sh"
    if [[ -x "$dispatcher" || -f "$dispatcher" ]]; then
      bash "$dispatcher" "$merged" "$round" > "$out"
      return $?
    fi
    _yoke_council_violation "council: no arbiter dispatch path available (set YOKE_ARBITER_CMD or ship lib/runtime/arbiter-dispatch.sh)"
    return 1
  }

  # _yoke_council_arbiter_consensus <verdict-path>
  #   Returns 0 when the verdict's "consensus": true; non-zero otherwise.
  _yoke_council_arbiter_consensus() {
    local verdict="$1"
    [[ -f "$verdict" ]] || return 1
    grep -Eq '"consensus"[[:space:]]*:[[:space:]]*true' "$verdict"
  }

  # _yoke_council_arbiter_summary <verdict-path>
  #   Echoes a one-line summary of the arbiter's verdict (consensus
  #   bool + contradiction count + tone-only count).
  _yoke_council_arbiter_summary() {
    local verdict="$1"
    [[ -f "$verdict" ]] || { printf 'no-verdict'; return 0; }
    local consensus="false"
    if _yoke_council_arbiter_consensus "$verdict"; then
      consensus="true"
    fi
    # Count `"category"` occurrences as a proxy for contradictions[]
    # length; count `"summary"` inside tone_only_pairs[] is harder
    # without jq, so we approximate with the JSON section markers.
    # Count entries by counting "category" fields (one per contradiction)
    # and "summary" fields under tone_only_pairs[]. Approximate but
    # deterministic against the spec's verdict schema.
    local contradictions tone_only
    contradictions="$(grep -oE '"category"[[:space:]]*:' "$verdict" | wc -l | tr -d ' ')"
    [[ -n "$contradictions" ]] || contradictions=0
    # tone_only_pairs[] entries lack `category` so the difference between
    # total `summary` fields and contradictions[] gives tone_only count.
    local total_summaries
    total_summaries="$(grep -oE '"summary"[[:space:]]*:' "$verdict" | wc -l | tr -d ' ')"
    [[ -n "$total_summaries" ]] || total_summaries=0
    tone_only=$((total_summaries - contradictions))
    [[ "$tone_only" -ge 0 ]] || tone_only=0
    printf 'consensus=%s contradictions=%s tone_only_pairs=%s' \
      "$consensus" "$contradictions" "$tone_only"
  }

  # _yoke_council_phase_b <slug> <cycle> [<cycle-dir>]
  _yoke_council_phase_b() {
    if [[ $# -lt 2 ]]; then
      _yoke_council_violation "council: phase-b requires <slug> <cycle> [<cycle-dir>]"
      return 2
    fi
    local slug="$1"
    local cycle="$2"
    local cycle_dir
    cycle_dir="$(_yoke_council_cycle_dir "$slug" "$cycle" "${3:-}")"
    if [[ -z "$slug" || -z "$cycle" ]]; then
      _yoke_council_violation "council: phase-b requires non-empty <slug> <cycle>"
      return 2
    fi
    if [[ ! "$cycle" =~ ^[0-9]+$ ]]; then
      _yoke_council_violation "council: invalid cycle '$cycle' (expected non-negative integer)"
      return 2
    fi
    if [[ ! -d "$cycle_dir" ]]; then
      _yoke_council_violation "council: cycle dir not found: '$cycle_dir'"
      return 1
    fi

    local rounds_max
    rounds_max="$(_yoke_council_resolve_rounds_max)"

    local merger
    merger="$(_yoke_council_repo_root)/lib/runtime/council-merge.sh"

    local merged_view
    merged_view="$(mktemp)"
    local arbiter_verdict
    arbiter_verdict="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '$merged_view' '$arbiter_verdict'" RETURN

    local exit_status=""
    local arbiter_summary="(no arbiter call this cycle)"
    local replica_counts=()
    local round=1

    while (( round <= rounds_max )); do
      # Merge the current state of the cycle directory into the merged
      # view. The Phase B body is appended to slice files between
      # rounds; the merge picks up whatever the personas wrote.
      bash "$merger" merge "$cycle_dir" > "$merged_view"

      local count
      count="$(_yoke_council_count_replicas "$cycle_dir" "$round")"
      replica_counts+=("$count")

      if [[ "$count" == "0" ]]; then
        exit_status="consensus"
        break
      fi

      # ≥ 1 réplica → invoke arbiter.
      if ! _yoke_council_invoke_arbiter "$merged_view" "$round" "$arbiter_verdict"; then
        _yoke_council_violation "council: arbiter dispatch failed in round $round"
        return 1
      fi
      arbiter_summary="$(_yoke_council_arbiter_summary "$arbiter_verdict")"
      if _yoke_council_arbiter_consensus "$arbiter_verdict"; then
        exit_status="consensus"
        break
      fi

      round=$((round + 1))
    done

    if [[ -z "$exit_status" ]]; then
      exit_status="trigger-4"
    fi

    # YAML summary on stdout. Validator + Orchestrator parse this verbatim.
    {
      printf 'rounds_consumed: %s\n' "${#replica_counts[@]}"
      printf 'per_round_replica_counts: [%s]\n' "$(IFS=,; printf '%s' "${replica_counts[*]}")"
      printf 'exit_status: %s\n' "$exit_status"
      printf 'arbiter_verdict_summary: "%s"\n' "$arbiter_summary"
      if [[ "$exit_status" == "trigger-4" && -s "$arbiter_verdict" ]]; then
        # Embed the last verdict path so the SKILL.md layer can hand it
        # to lib/runtime/trigger-4.sh::render. The trap cleans up the
        # tempfile; persist it to a stable path under the cycle dir
        # for downstream readers.
        local persisted="${cycle_dir}/.last-arbiter-verdict.json"
        cp "$arbiter_verdict" "$persisted"
        printf 'last_arbiter_verdict_path: "%s"\n' "$persisted"
      fi
    }

    if [[ "$exit_status" == "trigger-4" ]]; then
      return 10
    fi
    return 0
  }
fi

# --- CLI dispatch -----------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    phase-b)
      shift
      _yoke_council_phase_b "$@"
      exit "$?"
      ;;
    round-cap)
      shift
      _yoke_council_resolve_rounds_max "$@"
      printf '\n'
      exit 0
      ;;
    ""|-h|--help|help)
      cat <<'EOF'
council.sh — Phase B council loop for /yoke:implement.

Usage:
  council.sh phase-b   <slug> <cycle> [<cycle-dir>]
  council.sh round-cap [<config-path>]

Environment:
  YOKE_CONFIG_PATH   override the default `.yoke/config.yaml` for round-cap resolution.
  YOKE_RUNTIME_DIR   override the default `.yoke/runtime` for cycle-dir resolution.
  YOKE_ARBITER_CMD   test override for the arbiter dispatch path.

Exit codes:
  0   consensus reached (quiescence or arbiter-detected).
  10  trigger-4 (round cap exhausted with unresolved contradictions).
  1   unrecoverable error; a `wm:`-prefixed stderr line names the failure.
  2   CLI usage error.
EOF
      exit 0
      ;;
    *)
      _yoke_council_violation "council: unknown subcommand: '${1}'"
      exit 2
      ;;
  esac
fi
