#!/usr/bin/env bash
# shellcheck shell=bash
#
# sync-barrier.test.sh — Sprint 01 / Task t05 / Acceptance Contract
# Scenario 5 + FR-2.
#
# Exercises every documented contract of `lib/runtime/sync-barrier.sh`:
#
#   1. `wait-all` returns 0 quickly when every named marker already exists.
#   2. `wait-all` times out non-zero with a `wm: sync-barrier timeout:`
#      stderr line naming every still-missing marker when a persona
#      fails to write its marker before YOKE_BARRIER_TIMEOUT_SECONDS.
#   3. `clear-markers` is idempotent: a no-op when no markers exist AND
#      removes every leftover marker from a prior interrupted cycle.
#
# Cites `concepts/yoke-conventions` for the deterministic-sensor-output
# contract (every error path emits a `wm:`-prefixed stderr line).
#
# Test contract (binding for this file):
#   - exit 0 when every documented case behaves as specified.
#   - exit non-zero with a `wm: sync-barrier-test violation:`-prefixed
#     stderr line naming the failing case otherwise.
#
# Discovery: this test is enumerated by Sprint 01 Task t05's
# `**Acceptance criterion:**` line and by Acceptance Contract Scenario 5's
# `Then` clause.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
HELPER="${REPO_ROOT}/lib/runtime/sync-barrier.sh"

violation() {
  printf 'wm: sync-barrier-test violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "${HELPER}" ]] || violation "helper missing at ${HELPER}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

SLUG="2026-05-01-agent-council"
CYCLE="0"

# Each case gets its own scratch marker dir so leftover state from a
# prior case never leaks into the next.

# Case 1 — wait-all returns 0 quickly when every marker is already present.
CASE1_DIR="${TMP_DIR}/case1"
mkdir -p "${CASE1_DIR}"
: >"${CASE1_DIR}/.phase-a-done.sr-eng"
: >"${CASE1_DIR}/.phase-a-done.sr-qa"
: >"${CASE1_DIR}/.phase-a-done.sr-staff"
CASE1_STDERR="${TMP_DIR}/case1.err"
RC=0
YOKE_MARKER_DIR="${CASE1_DIR}" \
  YOKE_BARRIER_POLL_INTERVAL=0.05 \
  YOKE_BARRIER_TIMEOUT_SECONDS=2 \
  bash "${HELPER}" wait-all "${SLUG}" "${CYCLE}" sr-eng sr-qa sr-staff \
    2>"${CASE1_STDERR}" >/dev/null || RC=$?
[[ "${RC}" == "0" ]] \
  || violation "wait-all on three present markers returned ${RC}; expected 0 (stderr: $(tr '\n' ' ' < "${CASE1_STDERR}"))"
[[ ! -s "${CASE1_STDERR}" ]] \
  || violation "wait-all on three present markers wrote to stderr; expected silent pass (stderr: $(tr '\n' ' ' < "${CASE1_STDERR}"))"

# Case 2 — wait-all times out non-zero when one marker is missing.
CASE2_DIR="${TMP_DIR}/case2"
mkdir -p "${CASE2_DIR}"
: >"${CASE2_DIR}/.phase-a-done.sr-eng"
: >"${CASE2_DIR}/.phase-a-done.sr-qa"
# sr-staff intentionally absent.
CASE2_STDERR="${TMP_DIR}/case2.err"
RC=0
YOKE_MARKER_DIR="${CASE2_DIR}" \
  YOKE_BARRIER_POLL_INTERVAL=0.05 \
  YOKE_BARRIER_TIMEOUT_SECONDS=1 \
  bash "${HELPER}" wait-all "${SLUG}" "${CYCLE}" sr-eng sr-qa sr-staff \
    2>"${CASE2_STDERR}" >/dev/null || RC=$?
[[ "${RC}" != "0" ]] \
  || violation "wait-all on missing-marker fixture returned 0; expected non-zero"
grep -q '^wm: sync-barrier timeout:' "${CASE2_STDERR}" \
  || violation "wait-all timeout stderr is not 'wm: sync-barrier timeout:'-prefixed (got: $(tr '\n' ' ' < "${CASE2_STDERR}"))"
grep -q '\.phase-a-done\.sr-staff' "${CASE2_STDERR}" \
  || violation "wait-all timeout stderr does not name the missing marker '.phase-a-done.sr-staff' (got: $(tr '\n' ' ' < "${CASE2_STDERR}"))"
# The two satisfied markers must NOT appear in the missing list.
if grep -q '\.phase-a-done\.sr-eng' "${CASE2_STDERR}"; then
  violation "wait-all timeout stderr falsely lists '.phase-a-done.sr-eng' as missing (stderr: $(tr '\n' ' ' < "${CASE2_STDERR}"))"
fi

# Case 3a — clear-markers is a no-op when no markers exist.
CASE3A_DIR="${TMP_DIR}/case3a"
mkdir -p "${CASE3A_DIR}"
CASE3A_STDERR="${TMP_DIR}/case3a.err"
RC=0
YOKE_MARKER_DIR="${CASE3A_DIR}" \
  bash "${HELPER}" clear-markers "${SLUG}" "${CYCLE}" \
    2>"${CASE3A_STDERR}" >/dev/null || RC=$?
[[ "${RC}" == "0" ]] \
  || violation "clear-markers no-op returned ${RC}; expected 0 (stderr: $(tr '\n' ' ' < "${CASE3A_STDERR}"))"
[[ ! -s "${CASE3A_STDERR}" ]] \
  || violation "clear-markers no-op wrote to stderr; expected silent (stderr: $(tr '\n' ' ' < "${CASE3A_STDERR}"))"
# Confirm the directory still exists and is empty of markers.
LEFTOVERS=$(find "${CASE3A_DIR}" -maxdepth 1 -name '.phase-a-done.*' -print 2>/dev/null | wc -l | tr -d ' ')
[[ "${LEFTOVERS}" == "0" ]] \
  || violation "clear-markers no-op left ${LEFTOVERS} marker file(s) in ${CASE3A_DIR}"

# Case 3b — clear-markers removes leftovers from a prior interrupted cycle.
CASE3B_DIR="${TMP_DIR}/case3b"
mkdir -p "${CASE3B_DIR}"
: >"${CASE3B_DIR}/.phase-a-done.sr-eng"
: >"${CASE3B_DIR}/.phase-a-done.sr-qa"
: >"${CASE3B_DIR}/.phase-a-done.sr-staff"
# Touch an unrelated dotfile to confirm clear-markers does not over-reach.
: >"${CASE3B_DIR}/.unrelated"
CASE3B_STDERR="${TMP_DIR}/case3b.err"
RC=0
YOKE_MARKER_DIR="${CASE3B_DIR}" \
  bash "${HELPER}" clear-markers "${SLUG}" "${CYCLE}" \
    2>"${CASE3B_STDERR}" >/dev/null || RC=$?
[[ "${RC}" == "0" ]] \
  || violation "clear-markers leftover-removal returned ${RC}; expected 0 (stderr: $(tr '\n' ' ' < "${CASE3B_STDERR}"))"
LEFTOVERS=$(find "${CASE3B_DIR}" -maxdepth 1 -name '.phase-a-done.*' -print 2>/dev/null | wc -l | tr -d ' ')
[[ "${LEFTOVERS}" == "0" ]] \
  || violation "clear-markers left ${LEFTOVERS} marker file(s) behind in ${CASE3B_DIR}"
[[ -f "${CASE3B_DIR}/.unrelated" ]] \
  || violation "clear-markers wrongly removed unrelated dotfile '.unrelated' in ${CASE3B_DIR}"

# Case 3c — second clear-markers invocation is also a no-op (idempotency).
RC=0
YOKE_MARKER_DIR="${CASE3B_DIR}" \
  bash "${HELPER}" clear-markers "${SLUG}" "${CYCLE}" \
    2>"${CASE3B_STDERR}" >/dev/null || RC=$?
[[ "${RC}" == "0" ]] \
  || violation "second clear-markers (idempotency) returned ${RC}; expected 0 (stderr: $(tr '\n' ' ' < "${CASE3B_STDERR}"))"

exit 0
