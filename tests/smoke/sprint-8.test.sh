#!/bin/bash
# tests/smoke/sprint-8.test.sh
#
# Sprint 8 smoke — final-release verification. Confirms the v1.0.0
# release artifacts are in place: example project, lineage doc,
# troubleshooting doc, CI workflow, finalized README, version bumped
# everywhere.
#
# Also runs a full audit gate: every prior sprint smoke must still pass
# (DoD #7's "no Don'ts violated across the whole repo" full audit
# requirement).

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- Sprint 8 smoke (final release verification) ---"

# ------------------------------------------------------------------
# 1. Example project completeness (DoD #1)
# ------------------------------------------------------------------
ex_dir="examples/greenfield-payment-service"
[ -d "$ex_dir" ] || err "missing $ex_dir/"

for f in README.md CLAUDE.md .yoke/config.yaml .yoke/prd.md .yoke/tech-spec.md .yoke/acceptance-contract.md; do
  if [ -f "$ex_dir/$f" ]; then
    pass "example $f exists"
  else
    err "missing $ex_dir/$f"
  fi
done

# .gitkeep replaced by real content
[ ! -f "$ex_dir/.gitkeep" ] \
  && pass "example .gitkeep removed (replaced by real content)" \
  || err "example .gitkeep still present"

# Example artifacts have approved/ratified status
grep -q "Status: approved" "$ex_dir/.yoke/prd.md" \
  && pass "example prd.md is Status: approved" \
  || err "example prd.md not approved"
grep -q "Status: approved" "$ex_dir/.yoke/tech-spec.md" \
  && pass "example tech-spec.md is Status: approved" \
  || err "example tech-spec.md not approved"
grep -q "Status: ratified" "$ex_dir/.yoke/acceptance-contract.md" \
  && pass "example acceptance-contract.md is Status: ratified" \
  || err "example acceptance-contract.md not ratified"

# Example CLAUDE.md has the discoverable-sensor sections
for section in "## Testing" "## Linting" "## Build"; do
  grep -q -- "$section" "$ex_dir/CLAUDE.md" \
    && pass "example CLAUDE.md has '$section' section" \
    || err "example CLAUDE.md missing '$section' section"
done

# Example sensors actually parse via discover-from-claude-md
out=$(bash lib/sensors/discover-from-claude-md.sh "$ex_dir/CLAUDE.md" 2>&1) || true
testing_count=$(echo "$out" | grep -c 'category: testing' || true)
[ "$testing_count" -ge 2 ] \
  && pass "discover-from-claude-md.sh extracts ≥2 testing sensors from example" \
  || err "discover-from-claude-md.sh found $testing_count testing sensors in example (expected ≥2)"

# Example contract has BDD scenarios (≥3) and FRs (≥4)
scenario_count=$(grep -cE '^### Scenario [0-9]+' "$ex_dir/.yoke/acceptance-contract.md" || true)
[ "$scenario_count" -ge 3 ] \
  && pass "example contract has ≥3 BDD scenarios ($scenario_count)" \
  || err "example contract has $scenario_count BDD scenarios (expected ≥3)"

fr_count=$(grep -cE '^- \[ \] \*\*FR-' "$ex_dir/.yoke/acceptance-contract.md" || true)
[ "$fr_count" -ge 4 ] \
  && pass "example contract has ≥4 functional requirements ($fr_count)" \
  || err "example contract has $fr_count FRs (expected ≥4)"

# ------------------------------------------------------------------
# 2. README finalized (DoD #2)
# ------------------------------------------------------------------
grep -q "Version:.*1\.0\.0" README.md \
  && pass "README.md states v1.0.0" \
  || err "README.md not at v1.0.0"

grep -qF "/plugin marketplace add iurykrieger/yoke" README.md \
  && pass "README.md has install command" \
  || err "README.md missing install command"

grep -qF "docs/quickstart.md" README.md \
  && pass "README.md links to quickstart" \
  || err "README.md missing quickstart link"

grep -qF "docs/architecture.md" README.md \
  && pass "README.md links to architecture" \
  || err "README.md missing architecture link"

grep -qE "(badge|shields\.io|github\.com/.*workflow|CI)" README.md \
  && pass "README.md has CI badge / build status indicator" \
  || err "README.md missing CI badge"

# ------------------------------------------------------------------
# 3. All docs/*.md present and consistent (DoD #3)
# ------------------------------------------------------------------
for d in installation.md quickstart.md architecture.md canonical-memory-setup.md scheduling-strategy.md troubleshooting.md lineage.md; do
  if [ -f "docs/$d" ]; then
    pass "docs/$d exists"
  else
    err "missing docs/$d"
  fi
done

# Architecture has Model C table (Sprint 6 added)
grep -qF "Model C" docs/architecture.md \
  && pass "docs/architecture.md has Model C section" \
  || err "docs/architecture.md missing Model C section"

# Lineage has both upstream URLs (DoD #6)
grep -qF "github.com/pe-menezes/vibeflow" docs/lineage.md \
  && pass "docs/lineage.md cites Vibeflow URL" \
  || err "docs/lineage.md missing Vibeflow URL"
grep -qF "github.com/iurykrieger/claude-bedrock" docs/lineage.md \
  && pass "docs/lineage.md cites Bedrock URL" \
  || err "docs/lineage.md missing Bedrock URL"

# Lineage names per-skill mapping
for skill in discover tech-spec query.sh graph.sh propose-write.sh; do
  grep -q "$skill" docs/lineage.md \
    && pass "docs/lineage.md documents $skill provenance" \
    || err "docs/lineage.md missing $skill provenance"
done

grep -qF "ex nihilo" docs/lineage.md \
  && pass "docs/lineage.md has honesty statement" \
  || err "docs/lineage.md missing honesty statement"

# Troubleshooting has key sections
for section in Installation "Phase 1" "Phase 4" "Phase 5" "Phase 6"; do
  grep -qF -- "$section" docs/troubleshooting.md \
    && pass "docs/troubleshooting.md has '$section' section" \
    || err "docs/troubleshooting.md missing '$section'"
done

# ------------------------------------------------------------------
# 4. CI workflow (DoD #4)
# ------------------------------------------------------------------
ci=".github/workflows/ci.yml"
[ -f "$ci" ] || err "missing $ci"

grep -qE "on:.*pull_request|pull_request:" "$ci" \
  && pass "$ci runs on pull_request" \
  || err "$ci does not run on pull_request"

grep -q "push:" "$ci" \
  && pass "$ci runs on push" \
  || err "$ci does not run on push"

# All sprint smokes referenced
for s in 2 3 4 5 6 7 8; do
  grep -q "sprint-${s}.test.sh" "$ci" \
    && pass "$ci runs sprint-${s}.test.sh" \
    || err "$ci does not run sprint-${s}.test.sh"
done

# Pre-Sprint-6 wrapping with timeout 600 (Sprint-4 specifically)
grep -qE "timeout 600 bash tests/smoke/sprint-4.test.sh" "$ci" \
  && pass "$ci wraps Sprint-4 smoke in timeout 600 (R5 mitigation)" \
  || err "$ci does not protect Sprint-4 smoke with external timeout"

# JSON validation step
grep -qF "json.load" "$ci" \
  && pass "$ci validates JSON manifests" \
  || err "$ci missing JSON validation step"

# ------------------------------------------------------------------
# 5. Marketplace artifacts at v1.0.0 (DoD #5)
# ------------------------------------------------------------------
ver=$(python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['version'])")
[ "$ver" = "1.0.0" ] \
  && pass "plugin.json version is 1.0.0" \
  || err "plugin.json version is $ver (expected 1.0.0)"

mp_meta=$(python3 -c "import json; print(json.load(open('.claude-plugin/marketplace.json'))['metadata']['version'])")
mp_plugin=$(python3 -c "import json; print(json.load(open('.claude-plugin/marketplace.json'))['plugins'][0]['version'])")
[ "$mp_meta" = "1.0.0" ] && [ "$mp_plugin" = "1.0.0" ] \
  && pass "marketplace.json metadata + plugin both at 1.0.0" \
  || err "marketplace.json versions: metadata=$mp_meta plugin=$mp_plugin (expected 1.0.0)"

grep -qE "^## \[1\.0\.0\]" CHANGELOG.md \
  && pass "CHANGELOG.md has 1.0.0 entry" \
  || err "CHANGELOG.md missing 1.0.0 entry"

# ------------------------------------------------------------------
# 6. Lineage credit honest (DoD #7 craftsmanship gate)
# ------------------------------------------------------------------
# README credits both upstream
grep -qF "Vibeflow" README.md && grep -qF "Bedrock" README.md \
  && pass "README.md credits Vibeflow + Bedrock" \
  || err "README.md missing one or both upstream credits"

# Lineage doc has fork dates
grep -qE "Sprint 2|Sprint 5" docs/lineage.md \
  && pass "docs/lineage.md records fork sprints" \
  || err "docs/lineage.md missing fork sprints"

# ------------------------------------------------------------------
# 7. Full plugin-structure conformance audit (DoD #7)
# ------------------------------------------------------------------
# Every directory listed in plugin-structure.md exists
for d in .claude-plugin skills agents hooks templates lib lib/canonical-memory lib/ralph-loop lib/sensors docs tests; do
  [ -d "$d" ] && pass "directory $d/ exists" || err "missing directory $d/"
done

# 9 SKILL.md present
skill_count=$(find skills -mindepth 2 -name 'SKILL.md' | wc -l | tr -d ' ')
[ "$skill_count" -ge 9 ] \
  && pass "skills/ has $skill_count SKILL.md files (≥9)" \
  || err "skills/ has $skill_count SKILL.md files (expected ≥9)"

# 4 agent files present (post Sprint-5 amendment: Orchestrator moved to skills/orchestrator/)
agent_count=$(find agents -name '*.md' | wc -l | tr -d ' ')
[ "$agent_count" -ge 4 ] \
  && pass "agents/ has $agent_count agent files (≥4 after Orchestrator-as-skill amendment)" \
  || err "agents/ has $agent_count files (expected ≥4)"

# Orchestrator skill at new location
[ -f "skills/orchestrator/SKILL.md" ] \
  && pass "skills/orchestrator/SKILL.md exists (PRD v0 amendment honored)" \
  || err "skills/orchestrator/SKILL.md missing"

# Old orchestrator placeholder is deleted
[ ! -f "agents/orchestrator.md" ] \
  && pass "agents/orchestrator.md deleted (Sprint 5 deletion verified)" \
  || err "agents/orchestrator.md still present (should be deleted in Sprint 5)"

# ------------------------------------------------------------------
# 8. Full audit-gate regression — every prior sprint smoke must pass
# ------------------------------------------------------------------
echo "--- Full audit gate (every sprint smoke) ---"
for sprint in 2 3 4 5 6 7; do
  bash "tests/smoke/sprint-${sprint}.test.sh" > "/tmp/sp${sprint}-audit-gate.log" 2>&1 \
    && pass "Sprint-${sprint} smoke still PASS (full audit gate)" \
    || err "Sprint-${sprint} regressed in v1.0.0: $(tail -3 /tmp/sp${sprint}-audit-gate.log)"
done
bash tests/plugin-install.test.sh > /dev/null && pass "plugin-install.test.sh PASS"
bash tests/skills-format.test.sh > /dev/null && pass "skills-format.test.sh PASS"

echo "--- Result ---"
if [ "$fail" -eq 0 ]; then
  echo "PASS"
  exit 0
else
  echo "FAIL ($fail check(s) failed)"
  exit 1
fi
