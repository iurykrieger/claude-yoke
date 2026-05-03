#!/usr/bin/env bash
# shellcheck shell=bash
#
# gate-state.test.sh — Sprint 04 / Task t02 happy-path unit test
# (US-006 DoD bullets 3 + 4).
#
# Asserts that `lib/working-memory/gate-state.sh :: detect_gate_state`
# resolves the documented seven labels for the new and legacy ladders:
#
#   New flow:
#     awaiting:tech-spec          (no spec or unapproved spec)
#     awaiting:acceptance-criteria (spec approved, AC missing/unratified)
#     awaiting:generate-sprints   (spec + AC ratified, zero sprint files)
#     running:implement            (sprint files exist + status approved)
#
#   Legacy flow:
#     awaiting:tech-spec          (no spec or unapproved spec)
#     awaiting:acceptance-contract (legacy AC missing/unratified)
#     running:implement            (sprint files exist + status approved)
#
# Test contract:
#   - exit 0 with `PASS:` lines on success.
#   - exit non-zero with `wm: gate-state violation:`-prefixed stderr
#     otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

violation() {
  printf 'wm: gate-state violation: %s\n' "$1" >&2
  exit 1
}

# Build a self-contained .yoke fixture under a tempdir and run from there.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Each branch builds a fresh fixture; helpers below stamp the bits.
SLUG="2026-01-01-test-task"

write_spec() {
  local status="$1"
  mkdir -p "${TMP_DIR}/.yoke/specs"
  cat > "${TMP_DIR}/.yoke/specs/${SLUG}.md" <<EOF
# Spec: test

> Status: ${status}
EOF
}

write_ac_new() {
  local status="$1"
  mkdir -p "${TMP_DIR}/.yoke/acceptance-criteria"
  cat > "${TMP_DIR}/.yoke/acceptance-criteria/${SLUG}.md" <<EOF
# AC: test

> Status: ${status}
EOF
}

write_legacy_ac() {
  local status="$1"
  mkdir -p "${TMP_DIR}/.yoke/acceptance-contracts"
  cat > "${TMP_DIR}/.yoke/acceptance-contracts/${SLUG}.md" <<EOF
# AC (legacy): test

> Status: ${status}
EOF
}

write_sprint_file() {
  local n="$1"
  mkdir -p "${TMP_DIR}/.yoke/sprints"
  cat > "${TMP_DIR}/.yoke/sprints/${SLUG}-s$(printf '%02d' "$n").md" <<EOF
---
task_id: ${SLUG}-s$(printf '%02d' "$n")
sprint: ${n}
slug: ${SLUG}
status: approved
created_at: 2026-01-01
model: ""
traceability: ""
---

# Sprint $(printf '%02d' "$n") of 01: test

## Sprint objective
Stub.

## Sprint DoD

## Tasks

## Functional acceptance criteria

## Sensors
EOF
}

write_active_pointer() {
  mkdir -p "${TMP_DIR}/.yoke/runtime"
  printf '%s' "$SLUG" > "${TMP_DIR}/.yoke/runtime/.current"
}

clear_fixture() {
  rm -rf "${TMP_DIR}/.yoke"
}

run_state() {
  ( cd "$TMP_DIR" && \
    set +u && \
    source "${REPO_ROOT}/lib/working-memory/gate-state.sh" && \
    detect_gate_state )
}

# --- Branch 1: awaiting:tech-spec (no spec) --------------------------------

clear_fixture
write_active_pointer
got="$(run_state || true)"
[[ "$got" == "awaiting:tech-spec" ]] \
  || violation "expected awaiting:tech-spec (no spec); got: '${got}'"
printf 'PASS: awaiting:tech-spec branch (no spec)\n'

# --- Branch 2: awaiting:tech-spec (spec exists but draft) ------------------

clear_fixture
write_active_pointer
write_spec draft
got="$(run_state || true)"
[[ "$got" == "awaiting:tech-spec" ]] \
  || violation "expected awaiting:tech-spec (draft spec); got: '${got}'"
printf 'PASS: awaiting:tech-spec branch (draft spec)\n'

# --- Branch 3: awaiting:acceptance-criteria (new flow, AC missing) ---------

clear_fixture
write_active_pointer
write_spec approved
got="$(run_state || true)"
# No AC file means we fall to legacy branch — but legacy branch checks
# acceptance-contracts/. Without AC and without legacy AC, expect
# awaiting:acceptance-contract.
[[ "$got" == "awaiting:acceptance-contract" ]] \
  || violation "expected awaiting:acceptance-contract (no AC of either flavor); got: '${got}'"
printf 'PASS: awaiting:acceptance-contract branch (no AC of either flavor)\n'

# --- Branch 4: awaiting:acceptance-criteria (new flow, AC draft) -----------

clear_fixture
write_active_pointer
write_spec approved
write_ac_new draft
got="$(run_state || true)"
[[ "$got" == "awaiting:acceptance-criteria" ]] \
  || violation "expected awaiting:acceptance-criteria (draft AC); got: '${got}'"
printf 'PASS: awaiting:acceptance-criteria branch (draft AC)\n'

# --- Branch 5: awaiting:generate-sprints (new flow, zero sprint files) -----

clear_fixture
write_active_pointer
write_spec approved
write_ac_new ratified
got="$(run_state || true)"
[[ "$got" == "awaiting:generate-sprints" ]] \
  || violation "expected awaiting:generate-sprints; got: '${got}'"
printf 'PASS: awaiting:generate-sprints branch (new flow gate)\n'

# --- Branch 6: running:implement (new flow, sprint files present) ----------

clear_fixture
write_active_pointer
write_spec approved
write_ac_new ratified
write_sprint_file 1
got="$(run_state || true)"
[[ "$got" == "running:implement" ]] \
  || violation "expected running:implement (new flow, sprint present); got: '${got}'"
printf 'PASS: running:implement branch (new flow with sprint file)\n'

# --- Branch 7: legacy ladder selected (no acceptance-criteria/) ------------

clear_fixture
write_active_pointer
write_spec approved
write_legacy_ac ratified
write_sprint_file 1
got="$(run_state || true)"
[[ "$got" == "running:implement" ]] \
  || violation "expected running:implement (legacy flow, sprint present); got: '${got}'"
printf 'PASS: legacy ladder selected and walks (running:implement)\n'

# --- Branch 8: legacy awaiting:acceptance-contract (legacy AC draft) -------

clear_fixture
write_active_pointer
write_spec approved
write_legacy_ac draft
got="$(run_state || true)"
[[ "$got" == "awaiting:acceptance-contract" ]] \
  || violation "expected awaiting:acceptance-contract (legacy draft AC); got: '${got}'"
printf 'PASS: awaiting:acceptance-contract branch (legacy draft AC)\n'

printf 'PASS: gate-state ladder honors new + legacy flows\n'
exit 0
