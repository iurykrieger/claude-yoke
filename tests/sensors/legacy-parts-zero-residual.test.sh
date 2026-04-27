#!/bin/bash
# tests/sensors/legacy-parts-zero-residual.test.sh
#
# Self-test for lib/sensors/legacy-parts-zero-residual.sh. Exercises:
#   - clean tree → exit 0, empty stdout (pass path)
#   - planted -part-N.md → exit 1, one JSON violation on stdout (fail path)
#   - planted -s<NN>-t<MM>.md → exit 1, one JSON violation on stdout
#   - both planted → exit 1, two JSON violations
#   - emitted JSON has the six required keys (structured-output contract)
#
# All probes run inside an ephemeral $tmp tree to avoid polluting the
# working tree. The sensor is invoked with the temp tree as CWD so its
# hard-coded relative paths (.yoke/specs/, .yoke/tasks/) resolve against
# the fixture, not the host repo.
#
# Source: .yoke/acceptance-contracts/2026-04-27-sprint-as-cycle.md
# Scenario 4. Acceptance criterion s01-t04: this script exits 0 with
# all probe paths exercised.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SENSOR="$PLUGIN_ROOT/lib/sensors/legacy-parts-zero-residual.sh"

fail=0
pass() { echo "[PASS] $1"; }
err()  { echo "[FAIL] $1" >&2; fail=$((fail+1)); }

echo "--- legacy-parts-zero-residual sensor self-test ---"

# 0. Sensor file exists and is executable.
[ -f "$SENSOR" ] || { err "sensor missing at $SENSOR"; exit 1; }
[ -x "$SENSOR" ] && pass "sensor is executable" || err "sensor not executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Build a clean fixture tree: empty .yoke/specs/ and .yoke/tasks/.
mkdir -p "$tmp/.yoke/specs" "$tmp/.yoke/tasks"

# ---------------------------------------------------------------------------
# Pass path 1 — clean tree, sensor MUST exit 0 with empty stdout.
# ---------------------------------------------------------------------------
clean_stdout="$tmp/.clean.stdout"
if (cd "$tmp" && bash "$SENSOR") >"$clean_stdout" 2>/dev/null; then
    pass "pass path: clean tree → exit 0"
else
    err "pass path: clean tree should exit 0 but did not"
fi
if [ ! -s "$clean_stdout" ]; then
    pass "pass path: stdout empty on clean tree"
else
    err "pass path: stdout should be empty on clean tree"
    cat "$clean_stdout" >&2
fi

# ---------------------------------------------------------------------------
# Fail path 1 — planted -part-N.md under .yoke/specs/, sensor MUST exit
# non-zero AND emit one JSON violation pointing at the planted file.
# ---------------------------------------------------------------------------
planted_part="$tmp/.yoke/specs/2026-04-27-fixture-part-1.md"
echo "# fixture" > "$planted_part"

partn_stdout="$tmp/.partn.stdout"
if (cd "$tmp" && bash "$SENSOR") >"$partn_stdout" 2>/dev/null; then
    err "fail path 1: planted -part-N.md should make sensor exit non-zero"
else
    pass "fail path 1: planted -part-N.md → non-zero exit"
fi
if [ "$(wc -l < "$partn_stdout" | tr -d ' ')" = "1" ]; then
    pass "fail path 1: exactly one violation emitted"
else
    err "fail path 1: expected 1 violation, got $(wc -l < "$partn_stdout") line(s)"
    cat "$partn_stdout" >&2
fi
if grep -qF '2026-04-27-fixture-part-1.md' "$partn_stdout"; then
    pass "fail path 1: violation cites the planted file"
else
    err "fail path 1: violation does not cite planted file"
    cat "$partn_stdout" >&2
fi

# Structured-output shape check — six required keys present.
if command -v jq >/dev/null 2>&1; then
    if jq -e '.criterion and .status and .location and .fix_instruction and .sensor and .evidence' \
        < "$partn_stdout" >/dev/null 2>&1; then
        pass "fail path 1: JSON has all six required keys"
    else
        err "fail path 1: JSON missing one or more required keys"
        cat "$partn_stdout" >&2
    fi
else
    # Fallback: substring check for each key. jq is the canonical check.
    miss=""
    for k in criterion status location fix_instruction sensor evidence; do
        grep -qF "\"$k\":" "$partn_stdout" || miss="$miss $k"
    done
    if [ -z "$miss" ]; then
        pass "fail path 1: JSON has all six required keys (fallback substring check)"
    else
        err "fail path 1: JSON missing keys:$miss"
    fi
fi

rm -f "$planted_part"

# ---------------------------------------------------------------------------
# Fail path 2 — planted -s<NN>-t<MM>.md under .yoke/tasks/.
# ---------------------------------------------------------------------------
planted_task="$tmp/.yoke/tasks/2026-04-27-fixture-s01-t01.md"
echo "# fixture" > "$planted_task"

task_stdout="$tmp/.task.stdout"
if (cd "$tmp" && bash "$SENSOR") >"$task_stdout" 2>/dev/null; then
    err "fail path 2: planted -s<NN>-t<MM>.md should make sensor exit non-zero"
else
    pass "fail path 2: planted -s<NN>-t<MM>.md → non-zero exit"
fi
if [ "$(wc -l < "$task_stdout" | tr -d ' ')" = "1" ]; then
    pass "fail path 2: exactly one violation emitted"
else
    err "fail path 2: expected 1 violation, got $(wc -l < "$task_stdout") line(s)"
    cat "$task_stdout" >&2
fi
if grep -qF '2026-04-27-fixture-s01-t01.md' "$task_stdout"; then
    pass "fail path 2: violation cites the planted file"
else
    err "fail path 2: violation does not cite planted file"
fi

# ---------------------------------------------------------------------------
# Fail path 3 — both planted, expect two violations.
# ---------------------------------------------------------------------------
planted_part2="$tmp/.yoke/specs/2026-04-27-fixture-part-2.md"
echo "# fixture" > "$planted_part2"

both_stdout="$tmp/.both.stdout"
if (cd "$tmp" && bash "$SENSOR") >"$both_stdout" 2>/dev/null; then
    err "fail path 3: both planted should make sensor exit non-zero"
else
    pass "fail path 3: both planted → non-zero exit"
fi
if [ "$(wc -l < "$both_stdout" | tr -d ' ')" = "2" ]; then
    pass "fail path 3: exactly two violations emitted"
else
    err "fail path 3: expected 2 violations, got $(wc -l < "$both_stdout") line(s)"
    cat "$both_stdout" >&2
fi

# ---------------------------------------------------------------------------
# Pass path 2 — remove all fakes, sensor MUST exit 0 with empty stdout
# (idempotent recovery: no leftover state in the sensor itself).
# ---------------------------------------------------------------------------
rm -f "$planted_part2" "$planted_task"
recover_stdout="$tmp/.recover.stdout"
if (cd "$tmp" && bash "$SENSOR") >"$recover_stdout" 2>/dev/null; then
    pass "pass path 2: post-cleanup tree → exit 0"
else
    err "pass path 2: post-cleanup tree should exit 0"
fi
if [ ! -s "$recover_stdout" ]; then
    pass "pass path 2: stdout empty after cleanup"
else
    err "pass path 2: stdout should be empty after cleanup"
fi

# ---------------------------------------------------------------------------
# Working-tree non-pollution sanity check — no fixture artifact leaked
# into the host repo's .yoke/ during this test run.
# ---------------------------------------------------------------------------
if [ ! -e "$PLUGIN_ROOT/.yoke/specs/2026-04-27-fixture-part-1.md" ] \
   && [ ! -e "$PLUGIN_ROOT/.yoke/tasks/2026-04-27-fixture-s01-t01.md" ]; then
    pass "non-pollution: no planted artifact leaked into host .yoke/"
else
    err "non-pollution: leaked artifact found in host .yoke/"
fi

echo "--- done: $fail failure(s) ---"
[ "$fail" -eq 0 ]
