#!/usr/bin/env bash
#
# Binding Acceptance Criteria (PRD US-004 — runtime plan path is
# gitignored, ratified 2026-05-03T06:39:27Z):
#   "the skill emits a structured intermediate (committed to runtime
#    state under .yoke/runtime/.generate-sprints-plan.yaml, gitignored)"
#   Sprint DoD line: `grep -q '^\.yoke/runtime/\.generate-sprints-plan\.yaml$'
#     .gitignore` returns 0.
#   Task s02-t05 acceptance criterion (binding then-clause):
#     `git check-ignore -v .yoke/runtime/.generate-sprints-plan.yaml`
#     exits 0 AND
#     `git check-ignore -v .yoke/runtime/.generate-sprints-tmp/scratch`
#     exits 0.
#
# Sprint-level anchor:
#   - Functional acceptance criterion id: runtime-plan-gitignored
#
# Then-clause (binding):
#   `git check-ignore -v` exits 0 for both paths. The exact rule
#   source (top-level .gitignore vs .yoke/.gitignore) is NOT binding —
#   any matching gitignore rule satisfies the criterion. The repo
#   currently ships .yoke/.gitignore with `runtime/` which already
#   covers both paths; if Sr Eng's s02-t05 implementation lifts the
#   rules into a top-level .gitignore the test still passes.
#
# Watchdog convention — keep the smoke-test guard.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

FAIL=0

paths=(
  ".yoke/runtime/.generate-sprints-plan.yaml"
  ".yoke/runtime/.generate-sprints-tmp/scratch"
)

for p in "${paths[@]}"; do
  OUT="$(git check-ignore -v "$p" 2>&1 || true)"
  RC=0
  git check-ignore -v "$p" >/dev/null 2>&1 || RC=$?
  if [[ "$RC" -eq 0 ]]; then
    printf 'PASS: %s is gitignored (rule: %s)\n' "$p" "$OUT"
  else
    printf 'FAIL: %s is NOT gitignored (rc=%d)\n' "$p" "$RC" >&2
    FAIL=1
  fi
done

if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: runtime-plan-path-is-gitignored\n' >&2
  exit 1
fi
printf '\n--- Result ---\nPASS: runtime-plan-path-is-gitignored\n'
exit 0
