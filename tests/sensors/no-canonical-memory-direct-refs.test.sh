#!/usr/bin/env bash
# tests/sensors/no-canonical-memory-direct-refs.test.sh
#
# Self-test for lib/sensors/no-canonical-memory-direct-refs.sh. Three
# subcases per the binding Acceptance Criteria AC-005-1:
#   (positive) clean tree → silent success exit 0.
#   (negative) planted forbidden reference → exit 1, with structured-YAML
#              violation block on stdout (id / location /
#              correction_instruction / reference) and diagnostic
#              summary on stderr.
#   (reverse)  legitimate `resolve-provider.sh` reference → silent
#              success exit 0 (the only allow-listed name).
#
# Subcases run inside an ephemeral $tmp tree to avoid polluting the
# host worktree and to remain independent of the framework's live
# sensor surface. The sensor's --scan-dir flag points each subcase at
# the fixture root.
#
# Source: .yoke/acceptance-criteria/2026-05-05-stale-sensor-canonical-memory-refs.md
# US-005 / AC-005-1.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SENSOR="$PLUGIN_ROOT/lib/sensors/no-canonical-memory-direct-refs.sh"

fail=0
pass() { echo "[PASS] $1"; }
err()  { echo "[FAIL] $1" >&2; fail=$((fail+1)); }

echo "--- no-canonical-memory-direct-refs sensor self-test ---"

# (0) Sensor file presence + executability.
if [ ! -f "$SENSOR" ]; then
  err "sensor missing at $SENSOR"
  echo "--- done: $fail failure(s) ---"
  exit 1
fi
[ -x "$SENSOR" ] && pass "(0) sensor is executable" || err "(0) sensor not executable"

# (0b) Bash syntax check.
if bash -n "$SENSOR" 2>/dev/null; then
  pass "(0b) sensor parses under bash -n"
else
  err "(0b) sensor fails bash -n parse"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/lib/sensors"

# ---------------------------------------------------------------------------
# (1) Positive — clean fixture, sensor MUST exit 0 silent.
# ---------------------------------------------------------------------------
cat > "$tmp/lib/sensors/clean.sh" <<'EOF'
#!/usr/bin/env bash
# clean: no canonical-memory references at all
echo "clean sensor"
EOF
chmod +x "$tmp/lib/sensors/clean.sh"

pos_stdout="$tmp/.pos.stdout"
pos_stderr="$tmp/.pos.stderr"
if (bash "$SENSOR" --scan-dir "$tmp/lib/sensors") >"$pos_stdout" 2>"$pos_stderr"; then
  pass "(1) positive: clean tree → exit 0"
else
  err "(1) positive: clean tree should exit 0"
  echo "--- stderr ---" >&2; cat "$pos_stderr" >&2 || true
fi
if [ ! -s "$pos_stdout" ]; then pass "(1) positive: stdout silent"; else err "(1) positive: stdout not silent"; fi
if [ ! -s "$pos_stderr" ]; then pass "(1) positive: stderr silent"; else err "(1) positive: stderr not silent"; fi

# ---------------------------------------------------------------------------
# (2) Negative — planted forbidden reference, sensor MUST exit 1 with
# a structured-YAML violation block on stdout citing the file path + the
# offending substring, and a diagnostic summary on stderr.
# ---------------------------------------------------------------------------
cat > "$tmp/lib/sensors/planted.sh" <<'EOF'
#!/usr/bin/env bash
# planted: forbidden reference to a v2.0.0-extracted helper
source lib/canonical-memory/registry.sh
EOF
chmod +x "$tmp/lib/sensors/planted.sh"

neg_stdout="$tmp/.neg.stdout"
neg_stderr="$tmp/.neg.stderr"
if (bash "$SENSOR" --scan-dir "$tmp/lib/sensors") >"$neg_stdout" 2>"$neg_stderr"; then
  err "(2) negative: planted reference should make sensor exit 1"
else
  pass "(2) negative: planted reference → non-zero exit"
fi

# Structured-YAML violation must include id / location / correction / reference.
if grep -qF 'id: "no-canonical-memory-direct-refs"' "$neg_stdout"; then
  pass "(2) negative: stdout carries id key"
else
  err "(2) negative: stdout missing id key"
  echo "--- stdout ---" >&2; cat "$neg_stdout" >&2 || true
fi

if grep -qF 'planted.sh' "$neg_stdout"; then
  pass "(2) negative: stdout cites file path"
else
  err "(2) negative: stdout missing file path"
fi

if grep -qF 'registry.sh' "$neg_stdout"; then
  pass "(2) negative: stdout cites offending substring"
else
  err "(2) negative: stdout missing offending substring"
fi

if grep -qF '[[yoke-pattern-facade-vs-provider-verbs]]' "$neg_stdout"; then
  pass "(2) negative: stdout cites canonical-memory reference wikilink"
else
  err "(2) negative: stdout missing reference wikilink"
fi

if grep -qE 'sensor: no-canonical-memory-direct-refs found[[:space:]]+[0-9]+' "$neg_stderr"; then
  pass "(2) negative: stderr carries diagnostic summary"
else
  err "(2) negative: stderr missing diagnostic summary"
fi

rm -f "$tmp/lib/sensors/planted.sh"

# ---------------------------------------------------------------------------
# (3) Reverse — legitimate `resolve-provider.sh` reference is the ONLY
# allow-listed canonical-memory path. Sensor MUST exit 0 silent.
# ---------------------------------------------------------------------------
cat > "$tmp/lib/sensors/legit.sh" <<'EOF'
#!/usr/bin/env bash
# legit: facade-allowed reference to the surviving v2.0.0 helper
source lib/canonical-memory/resolve-provider.sh
yoke_resolve_provider
EOF
chmod +x "$tmp/lib/sensors/legit.sh"

rev_stdout="$tmp/.rev.stdout"
rev_stderr="$tmp/.rev.stderr"
if (bash "$SENSOR" --scan-dir "$tmp/lib/sensors") >"$rev_stdout" 2>"$rev_stderr"; then
  pass "(3) reverse: legitimate resolve-provider.sh reference → exit 0"
else
  err "(3) reverse: legitimate resolve-provider.sh reference should exit 0"
  echo "--- stderr ---" >&2; cat "$rev_stderr" >&2 || true
fi
if [ ! -s "$rev_stdout" ]; then pass "(3) reverse: stdout silent"; else err "(3) reverse: stdout not silent"; fi
if [ ! -s "$rev_stderr" ]; then pass "(3) reverse: stderr silent"; else err "(3) reverse: stderr not silent"; fi

# ---------------------------------------------------------------------------
# (4) Environmental — missing --scan-dir, sensor MUST exit 2 with
# diagnostic stderr.
# ---------------------------------------------------------------------------
env_stderr="$tmp/.env.stderr"
if bash "$SENSOR" --scan-dir "$tmp/does-not-exist" 2>"$env_stderr"; then
  err "(4) environmental: missing scan-dir should not exit 0"
else
  rc=$?
  if [ "$rc" -eq 2 ]; then
    pass "(4) environmental: missing scan-dir → exit 2"
  else
    err "(4) environmental: missing scan-dir should exit 2 (got $rc)"
  fi
fi
if grep -qF 'scan-dir not found' "$env_stderr"; then
  pass "(4) environmental: stderr cites scan-dir not found"
else
  err "(4) environmental: stderr missing diagnostic"
fi

# ---------------------------------------------------------------------------
# (5) Working-tree non-pollution sanity check.
# ---------------------------------------------------------------------------
if [ ! -e "$PLUGIN_ROOT/lib/sensors/planted.sh" ]; then
  pass "(5) non-pollution: no planted artifact leaked into host lib/sensors/"
else
  err "(5) non-pollution: leaked artifact at lib/sensors/planted.sh"
fi

echo "--- done: $fail failure(s) ---"
[ "$fail" -eq 0 ]
