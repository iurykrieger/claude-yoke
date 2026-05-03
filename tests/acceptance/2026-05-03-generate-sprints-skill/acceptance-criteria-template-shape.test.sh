#!/usr/bin/env bash
#
# Binding Acceptance Criteria (re-ratified 2026-05-03T10:44:11Z):
#   US-002 — Reshape acceptance-criteria around the canonical shape.
#   AC-002-1..AC-002-4 anchor the template-shape contract; this test
#   covers the documented-shape part of US-002's DoD ("template is the
#   canonical post-rename shape … this work consumes it as-is").
#
# Then-clause (binding):
#   `test -f templates/acceptance-criteria.md && grep -c '^### US-'
#   templates/acceptance-criteria.md` exits 0 with stdout integer >= 1
#   AND `grep -EIn '<slug>-s[0-9]+-t[0-9]+' templates/acceptance-criteria.md`
#   exits non-zero (no task-ID strings).
#
# History — re-ratification cutover note:
#   The prior cycle-0 draft of this test asserted `### UC-N` headings
#   (the pre-re-ratification UC-N shape). On 2026-05-03 the AC was
#   re-ratified post-merge to anchor on the canonical `### US-<NNN>`
#   shape (consumed verbatim from main's rename PR). The test was
#   re-authored in cycle 1 Phase A to match the binding contract.
#   The shape-checker `_lib/check-shape.sh` accepts both `US-` and
#   `UC-` for backward compatibility with cycle-0 fixtures; the
#   template assertion is strictly `US-` per the canonical contract.
#
set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

TEMPLATE="templates/acceptance-criteria.md"
FAIL=0

# ---------------------------------------------------------------------------
# Then-clause part 1 — file exists AND contains >= 1 `### US-` heading.
# ---------------------------------------------------------------------------
if [[ ! -f "$TEMPLATE" ]]; then
  printf 'FAIL: %s does not exist\n' "$TEMPLATE" >&2
  FAIL=1
else
  us_count="$(grep -c '^### US-' "$TEMPLATE" || true)"
  if [[ "$us_count" =~ ^[0-9]+$ ]] && [[ "$us_count" -ge 1 ]]; then
    printf 'PASS: template has %s US heading(s) (>= 1)\n' "$us_count"
  else
    printf 'FAIL: template has zero `### US-` headings (count=%s)\n' "$us_count" >&2
    FAIL=1
  fi
fi

# ---------------------------------------------------------------------------
# Then-clause part 2 — zero matches for `<slug>-s<NN>-t<MM>` task IDs.
# We use the same narrow regex documented in
# tests/acceptance/2026-05-03-generate-sprints-skill/_lib/check-shape.sh
# so the template-level invariant is decided by the same rule the
# runtime shape-checker uses.
# ---------------------------------------------------------------------------
if grep -EIn '[0-9]{4}-[0-9]{2}-[0-9]{2}-[A-Za-z0-9._-]+-s[0-9]+-t[0-9]+' "$TEMPLATE" >/tmp/ac-template-tids.out 2>&1; then
  printf 'FAIL: template carries forbidden task-ID reference(s):\n' >&2
  cat /tmp/ac-template-tids.out >&2
  FAIL=1
else
  printf 'PASS: template has zero task-ID references\n'
fi
rm -f /tmp/ac-template-tids.out

if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: acceptance-criteria-template-shape\n' >&2
  exit 1
fi
printf '\n--- Result ---\nPASS: acceptance-criteria-template-shape\n'
exit 0
