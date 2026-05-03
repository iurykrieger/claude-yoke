#!/usr/bin/env bash
# criterion: AC-003-3 / sprint-02 parse-inputs-emits-ucs-json
#
# Binding Acceptance Criteria (PRD US-003 + FR-3, ratified
# 2026-05-03T06:39:27Z):
#   FR-3: "/yoke:acceptance-criteria MUST emit a file at
#   .yoke/acceptance-criteria/<slug>.md whose body lists at least one
#   `### UC-<n>` heading, where each UC carries name, DoD, criteria,
#   FR mapping, and a sensor list."
#
#   The post re-ratification of 2026-05-03T10:44:11Z accepts both
#   `### US-<NNN>` (canonical) and `### UC-<n>` (legacy) headings (see
#   tests/acceptance/2026-05-03-generate-sprints-skill/_lib/check-shape.sh).
#   This test follows the brief's wording verbatim — `### US-` blocks —
#   while remaining tolerant of `### UC-` for back-compat fixtures.
#
# Sprint-level anchor:
#   - Functional acceptance criterion id: parse-inputs-emits-ucs-json
#   - Task s02-t03 acceptance criterion: `parse_acceptance_criteria`
#     stdout is valid JSON parseable by `python3 -c "import json,sys;
#     json.load(sys.stdin)"` AND the `ucs` array length equals the
#     count of `### UC-` (or `### US-`) headings in the fixture.
#
# Then-clause (binding):
#   1. Helper file `lib/generate-sprints/parse-inputs.sh` exists and
#      defines a function `parse_acceptance_criteria`.
#   2. Running the helper against the happy-path fixture
#      (tests/fixtures/generate-sprints/parse-inputs/happy.md) emits
#      stdout that is valid JSON.
#   3. The JSON's top-level `user_stories` (or legacy `ucs`) array
#      length equals the count of `### US-` (or `### UC-`) headings in
#      the fixture file.
#   4. Running the helper against the malformed fixture
#      (parse-inputs/malformed-us.md) exits non-zero with a `wm:`-
#      prefixed diagnostic on stderr.
#
# Sr Eng integration note:
#   The brief calls the JSON key `user_stories` (US-### shape); the
#   sprint task body calls it `ucs` (UC-N shape). The PRD (binding) is
#   silent on the JSON key name — only the array-length-equals-headings
#   invariant is binding. We accept either key as long as the length
#   invariant holds.
#
# Watchdog convention — keep the smoke-test guard.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

PARSE_LIB="lib/generate-sprints/parse-inputs.sh"
HAPPY="tests/fixtures/generate-sprints/parse-inputs/happy.md"
MALFORMED="tests/fixtures/generate-sprints/parse-inputs/malformed-us.md"
FAIL=0

# ---------------------------------------------------------------------------
# Then-clause part 1 — helper file exists.
# ---------------------------------------------------------------------------
if [[ ! -f "$PARSE_LIB" ]]; then
  printf 'FAIL: %s does not exist (Sr Eng output pending; expected in s02-t03)\n' "$PARSE_LIB" >&2
  printf '\n--- Result ---\nFAIL: us-003-parse-inputs-shape\n' >&2
  exit 1
fi
printf 'PASS: %s exists\n' "$PARSE_LIB"

# ---------------------------------------------------------------------------
# Source the helper. If sourcing throws, that is itself a binding-
# contract violation (the helper must be sourceable as a bash library
# per s02-t03's "function parse_acceptance_criteria <ac-path>").
# ---------------------------------------------------------------------------
# shellcheck disable=SC1090
if ! source "$PARSE_LIB" 2>/tmp/parse-inputs-source.err; then
  printf 'FAIL: cannot source %s:\n' "$PARSE_LIB" >&2
  sed 's/^/    /' /tmp/parse-inputs-source.err >&2 || true
  rm -f /tmp/parse-inputs-source.err
  printf '\n--- Result ---\nFAIL: us-003-parse-inputs-shape\n' >&2
  exit 1
fi
rm -f /tmp/parse-inputs-source.err

if ! declare -F parse_acceptance_criteria >/dev/null 2>&1; then
  printf 'FAIL: function `parse_acceptance_criteria` not defined after sourcing %s\n' "$PARSE_LIB" >&2
  printf '\n--- Result ---\nFAIL: us-003-parse-inputs-shape\n' >&2
  exit 1
fi
printf 'PASS: function `parse_acceptance_criteria` defined\n'

# ---------------------------------------------------------------------------
# Then-clause part 2 — happy path produces valid JSON.
# ---------------------------------------------------------------------------
if [[ ! -f "$HAPPY" ]]; then
  printf 'FAIL: happy fixture missing at %s\n' "$HAPPY" >&2
  FAIL=1
else
  HAPPY_OUT="$(mktemp)"
  HAPPY_RC=0
  parse_acceptance_criteria "$HAPPY" >"$HAPPY_OUT" 2>/dev/null || HAPPY_RC=$?
  if [[ "$HAPPY_RC" -ne 0 ]]; then
    printf 'FAIL: parse_acceptance_criteria exited %d on happy-path fixture\n' "$HAPPY_RC" >&2
    FAIL=1
  elif ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$HAPPY_OUT" 2>/dev/null; then
    printf 'FAIL: parse_acceptance_criteria stdout is not valid JSON\n' >&2
    sed 's/^/    /' "$HAPPY_OUT" | head -20 >&2 || true
    FAIL=1
  else
    printf 'PASS: parse_acceptance_criteria emits valid JSON on happy fixture\n'

    # ---------------------------------------------------------------------
    # Then-clause part 3 — array length equals heading count.
    # Accept either `user_stories` (US-### shape, brief's wording) or
    # `ucs` (UC-N shape, sprint-task wording). The binding invariant is
    # length-equals-headings.
    # ---------------------------------------------------------------------
    expected_n="$(grep -cE '^### (US|UC)-' "$HAPPY" || true)"
    actual_n="$(python3 -c '
import json, sys
data = json.load(open(sys.argv[1]))
arr = data.get("user_stories")
if arr is None:
    arr = data.get("ucs")
if arr is None:
    sys.exit("missing-key")
print(len(arr))
' "$HAPPY_OUT" 2>/dev/null || echo "ERR")"
    if [[ "$actual_n" == "ERR" ]]; then
      printf 'FAIL: JSON lacks both `user_stories` and `ucs` top-level keys\n' >&2
      FAIL=1
    elif [[ "$actual_n" -ne "$expected_n" ]]; then
      printf 'FAIL: array length=%s but heading count=%s in %s\n' \
        "$actual_n" "$expected_n" "$HAPPY" >&2
      FAIL=1
    else
      printf 'PASS: parsed array length=%s matches heading count=%s\n' \
        "$actual_n" "$expected_n"
    fi
  fi
  rm -f "$HAPPY_OUT"
fi

# ---------------------------------------------------------------------------
# Then-clause part 4 — malformed fixture rejected with wm:-prefixed
# stderr.
# ---------------------------------------------------------------------------
if [[ ! -f "$MALFORMED" ]]; then
  printf 'FAIL: malformed fixture missing at %s\n' "$MALFORMED" >&2
  FAIL=1
else
  MAL_ERR="$(mktemp)"
  MAL_RC=0
  parse_acceptance_criteria "$MALFORMED" >/dev/null 2>"$MAL_ERR" || MAL_RC=$?
  if [[ "$MAL_RC" -eq 0 ]]; then
    printf 'FAIL: parse_acceptance_criteria unexpectedly succeeded on malformed fixture\n' >&2
    FAIL=1
  elif ! grep -qE '^wm:' "$MAL_ERR"; then
    printf 'FAIL: malformed-fixture rejection lacks `wm:`-prefixed stderr\n' >&2
    sed 's/^/    /' "$MAL_ERR" >&2 || true
    FAIL=1
  else
    printf 'PASS: parse_acceptance_criteria rejected malformed fixture with wm: stderr\n'
  fi
  rm -f "$MAL_ERR"
fi

if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: us-003-parse-inputs-shape\n' >&2
  exit 1
fi
printf '\n--- Result ---\nPASS: us-003-parse-inputs-shape\n'
exit 0
