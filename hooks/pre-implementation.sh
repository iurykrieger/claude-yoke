#!/bin/bash
# pre-implementation.sh — runs before /yoke:implement enters its loop.
#
# Records the loop-start timestamp under .yoke/runtime/.loop-start so
# that hooks/check-hard-bounds.sh and lib/ralph-loop/status-snapshot.sh
# can compute elapsed time. Idempotent: leaves an existing .loop-start
# untouched (the loop may resume across multiple invocations of the
# skill within the same task; the recorded start is the first one).
#
# The structural preflight (PRD/Tech-Spec/Acceptance-Contract approval
# checks) lives in lib/ralph-loop/orchestrate.sh preflight, called
# directly from skills/implement/SKILL.md.

set -euo pipefail

hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/working-memory/paths.sh
source "${hook_dir}/../lib/working-memory/paths.sh"

runtime_dir="$(wm_runtime_dir)"
mkdir -p "$runtime_dir"

start_file="$runtime_dir/.loop-start"
if [ ! -f "$start_file" ]; then
  date +%s > "$start_file"
fi

exit 0
