#!/usr/bin/env bash
# tests/canonical-memory-write.test.sh
#
# Source-level invariants of the /yoke:canonize write protocol (v2.0.0):
#   (a) lib/canonical-memory/propose-write.sh does not exist
#   (b) skills/canonize/ exists (the new facade write surface)
#   (c) skills/preserve/ has been extracted to the claude-bedrock peer
#       plugin (must be absent in claude-yoke)
#   (d) skills/canonize/SKILL.md references resolve-provider.sh
#   (e) skills/canonize/SKILL.md dispatches via the configured provider's
#       canonize verb (Skill tool with $YOKE_PROVIDER_CANONIZE_SKILL)
#   (f) agents/orchestrator.md invokes /yoke:canonize
#   (g) no direct memory-path commit invocations exist outside the
#       extracted bedrock plugin (legacy regex against skills/preserve/)
#
# This is a doc-shape inspection. The actual write protocol (impact
# classes, rippability fields, git strategies, bidirectional linking)
# lives in the claude-bedrock peer plugin's preserve skill and is
# verified there. Cross-plugin integration is exercised in host
# projects, not here.

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

cd "$PLUGIN_ROOT"

# ---------------------------------------------------------------------
# (a) propose-write.sh remains absent — single write point invariant
# ---------------------------------------------------------------------
if [ ! -f "lib/canonical-memory/propose-write.sh" ]; then
  pass "(a) propose-write.sh absent (single write point)"
else
  err "(a) propose-write.sh exists (must be absent — single write point invariant)"
fi

# ---------------------------------------------------------------------
# (b) skills/canonize/ EXISTS — new facade write surface
# ---------------------------------------------------------------------
if [ -d "skills/canonize" ] && [ -f "skills/canonize/SKILL.md" ]; then
  pass "(b) skills/canonize/SKILL.md present (write facade)"
else
  err "(b) skills/canonize/SKILL.md missing — facade write surface required at v2.0.0"
fi

# ---------------------------------------------------------------------
# (c) skills/preserve/ ABSENT — extracted to claude-bedrock
# ---------------------------------------------------------------------
if [ ! -d "skills/preserve" ]; then
  pass "(c) skills/preserve/ absent (extracted to claude-bedrock peer plugin)"
else
  err "(c) skills/preserve/ exists (must be absent — extracted to claude-bedrock at v2.0.0)"
fi

CANON="skills/canonize/SKILL.md"
[ -f "$CANON" ] || harness::summary

# ---------------------------------------------------------------------
# (d) canonize SKILL references the provider resolver
# ---------------------------------------------------------------------
if grep -q 'resolve-provider\.sh' "$CANON"; then
  pass "(d) canonize references lib/canonical-memory/resolve-provider.sh"
else
  err "(d) canonize missing resolve-provider.sh reference"
fi

# ---------------------------------------------------------------------
# (e) canonize dispatches via the provider's canonize skill
# ---------------------------------------------------------------------
if grep -qE 'YOKE_PROVIDER_CANONIZE_SKILL|provider.*canonize.*Skill' "$CANON"; then
  pass "(e) canonize dispatches via provider's canonize skill"
else
  err "(e) canonize missing provider-skill dispatch"
fi

# ---------------------------------------------------------------------
# (f) Orchestrator invokes /yoke:canonize
# ---------------------------------------------------------------------
if grep -q '/yoke:canonize' agents/orchestrator.md; then
  pass "(f) orchestrator invokes /yoke:canonize via the Skill tool"
else
  err "(f) orchestrator does not invoke /yoke:canonize"
fi

# ---------------------------------------------------------------------
# (g) No direct memory-path commits outside the (now-extracted) preserve
# surface. After v2.0.0 the regex must return empty since claude-yoke
# no longer owns any direct git-write-to-memory-vault calls.
# ---------------------------------------------------------------------
LEAKS=$(grep -rEln 'git -C "?\$MEMORY_PATH"? commit' agents/ skills/ lib/ tests/ 2>/dev/null \
  | grep -v "^${BASH_SOURCE[0]#"$PLUGIN_ROOT/"}\$" || true)

if [ -z "$LEAKS" ]; then
  pass "(g) no direct memory commits anywhere in claude-yoke (write protocol lives in claude-bedrock)"
else
  err "(g) found direct memory commits in claude-yoke (should live only in claude-bedrock):"
  printf '%s\n' "$LEAKS" | sed 's/^/    /' >&2
fi

harness::summary
