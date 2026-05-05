#!/usr/bin/env bash
# tests/smoke/orchestrator-canonize-handoff.test.sh
#
# Regression sensor for the Orchestrator -> /yoke:canonize handoff
# contract. Backs the .yoke/sensors/tests-orchestrator-canonize-handoff.md
# computational sensor.
#
# Asserts that the v2.0.0 zero-argument facade contract documented at
# skills/canonize/SKILL.md Phase 0 is honored uniformly by the two
# consumer surfaces (agents/orchestrator.md and skills/implement/SKILL.md)
# and that no caller-identity discriminator has been reintroduced
# anywhere in the plugin tree.
#
# Exit codes:
#   0  Contract coherent across the three surfaces; no discriminator
#      reintroduced.
#   1  Regression detected; reproduces the v2.0.0 hard-rejection
#      diagnostic on stderr.

set -eu

# Internal watchdog (per CLAUDE.md testing convention).
sleep 600 && kill -TERM $$ &
WD_PID=$!
trap 'kill $WD_PID 2>/dev/null || true' EXIT

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

V2_DIAG="wm: /yoke:canonize takes no arguments at v2.0.0"
fail=0

# Check 1 - consumer prose is free of the retired flag.
# Pattern is split across two grep -e clauses so this test file's own
# search pattern does not match the literal token in its source.
prose_matches="$(grep -nE -e '--from-orchestrator' -e 'from-orchestrator' \
    agents/orchestrator.md skills/implement/SKILL.md 2>/dev/null || true)"
if [ -n "$prose_matches" ]; then
    echo "$V2_DIAG" >&2
    echo "regression: '--from-orchestrator' reference in consumer prose:" >&2
    printf '%s\n' "$prose_matches" >&2
    fail=1
fi

# Check 2 - no env-var discriminator anywhere in the plugin tree.
# Scope: agents/, skills/, lib/, hooks/. tests/ is excluded so this
# test file does not match itself.
env_matches="$(grep -rnE 'YOKE_FROM_ORCHESTRATOR' \
    agents/ skills/ lib/ hooks/ 2>/dev/null || true)"
if [ -n "$env_matches" ]; then
    echo "$V2_DIAG" >&2
    echo "regression: env-var discriminator reintroduced:" >&2
    printf '%s\n' "$env_matches" >&2
    fail=1
fi

# Check 3 - no wrapper subskill reintroduced.
# Scope: same as check 2. tests/ is excluded.
wrapper_matches="$(grep -rnE 'canonize-from-orchestrator' \
    agents/ skills/ lib/ hooks/ 2>/dev/null || true)"
if [ -n "$wrapper_matches" ]; then
    echo "$V2_DIAG" >&2
    echo "regression: wrapper subskill reintroduced:" >&2
    printf '%s\n' "$wrapper_matches" >&2
    fail=1
fi

# Check 4 - the canonize skill's zero-argument guard is intact.
# The contract authority must keep emitting the v2.0.0 hard-rejection
# diagnostic; weakening it there cascades to every consumer.
if ! grep -qF "$V2_DIAG" skills/canonize/SKILL.md; then
    echo "$V2_DIAG" >&2
    echo "regression: zero-argument guard removed from skills/canonize/SKILL.md" >&2
    fail=1
fi

if [ "$fail" -ne 0 ]; then
    exit 1
fi

echo "PASS: canonize-invocation contract aligned across the three surfaces"
exit 0
