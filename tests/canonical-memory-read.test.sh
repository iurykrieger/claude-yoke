#!/usr/bin/env bash
# tests/canonical-memory-read.test.sh
#
# /yoke:search-canonical-memory read protocol (v2.0.0).
#
# Pre-v2.0.0 this test exercised scaffold + register + resolve against
# Bedrock-specific scripts (registry.sh, scaffold-memory.sh,
# resolve-memory.sh). Those scripts were extracted to the claude-bedrock
# peer plugin per the 2026-04-30 pluggable-canonical-memory PRD; the
# substrate-specific no-clone / no-pull / no-fetch invariant lives in
# claude-bedrock's own test suite now.
#
# At v2.0.0 the read facade is provider-agnostic. The remaining
# claude-yoke-side invariants are:
#
#   (a) lib/canonical-memory/resolve-provider.sh exists and is the
#       only file under lib/canonical-memory/.
#   (b) resolve-provider.sh exports yoke_resolve_provider as a sourced
#       function; sourcing succeeds and the function is callable.
#   (c) resolve-provider.sh contains no git clone/pull/fetch invocations
#       (the resolver answers "what provider?", not "where is the
#       memory?" — git operations live in the provider plugin).
#   (d) skills/search-canonical-memory/SKILL.md sources the resolver
#       and dispatches via $YOKE_PROVIDER_SEARCH_SKILL.

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

cd "$PLUGIN_ROOT"

RESOLVE="lib/canonical-memory/resolve-provider.sh"
SEARCH="skills/search-canonical-memory/SKILL.md"

# ---------------------------------------------------------------------
# (a) lib/canonical-memory/ contains exactly resolve-provider.sh
# ---------------------------------------------------------------------
if [ -f "$RESOLVE" ]; then
  pass "(a) lib/canonical-memory/resolve-provider.sh exists"
else
  err "(a) lib/canonical-memory/resolve-provider.sh missing"
fi

if [ -d "lib/canonical-memory" ]; then
  count=$(ls lib/canonical-memory/ 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" = "1" ]; then
    pass "(a) lib/canonical-memory/ contains exactly one file"
  else
    err "(a) lib/canonical-memory/ contains $count files (expected 1; rest extracted to claude-bedrock)"
  fi
fi

# ---------------------------------------------------------------------
# (b) resolve-provider.sh defines yoke_resolve_provider as a function
# ---------------------------------------------------------------------
if [ -f "$RESOLVE" ]; then
  if grep -qE '^(yoke_resolve_provider\(\)|function yoke_resolve_provider)' "$RESOLVE"; then
    pass "(b) resolve-provider.sh defines yoke_resolve_provider"
  else
    err "(b) resolve-provider.sh missing yoke_resolve_provider function definition"
  fi
fi

# ---------------------------------------------------------------------
# (c) resolve-provider.sh has no git clone/pull/fetch invocations
# ---------------------------------------------------------------------
if [ -f "$RESOLVE" ]; then
  if grep -nE 'git[[:space:]]+(clone|pull|fetch)' "$RESOLVE"; then
    err "(c) resolve-provider.sh contains forbidden git clone/pull/fetch"
  else
    pass "(c) resolve-provider.sh source contains no clone/pull/fetch"
  fi
fi

# ---------------------------------------------------------------------
# (d) search-canonical-memory facade dispatches via the resolver
# ---------------------------------------------------------------------
if [ -f "$SEARCH" ]; then
  grep -q 'resolve-provider' "$SEARCH" \
    && pass "(d) search-canonical-memory references resolve-provider" \
    || err "(d) search-canonical-memory missing resolve-provider reference"

  grep -qE 'YOKE_PROVIDER_SEARCH_SKILL|provider.*search.*Skill' "$SEARCH" \
    && pass "(d) search-canonical-memory dispatches via provider's search skill" \
    || err "(d) search-canonical-memory missing provider-skill dispatch"
else
  err "(d) skills/search-canonical-memory/SKILL.md missing"
fi

harness::summary
