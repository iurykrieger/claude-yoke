#!/usr/bin/env bash
# shellcheck shell=bash
#
# orchestrate-gate-refusal.test.sh — Sprint 04 / Task t03 happy-path unit
# test (US-006 DoD bullet 4).
#
# Asserts that `lib/ralph-loop/orchestrate.sh preflight` refuses to
# run on a new-flow task in state `awaiting:generate-sprints` with
# the literal stderr `wm: run /yoke:generate-sprints to advance to
# Phase 4` and exits non-zero. Legacy tasks (no
# acceptance-criteria/<slug>.md present) keep walking unaffected.
#
# Test contract:
#   - exit 0 with `PASS:` lines on success.
#   - exit non-zero with `wm: orchestrate-gate violation:`-prefixed
#     stderr otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
ORCHESTRATE="${REPO_ROOT}/lib/ralph-loop/orchestrate.sh"

violation() {
  printf 'wm: orchestrate-gate violation: %s\n' "$1" >&2
  exit 1
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SLUG="2026-01-01-test-task"

write_config() {
  mkdir -p "${TMP_DIR}/.yoke"
  cat > "${TMP_DIR}/.yoke/config.yaml" <<'EOF'
canonical_memory:
  provider: bedrock
EOF
}

write_active_pointer() {
  mkdir -p "${TMP_DIR}/.yoke/runtime"
  printf '%s' "$SLUG" > "${TMP_DIR}/.yoke/runtime/.current"
}

write_prd() {
  mkdir -p "${TMP_DIR}/.yoke/prds"
  cat > "${TMP_DIR}/.yoke/prds/${SLUG}.md" <<'EOF'
# PRD: test

> Status: approved
EOF
}

write_spec() {
  mkdir -p "${TMP_DIR}/.yoke/specs"
  cat > "${TMP_DIR}/.yoke/specs/${SLUG}.md" <<'EOF'
# Spec: test

> Status: approved
EOF
}

write_ac_new() {
  mkdir -p "${TMP_DIR}/.yoke/acceptance-criteria"
  cat > "${TMP_DIR}/.yoke/acceptance-criteria/${SLUG}.md" <<'EOF'
# AC: test

> Status: ratified
EOF
}

write_legacy_ac() {
  mkdir -p "${TMP_DIR}/.yoke/acceptance-contracts"
  cat > "${TMP_DIR}/.yoke/acceptance-contracts/${SLUG}.md" <<'EOF'
# AC (legacy): test

> Status: ratified
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

run_preflight() {
  ( cd "$TMP_DIR" && "$ORCHESTRATE" preflight 2>"${TMP_DIR}/.stderr" >"${TMP_DIR}/.stdout" )
}

# --- Branch 1: new-flow refusal --------------------------------------------

write_config
write_active_pointer
write_prd
write_spec
write_ac_new
# No sprint files — gate-state should be awaiting:generate-sprints.

set +e
run_preflight
rc=$?
set -e

[[ "$rc" -ne 0 ]] \
  || violation "expected non-zero exit on awaiting:generate-sprints; got 0"

if ! grep -qF "wm: run /yoke:generate-sprints to advance to Phase 4" \
    "${TMP_DIR}/.stderr"; then
  printf 'stderr captured was:\n' >&2
  cat "${TMP_DIR}/.stderr" >&2
  violation "stderr did not contain the literal refusal message"
fi
printf 'PASS: new-flow refusal correct\n'

# --- Branch 2: legacy walks unaffected -------------------------------------

# Replace the new-flow AC with a legacy AC + sprint file.
rm -rf "${TMP_DIR}/.yoke/acceptance-criteria"
write_legacy_ac
write_sprint_file 1

set +e
run_preflight
rc=$?
set -e

if [[ "$rc" -ne 0 ]]; then
  printf 'stderr captured was:\n' >&2
  cat "${TMP_DIR}/.stderr" >&2
  violation "expected zero exit on legacy walk; got ${rc}"
fi

if ! grep -qFx "ok" "${TMP_DIR}/.stdout"; then
  printf 'stdout captured was:\n' >&2
  cat "${TMP_DIR}/.stdout" >&2
  violation "stdout did not print the literal 'ok'"
fi
printf 'PASS: legacy walks unaffected\n'

printf 'PASS: orchestrate.sh preflight honors gate-state refusal\n'
exit 0
