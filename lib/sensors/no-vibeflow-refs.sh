#!/bin/bash
# Sensor: zero references to the legacy doctrine directory in framework surface.
# Exits 0 if no matches; non-zero with file:line:context output otherwise.
#
# Implementation note: the search needle is constructed at runtime from
# two halves so this script can be migrated, audited, and version-
# controlled without tripping its own check. (Self-reference paradox:
# a sensor that searches for string X must mention string X to do its
# job. Constructing the needle from parts breaks the paradox.)
#
# Source: .yoke/acceptance-contracts/2026-04-27-yoke-doctrine-canonization.md
# Scenario 14 / FR-1 / FR-4. Tripwire pinning the "no legacy doctrine
# refs in framework surface" invariant after Sprint 4 cutover.
set -euo pipefail
needle=".vi""beflow/"
exclude_self="$(realpath "$0" 2>/dev/null || echo "$0")"
matches="$(grep -rnF "$needle" skills/ agents/ hooks/ lib/ templates/ 2>/dev/null \
  | grep -vF "$(basename "$0")" \
  | grep -vF "no-vibeflow-refs.test.sh" \
  || true)"
if [[ -n "$matches" ]]; then
  echo "$matches" >&2
  echo "sensor: no-vibeflow-refs found $(echo "$matches" | wc -l) match(es)" >&2
  exit 1
fi
exit 0
