#!/usr/bin/env bash
# tests/canonical-memory-read.test.sh
#
# /yoke:ask read protocol — no-clone invariant exercised against
# scaffold + register + resolve:
#   - scaffold-memory.sh creates a fresh memory repo
#   - registry.sh add registers it under a name
#   - resolve-memory.sh --memory <name> returns the registered path
#   - calling resolve twice does NOT mutate git reflog (no clone/pull/fetch)
#   - resolve-memory.sh source contains no clone/pull/fetch invocations

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

# Isolate the registry by overriding YOKE_PLUGIN_DIR to a tmpdir; the
# real plugin directory's memories.json is not touched. Symlink the
# templates/ directory so scaffold-memory.sh (which resolves templates
# relative to YOKE_PLUGIN_DIR) still finds the canonical templates.
TMP=$(mktemp -d)
ln -s "$PLUGIN_ROOT/templates" "$TMP/templates"
export YOKE_PLUGIN_DIR="$TMP"
trap 'rm -rf "$TMP"' EXIT

REG="$PLUGIN_ROOT/lib/canonical-memory/registry.sh"
SCAFFOLD="$PLUGIN_ROOT/lib/canonical-memory/scaffold-memory.sh"
RESOLVE="$PLUGIN_ROOT/lib/canonical-memory/resolve-memory.sh"

# ---------------------------------------------------------------------
# Setup — scaffold + register
# ---------------------------------------------------------------------
if bash "$REG" init >/dev/null 2>&1; then
  pass "registry init"
else
  err "registry init failed"
fi

MEM="$TMP/m"
if bash "$SCAFFOLD" "$MEM" >/dev/null 2>&1; then
  pass "scaffold-memory created $MEM"
  # CI may lack global git identity — set local config defensively.
  git -C "$MEM" config --local user.email "test@example.com" 2>/dev/null || true
  git -C "$MEM" config --local user.name "test" 2>/dev/null || true
else
  err "scaffold-memory failed"
fi

if bash "$REG" add main "$MEM" >/dev/null 2>&1; then
  pass "registry add main"
else
  err "registry add main failed"
fi

# ---------------------------------------------------------------------
# Reflog stability across two consecutive resolutions
# ---------------------------------------------------------------------
ref_before=$(git -C "$MEM" reflog 2>/dev/null | wc -l | tr -d ' ')

out1=$(bash "$RESOLVE" --memory main 2>/dev/null || true)
if [ -n "$out1" ]; then
  pass "first resolve returned: $out1"
else
  err "first resolve returned empty"
fi

ref_after_1=$(git -C "$MEM" reflog 2>/dev/null | wc -l | tr -d ' ')
if [ "$ref_after_1" = "$ref_before" ]; then
  pass "first resolve performed no git mutations (reflog stable)"
else
  err "first resolve mutated reflog ($ref_before -> $ref_after_1)"
fi

# Second resolve must return the same path with no git side-effects.
sleep 1
out2=$(bash "$RESOLVE" --memory main 2>/dev/null || true)
if [ "$out2" = "$out1" ]; then
  pass "second resolve returned the same result"
else
  err "second resolve returned a different result: '$out2' vs '$out1'"
fi

ref_after_2=$(git -C "$MEM" reflog 2>/dev/null | wc -l | tr -d ' ')
if [ "$ref_after_2" = "$ref_before" ]; then
  pass "second resolve performed no git mutations (reflog stable)"
else
  err "second resolve mutated reflog ($ref_before -> $ref_after_2)"
fi

# ---------------------------------------------------------------------
# Source-level: resolve-memory.sh contains no clone/pull/fetch
# ---------------------------------------------------------------------
if grep -nE 'git[[:space:]]+(clone|pull|fetch)' "$RESOLVE"; then
  err "resolve-memory.sh contains forbidden git clone/pull/fetch invocations"
else
  pass "resolve-memory.sh source contains no clone/pull/fetch"
fi

harness::summary
