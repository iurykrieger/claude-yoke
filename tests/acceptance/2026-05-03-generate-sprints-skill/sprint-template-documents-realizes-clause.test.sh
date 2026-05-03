#!/usr/bin/env bash
#
# Acceptance Contract Scenario 4 (binding):
#   "`templates/sprint.md` documents the `(Realizes: UC-N)` clause"
#   Task: 2026-05-03-generate-sprints-skill-s01-t04
#
# Then-clause (verbatim):
#   `grep -c '(Realizes:' templates/sprint.md` returns 0 status
#   with stdout integer >= 1
#   AND `grep -c 'legacy-flow' templates/sprint.md` returns 0
#   status with stdout integer >= 1.
#
set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

TEMPLATE="templates/sprint.md"
FAIL=0

if [[ ! -f "$TEMPLATE" ]]; then
  printf 'FAIL: %s does not exist\n' "$TEMPLATE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Block 1 — `(Realizes:` documented at least once.
# ---------------------------------------------------------------------------
realizes_count="$(grep -c '(Realizes:' "$TEMPLATE" || true)"
if [[ "$realizes_count" =~ ^[0-9]+$ ]] && [[ "$realizes_count" -ge 1 ]]; then
  printf 'PASS: templates/sprint.md documents (Realizes: ...) clause (count=%s)\n' "$realizes_count"
else
  printf 'FAIL: templates/sprint.md does not document (Realizes: ...) clause (count=%s)\n' "$realizes_count" >&2
  FAIL=1
fi

# ---------------------------------------------------------------------------
# Block 2 — `legacy-flow` carve-out documented at least once.
# ---------------------------------------------------------------------------
legacy_count="$(grep -c 'legacy-flow' "$TEMPLATE" || true)"
if [[ "$legacy_count" =~ ^[0-9]+$ ]] && [[ "$legacy_count" -ge 1 ]]; then
  printf 'PASS: templates/sprint.md documents the legacy-flow carve-out (count=%s)\n' "$legacy_count"
else
  printf 'FAIL: templates/sprint.md missing the legacy-flow carve-out (count=%s)\n' "$legacy_count" >&2
  FAIL=1
fi

if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: sprint-template-documents-realizes-clause\n' >&2
  exit 1
fi
printf '\n--- Result ---\nPASS: sprint-template-documents-realizes-clause\n'
exit 0
