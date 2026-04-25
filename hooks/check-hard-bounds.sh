#!/bin/bash
# check-hard-bounds.sh — enforce hard bounds on the ralph loop after each cycle.
#
# Verifies (in this order):
#   - Cycle count vs cycles_max  (read from .yoke/runtime/.cycle-counter and .yoke/config.yaml)
#   - Elapsed time vs timeout_seconds  (read from .yoke/runtime/.loop-start)
#   - Token usage vs token_budget  (read from .yoke/runtime/.token-budget-used)
#
# When any bound is reached, this script does NOT abort the task. It invokes
# `lib/ralph-loop/escalate.sh` to emit a structured Trigger-4 packet, then
# exits 10 so the calling skill can pause and surface the packet to the user.
#
# Usage: check-hard-bounds.sh [--config <path>]
# Default config: .yoke/config.yaml
#
# Defaults (if no overrides):
#   cycles_max: 8
#   timeout_seconds: 14400  (4h)
#   token_budget: 200000
#
# Per-project overrides come from .yoke/config.yaml under
# `overrides.hard_bounds:` (cycles_max, timeout_seconds, token_budget).
#
# Exit codes:
#   0   no bound hit (loop may continue)
#   2   usage error
#   3   .yoke/ missing (or required state file missing)
#   10  hard bound reached (escalate.sh has been invoked; loop should pause)

set -euo pipefail

# Locate paths helper relative to this hook (so cwd doesn't matter).
hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/working-memory/paths.sh
source "${hook_dir}/../lib/working-memory/paths.sh"

config=".yoke/config.yaml"

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --config) config="${2:-.yoke/config.yaml}"; shift 2 ;;
    -h|--help) sed -n '1,30p' "$0"; exit 0 ;;
    "") break ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ ! -d ".yoke" ]; then
  echo "Error: .yoke/ not found." >&2
  exit 3
fi

# Read overrides from config
read_override() {
  local key="$1"
  local default="$2"
  if [ ! -f "$config" ]; then
    echo "$default"
    return
  fi
  local v
  v=$(awk -v k="$key" '
    /^overrides:/                     { in_o=1; next }
    in_o && /^[a-z]/                  { in_o=0 }
    in_o && /^[[:space:]]+hard_bounds:/ { in_h=1; next }
    in_o && in_h && /^[[:space:]]+[a-z]/ && !/^[[:space:]]+#/ {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      if (line ~ "^"k":") {
        sub(".*"k":[[:space:]]*", "", line)
        gsub(/[[:space:]]+#.*/, "", line)
        gsub(/^"|"$/, "", line)
        print line
        exit
      }
    }
    in_o && in_h && /^[[:space:]]+[^[:space:]]/ && /^[[:space:]]+[a-z]+:/ && !/^[[:space:]]+hard_bounds/ {
      # End of hard_bounds block when we hit another sibling key
    }
  ' "$config" 2>/dev/null)
  if [ -z "$v" ]; then
    echo "$default"
  else
    echo "$v"
  fi
}

cycles_max=$(read_override "cycles_max" "8")
timeout_seconds=$(read_override "timeout_seconds" "14400")
token_budget=$(read_override "token_budget" "200000")

# Cycle counter
counter_file="$(wm_cycle_counter_path)"
cycles=0
if [ -f "$counter_file" ]; then
  cycles=$(cat "$counter_file")
fi

# Elapsed time (loop start timestamp under runtime/, unix epoch seconds)
start_file="$(wm_runtime_dir)/.loop-start"
elapsed=0
if [ -f "$start_file" ]; then
  start_ts=$(cat "$start_file")
  now_ts=$(date +%s)
  elapsed=$((now_ts - start_ts))
fi

# Token budget used (best-effort; populated by post-iteration if tracked)
budget_file="$(wm_runtime_dir)/.token-budget-used"
tokens=0
if [ -f "$budget_file" ]; then
  tokens=$(cat "$budget_file")
fi

# Check bounds
bound_hit=""
if [ "$cycles" -ge "$cycles_max" ]; then
  bound_hit="cycles"
elif [ "$elapsed" -ge "$timeout_seconds" ]; then
  bound_hit="timeout"
elif [ "$tokens" -ge "$token_budget" ]; then
  bound_hit="budget"
fi

if [ -z "$bound_hit" ]; then
  exit 0
fi

# Bound hit — invoke escalate.sh with a hard-bound reason
hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
escalate_sh="${hook_dir}/../lib/ralph-loop/escalate.sh"

if [ -f "$escalate_sh" ]; then
  bash "$escalate_sh" \
    --reason "hard-bound" \
    --category "$bound_hit" \
    --cycles "$cycles" \
    --cycles-max "$cycles_max" \
    --elapsed "$elapsed" \
    --timeout "$timeout_seconds" \
    --tokens "$tokens" \
    --token-budget "$token_budget" || true
fi

echo "Hard bound reached: $bound_hit (cycles=$cycles/$cycles_max, elapsed=${elapsed}s/${timeout_seconds}s, tokens=$tokens/$token_budget)" >&2
exit 10
