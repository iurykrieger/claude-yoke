#!/usr/bin/env bash
# Use case: docs/architecture.md documents the sprint-synthesis
# phase introduced by /yoke:generate-sprints.
#
# Behaviour under test (durable):
#   The architecture document MUST acknowledge the dedicated
#   sprint-synthesis phase that sits between binding criteria and
#   council runtime, and MUST cite the skill that produces it
#   (`/yoke:generate-sprints`). The phase label has historically
#   been written as `Phase 2.5` (transitional naming) and as
#   `Phase 3.5` (current chain-aware naming); either label
#   satisfies the binding behaviour — what matters is that the
#   doc names the phase AND names the skill, so a reader can find
#   the producer of `.yoke/sprints/<slug>-s<NN>.md`.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

DOC="docs/architecture.md"

if [[ ! -f "$DOC" ]]; then
  printf 'FAIL: %s missing\n' "$DOC" >&2
  exit 1
fi

# Block 1 — the sprint-synthesis phase is named.
PHASE_COUNT="$(grep -cE 'Phase (2\.5|3\.5)' "$DOC" 2>/dev/null || true)"
PHASE_COUNT="${PHASE_COUNT:-0}"
if (( PHASE_COUNT < 1 )); then
  printf 'FAIL: sprint-synthesis phase (Phase 2.5 or Phase 3.5) not mentioned in %s\n' "$DOC" >&2
  exit 1
fi
printf 'PASS: sprint-synthesis phase mentions in %s = %s\n' "$DOC" "$PHASE_COUNT"

# Block 2 — the producer skill is cited.
SKILL_COUNT="$(grep -c '/yoke:generate-sprints' "$DOC" 2>/dev/null || true)"
SKILL_COUNT="${SKILL_COUNT:-0}"
if (( SKILL_COUNT < 1 )); then
  printf 'FAIL: `/yoke:generate-sprints` mentions in %s = %s, expected >= 1\n' "$DOC" "$SKILL_COUNT" >&2
  exit 1
fi
printf 'PASS: `/yoke:generate-sprints` mentions in %s = %s\n' "$DOC" "$SKILL_COUNT"

printf '\n--- Result ---\nPASS: architecture-doc-mentions-sprint-synthesis-phase\n'
exit 0
