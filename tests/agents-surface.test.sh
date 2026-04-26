#!/usr/bin/env bash
# tests/agents-surface.test.sh
#
# Structural contract of the runtime subagents in agents/:
#   (a) exactly 3 *.md files
#   (b) the three are generator.md, validator.md, orchestrator.md
#   (c) orchestrator declares sole write authority over canonical memory
#   (d) validator declares the structured JSON verdict format
#   (e) generator declares progress.md per-cycle persistence

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

cd "$PLUGIN_ROOT"

# ---------------------------------------------------------------------
# (a) Exactly 3 *.md files in agents/
# ---------------------------------------------------------------------
agent_count=$(find agents -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
if [ "$agent_count" -eq 3 ]; then
  pass "agents/ contains exactly 3 .md files"
else
  err "agents/ contains $agent_count .md files (expected 3)"
fi

# ---------------------------------------------------------------------
# (b) The three runtime subagents are present
# ---------------------------------------------------------------------
for a in generator.md validator.md orchestrator.md; do
  if [ -f "agents/$a" ]; then
    pass "agents/$a present"
  else
    err "agents/$a missing"
  fi
done

# ---------------------------------------------------------------------
# (c) Orchestrator declares sole write authority over canonical memory
# ---------------------------------------------------------------------
if grep -qiE 'sole writer|only.*writer|sole .*write|write authority' agents/orchestrator.md; then
  pass "orchestrator declares sole canonical-memory write authority"
else
  err "orchestrator does not declare sole-write authority"
fi

# ---------------------------------------------------------------------
# (d) Validator declares the structured JSON verdict format
# ---------------------------------------------------------------------
if grep -qiE 'structured[[:space:]]+JSON[[:space:]]+verdict|JSON[[:space:]]+verdict' agents/validator.md; then
  pass "validator declares structured-JSON-verdict format"
else
  err "validator does not declare structured-JSON-verdict format"
fi

# ---------------------------------------------------------------------
# (e) Generator declares progress.md per-cycle persistence
# ---------------------------------------------------------------------
if grep -qiE 'progress\.md.*(every cycle|each cycle|per cycle|end of every cycle)|(every cycle|each cycle|per cycle|end of every cycle).*progress\.md' agents/generator.md; then
  pass "generator declares progress.md per-cycle persistence"
else
  err "generator does not declare progress.md per-cycle persistence"
fi

harness::summary
