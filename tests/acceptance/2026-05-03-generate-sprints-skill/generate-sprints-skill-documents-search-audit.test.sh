#!/usr/bin/env bash
#
# Binding Acceptance Criterion (binding contract):
#   "Each `/yoke:search-canonical-memory` invocation produces exactly one
#    `search:` line in `.yoke/runtime/progress.md` for the active cycle."
#
set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

SKILL_BODY="skills/generate-sprints/SKILL.md"
FAIL=0

if [[ ! -f "$SKILL_BODY" ]]; then
  printf 'FAIL: %s missing — required by Sprint 3 task s03-t01\n' "$SKILL_BODY" >&2
  exit 1
fi

# Step 1 — skill body references the canonical-memory invocation.
if ! grep -qE 'search-canonical-memory' "$SKILL_BODY"; then
  printf 'FAIL: %s does not reference `/yoke:search-canonical-memory` — required by s03-t01 contract\n' \
    "$SKILL_BODY" >&2
  FAIL=1
fi

# Step 2 — skill body documents the `search:` log convention.
# Acceptable forms: `search:` (literal token), backticked `search:`, or the
# phrasing "search: event" / "as a search:" inline.
if ! grep -qE '(`search:`|`search:\s|search:\s+event|as a `?search:?`?\s+event|log[^.]+search:?)' "$SKILL_BODY"; then
  printf 'FAIL: %s does not document the `search:` log convention in progress.md\n' \
    "$SKILL_BODY" >&2
  FAIL=1
fi

# Step 3 — proximity check: the `search:` literal MUST appear within 50
# lines of every `/yoke:search-canonical-memory` mention. This guards
# against the documentation drifting (the call documented in one
# section, the logging convention forgotten in another).
SEARCH_LINES="$(grep -nE 'search-canonical-memory' "$SKILL_BODY" | cut -d: -f1)"
LOG_LINES="$(grep -nE 'search:' "$SKILL_BODY" | cut -d: -f1)"

if [[ -z "$SEARCH_LINES" || -z "$LOG_LINES" ]]; then
  # Already flagged above; nothing more to do.
  :
else
  PROX_OK=1
  for s in $SEARCH_LINES; do
    NEAR=0
    for l in $LOG_LINES; do
      diff=$((s > l ? s - l : l - s))
      if [[ "$diff" -le 50 ]]; then
        NEAR=1
        break
      fi
    done
    if [[ "$NEAR" -ne 1 ]]; then
      printf 'FAIL: %s line %d (`search-canonical-memory`) has no `search:` log mention within 50 lines\n' \
        "$SKILL_BODY" "$s" >&2
      PROX_OK=0
    fi
  done
  if [[ "$PROX_OK" -ne 1 ]]; then
    FAIL=1
  fi
fi

if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: generate-sprints-skill-documents-search-audit\n' >&2
  exit 1
fi

printf 'PASS: skill body documents `/yoke:search-canonical-memory` invocation AND `search:` log convention with proximity ≤ 50 lines\n'
printf '\n--- Result ---\nPASS: generate-sprints-skill-documents-search-audit\n'
exit 0
