#!/usr/bin/env bash
# criterion: scenario-05-ac-shape-smoke-green
#
# Acceptance Contract Scenario 5 (binding):
#   "AC-shape smoke test green across three fixtures"
#   Task: 2026-05-03-generate-sprints-skill-s01-t05
#
# Then-clause (verbatim):
#   The test exits 0 AND stdout contains exactly three lines starting
#   with `PASS:` (one per fixture branch) AND the negative-case
#   branches surface `wm: forbidden task-ID reference` and
#   `wm: no UC headings found` respectively.
#
# This acceptance test wraps the smoke
# `tests/smoke/acceptance-criteria-shape.test.sh` (the deliverable of
# task t05) and asserts the documented stdout shape on top of the
# smoke's own internal pass/fail logic. Independently, it also
# directly invokes the shape-checker against the malformed fixtures
# to assert the documented stderr literals — making this acceptance
# test resilient against a smoke that prints the right three PASS
# lines but suppresses stderr on the negative branches.
#
# Sprint anchor (sprint file's `## Functional acceptance criteria`):
#   ac-shape-smoke-test-green

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

SMOKE="tests/smoke/acceptance-criteria-shape.test.sh"
CHECKER="tests/acceptance/2026-05-03-generate-sprints-skill/_lib/check-shape.sh"
INVALID_TIDS="tests/fixtures/acceptance-criteria/invalid-task-ids.md"
INVALID_NO_UC="tests/fixtures/acceptance-criteria/invalid-no-uc.md"

FAIL=0

# Pre-flight — every artifact this scenario depends on must exist.
for f in "$SMOKE" "$CHECKER" "$INVALID_TIDS" "$INVALID_NO_UC"; do
  if [[ ! -f "$f" ]]; then
    printf 'FAIL: required artifact missing: %s\n' "$f" >&2
    FAIL=1
  fi
done
if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: scenario-05 (pre-flight)\n' >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Block 1 — the smoke exits 0.
# ---------------------------------------------------------------------------
SMOKE_OUT="$(mktemp)"
if bash "$SMOKE" >"$SMOKE_OUT" 2>/dev/null; then
  printf 'PASS: smoke exits 0\n'
else
  rc=$?
  printf 'FAIL: smoke exited rc=%d\n' "$rc" >&2
  cat "$SMOKE_OUT" >&2 || true
  FAIL=1
fi

# ---------------------------------------------------------------------------
# Block 2 — stdout contains exactly three lines starting with `PASS:`.
# ---------------------------------------------------------------------------
pass_lines="$(grep -c '^PASS:' "$SMOKE_OUT" || true)"
if [[ "$pass_lines" == "3" ]]; then
  printf 'PASS: smoke stdout has exactly 3 PASS: lines\n'
else
  printf 'FAIL: smoke stdout has %s PASS: lines (expected exactly 3)\n' "$pass_lines" >&2
  FAIL=1
fi
rm -f "$SMOKE_OUT"

# ---------------------------------------------------------------------------
# Block 3 — invalid-task-ids fixture surfaces the documented stderr.
# ---------------------------------------------------------------------------
ERR_TIDS="$(mktemp)"
if bash "$CHECKER" "$INVALID_TIDS" >/dev/null 2>"$ERR_TIDS"; then
  printf 'FAIL: shape-checker incorrectly accepted invalid-task-ids fixture\n' >&2
  FAIL=1
else
  if grep -q 'wm: forbidden task-ID reference' "$ERR_TIDS"; then
    printf 'PASS: invalid-task-ids stderr surfaces documented literal\n'
  else
    printf 'FAIL: invalid-task-ids stderr missing literal. stderr=%s\n' "$(cat "$ERR_TIDS")" >&2
    FAIL=1
  fi
fi
rm -f "$ERR_TIDS"

# ---------------------------------------------------------------------------
# Block 4 — invalid-no-uc fixture surfaces the documented stderr.
# ---------------------------------------------------------------------------
ERR_NOUC="$(mktemp)"
if bash "$CHECKER" "$INVALID_NO_UC" >/dev/null 2>"$ERR_NOUC"; then
  printf 'FAIL: shape-checker incorrectly accepted invalid-no-uc fixture\n' >&2
  FAIL=1
else
  if grep -q 'wm: no UC headings found' "$ERR_NOUC"; then
    printf 'PASS: invalid-no-uc stderr surfaces documented literal\n'
  else
    printf 'FAIL: invalid-no-uc stderr missing literal. stderr=%s\n' "$(cat "$ERR_NOUC")" >&2
    FAIL=1
  fi
fi
rm -f "$ERR_NOUC"

if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: scenario-05\n' >&2
  exit 1
fi
printf '\n--- Result ---\nPASS: scenario-05\n'
exit 0
