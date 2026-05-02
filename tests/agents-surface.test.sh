#!/usr/bin/env bash
# tests/agents-surface.test.sh
#
# Structural contract of the v3.0 council runtime subagents in agents/:
#   (a) exactly 6 *.md files (3 personas + arbiter + canonize-only orchestrator + semantic-judge)
#   (b) the six are sr-eng.md, sr-qa.md, sr-staff.md, council-arbiter.md,
#       orchestrator.md, semantic-judge.md
#   (c) orchestrator declares canonize mode + sole canonical-memory write authority
#   (d) council-arbiter declares the structured JSON verdict format
#   (e) sr-eng declares slice-file per-cycle persistence under .yoke/runtime/cycles/<N>/

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

cd "$PLUGIN_ROOT"

# ---------------------------------------------------------------------
# (a) Expected v3.0 runtime subagents enumerated; exact match (no extras)
# ---------------------------------------------------------------------
expected_agents=(sr-eng.md sr-qa.md sr-staff.md council-arbiter.md orchestrator.md semantic-judge.md)
agent_count=$(find agents -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')

if [ "$agent_count" -eq "${#expected_agents[@]}" ]; then
  pass "agents/ contains exactly ${#expected_agents[@]} .md files"
else
  err "agents/ contains $agent_count .md files (expected ${#expected_agents[@]})"
fi

# ---------------------------------------------------------------------
# (b) Each expected runtime subagent file is present
# ---------------------------------------------------------------------
for a in "${expected_agents[@]}"; do
  if [ -f "agents/$a" ]; then
    pass "agents/$a present"
  else
    err "agents/$a missing"
  fi
done

# ---------------------------------------------------------------------
# (c) Orchestrator declares canonize mode + sole canonical-memory write authority
# ---------------------------------------------------------------------
if grep -qiE 'sole writer|only.*writer|sole .*write|write authority' agents/orchestrator.md; then
  pass "orchestrator declares sole canonical-memory write authority"
else
  err "orchestrator does not declare sole-write authority"
fi

if grep -qiE 'canonize' agents/orchestrator.md; then
  pass "orchestrator declares canonize mode"
else
  err "orchestrator does not declare canonize mode"
fi

# ---------------------------------------------------------------------
# (d) Council-arbiter declares the structured JSON verdict format
# ---------------------------------------------------------------------
if grep -qiE 'structured[[:space:]]+JSON[[:space:]]+verdict|JSON[[:space:]]+verdict|verdict[[:space:]]+schema' agents/council-arbiter.md; then
  pass "council-arbiter declares structured-JSON-verdict format"
else
  err "council-arbiter does not declare structured-JSON-verdict format"
fi

# ---------------------------------------------------------------------
# (e) Sr Eng declares per-cycle slice-file persistence under
#     .yoke/runtime/cycles/<N>/sr-eng.md
# ---------------------------------------------------------------------
if grep -qiE 'sr-eng\.md|cycles/[^/]+/sr-eng|Phase A.*own progress|slice file' agents/sr-eng.md; then
  pass "sr-eng declares per-cycle slice-file persistence"
else
  err "sr-eng does not declare per-cycle slice-file persistence"
fi

harness::summary
