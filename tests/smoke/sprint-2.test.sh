#!/bin/bash
# tests/smoke/sprint-2.test.sh
#
# Sprint 2 smoke test — validates the static artifacts shipped in v0.2.0.
# Full end-to-end (idea → PRD → Tech Spec via Claude Code) requires a live
# Claude Code session and is intrinsic manual verification.
#
# Pre-Sprint-6: this test does NOT invoke any ralph loop. External `timeout`
# is therefore not strictly required, but use one in CI as a precaution
# (e.g. `timeout 600 bash tests/smoke/sprint-2.test.sh`).

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

# 2. Generator subagent file present and substantive (no longer placeholder)
gen="agents/generator.md"
if [ ! -f "$gen" ]; then
  err "missing $gen"
elif [ "$(wc -l < "$gen")" -gt 50 ]; then
  pass "$gen substantive (>50 lines)"
else
  err "$gen looks like a placeholder ($(wc -l < "$gen") lines)"
fi

# 3. PRD template has manifesto-shape sections
prd="templates/prd.md"
for section in "## Product invariants" "## Business context" "## Known constraints" "## Risks" "## Open questions"; do
  if grep -q -- "$section" "$prd"; then
    pass "$prd has '$section' section"
  else
    err "$prd missing '$section'"
  fi
done

# 4. Tech Spec template has manifesto-shape sections
ts="templates/tech-spec.md"
for section in "## Sprints" "Acceptance criterion:" "## Contracts and interfaces" "## Dependencies"; do
  if grep -q -- "$section" "$ts"; then
    pass "$ts has '$section'"
  else
    err "$ts missing '$section'"
  fi
done

# 5. query.sh runs against an empty test directory (returns empty-state)
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
if out=$(bash lib/canonical-memory/query.sh "anything" "$tmpdir" 2>&1); then
  if echo "$out" | grep -qi "no entries yet"; then
    pass "query.sh empty-state UX correct"
  else
    err "query.sh did not emit empty-state message: $out"
  fi
else
  err "query.sh failed against empty dir: $out"
fi

# 6. query.sh finds matches in a populated test directory
mkdir -p "$tmpdir/policies"
cat > "$tmpdir/policies/example.md" <<'EOF'
---
ratified_at: 2026-01-01
impact_level: low
---
# Example policy
This is a test entry.
EOF
if out=$(bash lib/canonical-memory/query.sh "test entry" "$tmpdir" 2>&1); then
  if echo "$out" | grep -q "policies/example.md"; then
    pass "query.sh finds matches in populated repo"
  else
    err "query.sh did not find expected match: $out"
  fi
else
  err "query.sh failed against populated dir: $out"
fi

# 7. query.sh returns "no matches" with a specific count for missing terms
if out=$(bash lib/canonical-memory/query.sh "absent-term-xyz" "$tmpdir" 2>&1); then
  if echo "$out" | grep -qi "no matches"; then
    pass "query.sh no-matches UX correct"
  else
    err "query.sh did not emit no-matches message: $out"
  fi
else
  err "query.sh failed for missing term: $out"
fi

# 8. Generator prompt distinct from Implementation Agent (DoD #5).
# Originally checked size ratio (assuming Implementation stays a small
# placeholder), but Sprint 4 legitimately expands the Implementation
# Agent. Switch to a content-diff check that holds across sprints.
diff_output=$(diff "agents/generator.md" "agents/implementation.md" 2>/dev/null || true)
diff_lines=$(printf '%s' "$diff_output" | wc -l | tr -d ' ')
if [ "$diff_lines" -gt 50 ]; then
  pass "Generator prompt substantively distinct from Implementation Agent (diff=$diff_lines lines)"
else
  err "Generator/Implementation prompts not distinct enough (diff=$diff_lines lines)"
fi

# 9. Anti-scope (point-in-time at Sprint-2 completion): only assert
# placeholders for items that NO LATER sprint advances within v1.0.
#
# Items advanced by later sprints (so we DO NOT check them here):
#   - Validator subagent → Sprint 3
#   - verify-acceptance.sh → Sprint 3
#   - Implementation Agent → Sprint 4
#   - Validation Agent → Sprint 4
#   - post-iteration.sh / pre-implementation.sh → Sprint 4
#   - Orchestrator → Sprint 5 (moves to skills/orchestrator/)
#   - check-hard-bounds.sh / escalate.sh → Sprint 6
#   - canonize / drift-sense / status skills → Sprints 5/7/8
#
# After Sprint 5 deletes agents/orchestrator.md, even the
# orchestrator-placeholder assertion would break — so we drop it now
# and rely on each sprint's own smoke + audit to enforce its anti-scope
# at the time of writing.
pass "Sprint-2 anti-scope: assertions deferred to per-sprint smokes (intentional design)"

echo "--- Result ---"
if [ "$fail" -eq 0 ]; then
  echo "PASS"
  exit 0
else
  echo "FAIL ($fail check(s) failed)"
  exit 1
fi
