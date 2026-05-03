#!/usr/bin/env bash
# criterion: scenario-02-wm-acceptance-criteria-path
#
# Acceptance Contract Scenario 2 (binding):
#   "`wm_acceptance_criteria_path` resolves the canonical path"
#   Task: 2026-05-03-generate-sprints-skill-s01-t02
#
# Then-clause (verbatim):
#   `bash -c 'source lib/working-memory/paths.sh
#       && wm_acceptance_criteria_path 2026-01-01-foo'`
#   prints exactly `.yoke/acceptance-criteria/2026-01-01-foo.md`
#   AND exits 0.
#
# Sprint anchor (sprint file's `## Functional acceptance criteria`):
#   wm-acceptance-criteria-path-callable
#
# This test is authored against the post-rename world. The Sr Eng
# slice for cycle 0 MUST add the `wm_acceptance_criteria_path`
# helper to `lib/working-memory/paths.sh`. Until then, this test
# correctly fails with a clear diagnostic — its job is to PROVE
# THE CODE WRONG until the criterion closes.

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
# Block 1 — function is defined after sourcing.
# ---------------------------------------------------------------------------
if bash -c "source '$PATHS_LIB' && declare -f wm_acceptance_criteria_path >/dev/null"; then
  printf 'PASS: wm_acceptance_criteria_path is defined after sourcing\n'
else
  printf 'FAIL: wm_acceptance_criteria_path is NOT defined in %s\n' "$PATHS_LIB" >&2
  FAIL=1
fi

# ---------------------------------------------------------------------------
# Block 2 — invocation with valid slug prints the documented path
#           and exits 0. The expected stdout is exact (no trailing
#           extras) per the contract's "prints exactly" wording.
# ---------------------------------------------------------------------------
if [[ "$FAIL" -eq 0 ]]; then
  out="$(bash -c "source '$PATHS_LIB' && wm_acceptance_criteria_path 2026-01-01-foo" 2>/tmp/ac-path-2.err || true)"
  rc=$?
  if [[ "$rc" -ne 0 ]]; then
    printf 'FAIL: invocation exited rc=%d\n' "$rc" >&2
    printf '       stderr: %s\n' "$(cat /tmp/ac-path-2.err 2>/dev/null)" >&2
    FAIL=1
  elif [[ "$out" != ".yoke/acceptance-criteria/2026-01-01-foo.md" ]]; then
    printf 'FAIL: stdout mismatch.\n' >&2
    printf '       expected: %s\n' '.yoke/acceptance-criteria/2026-01-01-foo.md' >&2
    printf '       actual:   %s\n' "$out" >&2
    FAIL=1
  else
    printf 'PASS: prints exact canonical path and exits 0\n'
  fi
fi
rm -f /tmp/ac-path-2.err

# ---------------------------------------------------------------------------
# Block 3 — the helper accepts an arbitrary valid slug. This catches
#           an implementation that hard-codes the slug as a constant
#           instead of templating it.
# ---------------------------------------------------------------------------
if [[ "$FAIL" -eq 0 ]]; then
  out="$(bash -c "source '$PATHS_LIB' && wm_acceptance_criteria_path 2099-12-31-other-slug" 2>/dev/null || true)"
  if [[ "$out" == ".yoke/acceptance-criteria/2099-12-31-other-slug.md" ]]; then
    printf 'PASS: helper templates the slug (does not hard-code)\n'
  else
    printf 'FAIL: helper does not template the slug. actual=%s\n' "$out" >&2
    FAIL=1
  fi
fi

if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: scenario-02\n' >&2
  exit 1
fi
printf '\n--- Result ---\nPASS: scenario-02\n'
exit 0
