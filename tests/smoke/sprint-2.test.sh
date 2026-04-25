#!/bin/bash
# tests/smoke/sprint-2.test.sh
#
# Sprint 2 smoke test — validates the spec-phase artifacts shipped in
# v0.2.0 and refreshed in v1.1.0 (skills-only spec phase, no subagent
# spawn).
#
# Pre-Sprint-6: this test does NOT invoke any ralph loop. External
# `timeout` is therefore not strictly required, but use one in CI as a
# precaution (e.g. `timeout 600 bash tests/smoke/sprint-2.test.sh`).

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- Sprint 2 smoke ---"

# 1. SKILL.md files exist with valid frontmatter (name + description)
for skill in discover tech-spec ask; do
  f="skills/${skill}/SKILL.md"
  if [ ! -f "$f" ]; then
    err "missing $f"
    continue
  fi
  if awk 'BEGIN{c=0; n=0; d=0} /^---$/{c++; next} c==1 && /^name:/{n=1} c==1 && /^description:/{d=1} END{exit (n && d) ? 0 : 1}' "$f"; then
    pass "$f frontmatter valid"
  else
    err "$f missing name/description in frontmatter"
  fi
done

# 2. v1.1 — spec-phase skills do NOT include Task in allowed-tools
#    (DoD #1 of runtime-only-agents-part-2: skills deliberate; subagents adapt).
#    /yoke:discover and /yoke:tech-spec drive their dialogues inline.
for skill in discover tech-spec; do
  f="skills/${skill}/SKILL.md"
  allowed_line=$(awk '/^allowed-tools:/{print; exit}' "$f" || true)
  if [ -z "$allowed_line" ]; then
    err "$f missing allowed-tools field"
  elif echo "$allowed_line" | grep -qw "Task"; then
    err "$f allowed-tools includes Task — should be inline (no subagent spawn): $allowed_line"
  else
    pass "$f allowed-tools excludes Task (skill-only)"
  fi
done

# 3. v1.1 — spec-phase skills embed persona inline (no "Spawn agents/...")
for skill in discover tech-spec; do
  f="skills/${skill}/SKILL.md"
  if grep -q "Spawn .agents/" "$f" || grep -q "Invoke the Generator subagent" "$f"; then
    err "$f still references subagent spawn (should be inline)"
  else
    pass "$f drops subagent-spawn references"
  fi
  if grep -qE "Generator persona|Your role .*persona" "$f"; then
    pass "$f embeds persona inline"
  else
    err "$f does not declare an inline persona"
  fi
done

# 4. PRD template has manifesto-shape sections
prd="templates/prd.md"
for section in "## Product invariants" "## Business context" "## Known constraints" "## Risks" "## Open questions"; do
  if grep -q -- "$section" "$prd"; then
    pass "$prd has '$section' section"
  else
    err "$prd missing '$section'"
  fi
done

# 5. Tech Spec template has manifesto-shape sections
ts="templates/tech-spec.md"
for section in "## Sprints" "Acceptance criterion:" "## Contracts and interfaces" "## Dependencies"; do
  if grep -q -- "$section" "$ts"; then
    pass "$ts has '$section'"
  else
    err "$ts missing '$section'"
  fi
done

# 6. Triggers 1 + 2 surface verbatim from the skills (binding prompts).
grep -q "Trigger 1 — PRD approval" skills/discover/SKILL.md \
  && pass "/yoke:discover prints Trigger-1 binding prompt" \
  || err "/yoke:discover missing Trigger-1 binding prompt"
grep -q "Trigger 2 — Tech Spec approval" skills/tech-spec/SKILL.md \
  && pass "/yoke:tech-spec prints Trigger-2 binding prompt" \
  || err "/yoke:tech-spec missing Trigger-2 binding prompt"

# 7. /yoke:ask routing preserved in spec-phase skills
for skill in discover tech-spec; do
  f="skills/${skill}/SKILL.md"
  if grep -q "/yoke:ask" "$f"; then
    pass "$f routes canonical-memory reads through /yoke:ask"
  else
    err "$f missing /yoke:ask routing"
  fi
done

# 8. /yoke:ask is the canonical-memory adaptive read skill
#    (Part 3 of the bedrock canonical-memory port retired direct query.sh
#    invocation — the skill now resolves the memory via Part 1's
#    resolve-memory.sh and reads the filesystem directly).
ask="skills/ask/SKILL.md"
ask_allowed=$(awk '/^allowed-tools:/{print; exit}' "$ask" || true)
if echo "$ask_allowed" | grep -qw "Task"; then
  err "/yoke:ask allowed-tools includes Task (should not spawn subagents)"
else
  pass "/yoke:ask allowed-tools excludes Task"
fi
grep -q "resolve-memory.sh" "$ask" \
  && pass "/yoke:ask resolves the active memory via Part 1's lib" \
  || err "/yoke:ask does not reference resolve-memory.sh"
grep -qE 'query-traces/<slug>\.md|wm_query_trace_path' "$ask" \
  && pass "/yoke:ask writes to versioned .yoke/query-traces/<slug>.md" \
  || err "/yoke:ask does not write query trace"
grep -qiE 'never.*(clone|pull|fetch)' "$ask" \
  && pass "/yoke:ask declares the no-clone invariant (Part 3 DoD-1)" \
  || err "/yoke:ask missing no-clone invariant"

# 9. Memory resolution lib + scaffold helper from Part 1 are present
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
[ -x lib/canonical-memory/registry.sh ] || [ -f lib/canonical-memory/registry.sh ] \
  && pass "lib/canonical-memory/registry.sh present" \
  || err "registry.sh missing"
[ -x lib/canonical-memory/resolve-memory.sh ] || [ -f lib/canonical-memory/resolve-memory.sh ] \
  && pass "lib/canonical-memory/resolve-memory.sh present" \
  || err "resolve-memory.sh missing"

# 10. /yoke:ask declares the no-fabrication rule
grep -qiE 'never fabricate|do not fabricate|never invent' "$ask" \
  && pass "/yoke:ask declares no-fabrication rule" \
  || err "/yoke:ask missing no-fabrication declaration"

# 11. /yoke:ask caps entity reads at 15 (progressive disclosure)
grep -qE '15 entit|cap.*15|≤[[:space:]]*15' "$ask" \
  && pass "/yoke:ask caps entity reads at 15 (progressive disclosure)" \
  || err "/yoke:ask missing 15-entity cap"

# 12. v1.1 anti-scope: spec-phase Generator/Validator subagent files MUST
#     NOT exist in agents/ (they were eliminated). agents/ contains only
#     runtime subagents — Sprint 4 owns those assertions.
[ ! -f "agents/implementation.md" ] && [ ! -f "agents/validation.md" ] \
  && pass "spec-phase / pre-rename agent files removed in v1.1" \
  || err "old agent file (implementation.md or validation.md) still present"

echo "--- Result ---"
if [ "$fail" -eq 0 ]; then
  echo "PASS"
  exit 0
else
  echo "FAIL ($fail check(s) failed)"
  exit 1
fi
