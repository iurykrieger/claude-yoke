#!/usr/bin/env bash
# criterion: AC-008-2
#
# Binding Acceptance Criterion (PRD US-008, ratified 2026-05-03T10:44:11Z):
#   AC-008-2: grep -c 'skills/generate-sprints' docs/lineage.md returns ≥ 1.
#
# Sprint-4 anchor:
#   - sprint task s04-t07 (covering both architecture and lineage
#     doc updates) acceptance criterion: "grep -c 'skills/generate-sprints'
#     docs/lineage.md returns 0 status with stdout integer ≥ 1."
#   - functional acceptance criterion id:
#     lineage-doc-mentions-generate-sprints.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

DOC="docs/lineage.md"

if [[ ! -f "$DOC" ]]; then
  printf 'FAIL: AC-008-2 — %s missing\n' "$DOC" >&2
  exit 1
fi

LIN_COUNT="$(grep -c 'skills/generate-sprints' "$DOC" 2>/dev/null || true)"
LIN_COUNT="${LIN_COUNT:-0}"
if (( LIN_COUNT < 1 )); then
  printf 'FAIL: AC-008-2 — `skills/generate-sprints` mentions in %s = %s, expected >= 1\n' \
    "$DOC" "$LIN_COUNT" >&2
  exit 1
fi
printf 'PASS: AC-008-2 — `skills/generate-sprints` mentions in %s = %s\n' "$DOC" "$LIN_COUNT"

# Defence-in-depth: lineage entry should mark the skill as `native`
# per the binding DoD bullet 2 ("listed as native (no upstream
# lineage) with a one-paragraph rationale"). Keep this assertion as
# a NOTICE rather than a hard FAIL: the AC-008-2 binding contract
# is grep-count only; the rationale qualifier is DoD-level and not
# part of the AC-decidable surface.
NATIVE_HITS="$(grep -nE 'skills/generate-sprints.*native|native.*skills/generate-sprints' "$DOC" 2>/dev/null || true)"
if [[ -z "$NATIVE_HITS" ]]; then
  printf 'NOTICE: AC-008-2 binding satisfied; `native` qualifier proximity not asserted (DoD-level).\n'
else
  printf 'PASS: lineage entry tagged native (proximity match found)\n'
fi

printf '\n--- Result ---\nPASS: us-008-lineage-doc\n'
exit 0
