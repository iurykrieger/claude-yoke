#!/usr/bin/env bash
# shellcheck shell=bash
#
# persona-loader.test.sh — Sprint 01 / Task t03 / Acceptance Contract
# Scenario 3 + FR-1.
#
# Exercises every documented contract of `lib/runtime/persona-loader.sh`:
#
#   1. `validate <valid-fixture>`            → exit 0, no stderr.
#   2. `validate <missing-objective>`        → non-zero, stderr names
#                                              the offending key.
#   3. `validate <toolkit-as-string>`        → non-zero, stderr names
#                                              the type violation.
#   4. `validate <missing-tools>`            → non-zero, stderr names
#                                              the offending key.
#   5. `validate-all <agents-dir>`           → exit 0 against the three
#                                              shipped persona files.
#
# Test contract (binding for this file):
#   - exit 0 when every documented case behaves as specified.
#   - exit non-zero with a `wm: persona-loader-test violation:`-prefixed
#     stderr line naming the failing case otherwise.
#
# Discovery: this test is enumerated by Sprint 01 Task t03's
# `**Acceptance criterion:**` line and by Acceptance Contract Scenario 3's
# `Then` clause.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
LOADER="${REPO_ROOT}/lib/runtime/persona-loader.sh"
FIXTURES_DIR="${REPO_ROOT}/tests/runtime/fixtures"
AGENTS_DIR="${REPO_ROOT}/agents"

violation() {
  printf 'wm: persona-loader-test violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "${LOADER}" ]] || violation "loader missing at ${LOADER}"

# Run the loader, capturing stdout, stderr, and exit code without
# tripping `set -e` on the deliberately-failing cases.
run_loader() {
  local stderr_path="$1"
  shift
  local rc=0
  bash "${LOADER}" "$@" 2>"${stderr_path}" >/dev/null || rc=$?
  printf '%s' "${rc}"
}

STDERR_TMP="$(mktemp)"
trap 'rm -f "${STDERR_TMP}"' EXIT

# Case 1 — valid fixture passes silently.
RC="$(run_loader "${STDERR_TMP}" validate "${FIXTURES_DIR}/persona-frontmatter-valid.md")"
[[ "${RC}" == "0" ]] \
  || violation "valid fixture returned exit ${RC}; expected 0 (stderr: $(tr '\n' ' ' < "${STDERR_TMP}"))"
[[ ! -s "${STDERR_TMP}" ]] \
  || violation "valid fixture wrote to stderr; expected silent pass (stderr: $(tr '\n' ' ' < "${STDERR_TMP}"))"

# Case 2 — missing-objective fixture fails with a wm: line naming objective.
RC="$(run_loader "${STDERR_TMP}" validate "${FIXTURES_DIR}/persona-missing-objective.md")"
[[ "${RC}" != "0" ]] \
  || violation "missing-objective fixture returned exit 0; expected non-zero"
grep -q '^wm: ' "${STDERR_TMP}" \
  || violation "missing-objective fixture stderr is not 'wm:'-prefixed (got: $(tr '\n' ' ' < "${STDERR_TMP}"))"
grep -q 'objective' "${STDERR_TMP}" \
  || violation "missing-objective fixture stderr does not name the 'objective' key (got: $(tr '\n' ' ' < "${STDERR_TMP}"))"

# Case 3 — toolkit-as-string fixture fails with a wm: line naming sensor-toolkit.
RC="$(run_loader "${STDERR_TMP}" validate "${FIXTURES_DIR}/persona-toolkit-string.md")"
[[ "${RC}" != "0" ]] \
  || violation "toolkit-string fixture returned exit 0; expected non-zero"
grep -q '^wm: ' "${STDERR_TMP}" \
  || violation "toolkit-string fixture stderr is not 'wm:'-prefixed (got: $(tr '\n' ' ' < "${STDERR_TMP}"))"
grep -q 'sensor-toolkit' "${STDERR_TMP}" \
  || violation "toolkit-string fixture stderr does not name 'sensor-toolkit' (got: $(tr '\n' ' ' < "${STDERR_TMP}"))"

# Case 4 — missing-tools fixture fails with a wm: line naming tools.
RC="$(run_loader "${STDERR_TMP}" validate "${FIXTURES_DIR}/persona-tools-missing.md")"
[[ "${RC}" != "0" ]] \
  || violation "missing-tools fixture returned exit 0; expected non-zero"
grep -q '^wm: ' "${STDERR_TMP}" \
  || violation "missing-tools fixture stderr is not 'wm:'-prefixed (got: $(tr '\n' ' ' < "${STDERR_TMP}"))"
grep -qE '\btools\b' "${STDERR_TMP}" \
  || violation "missing-tools fixture stderr does not name 'tools' (got: $(tr '\n' ' ' < "${STDERR_TMP}"))"

# Case 5 — validate-all against the three shipped persona files passes.
RC="$(run_loader "${STDERR_TMP}" validate-all "${AGENTS_DIR}")"
[[ "${RC}" == "0" ]] \
  || violation "validate-all on agents/ returned exit ${RC}; expected 0 (stderr: $(tr '\n' ' ' < "${STDERR_TMP}"))"

exit 0
