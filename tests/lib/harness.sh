#!/usr/bin/env bash
# tests/lib/harness.sh — shared bash harness for framework tests.
#
# Sourced by every tests/<concept>.test.sh file. Exposes:
#
#   PLUGIN_ROOT          absolute path to the repository root
#   pass <message>       record + print a passing assertion
#   err  <message>       record + print a failing assertion (stderr)
#   harness::summary     print PASS/FAIL totals and exit 0 (clean) / 1 (any err)
#
# Usage:
#   #!/usr/bin/env bash
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"
#   cd "$PLUGIN_ROOT"
#   <assertion> && pass "what worked" || err "what broke"
#   harness::summary

set -euo pipefail

# Resolve repo root from the location of this file: tests/lib/harness.sh -> ../..
_HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$_HARNESS_DIR/../.." && pwd)"
export PLUGIN_ROOT

_HARNESS_PASS=0
_HARNESS_FAIL=0

pass() {
  _HARNESS_PASS=$((_HARNESS_PASS + 1))
  printf '✓ %s\n' "$1"
}

err() {
  _HARNESS_FAIL=$((_HARNESS_FAIL + 1))
  printf '✗ %s\n' "$1" >&2
}

harness::summary() {
  printf '\n--- Result ---\n'
  if [ "$_HARNESS_FAIL" -eq 0 ]; then
    printf 'PASS (%d check(s))\n' "$_HARNESS_PASS"
    exit 0
  fi
  printf 'FAIL (%d failed, %d passed)\n' "$_HARNESS_FAIL" "$_HARNESS_PASS"
  exit 1
}
