#!/usr/bin/env bash
# tests/sensors/body-lint.test.sh — permanent CI-gated test for the
# strict body-shape contract enforced by ack-sensors.sh --mode readiness.
#
# Loops over every fixture under tests/fixtures/sensors/body-lint/,
# invokes `lib/sensors/ack-sensors.sh --mode readiness <fixture>`,
# and asserts the expected exit code + (for invalid fixtures) the
# expected substring in stderr.
#
# Source PRD: .yoke/prds/2026-04-30-sensor-harness-realignment.md
# (Sprint 3, t04). Permanent — runs in the CI gate (Sprint 3 t06).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

FAIL=0
INVOCATIONS=0
fail() { echo "FAIL: $*" >&2; FAIL=1; }
pass() { echo "PASS: $*"; }

echo "--- body-lint permanent test ---"

# ---------------------------------------------------------------------------
# Run a single fixture and assert (expected_exit, optional substrings).
# Args: <fixture-path> <expected-exit> [<stderr-substring> ...]
#   expected_exit:
#     0       — fixture is valid; readiness must succeed.
#     non0    — fixture is invalid; readiness must fail with non-zero exit
#               AND every supplied substring must appear in stderr.
#     warn0   — fixture is conditionally valid (warning, not fail);
#               readiness must succeed AND every supplied substring must
#               appear in stderr (warning text).
# ---------------------------------------------------------------------------
run_fixture() {
  local fixture="$1"
  local expected="$2"
  shift 2

  if [ ! -f "$fixture" ]; then
    fail "fixture missing: ${fixture}"
    return
  fi

  INVOCATIONS=$((INVOCATIONS + 1))

  local out ec
  set +e
  out=$(bash lib/sensors/ack-sensors.sh --mode readiness "$fixture" 2>&1)
  ec=$?
  set -e

  case "$expected" in
    0)
      if [ "$ec" -ne 0 ]; then
        fail "${fixture}: expected exit 0, got ${ec}; stderr: $(printf '%s' "$out" | head -3)"
        return
      fi
      pass "${fixture}: valid fixture passes readiness"
      ;;
    non0)
      if [ "$ec" -eq 0 ]; then
        fail "${fixture}: expected non-zero exit, got 0"
        return
      fi
      local sub missing=0
      for sub in "$@"; do
        if ! printf '%s' "$out" | grep -q "$sub"; then
          fail "${fixture}: stderr missing substring '${sub}' (got: $(printf '%s' "$out" | head -2))"
          missing=$((missing + 1))
        fi
      done
      [ "$missing" -eq 0 ] && pass "${fixture}: invalid fixture rejected with expected stderr"
      ;;
    warn0)
      if [ "$ec" -ne 0 ]; then
        fail "${fixture}: expected warning (exit 0), got non-zero exit ${ec}"
        return
      fi
      local sub missing=0
      for sub in "$@"; do
        if ! printf '%s' "$out" | grep -q "$sub"; then
          fail "${fixture}: stderr missing warning substring '${sub}'"
          missing=$((missing + 1))
        fi
      done
      [ "$missing" -eq 0 ] && pass "${fixture}: warning fixture passes with expected stderr"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Valid fixtures — must pass.
# ---------------------------------------------------------------------------
run_fixture "tests/fixtures/sensors/body-lint/valid-comp.md" 0
run_fixture "tests/fixtures/sensors/body-lint/valid-inf.md"  0

# ---------------------------------------------------------------------------
# Invalid fixtures — must fail with substring in stderr.
# ---------------------------------------------------------------------------
run_fixture "tests/fixtures/sensors/body-lint/missing-how-to-run.md" \
            non0 "## How to run"
run_fixture "tests/fixtures/sensors/body-lint/missing-known-issues.md" \
            non0 "## Known issues"
run_fixture "tests/fixtures/sensors/body-lint/missing-frequent-errors.md" \
            non0 "## Frequent errors"
run_fixture "tests/fixtures/sensors/body-lint/empty-known-issues.md" \
            non0 "Known issues" "empty"
run_fixture "tests/fixtures/sensors/body-lint/malformed-bullet.md" \
            non0 "Frequent errors"
run_fixture "tests/fixtures/sensors/body-lint/missing-prompt-on-inferential.md" \
            non0 "### Prompt"
run_fixture "tests/fixtures/sensors/body-lint/missing-rubric-on-inferential.md" \
            non0 "### Rubric"
run_fixture "tests/fixtures/sensors/body-lint/missing-verdict-on-inferential.md" \
            non0 "### Verdict schema"

# ---------------------------------------------------------------------------
# Warning fixture — passes with stderr containing the warning.
# ---------------------------------------------------------------------------
run_fixture "tests/fixtures/sensors/body-lint/calibration-on-computational.md" \
            warn0 "Warning" "Calibration"

# ---------------------------------------------------------------------------
# Invocation-count assertion: at least 11 distinct fixtures exercised.
# ---------------------------------------------------------------------------
if [ "$INVOCATIONS" -lt 11 ]; then
  fail "exercised only ${INVOCATIONS} fixtures (expected ≥ 11)"
else
  pass "exercised ${INVOCATIONS} distinct fixtures (≥ 11 required)"
fi

if [ "$FAIL" -eq 0 ]; then
  echo "--- body-lint: ALL PASS (${INVOCATIONS} fixtures) ---"
  exit 0
else
  echo "--- body-lint: FAILURES ABOVE ---" >&2
  exit 1
fi
