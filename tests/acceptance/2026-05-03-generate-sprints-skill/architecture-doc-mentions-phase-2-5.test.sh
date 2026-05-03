#!/usr/bin/env bash
#
# Binding Acceptance Criterion (binding contract):
#   AC-008-1: grep -c 'Phase 2\.5' docs/architecture.md returns ≥ 1;
#             grep -c '/yoke:generate-sprints' docs/architecture.md
#             returns ≥ 1.
#
set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

DOC="docs/architecture.md"

if [[ ! -f "$DOC" ]]; then
  printf 'FAIL: AC-008-1 — %s missing\n' "$DOC" >&2
  exit 1
fi

PHASE_COUNT="$(grep -c 'Phase 2\.5' "$DOC" 2>/dev/null || true)"
PHASE_COUNT="${PHASE_COUNT:-0}"
if (( PHASE_COUNT < 1 )); then
  printf 'FAIL: AC-008-1 — `Phase 2.5` mentions in %s = %s, expected >= 1\n' "$DOC" "$PHASE_COUNT" >&2
  exit 1
fi
printf 'PASS: AC-008-1 — `Phase 2.5` mentions in %s = %s\n' "$DOC" "$PHASE_COUNT"

SKILL_COUNT="$(grep -c '/yoke:generate-sprints' "$DOC" 2>/dev/null || true)"
SKILL_COUNT="${SKILL_COUNT:-0}"
if (( SKILL_COUNT < 1 )); then
  printf 'FAIL: AC-008-1 — `/yoke:generate-sprints` mentions in %s = %s, expected >= 1\n' "$DOC" "$SKILL_COUNT" >&2
  exit 1
fi
printf 'PASS: AC-008-1 — `/yoke:generate-sprints` mentions in %s = %s\n' "$DOC" "$SKILL_COUNT"

printf '\n--- Result ---\nPASS: architecture-doc-mentions-phase-2-5\n'
exit 0
