#!/usr/bin/env bash
# Use case: working-memory paths helpers resolve the canonical
# acceptance-criteria file for a given task slug.
#
# Behaviour under test (durable):
#   `lib/working-memory/paths.sh` exposes two helpers that callers
#   across the framework use to locate the acceptance-criteria
#   working-memory artifact for an active task:
#
#     1. `wm_acceptance_criteria_path <slug>` — pure function. Prints
#        the canonical path `.yoke/acceptance-criteria/<slug>.md` to
#        stdout and exits 0. No filesystem side effects, no existence
#        check. Templating the slug (not hard-coding) is required.
#
#     2. `wm_acceptance_criteria_in_use <slug>` — predicate. Returns
#        0 when the canonical file exists for the slug, non-zero
#        otherwise.
#
# Why this is durable: every consumer of the new-flow acceptance-
# criteria artifact (status, implement, generate-sprints, canonize,
# council personas) calls one of these helpers to locate or check
# the file. If either helper drifts the entire working-memory
# protocol breaks.

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
# Block 1 — `wm_acceptance_criteria_path` resolves canonical path.
# ---------------------------------------------------------------------------
if bash -c "source '$PATHS_LIB' && declare -f wm_acceptance_criteria_path >/dev/null"; then
  printf 'PASS: wm_acceptance_criteria_path is defined after sourcing\n'
else
  printf 'FAIL: wm_acceptance_criteria_path is NOT defined in %s\n' "$PATHS_LIB" >&2
  FAIL=1
fi

if [[ "$FAIL" -eq 0 ]]; then
  out="$(bash -c "source '$PATHS_LIB' && wm_acceptance_criteria_path 2026-01-01-foo" 2>/tmp/wm-paths.err || true)"
  rc=$?
  if [[ "$rc" -ne 0 ]]; then
    printf 'FAIL: wm_acceptance_criteria_path exited rc=%d\n' "$rc" >&2
    printf '       stderr: %s\n' "$(cat /tmp/wm-paths.err 2>/dev/null)" >&2
    FAIL=1
  elif [[ "$out" != ".yoke/acceptance-criteria/2026-01-01-foo.md" ]]; then
    printf 'FAIL: stdout mismatch.\n' >&2
    printf '       expected: %s\n' '.yoke/acceptance-criteria/2026-01-01-foo.md' >&2
    printf '       actual:   %s\n' "$out" >&2
    FAIL=1
  else
    printf 'PASS: wm_acceptance_criteria_path prints exact canonical path and exits 0\n'
  fi
fi
rm -f /tmp/wm-paths.err

# Slug-templating gate: catches an implementation that hard-codes the
# slug as a constant instead of templating it.
if [[ "$FAIL" -eq 0 ]]; then
  out="$(bash -c "source '$PATHS_LIB' && wm_acceptance_criteria_path 2099-12-31-other-slug" 2>/dev/null || true)"
  if [[ "$out" == ".yoke/acceptance-criteria/2099-12-31-other-slug.md" ]]; then
    printf 'PASS: wm_acceptance_criteria_path templates the slug (does not hard-code)\n'
  else
    printf 'FAIL: wm_acceptance_criteria_path does not template the slug. actual=%s\n' "$out" >&2
    FAIL=1
  fi
fi

# ---------------------------------------------------------------------------
# Block 2 — `wm_acceptance_criteria_in_use` predicate.
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
SLUG_PRESENT="2099-12-31-wm-paths-present"
SLUG_ABSENT="2099-12-31-wm-paths-absent"
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
# placeholder fixture (auto-managed by the test; safe to delete)
EOF

if [[ "$FAIL" -eq 0 ]]; then
  if bash -c "source '$PATHS_LIB' && wm_acceptance_criteria_in_use '${SLUG_PRESENT}'" 2>/dev/null; then
    printf 'PASS: predicate returns 0 when file exists\n'
  else
    rc=$?
    printf 'FAIL: predicate returned rc=%d when file exists (expected 0)\n' "$rc" >&2
    FAIL=1
  fi
fi

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
  printf '\n--- Result ---\nFAIL: working-memory-paths-resolve-acceptance-criteria\n' >&2
  exit 1
fi
printf '\n--- Result ---\nPASS: working-memory-paths-resolve-acceptance-criteria\n'
exit 0
