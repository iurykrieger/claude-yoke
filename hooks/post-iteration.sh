#!/bin/bash
# post-iteration.sh — runs at the end of every ralph-loop cycle.
#
# Increments the cycle counter at .yoke/.cycle-counter (read by
# Sprint-6's hooks/check-hard-bounds.sh) and snapshots
# verify-acceptance.sh output to .yoke/.snapshots/cycle-<N>.yaml.
#
# Usage: post-iteration.sh [<acceptance-contract-path>]
# Default contract: .yoke/acceptance-contract.md
#
# v0.4.0: snapshot + counter only. Sprint 6 wires the counter into
# hooks/check-hard-bounds.sh for cycle-cap enforcement.
#
# Exit codes:
#   0   success
#   3   .yoke/ missing

set -euo pipefail

contract="${1:-.yoke/acceptance-contract.md}"

if [ ! -d ".yoke" ]; then
  echo "Error: .yoke/ not found. Run /yoke:bootstrap first." >&2
  exit 3
fi

snapshot_dir=".yoke/.snapshots"
mkdir -p "$snapshot_dir"

# Cycle counter (read by check-hard-bounds.sh in Sprint 6+)
counter_file=".yoke/.cycle-counter"
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
