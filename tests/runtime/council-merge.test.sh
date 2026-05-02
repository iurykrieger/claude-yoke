#!/usr/bin/env bash
# shellcheck shell=bash
#
# council-merge.test.sh — Sprint 01 / Task t04 / Acceptance Contract
# Scenario 4 + FR-2.
#
# Exercises every documented contract of `lib/runtime/council-merge.sh`:
#
#   1. `merge <cycle-3-personas-fixture>` produces non-empty stdout AND
#      two consecutive invocations are byte-identical (verified by
#      `diff -q`). This pins the determinism guarantee.
#   2. The merged view orders personas alphabetically regardless of
#      file mtime (the test shuffles mtimes before merging and asserts
#      the persona H2 order is sr-eng → sr-qa → sr-staff).
#   3. `check-slice-isolation <cycle-slice-violation-fixture>` exits
#      non-zero with a `wm: slice-isolation violation:` stderr line
#      naming the offending slice file; the same subcommand on the
#      cycle-3-personas fixture exits 0 silently.
#
# Test contract (binding for this file):
#   - exit 0 when every documented case behaves as specified.
#   - exit non-zero with a `wm: council-merge-test violation:`-prefixed
#     stderr line naming the failing case otherwise.
#
# Discovery: this test is enumerated by Sprint 01 Task t04's
# `**Acceptance criterion:**` line and by Acceptance Contract Scenario 4's
# `Then` clause.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
HELPER="${REPO_ROOT}/lib/runtime/council-merge.sh"
PERSONAS_FIXTURE="${REPO_ROOT}/tests/runtime/fixtures/cycle-3-personas"
VIOLATION_FIXTURE="${REPO_ROOT}/tests/runtime/fixtures/cycle-slice-violation"

violation() {
  printf 'wm: council-merge-test violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "${HELPER}" ]] || violation "helper missing at ${HELPER}"
[[ -d "${PERSONAS_FIXTURE}" ]] || violation "personas fixture missing at ${PERSONAS_FIXTURE}"
[[ -d "${VIOLATION_FIXTURE}" ]] || violation "violation fixture missing at ${VIOLATION_FIXTURE}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Case 1 — determinism: two consecutive `merge` invocations on the
# personas fixture produce byte-identical stdout.
RUN_A="${TMP_DIR}/run-a.out"
RUN_B="${TMP_DIR}/run-b.out"
bash "${HELPER}" merge "${PERSONAS_FIXTURE}" >"${RUN_A}"
bash "${HELPER}" merge "${PERSONAS_FIXTURE}" >"${RUN_B}"
[[ -s "${RUN_A}" ]] \
  || violation "first merge produced empty stdout against ${PERSONAS_FIXTURE}"
if ! diff -q "${RUN_A}" "${RUN_B}" >/dev/null; then
  violation "two consecutive merge invocations are not byte-identical (diff: $(diff "${RUN_A}" "${RUN_B}" | head -n 5 | tr '\n' ' '))"
fi

# Case 2 — alphabetical merge order regardless of file mtime. Build a
# scratch cycle directory by copying the personas fixture, then shuffle
# mtimes so sr-staff is oldest and sr-eng is newest. The merge order
# must still be alphabetical (sr-eng → sr-qa → sr-staff).
SHUFFLED_DIR="${TMP_DIR}/shuffled-cycle"
mkdir -p "${SHUFFLED_DIR}"
cp "${PERSONAS_FIXTURE}/sr-eng.md" "${SHUFFLED_DIR}/sr-eng.md"
cp "${PERSONAS_FIXTURE}/sr-qa.md" "${SHUFFLED_DIR}/sr-qa.md"
cp "${PERSONAS_FIXTURE}/sr-staff.md" "${SHUFFLED_DIR}/sr-staff.md"
# Touch in reverse order so sr-staff is oldest mtime and sr-eng is newest.
touch -t 202001010000 "${SHUFFLED_DIR}/sr-staff.md"
touch -t 202101010000 "${SHUFFLED_DIR}/sr-qa.md"
touch -t 202201010000 "${SHUFFLED_DIR}/sr-eng.md"
SHUFFLED_OUT="${TMP_DIR}/shuffled.out"
bash "${HELPER}" merge "${SHUFFLED_DIR}" >"${SHUFFLED_OUT}"
# Extract the H2 persona-name order; expect sr-eng, sr-qa, sr-staff.
ORDER="$(grep -E '^## ' "${SHUFFLED_OUT}" | sed -E 's/^## //' | tr '\n' ',' | sed 's/,$//')"
EXPECTED_ORDER="sr-eng,sr-qa,sr-staff"
[[ "${ORDER}" == "${EXPECTED_ORDER}" ]] \
  || violation "merge order under shuffled mtimes was '${ORDER}'; expected '${EXPECTED_ORDER}'"

# Case 3a — slice-isolation sensor exits 0 silently on the personas fixture.
ISOLATION_STDERR="${TMP_DIR}/isolation-pass.err"
RC=0
bash "${HELPER}" check-slice-isolation "${PERSONAS_FIXTURE}" 2>"${ISOLATION_STDERR}" >/dev/null || RC=$?
[[ "${RC}" == "0" ]] \
  || violation "check-slice-isolation on the personas fixture returned exit ${RC}; expected 0 (stderr: $(tr '\n' ' ' < "${ISOLATION_STDERR}"))"
[[ ! -s "${ISOLATION_STDERR}" ]] \
  || violation "check-slice-isolation on the personas fixture wrote to stderr; expected silent pass (stderr: $(tr '\n' ' ' < "${ISOLATION_STDERR}"))"

# Case 3b — slice-isolation sensor flags the violation fixture with a
# `wm: slice-isolation violation:` stderr line naming the offending slice.
VIOLATION_STDERR="${TMP_DIR}/isolation-fail.err"
RC=0
bash "${HELPER}" check-slice-isolation "${VIOLATION_FIXTURE}" 2>"${VIOLATION_STDERR}" >/dev/null || RC=$?
[[ "${RC}" != "0" ]] \
  || violation "check-slice-isolation on the violation fixture returned exit 0; expected non-zero"
grep -q '^wm: slice-isolation violation:' "${VIOLATION_STDERR}" \
  || violation "check-slice-isolation violation fixture stderr is not 'wm: slice-isolation violation:'-prefixed (got: $(tr '\n' ' ' < "${VIOLATION_STDERR}"))"
grep -q 'sr-eng.md' "${VIOLATION_STDERR}" \
  || violation "check-slice-isolation violation fixture stderr does not name the offending slice 'sr-eng.md' (got: $(tr '\n' ' ' < "${VIOLATION_STDERR}"))"

exit 0
