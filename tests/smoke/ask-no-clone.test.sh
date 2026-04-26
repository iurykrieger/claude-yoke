#!/usr/bin/env bash
# tests/smoke/ask-no-clone.test.sh
#
# Part 3 smoke test — verifies the no-clone invariant of /yoke:ask:
#   - Two consecutive reads against the same registered memory perform
#     zero `git fetch`, `git pull`, or `git clone` operations.
#   - The Part 1 resolution lib returns the registered local path
#     directly; the skill never re-fetches.
#
# This test exercises the *resolution* layer (Part 1 lib) and verifies
# the registered path's git reflog count does not change between two
# resolutions. The full skill body is markdown — it is exercised by
# end-to-end runs in the host project, not by this smoke test.

set -euo pipefail

if [ -z "${SMOKE_TIMEOUT_WRAPPED:-}" ] && command -v timeout >/dev/null 2>&1; then
  exec env SMOKE_TIMEOUT_WRAPPED=1 timeout 600 bash "$0" "$@"
fi

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export YOKE_PLUGIN_DIR="$PLUGIN_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"; rm -f "$PLUGIN_DIR/memories.json"' EXIT

REG="$PLUGIN_DIR/lib/canonical-memory/registry.sh"
SCAFFOLD="$PLUGIN_DIR/lib/canonical-memory/scaffold-memory.sh"
RESOLVE="$PLUGIN_DIR/lib/canonical-memory/resolve-memory.sh"

pass() { echo "  PASS — $*"; }
fail() { echo "  FAIL — $*" >&2; exit 1; }

# Set up: scaffold a fresh memory and register it
echo "Setup: scaffold + register"
MEM="$WORK/m"
bash "$SCAFFOLD" "$MEM" >/dev/null
bash "$REG" init
bash "$REG" add main "$MEM" >/dev/null
pass "memory scaffolded and registered"

# Reflog snapshot before any resolution
ref_before=$(git -C "$MEM" reflog | wc -l | tr -d ' ')

# First resolve
out1=$(bash "$RESOLVE" --memory main)
[ -n "$out1" ] || fail "first resolve returned empty"
pass "first resolve returned: $out1"

# Reflog snapshot after first resolve
ref_after_1=$(git -C "$MEM" reflog | wc -l | tr -d ' ')
[ "$ref_after_1" = "$ref_before" ] || fail "first resolve mutated git reflog ($ref_before -> $ref_after_1)"
pass "first resolve performed no git operations (reflog stable)"

# Sleep < 60s and resolve again (per DoD-5: "second invocation within 60s does not re-clone")
sleep 1
out2=$(bash "$RESOLVE" --memory main)
[ "$out2" = "$out1" ] || fail "second resolve returned different result: '$out2'"
ref_after_2=$(git -C "$MEM" reflog | wc -l | tr -d ' ')
[ "$ref_after_2" = "$ref_before" ] || fail "second resolve mutated git reflog ($ref_before -> $ref_after_2)"
pass "second resolve within 60s performed no git operations (reflog stable)"

# Verify the resolution lib never invokes `git clone`/`git pull`/`git fetch`
# in its own source — defensive read-through.
if grep -nE 'git[[:space:]]+(clone|pull|fetch)' "$RESOLVE"; then
  fail "resolve-memory.sh contains forbidden git clone/pull/fetch invocations"
fi
pass "resolve-memory.sh contains no clone/pull/fetch"

# Verify the new ask SKILL.md declares the no-clone invariant.
ASK="$PLUGIN_DIR/skills/ask/SKILL.md"
if ! grep -qE 'never[[:space:]]+(`?git\s+)?(clone|pull|fetch)' "$ASK"; then
  if ! grep -qiE 'never .*(clone|pull|fetch)' "$ASK"; then
    fail "ask SKILL.md missing no-clone invariant"
  fi
fi
pass "ask SKILL.md declares no-clone invariant"

# Verify query.sh is gone (DoD-4)
if [ -f "$PLUGIN_DIR/lib/canonical-memory/query.sh" ]; then
  fail "query.sh still exists — DoD-4 violation"
fi
pass "query.sh deleted (DoD-4)"

echo
echo "All Part 3 no-clone scenarios PASS"
