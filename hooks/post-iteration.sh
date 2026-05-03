#!/bin/bash
# post-iteration.sh — runs at the end of every ralph-loop cycle.
#
# Increments the cycle counter at .yoke/runtime/.cycle-counter (read by
# Sprint-6's hooks/check-hard-bounds.sh) and persists the cycle's
# verify-acceptance.sh snapshot to .yoke/runtime/.snapshots/cycle-<N>.yaml.
#
# Usage: post-iteration.sh [<acceptance-criteria-path>]
# Default contract: resolved via lib/working-memory/paths.sh::wm_acceptance_criteria_path
#
# Snapshot resolution order (Part-1 perf-quickwins, v0.7.0):
#   1. If .yoke/runtime/.pending-snapshot.yaml exists (written by
#      skills/implement/SKILL.md step 2 via verify-acceptance.sh,
#      possibly with --criterion scoping), move it to
#      .yoke/runtime/.snapshots/cycle-<N>.yaml. Likewise promote
#      .yoke/runtime/.pending-fragments/ to
#      .yoke/runtime/.snapshots/cycle-<N>.fragments/.
#      The hook does NOT re-run sensors — that satisfies the
#      "exactly once per cycle" invariant.
#   2. Else, fall back to running verify-acceptance.sh inline (legacy
#      path, used by direct callers and pre-perf-quickwins flows).
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
  contract="$(wm_acceptance_criteria_path)" || exit 3
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

# Pending-snapshot promotion (Part-1 perf-quickwins).
runtime_dir="$(wm_runtime_dir)"
pending_snapshot="${runtime_dir}/.pending-snapshot.yaml"
pending_fragments="${runtime_dir}/.pending-fragments"
target_snapshot="${snapshot_dir}/cycle-${counter}.yaml"
target_fragments="${snapshot_dir}/cycle-${counter}.fragments"

if [ -f "$pending_snapshot" ]; then
  # Coordinator's single per-cycle execution already produced the YAML.
  # Promote it; do NOT re-run sensors.
  mv "$pending_snapshot" "$target_snapshot"
  if [ -d "$pending_fragments" ]; then
    rm -rf "$target_fragments"
    mv "$pending_fragments" "$target_fragments"
  fi
else
  # Fallback: run verify-acceptance.sh inline (legacy path; serial run).
  verify_sh="${hook_dir}/verify-acceptance.sh"
  if [ -f "$contract" ] && [ -f "$verify_sh" ]; then
    bash "$verify_sh" "$contract" --concurrency 1 \
      --fragments-dir "$target_fragments" \
      > "$target_snapshot" 2>&1 || true
  fi
fi

echo "cycle=${counter} snapshot=${target_snapshot}"
exit 0
