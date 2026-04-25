#!/bin/bash
# post-iteration.sh — runs at the end of every ralph-loop cycle.
#
# Increments the cycle counter at .yoke/runtime/.cycle-counter (read by
# Sprint-6's hooks/check-hard-bounds.sh) and snapshots
# verify-acceptance.sh output to .yoke/runtime/.snapshots/cycle-<N>.yaml.
#
# Usage: post-iteration.sh [<acceptance-contract-path>]
# Default contract: resolved via lib/working-memory/paths.sh::wm_acceptance_contract_path
#
# v0.4.0: snapshot + counter only. Sprint 6 wires the counter into
# hooks/check-hard-bounds.sh for cycle-cap enforcement.
#
# Exit codes:
#   0   success
#   3   .yoke/ missing or no active task

set -euo pipefail

# Locate paths helper relative to this hook (so cwd doesn't matter).
hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/working-memory/paths.sh
source "${hook_dir}/../lib/working-memory/paths.sh"

if [ ! -d ".yoke" ]; then
  echo "Error: .yoke/ not found. Run /yoke:bootstrap first." >&2
  exit 3
fi

# Resolve contract: either explicit arg or via active slug.
if [ -n "${1:-}" ]; then
  contract="$1"
else
  contract="$(wm_acceptance_contract_path)" || exit 3
fi

snapshot_dir="$(wm_snapshots_dir)"
mkdir -p "$snapshot_dir"

# Cycle counter (read by check-hard-bounds.sh in Sprint 6+)
counter_file="$(wm_cycle_counter_path)"
mkdir -p "$(dirname "$counter_file")"
if [ ! -f "$counter_file" ]; then
  echo "0" > "$counter_file"
fi
counter=$(cat "$counter_file")
counter=$((counter + 1))
echo "$counter" > "$counter_file"

# Snapshot verify-acceptance output. Locate the verify hook relative to this
# hook's own location (so it works regardless of the caller's cwd).
hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
verify_sh="${hook_dir}/verify-acceptance.sh"
if [ -f "$contract" ] && [ -f "$verify_sh" ]; then
  bash "$verify_sh" "$contract" > "$snapshot_dir/cycle-${counter}.yaml" 2>&1 || true
fi

echo "cycle=${counter} snapshot=${snapshot_dir}/cycle-${counter}.yaml"
exit 0
