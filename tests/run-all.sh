#!/usr/bin/env bash
# tests/run-all.sh — run every tests/<concept>.test.sh in lexicographic order.
#
# Excludes tests/lib/ (harness only) and run-all.sh itself. Returns
# non-zero exit if any test failed. Used for local convenience; CI runs
# each concern file as its own matrix job.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$ROOT/tests"

cd "$ROOT"

fail=0
total=0

shopt -s nullglob
for t in "$TESTS_DIR"/*.test.sh; do
  rel="${t#"$ROOT"/}"
  total=$((total + 1))
  printf -- '\n=== %s ===\n' "$rel"
  if bash "$t"; then
    printf -- '--- %s: PASS ---\n' "$rel"
  else
    printf -- '--- %s: FAIL ---\n' "$rel" >&2
    fail=$((fail + 1))
  fi
done

printf -- '\n=== run-all: %d/%d failed ===\n' "$fail" "$total"
[ "$fail" -eq 0 ]
