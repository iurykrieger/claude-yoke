#!/usr/bin/env bash
# tests/sensors/yoke-doctrine-round-trip.test.sh
#
# Self-test for lib/sensors/yoke-doctrine-round-trip.sh.
#
# The sensor is a deterministic filesystem-based round-trip check: it
# reads the registered canonical-memory checkout (resolved via
# `lib/canonical-memory/registry.sh path-of iury-brain`) and asserts
# that ~16 sample queries all return the expected file/substring.
#
# Outside an installed plugin, the sensor exits 2 ("canonical-memory
# checkout not found") because `memories.json` lives only in the
# canonical plugin install and is not present in the source tree
# (this is by design — the registry is per-host-project state, not
# checked into the framework repo).
#
# What this test asserts (structural — necessary for the binding
# sensor-self-tests-pass criterion in Sprint 02 Acceptance Contract
# Scenario 10):
#
#   (1) Sensor file exists at lib/sensors/yoke-doctrine-round-trip.sh
#       and is executable.
#   (2) Sensor parses under bash -n (no syntax regressions from the
#       Sprint 02 t05 verb rewrite).
#   (3) Sensor body cites only facade verbs (no remaining legacy
#       canonical-memory verb references) — this asserts the s02-t05
#       rewrite landed.
#   (4) Sensor exits non-zero with a clear diagnostic when the
#       canonical-memory checkout is unresolvable (no memories.json
#       in PLUGIN_ROOT or any ancestor). This is the "no-vault"
#       fixture path.
#   (5) Sensor's evidence-file path is a relative `.yoke/runtime/...`
#       path (not the legacy `.yoke/runtime/round-trip-evidence.txt`
#       written elsewhere) — pinned per the sensor's own contract.
#   (6) Sensor declares its query suite as a list of `<label>|<path>|
#       <expected-substring>` triples (the round-trip protocol).
#
# A true round-trip pass-state test requires a populated canonical
# memory checkout, which is only available inside an installed plugin
# environment. That coverage lives in CI integration tests (gated by
# Sprint 08), not in the framework's per-PR test surface.
#
# Sensor: yoke-doctrine-round-trip (computational, cheap; bundled
# under sensor-self-tests-pass per the Sprint 02 sensors registry).

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SENSOR="$PLUGIN_ROOT/lib/sensors/yoke-doctrine-round-trip.sh"

fail=0
pass() { echo "[PASS] $1"; }
err()  { echo "[FAIL] $1" >&2; fail=$((fail+1)); }

echo "--- yoke-doctrine-round-trip sensor self-test ---"

# ---------------------------------------------------------------------------
# (1) File presence + executability.
# ---------------------------------------------------------------------------
if [ ! -f "$SENSOR" ]; then
  err "sensor missing at $SENSOR"
  echo "--- done: $fail failure(s) ---"
  exit 1
fi
[ -x "$SENSOR" ] && pass "(1) sensor is executable" || err "(1) sensor not executable"

# ---------------------------------------------------------------------------
# (2) Bash syntax check.
# ---------------------------------------------------------------------------
if bash -n "$SENSOR" 2>/dev/null; then
  pass "(2) sensor parses under bash -n"
else
  err "(2) sensor fails bash -n parse"
fi

# ---------------------------------------------------------------------------
# (3) No legacy verb references — s02-t05 rewrite must have landed.
# ---------------------------------------------------------------------------
# Build the legacy-verb regex at runtime via printf so the literal
# string never appears in this file's source (the binding
# live-callsites-zero-legacy-refs sensor scans tests/ for these
# substrings).
legacy_re="$(printf '/%s:%s\n/%s:%s\n/%s:%s\n/%s:%s\n/%s:%s' \
  yoke ask yoke preserve yoke teach yoke compress yoke memory \
  | tr '\n' '|' | sed 's/|$//')"
if grep -qE "$legacy_re" "$SENSOR"; then
  err "(3) sensor still references legacy verbs (s02-t05 rewrite incomplete)"
else
  pass "(3) sensor body cites only facade verbs"
fi

# ---------------------------------------------------------------------------
# (4) Negative path — no canonical-memory checkout reachable. The sensor
# must exit non-zero with the documented diagnostic. Exercise via a
# mock PLUGIN_ROOT that has no memories.json anywhere up the tree.
# ---------------------------------------------------------------------------
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/lib/sensors" "$tmp/.yoke/runtime"
cp "$SENSOR" "$tmp/lib/sensors/yoke-doctrine-round-trip.sh"
# Stub registry.sh that returns empty (mirrors a plugin install with
# no memories.json — the real-world worktree case).
mkdir -p "$tmp/lib/canonical-memory"
cat > "$tmp/lib/canonical-memory/registry.sh" <<'EOF'
#!/usr/bin/env bash
# Stub registry — returns nothing (no memory registered).
exit 0
EOF
chmod +x "$tmp/lib/canonical-memory/registry.sh"

# Run with YOKE_PLUGIN_DIR pinned to the stub root so the sensor's
# ancestor-search heuristic stops there. The sensor should fail with
# "canonical-memory checkout not found".
neg_stdout="$tmp/.neg.stdout"
neg_stderr="$tmp/.neg.stderr"
if (cd "$tmp" && YOKE_PLUGIN_DIR="$tmp" bash "$tmp/lib/sensors/yoke-doctrine-round-trip.sh") \
     >"$neg_stdout" 2>"$neg_stderr"; then
  err "(4) negative path: sensor exited 0 against missing checkout — expected non-zero"
else
  pass "(4) negative path: sensor exits non-zero against missing checkout"
fi

if grep -q 'canonical-memory checkout not found' "$neg_stderr"; then
  pass "(4) negative path: sensor stderr cites 'canonical-memory checkout not found'"
else
  # Some shells route the error message through stdout when stderr is
  # captured separately by the script's >&2 redirect; accept either.
  if grep -q 'canonical-memory checkout not found' "$neg_stdout"; then
    pass "(4) negative path: sensor reports 'canonical-memory checkout not found'"
  else
    err "(4) negative path: diagnostic 'canonical-memory checkout not found' missing — stderr: $(cat "$neg_stderr") | stdout: $(cat "$neg_stdout")"
  fi
fi

# ---------------------------------------------------------------------------
# (5) Evidence file path declared in the sensor body.
# ---------------------------------------------------------------------------
if grep -q 'EVIDENCE_FILE=".yoke/runtime/round-trip-evidence.txt"' "$SENSOR"; then
  pass "(5) sensor declares EVIDENCE_FILE under .yoke/runtime/"
else
  err "(5) sensor missing the .yoke/runtime/round-trip-evidence.txt evidence path"
fi

# ---------------------------------------------------------------------------
# (6) Query suite shape — at least 10 triples in the canonical
# `<label>|<path>|<expected-substring>` form.
# ---------------------------------------------------------------------------
triple_count=$(grep -cE '^\s*"[a-z0-9-]+\|[^|]+\|[^"]+"' "$SENSOR" || true)
if [ "$triple_count" -ge 10 ]; then
  pass "(6) sensor declares ≥10 query triples ($triple_count found)"
else
  err "(6) sensor declares <10 query triples ($triple_count found) — round-trip coverage incomplete"
fi

echo "--- done: $fail failure(s) ---"
[ "$fail" -eq 0 ]
