#!/usr/bin/env bash
# shellcheck shell=bash
#
# phase-a-orchestration.test.sh — Sprint 02 / Task t01 / AC Scenario 6 + FR-2.
#
# Drives `lib/runtime/cycle.sh` end-to-end against engineered fixtures.
# Phase A's actual Task spawn lives in skills/implement/SKILL.md; this
# test substitutes the spawn with deterministic persona stubs that
# write a slice file + Phase-A marker, then exercises:
#
#   1. cycle.sh pre-spawn — clears stale markers + validates personas + emits the persona list.
#   2. <stub spawn> — the test driver runs three persona stubs in parallel.
#   3. cycle.sh post-spawn — the defensive wait-all returns 0 when every marker is present.
#
# Negative case (the marker-missing fixture):
#   - Two stubs write slice + marker; the third writes only the slice.
#   - cycle.sh post-spawn returns non-zero with a `wm: sync-barrier timeout:` stderr line
#     naming the missing marker.
#
# Test contract (binding for this file):
#   - exit 0 when every documented case behaves as specified.
#   - exit non-zero with a `wm: phase-a-orch-test violation:`-prefixed
#     stderr line naming the failing case otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
CYCLE_HELPER="${REPO_ROOT}/lib/runtime/cycle.sh"
AGENTS_DIR="${REPO_ROOT}/agents"

violation() {
  printf 'wm: phase-a-orch-test violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "${CYCLE_HELPER}" ]] || violation "cycle helper missing at ${CYCLE_HELPER}"
[[ -d "${AGENTS_DIR}" ]] || violation "agents dir missing at ${AGENTS_DIR}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

SLUG="2026-05-01-agent-council"
CYCLE="0"

# Persona stub: writes a minimal slice + marker into the runtime dirs
# the orchestration test points it at. Captured here as a heredoc so
# the test is self-contained and shellcheck-clean.
write_persona_stub() {
  local cycle_dir="$1"
  local marker_dir="$2"
  local persona="$3"
  mkdir -p "$cycle_dir" "$marker_dir"
  cat >"${cycle_dir}/${persona}.md" <<EOF
---
author: ${persona}
cycle: ${CYCLE}
phase: a
---

## Phase A — own progress

author: ${persona}

- file: tests/runtime/fixtures/working-set-three-personas/README.md
- intent: engineered persona stub for the Phase A orchestration test
EOF
  : >"${marker_dir}/.phase-a-done.${persona}"
}

# Case 1 — pre-spawn returns the sorted persona list and validates all council files.
CASE1_DIR="${TMP_DIR}/case1"
CASE1_MARKER_DIR="${CASE1_DIR}/.yoke/runtime"
mkdir -p "${CASE1_MARKER_DIR}"
CASE1_STDERR="${TMP_DIR}/case1.err"
RC=0
PERSONAS_LIST="$(YOKE_AGENTS_DIR="${AGENTS_DIR}" \
                 YOKE_MARKER_DIR="${CASE1_MARKER_DIR}" \
                 bash "${CYCLE_HELPER}" pre-spawn "${SLUG}" "${CYCLE}" \
                 2>"${CASE1_STDERR}")" || RC=$?
[[ "${RC}" == "0" ]] \
  || violation "pre-spawn returned ${RC}; expected 0 (stderr: $(tr '\n' ' ' < "${CASE1_STDERR}"))"
EXPECTED="sr-eng
sr-qa
sr-staff"
if [[ "${PERSONAS_LIST}" != "${EXPECTED}" ]]; then
  violation "pre-spawn persona list was '$(printf '%s' "${PERSONAS_LIST}" | tr '\n' ',')'; expected 'sr-eng,sr-qa,sr-staff,'"
fi

# Case 2 — happy path: post-spawn returns 0 after every marker is written.
CASE2_DIR="${TMP_DIR}/case2"
CASE2_CYCLE_DIR="${CASE2_DIR}/.yoke/runtime/cycles/${CYCLE}"
CASE2_MARKER_DIR="${CASE2_DIR}/.yoke/runtime"
mkdir -p "${CASE2_CYCLE_DIR}" "${CASE2_MARKER_DIR}"

# Spawn the three persona stubs in parallel (background) and wait for them.
write_persona_stub "${CASE2_CYCLE_DIR}" "${CASE2_MARKER_DIR}" "sr-eng" &
write_persona_stub "${CASE2_CYCLE_DIR}" "${CASE2_MARKER_DIR}" "sr-qa" &
write_persona_stub "${CASE2_CYCLE_DIR}" "${CASE2_MARKER_DIR}" "sr-staff" &
wait

CASE2_STDERR="${TMP_DIR}/case2.err"
RC=0
YOKE_AGENTS_DIR="${AGENTS_DIR}" \
  YOKE_MARKER_DIR="${CASE2_MARKER_DIR}" \
  YOKE_BARRIER_POLL_INTERVAL=0.05 \
  YOKE_BARRIER_TIMEOUT_SECONDS=2 \
  bash "${CYCLE_HELPER}" post-spawn "${SLUG}" "${CYCLE}" \
    2>"${CASE2_STDERR}" >/dev/null || RC=$?
[[ "${RC}" == "0" ]] \
  || violation "post-spawn returned ${RC} on the happy-path fixture; expected 0 (stderr: $(tr '\n' ' ' < "${CASE2_STDERR}"))"

# Confirm the three slice files exist where the test expects them.
for persona in sr-eng sr-qa sr-staff; do
  [[ -f "${CASE2_CYCLE_DIR}/${persona}.md" ]] \
    || violation "expected slice missing: ${CASE2_CYCLE_DIR}/${persona}.md"
  [[ -f "${CASE2_MARKER_DIR}/.phase-a-done.${persona}" ]] \
    || violation "expected marker missing: ${CASE2_MARKER_DIR}/.phase-a-done.${persona}"
done

# Case 3 — marker-missing fixture: post-spawn times out non-zero naming the missing marker.
CASE3_DIR="${TMP_DIR}/case3"
CASE3_CYCLE_DIR="${CASE3_DIR}/.yoke/runtime/cycles/${CYCLE}"
CASE3_MARKER_DIR="${CASE3_DIR}/.yoke/runtime"
mkdir -p "${CASE3_CYCLE_DIR}" "${CASE3_MARKER_DIR}"

# Two stubs write slice + marker; the third (sr-staff) writes only the slice.
write_persona_stub "${CASE3_CYCLE_DIR}" "${CASE3_MARKER_DIR}" "sr-eng"
write_persona_stub "${CASE3_CYCLE_DIR}" "${CASE3_MARKER_DIR}" "sr-qa"
mkdir -p "${CASE3_CYCLE_DIR}"
cat >"${CASE3_CYCLE_DIR}/sr-staff.md" <<EOF
---
author: sr-staff
cycle: ${CYCLE}
phase: a
---

## Phase A — own progress

(intentionally no marker — this is the engineered failure fixture)
EOF
# sr-staff marker intentionally absent.

CASE3_STDERR="${TMP_DIR}/case3.err"
RC=0
YOKE_AGENTS_DIR="${AGENTS_DIR}" \
  YOKE_MARKER_DIR="${CASE3_MARKER_DIR}" \
  YOKE_BARRIER_POLL_INTERVAL=0.05 \
  YOKE_BARRIER_TIMEOUT_SECONDS=1 \
  bash "${CYCLE_HELPER}" post-spawn "${SLUG}" "${CYCLE}" \
    2>"${CASE3_STDERR}" >/dev/null || RC=$?
[[ "${RC}" != "0" ]] \
  || violation "post-spawn on the marker-missing fixture returned 0; expected non-zero"
grep -q '^wm: sync-barrier timeout:' "${CASE3_STDERR}" \
  || violation "post-spawn marker-missing stderr is not 'wm: sync-barrier timeout:'-prefixed (got: $(tr '\n' ' ' < "${CASE3_STDERR}"))"
grep -q '\.phase-a-done\.sr-staff' "${CASE3_STDERR}" \
  || violation "post-spawn marker-missing stderr does not name '.phase-a-done.sr-staff' (got: $(tr '\n' ' ' < "${CASE3_STDERR}"))"

exit 0
