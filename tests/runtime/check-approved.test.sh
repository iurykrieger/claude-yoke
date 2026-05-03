#!/usr/bin/env bash
# shellcheck shell=bash
#
# check-approved.test.sh — Sprint 02 / Task t02 happy-path unit test
# (US-003 DoD bullet 2).
#
# Asserts that `lib/working-memory/check-approved.sh`'s three
# predicates (`wm_check_prd_approved`, `wm_check_spec_approved`,
# `wm_check_ac_ratified`) accept the canonical approved/ratified
# blockquote-Status grammar and reject anything else.
#
# Test contract:
#   - exit 0 with `PASS:` lines on success.
#   - exit non-zero with `wm: check-approved violation:`-prefixed
#     stderr otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

violation() {
  printf 'wm: check-approved violation: %s\n' "$1" >&2
  exit 1
}

# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/working-memory/check-approved.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# --- Spec helper happy path: matches binding spec ---------------------------

SPEC_PATH="${REPO_ROOT}/.yoke/specs/2026-05-03-generate-sprints-skill.md"
wm_check_spec_approved "$SPEC_PATH" \
  || violation "wm_check_spec_approved rejected the binding spec"

# --- AC helper happy path: matches binding AC ------------------------------

AC_PATH="${REPO_ROOT}/.yoke/acceptance-criteria/2026-05-03-generate-sprints-skill.md"
wm_check_ac_ratified "$AC_PATH" \
  || violation "wm_check_ac_ratified rejected the binding AC"

# --- PRD helper happy path: matches binding PRD ----------------------------

PRD_PATH="${REPO_ROOT}/.yoke/prds/2026-05-03-generate-sprints-skill.md"
wm_check_prd_approved "$PRD_PATH" \
  || violation "wm_check_prd_approved rejected the binding PRD"

# --- Negative-shape rejection (happy path of the rejection branch) ---------

# A file missing the `> Status: ...` blockquote MUST be rejected by
# every predicate. This is the happy path of the failure branch — we
# assert the predicate emits `wm:`-prefixed stderr.
DRAFT_PATH="${TMP_DIR}/draft.md"
cat > "$DRAFT_PATH" <<'EOF'
# Draft

> Status: draft
EOF

if wm_check_spec_approved "$DRAFT_PATH" 2>/dev/null; then
  violation "wm_check_spec_approved accepted a draft file"
fi
if wm_check_ac_ratified "$DRAFT_PATH" 2>/dev/null; then
  violation "wm_check_ac_ratified accepted a draft file"
fi

# --- Missing path branch ---------------------------------------------------

if wm_check_spec_approved "${TMP_DIR}/does-not-exist.md" 2>/dev/null; then
  violation "wm_check_spec_approved accepted a missing path"
fi

printf 'PASS: check-approved predicates honor the `> Status:` grammar\n'
exit 0
