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
# v2.0.0 migration-pin path — plant claude-yoke/entities/foo.md, sensor
# MUST exit non-zero with the migration-pin diagnostic on stderr. Mirrors
# Acceptance Contract Scenario 13 / FR-8: the sensor pins the
# extraction-to-claude-bedrock invariant after s03-t03.
# ---------------------------------------------------------------------------
mkdir -p "$tmp/entities"
cat > "$tmp/entities/foo.md" <<'EOF'
---
type: actor
name: foo
---
EOF

migration_stderr="$tmp/.migration.stderr"
if (cd "$tmp" && bash "$SENSOR") 2>"$migration_stderr"; then
  err "migration-pin path: planted entities/foo.md should make sensor exit non-zero"
else
  pass "migration-pin path: planted entities/foo.md → non-zero exit"
fi

if grep -qE 'entities/.*must not exist|entities/.*reintroduced|migration-pin' "$migration_stderr"; then
  pass "migration-pin path: stderr contains migration-pin diagnostic"
else
  err "migration-pin path: stderr missing migration-pin diagnostic"
  echo "--- captured stderr ---" >&2
  cat "$migration_stderr" >&2 || true
fi

# Same probe for templates/canonical/ — second arm of the migration pin.
rm -rf "$tmp/entities"
mkdir -p "$tmp/templates/canonical/actor"
cat > "$tmp/templates/canonical/actor/_template.md" <<'EOF'
---
type: actor
---
EOF

canonical_stderr="$tmp/.canonical.stderr"
if (cd "$tmp" && bash "$SENSOR") 2>"$canonical_stderr"; then
  err "migration-pin path: planted templates/canonical/ should make sensor exit non-zero"
else
  pass "migration-pin path: planted templates/canonical/ → non-zero exit"
fi

if grep -qE 'templates/canonical/.*must not exist|templates/canonical/.*reintroduced|migration-pin' "$canonical_stderr"; then
  pass "migration-pin path: stderr contains migration-pin diagnostic for templates/canonical/"
else
  err "migration-pin path: stderr missing migration-pin diagnostic for templates/canonical/"
fi

# Cleanup before the working-tree pollution check.
rm -rf "$tmp/entities" "$tmp/templates/canonical"

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
