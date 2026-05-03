#!/usr/bin/env bash
# criterion: AC-008-3
#
# Binding Acceptance Criterion (PRD US-008, ratified 2026-05-03T10:44:11Z):
#   AC-008-3: grep -c 'yoke-pattern-sprint-synthesis'
#             .yoke/runtime/.preserve-packet.md returns ≥ 1;
#             grep -c 'Trigger 2\.5' .yoke/runtime/.preserve-packet.md
#             returns ≥ 1.
#
# Sprint-4 anchor:
#   - sprint task s04-t08 acceptance criterion: "grep -c
#     'yoke-pattern-sprint-synthesis' .yoke/runtime/.preserve-packet.md
#     returns 0 status with stdout integer ≥ 1 AND grep -c 'Trigger 2\.5'
#     .yoke/runtime/.preserve-packet.md returns 0 status with stdout
#     integer ≥ 1."
#   - functional acceptance criterion ids:
#     canonize-packet-stages-pattern-entry,
#     canonize-packet-stages-trigger-25-amendment.
#
# Note: .yoke/runtime/.preserve-packet.md is gitignored runtime state
# (Sprint 4 task t08 documents the manual pre-population). This test
# asserts presence + binding-grep-count; it does not assert frontmatter
# shape (that is consumed by the Orchestrator at /yoke:canonize time,
# downstream of this binding gate).

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

PACKET=".yoke/runtime/.preserve-packet.md"

if [[ ! -f "$PACKET" ]]; then
  printf 'FAIL: AC-008-3 — preserve-packet missing at %s\n' "$PACKET" >&2
  exit 1
fi

PATTERN_COUNT="$(grep -c 'yoke-pattern-sprint-synthesis' "$PACKET" 2>/dev/null || true)"
PATTERN_COUNT="${PATTERN_COUNT:-0}"
if (( PATTERN_COUNT < 1 )); then
  printf 'FAIL: AC-008-3 — `yoke-pattern-sprint-synthesis` mentions in %s = %s, expected >= 1\n' \
    "$PACKET" "$PATTERN_COUNT" >&2
  exit 1
fi
printf 'PASS: AC-008-3 — `yoke-pattern-sprint-synthesis` mentions = %s\n' "$PATTERN_COUNT"

TRIG_COUNT="$(grep -c 'Trigger 2\.5' "$PACKET" 2>/dev/null || true)"
TRIG_COUNT="${TRIG_COUNT:-0}"
if (( TRIG_COUNT < 1 )); then
  printf 'FAIL: AC-008-3 — `Trigger 2.5` mentions in %s = %s, expected >= 1\n' \
    "$PACKET" "$TRIG_COUNT" >&2
  exit 1
fi
printf 'PASS: AC-008-3 — `Trigger 2.5` mentions = %s\n' "$TRIG_COUNT"

printf '\n--- Result ---\nPASS: us-008-canonize-packet\n'
exit 0
