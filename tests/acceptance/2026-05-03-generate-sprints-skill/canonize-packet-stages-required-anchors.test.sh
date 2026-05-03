#!/usr/bin/env bash
#
# Binding Acceptance Criterion (binding contract):
#   AC-008-3: grep -c 'yoke-pattern-sprint-synthesis'
#             .yoke/runtime/.preserve-packet.md returns ≥ 1;
#             grep -c 'Trigger 2\.5' .yoke/runtime/.preserve-packet.md
#             returns ≥ 1.
#
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

printf '\n--- Result ---\nPASS: canonize-packet-stages-required-anchors\n'
exit 0
