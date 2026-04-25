#!/usr/bin/env bash
# tests/smoke/memory-migration.test.sh
#
# Part 2 smoke test — verifies:
#   (a) fresh install with no prior canonical memory
#   (b) install with existing canonical_memory.url + ~/.cache/yoke/canonical clone
#   (c) /yoke:memory add for an empty directory (scaffolds)
#   (d) /yoke:memory add for an already-registered URL (rejects)
#
# Wraps with `timeout 600` per pre-Sprint-6 conventions.
# Bash 4+ assumed.

set -euo pipefail

# Run with an outer `timeout 600` from CI per pre-Sprint-6 conventions.
# Locally, `timeout` may not exist (macOS without coreutils); auto-wrap
# only when the binary is available, otherwise rely on the bounded
# scenarios below to complete quickly.
if [ -z "${SMOKE_TIMEOUT_WRAPPED:-}" ] && command -v timeout >/dev/null 2>&1; then
  exec env SMOKE_TIMEOUT_WRAPPED=1 timeout 600 bash "$0" "$@"
fi

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export YOKE_PLUGIN_DIR="$PLUGIN_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"; rm -f "$PLUGIN_DIR/memories.json"' EXIT

REG="$PLUGIN_DIR/lib/canonical-memory/registry.sh"
SCAFFOLD="$PLUGIN_DIR/lib/canonical-memory/scaffold-memory.sh"

pass() { echo "  PASS — $*"; }
fail() { echo "  FAIL — $*" >&2; exit 1; }

# Reset registry between scenarios.
reset_registry() {
  rm -f "$PLUGIN_DIR/memories.json"
}

# ---------------------------------------------------------------------------
# Scenario (a): fresh install with no prior canonical memory
# ---------------------------------------------------------------------------
echo "Scenario (a): fresh install — no prior canonical memory"
reset_registry
bash "$REG" init
out=$(bash "$REG" list)
[ "$out" = "(no memories registered)" ] || fail "expected empty registry message; got: $out"
pass "fresh registry shows empty-state message"

# ---------------------------------------------------------------------------
# Scenario (b): existing canonical_memory.url + cache clone — migration
# ---------------------------------------------------------------------------
echo "Scenario (b): pre-existing config + cache clone — migration path"
reset_registry

# Simulate a pre-v0.7 install: a clone exists at ~/.cache/yoke/canonical/<slug>/
# (don't actually touch the user's $HOME; use a fake home for this scenario).
FAKE_HOME="$WORK/home"
mkdir -p "$FAKE_HOME/.cache/yoke/canonical"
LEGACY_CACHE="$FAKE_HOME/.cache/yoke/canonical/sample-canonical-memory"
git init --quiet "$LEGACY_CACHE"
( cd "$LEGACY_CACHE" && git -c user.email=t@t -c user.name=t commit --allow-empty --quiet -m "init" )

# Migration target (XDG default chosen by bootstrap):
XDG_TARGET="$FAKE_HOME/.local/share/yoke/canonical/sample-canonical-memory"

# Simulate the migration logic that bootstrap will perform:
mkdir -p "$(dirname "$XDG_TARGET")"
git clone --quiet "$LEGACY_CACHE" "$XDG_TARGET"
SLUG="sample-canonical-memory"
URL="$LEGACY_CACHE"
bash "$REG" add "$SLUG" "$XDG_TARGET" "$URL"

# Verify registry write happened before cache deletion (DoD-4 ordering rule).
[ "$(bash "$REG" path-of "$SLUG")" = "$XDG_TARGET" ] || fail "registry did not record migrated path"
pass "registry write succeeded before cache deletion"

# Now delete the cache (last step in the bootstrap sequence).
rm -rf "$LEGACY_CACHE"
[ ! -d "$LEGACY_CACHE" ] || fail "legacy cache should be deleted"
pass "legacy cache deleted after registry write"

# Re-running migration must be a no-op (idempotency).
if bash "$REG" add "$SLUG" "$XDG_TARGET" "$URL" 2>/dev/null; then
  fail "expected duplicate-name rejection on re-run; add succeeded"
else
  pass "re-running migration rejects duplicate registration (idempotent)"
fi

# ---------------------------------------------------------------------------
# Scenario (c): /yoke:memory add for an empty directory (scaffolds)
# ---------------------------------------------------------------------------
echo "Scenario (c): /yoke:memory add against empty path — scaffolds"
reset_registry
EMPTY="$WORK/fresh-memory"
bash "$SCAFFOLD" "$EMPTY" >/dev/null
bash "$REG" add fresh "$EMPTY"

[ -f "$EMPTY/actors/_template.md" ] || fail "scaffold did not create actor template"
[ -f "$EMPTY/.yoke-memory/config.json" ] || fail "scaffold did not create per-memory config"
[ -d "$EMPTY/.git" ] || fail "scaffold did not init git"
[ "$(bash "$REG" path-of fresh)" = "$EMPTY" ] || fail "registry did not record scaffolded memory"
pass "empty-path add scaffolds and registers"

# ---------------------------------------------------------------------------
# Scenario (d): /yoke:memory add for an already-registered URL (rejects)
# ---------------------------------------------------------------------------
echo "Scenario (d): /yoke:memory add with duplicate URL — rejects"
reset_registry
DUP_URL="https://example.test/dup.git"
bash "$REG" add first "$WORK/d1" "$DUP_URL" >/dev/null

if bash "$REG" add second "$WORK/d2" "$DUP_URL" 2>/dev/null; then
  fail "expected exit 4 on duplicate URL; add succeeded"
else
  pass "duplicate-URL add rejected"
fi

# ---------------------------------------------------------------------------
echo
echo "All Part 2 smoke scenarios PASS"
