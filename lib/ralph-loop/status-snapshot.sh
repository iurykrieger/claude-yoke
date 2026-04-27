#!/usr/bin/env bash
# status-snapshot.sh — emit one cycle-end status block.
#
# Usage: status-snapshot.sh <runtime-dir>
#
# Reads the cycle's scratch state under <runtime-dir> (= .yoke/runtime
# inside the host project) and emits a structured markdown status
# block to stdout. Invoked once per cycle by /yoke:implement after
# hooks/post-iteration.sh and hooks/check-hard-bounds.sh complete,
# before the next cycle's batch is issued.
#
# Inputs (under <runtime-dir>):
#   .cycle-counter                          — current cycle number
#   .loop-start                             — unix-epoch loop start
#   .snapshots/cycle-<N>.yaml               — computational sensor output
#   .judge-verdicts/cycle-<N>/*.json        — inferential-sensor verdicts
#   .judge-verdicts/cycle-<N>/.failures.log — per-cycle judge failure log
#                                             (one failed sensor id per line)
#
# Hard-bound config is read from ./.yoke/config.yaml via the same
# overrides.hard_bounds keys that hooks/check-hard-bounds.sh reads.
#
# Exit codes:
#   0   block emitted successfully (always — missing inputs are
#       absorbed into the block as conservative defaults so the
#       coordinator never aborts a cycle on snapshot trouble)
#   2   usage error
#
# Output format (fixed; one fact per line; section order: title →
# agent states → sensor counts → bounds):
#
#   ### Cycle <N> · <elapsed>s
#
#   - Generator:    done
#   - Validator:    done
#   - Orchestrator: done
#   - judge:<sensor-id-or-criterion>: done|failed
#
#   Sensors: <pass>/<fail>/<skip> computational · <pass>/<fail>/<skip> inferential
#   Bounds:  <cycles>/<cycles_max> cycles · <elapsed>s/<timeout>s elapsed

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: status-snapshot.sh <runtime-dir>

Emit one cycle-end status block to stdout from the cycle scratch
state under <runtime-dir>. Always exits 0 unless the invocation
itself is malformed (exit 2).
EOF
}

if [ $# -lt 1 ]; then
  echo "status-snapshot: missing required <runtime-dir> argument" >&2
  usage >&2
  exit 2
fi

runtime_dir="$1"

if [ ! -d "$runtime_dir" ]; then
  # Structured-error contract per conventions.md "Sensor output for LLM
  # consumption": precise identification + location + correction.
  cat >&2 <<EOF
status-snapshot: error
  reason: runtime-dir-not-found
  location: ${runtime_dir}
  correction: ensure /yoke:implement preflight has created \$(wm_runtime_dir) before invoking this helper
EOF
  exit 3
fi

# --- Cycle number -----------------------------------------------------------
counter_file="$runtime_dir/.cycle-counter"
cycle=0
if [ -f "$counter_file" ]; then
  raw_cycle=$(tr -d '[:space:]' < "$counter_file" 2>/dev/null || true)
  if [[ "$raw_cycle" =~ ^[0-9]+$ ]]; then
    cycle="$raw_cycle"
  fi
fi

# --- Elapsed time -----------------------------------------------------------
start_file="$runtime_dir/.loop-start"
elapsed_secs=0
elapsed_str="0s"
if [ -f "$start_file" ]; then
  start_ts=$(tr -d '[:space:]' < "$start_file" 2>/dev/null || true)
  if [[ "$start_ts" =~ ^[0-9]+$ ]]; then
    now_ts=$(date +%s)
    elapsed_secs=$((now_ts - start_ts))
    [ "$elapsed_secs" -lt 0 ] && elapsed_secs=0
    elapsed_str="${elapsed_secs}s"
  fi
fi

# --- Hard-bound config (mirrors check-hard-bounds.sh) -----------------------
config=".yoke/config.yaml"
cycles_max=8
timeout_seconds=14400

read_hard_bound() {
  local key="$1"
  local default="$2"
  if [ ! -f "$config" ]; then
    echo "$default"
    return
  fi
  local v
  v=$(awk -v k="$key" '
    /^overrides:/                       { in_o=1; next }
    in_o && /^[a-z]/                    { in_o=0 }
    in_o && /^[[:space:]]+hard_bounds:/ { in_h=1; next }
    in_o && in_h && $1 == k":" {
      print $2; exit
    }
  ' "$config" 2>/dev/null || true)
  if [ -z "$v" ]; then
    echo "$default"
  else
    echo "$v"
  fi
}

cycles_max=$(read_hard_bound "cycles_max" "$cycles_max")
timeout_seconds=$(read_hard_bound "timeout_seconds" "$timeout_seconds")

# --- Sensor counts (computational) ------------------------------------------
snap_file="$runtime_dir/.snapshots/cycle-${cycle}.yaml"
comp_pass=0; comp_fail=0; comp_skip=0
if [ -f "$snap_file" ]; then
  comp_pass=$(awk '/^[[:space:]]*status:[[:space:]]*pass[[:space:]]*$/{c++} END{print c+0}' "$snap_file")
  comp_fail=$(awk '/^[[:space:]]*status:[[:space:]]*fail[[:space:]]*$/{c++} END{print c+0}' "$snap_file")
  comp_skip=$(awk '/^[[:space:]]*status:[[:space:]]*skip[[:space:]]*$/{c++} END{print c+0}' "$snap_file")
fi

# --- Sensor counts + per-judge state (inferential) --------------------------
verdicts_dir="$runtime_dir/.judge-verdicts/cycle-${cycle}"
inf_pass=0; inf_fail=0; inf_skip=0
declare -a judge_lines=()

if [ -d "$verdicts_dir" ]; then
  failures_log="$verdicts_dir/.failures.log"

  # Failed-judge ids (one per line) — used to decide done vs failed
  failed_ids=""
  if [ -f "$failures_log" ]; then
    failed_ids=$(cat "$failures_log" 2>/dev/null || true)
  fi

  shopt -s nullglob
  for verdict_file in "$verdicts_dir"/*.json; do
    label=$(basename "$verdict_file" .json)
    state="done"
    if [ -n "$failed_ids" ] \
      && printf '%s\n' "$failed_ids" | grep -qFx -- "$label"; then
      state="failed"
    fi
    judge_lines+=("- judge:${label}: ${state}")

    status_field=$(
      grep -oE '"status"[[:space:]]*:[[:space:]]*"[a-z]+"' "$verdict_file" \
        2>/dev/null | head -n1 \
        | sed -E 's/.*"([a-z]+)"[^"]*$/\1/'
    )
    case "${status_field:-}" in
      pass) inf_pass=$((inf_pass + 1)) ;;
      fail) inf_fail=$((inf_fail + 1)) ;;
      skip) inf_skip=$((inf_skip + 1)) ;;
    esac
  done
  shopt -u nullglob

  # Surface judges that failed without producing a verdict file
  # (failures.log entry but no .json on disk).
  if [ -n "$failed_ids" ]; then
    while IFS= read -r failed_id; do
      [ -z "$failed_id" ] && continue
      if [ ! -f "$verdicts_dir/${failed_id}.json" ]; then
        judge_lines+=("- judge:${failed_id}: failed")
      fi
    done <<< "$failed_ids"
  fi
fi

# --- Emit the block ---------------------------------------------------------
printf '### Cycle %s · %s\n' "$cycle" "$elapsed_str"
printf '\n'
printf -- '- Generator:    done\n'
printf -- '- Validator:    done\n'
printf -- '- Orchestrator: done\n'
for line in "${judge_lines[@]:-}"; do
  [ -z "$line" ] && continue
  printf '%s\n' "$line"
done
printf '\n'
printf 'Sensors: %s/%s/%s computational · %s/%s/%s inferential\n' \
  "$comp_pass" "$comp_fail" "$comp_skip" \
  "$inf_pass" "$inf_fail" "$inf_skip"
printf 'Bounds:  %s/%s cycles · %ss/%ss elapsed\n' \
  "$cycle" "$cycles_max" "$elapsed_secs" "$timeout_seconds"

exit 0
