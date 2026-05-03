#!/usr/bin/env bash
# Use case: the canonize hand-off packet stages the anchors that
# the next /yoke:canonize run must promote.
#
# Behaviour under test (durable):
#   At full-run termination the implement coordinator stages a
#   canonize hand-off packet at .yoke/runtime/.preserve-packet.md
#   carrying every anchor the Orchestrator must reference at
#   canonize-time. For the sprint-synthesis cutover the binding
#   anchors are:
#     1. The pattern entry the new doctrine produces
#        (`yoke-pattern-sprint-synthesis`).
#     2. The Trigger that gates the new sprint-approval menu
#        (Trigger 2.5 historically, Trigger 3.5 in the chain-aware
#        naming — either label satisfies the binding behaviour).
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

TRIG_COUNT="$(grep -cE 'Trigger (2\.5|3\.5)' "$PACKET" 2>/dev/null || true)"
TRIG_COUNT="${TRIG_COUNT:-0}"
if (( TRIG_COUNT < 1 )); then
  printf 'FAIL: sprint-approval Trigger (Trigger 2.5 or Trigger 3.5) mentions in %s = %s, expected >= 1\n' \
    "$PACKET" "$TRIG_COUNT" >&2
  exit 1
fi
printf 'PASS: sprint-approval Trigger mentions = %s\n' "$TRIG_COUNT"

printf '\n--- Result ---\nPASS: canonize-packet-stages-required-anchors\n'
exit 0
