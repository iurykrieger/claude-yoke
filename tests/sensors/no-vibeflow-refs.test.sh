#!/bin/bash
# tests/sensors/no-vibeflow-refs.test.sh
#
# Self-test for lib/sensors/no-vibeflow-refs.sh. Exercises both the
# pass path (clean tree → exit 0) and the fail path (a planted
# .vibeflow/ reference → exit 1, with file:line in stderr).
#
# Both probes run inside an ephemeral $tmp tree to avoid polluting the
# working tree and to remain independent of the live framework's
# pre-cutover .vibeflow/ count. The sensor is invoked with the temp
# tree as CWD so its hard-coded relative paths (skills/ agents/ hooks/
# lib/ templates/) resolve against the fixture, not the host repo.
#
# Source: .yoke/acceptance-contracts/2026-04-27-yoke-doctrine-canonization.md
# Scenario 14. Acceptance criterion s05-t01: this script exits 0 with
# both paths exercised.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SENSOR="$PLUGIN_ROOT/lib/sensors/no-vibeflow-refs.sh"

fail=0
pass() { echo "[PASS] $1"; }
err()  { echo "[FAIL] $1" >&2; fail=$((fail+1)); }

echo "--- no-vibeflow-refs sensor self-test ---"

# 0. Sensor file exists and is executable.
[ -f "$SENSOR" ] || { err "sensor missing at $SENSOR"; exit 1; }
[ -x "$SENSOR" ] && pass "sensor is executable" || err "sensor not executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Build a clean fixture tree containing the same framework surfaces the
# sensor scans. Keep them empty (no .vibeflow/ references) for the pass
# path.
mkdir -p "$tmp/skills" "$tmp/agents" "$tmp/hooks" "$tmp/lib" "$tmp/templates"
echo "# clean stub" > "$tmp/skills/example.md"
echo "# clean stub" > "$tmp/agents/example.md"
echo "# clean stub" > "$tmp/hooks/example.sh"
echo "# clean stub" > "$tmp/lib/example.sh"
echo "# clean stub" > "$tmp/templates/example.md"

# ---------------------------------------------------------------------------
# Pass path — clean tree, sensor MUST exit 0 with no stderr matches.
# ---------------------------------------------------------------------------
pass_stderr="$tmp/.pass.stderr"
if (cd "$tmp" && bash "$SENSOR") 2>"$pass_stderr"; then
  pass "pass path: clean tree → exit 0"
else
  err "pass path: clean tree should exit 0 but did not"
  echo "--- captured stderr ---" >&2
  cat "$pass_stderr" >&2 || true
fi

if [ -s "$pass_stderr" ]; then
  err "pass path: stderr should be empty on clean tree"
  cat "$pass_stderr" >&2 || true
else
  pass "pass path: stderr is empty"
fi

# ---------------------------------------------------------------------------
# Fail path — plant a .vibeflow/ reference under skills/, sensor MUST
# exit non-zero AND emit file:line in stderr.
# ---------------------------------------------------------------------------
planted="$tmp/skills/planted.md"
cat > "$planted" <<'EOF'
# planted reference
See .vibeflow/patterns/example.md for the legacy doctrine path.
EOF

fail_stderr="$tmp/.fail.stderr"
if (cd "$tmp" && bash "$SENSOR") 2>"$fail_stderr"; then
  err "fail path: planted reference should make sensor exit non-zero"
else
  pass "fail path: planted reference → non-zero exit"
fi

if grep -qF 'skills/planted.md' "$fail_stderr" \
   && grep -qF '.vibeflow/' "$fail_stderr"; then
  pass "fail path: stderr contains file:line with .vibeflow/ token"
else
  err "fail path: stderr missing file:line + .vibeflow/ token"
  echo "--- captured stderr ---" >&2
  cat "$fail_stderr" >&2 || true
fi

# Confirm the diagnostic summary line is present.
if grep -qE 'sensor: no-vibeflow-refs found[[:space:]]+[0-9]+[[:space:]]+match' "$fail_stderr"; then
  pass "fail path: stderr contains diagnostic summary line"
else
  err "fail path: stderr missing diagnostic summary line"
fi

# Cleanup the planted file before exit (trap handles $tmp wipe anyway).
rm -f "$planted"

# ---------------------------------------------------------------------------
# Working-tree non-pollution sanity check — no fixture artifact leaked
# into the host repo's framework surfaces during this test run.
# ---------------------------------------------------------------------------
if [ ! -e "$PLUGIN_ROOT/skills/planted.md" ]; then
  pass "non-pollution: no planted artifact leaked into host skills/"
else
  err "non-pollution: leaked artifact found at skills/planted.md"
fi

echo "--- done: $fail failure(s) ---"
[ "$fail" -eq 0 ]
