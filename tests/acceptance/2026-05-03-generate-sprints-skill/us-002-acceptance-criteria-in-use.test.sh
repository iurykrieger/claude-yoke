#!/usr/bin/env bash
# criterion: AC-002-2
#
# Binding Acceptance Criteria (re-ratified 2026-05-03T10:44:11Z):
#   US-002 — Reshape acceptance-criteria around the canonical shape.
#
#   AC-002-2: `bash -c 'source lib/working-memory/paths.sh
#       && wm_acceptance_criteria_in_use 2026-01-01-foo'` exits 0 when
#       the file exists and 1 otherwise.
#
# This test exercises the `wm_acceptance_criteria_in_use` peer
# predicate added by US-002's DoD bullet
# ("`lib/working-memory/paths.sh` carries `wm_acceptance_criteria_path`
#  ... AND `wm_acceptance_criteria_in_use` (peer predicate)"). The
# helper is in Sr Eng's lane (`lib/`); this test is the QA-side
# contract enforcement.
#
# Sprint anchor (.yoke/sprints/2026-05-03-generate-sprints-skill-s01.md):
#   wm-acceptance-criteria-path-callable (Functional acceptance criterion id)
#   covers the wider US-002 path-helper surface.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

PATHS_LIB="lib/working-memory/paths.sh"
FAIL=0

if [[ ! -f "$PATHS_LIB" ]]; then
  printf 'FAIL: %s does not exist\n' "$PATHS_LIB" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Block 1 — the predicate is defined after sourcing.
# ---------------------------------------------------------------------------
if bash -c "source '$PATHS_LIB' && declare -f wm_acceptance_criteria_in_use >/dev/null"; then
  printf 'PASS: wm_acceptance_criteria_in_use is defined after sourcing\n'
else
  printf 'FAIL: wm_acceptance_criteria_in_use is NOT defined in %s\n' "$PATHS_LIB" >&2
  FAIL=1
fi

# Use a sandbox slug that absolutely will not collide with any real
# acceptance-criteria file in the repo. The slug carries an "exist"
# variant (created by this test for the positive case) and an "absent"
# variant (never created).
SLUG_PRESENT="2099-12-31-us-002-2-present"
SLUG_ABSENT="2099-12-31-us-002-2-absent"
TARGET_DIR=".yoke/acceptance-criteria"
mkdir -p "$TARGET_DIR"
TARGET_FILE="${TARGET_DIR}/${SLUG_PRESENT}.md"
TARGET_ABSENT="${TARGET_DIR}/${SLUG_ABSENT}.md"

# Defensive cleanup of the present-fixture if a prior failed run left
# it behind. Always remove the absent-fixture (must not exist).
rm -f "$TARGET_FILE" "$TARGET_ABSENT"

# Cleanup trap — guarantees we leave the working tree as we found it.
cleanup_fixtures() {
  rm -f "$TARGET_FILE" "$TARGET_ABSENT"
}
trap 'cleanup_fixtures; kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

# Create a minimal placeholder file for the present-case.
cat > "$TARGET_FILE" <<EOF
---
slug: ${SLUG_PRESENT}
status: draft
---
# placeholder fixture for AC-002-2 (auto-managed by the test; safe to delete)
EOF

# ---------------------------------------------------------------------------
# Block 2 — file present: predicate exits 0.
# ---------------------------------------------------------------------------
if [[ "$FAIL" -eq 0 ]]; then
  if bash -c "source '$PATHS_LIB' && wm_acceptance_criteria_in_use '${SLUG_PRESENT}'" 2>/dev/null; then
    printf 'PASS: predicate returns 0 when file exists\n'
  else
    rc=$?
    printf 'FAIL: predicate returned rc=%d when file exists (expected 0)\n' "$rc" >&2
    FAIL=1
  fi
fi

# ---------------------------------------------------------------------------
# Block 3 — file absent: predicate exits non-zero.
# ---------------------------------------------------------------------------
if [[ "$FAIL" -eq 0 ]]; then
  if bash -c "source '$PATHS_LIB' && wm_acceptance_criteria_in_use '${SLUG_ABSENT}'" 2>/dev/null; then
    printf 'FAIL: predicate returned 0 when file does NOT exist (expected non-zero)\n' >&2
    FAIL=1
  else
    printf 'PASS: predicate returns non-zero when file does not exist\n'
  fi
fi

# Explicit cleanup before the final summary so a partial-PASS run
# leaves no residue.
cleanup_fixtures

if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: us-002-acceptance-criteria-in-use\n' >&2
  exit 1
fi
printf '\n--- Result ---\nPASS: us-002-acceptance-criteria-in-use\n'
exit 0
