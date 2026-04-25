#!/bin/bash
# tests/smoke/sprint-5.test.sh
#
# Sprint 5 smoke — Orchestrator subagent (3 modes), canonization
# criteria, git-native low-impact PR path, /yoke:canonize escape hatch,
# auto-canonize handoff at /yoke:implement termination.
#
# Real-flow PR creation requires `gh` authenticated against a test
# repo. Smoke uses --dry-run to avoid network/auth dependencies.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- Sprint 5 smoke ---"

# 1. v1.1 — Orchestrator is a runtime subagent in agents/orchestrator.md
#    (the v0.5.0 PRD-amendment skill at skills/orchestrator/SKILL.md is
#    deleted; canonical-memory mediation moves to /yoke:ask + the
#    Orchestrator subagent's consult mode).
orch="agents/orchestrator.md"
[ -f "$orch" ] || err "missing $orch (v1.1 promotes Orchestrator back to a subagent)"
[ "$(wc -l < "$orch")" -gt 50 ] && pass "$orch substantive (>50 lines)" || err "$orch looks like a placeholder"
awk 'BEGIN{c=0; n=0; d=0} /^---$/{c++; next} c==1 && /^name:/{n=1} c==1 && /^description:/{d=1} END{exit (n && d) ? 0 : 1}' "$orch" \
  && pass "$orch frontmatter valid" \
  || err "$orch missing name/description"

[ ! -f "skills/orchestrator/SKILL.md" ] \
  && pass "skills/orchestrator/SKILL.md deleted (v1.1 retires the Orchestrator skill)" \
  || err "skills/orchestrator/SKILL.md still exists — should be removed in v1.1"

# 2. Three runtime modes declared in agents/orchestrator.md
for mode in consult monitor canonize; do
  if grep -qF "[orchestrator:$mode]" "$orch"; then
    pass "$orch declares $mode mode token"
  else
    err "$orch missing $mode mode declaration"
  fi
done

# 3. /yoke:preserve — single write point (Part 4 of the bedrock
#    canonical-memory port retired skills/canonize and propose-write.sh).
sk="skills/preserve/SKILL.md"
[ -f "$sk" ] || err "missing $sk"

allowed_line=$(awk '/^allowed-tools:/{print; exit}' "$sk" || true)
echo "$allowed_line" | grep -qw "Skill" \
  && pass "$sk allowed-tools includes Skill (Phase 5 invokes /yoke:ask, etc.)" \
  || err "$sk missing Skill in allowed-tools"

grep -qE "single write point|single write entry|sole write" "$sk" \
  && pass "$sk positions itself as the single write entry" \
  || err "$sk does not declare single-write-point invariant"

grep -qE "Model C|impact_level|impact-class" "$sk" \
  && pass "$sk wires Model C in Phase 3" \
  || err "$sk missing Model C wiring"

# Skills/canonize was retired in Part 4 (DoD-4).
[ ! -d "skills/canonize" ] \
  && pass "skills/canonize/ removed (Part 4 DoD-4)" \
  || err "skills/canonize/ still present"

# propose-write.sh was retired in Part 4 (DoD-4).
[ ! -f "lib/canonical-memory/propose-write.sh" ] \
  && pass "lib/canonical-memory/propose-write.sh removed (Part 4 DoD-4)" \
  || err "propose-write.sh still present"

# 4. /yoke:implement issues auto-canonize handoff at loop termination
#    (auto-canonize fires from /yoke:implement; Orchestrator invokes
#    /yoke:preserve via the Skill tool — Part 4 of the bedrock port).
imp="skills/implement/SKILL.md"
grep -qE 'mode=canonize|canonize-mode|/yoke:preserve' "$imp" \
  && pass "$imp issues canonize handoff at loop termination" \
  || err "$imp missing auto-canonize termination handoff"

grep -qE "Termination|termination|canonize handoff" "$imp" \
  && pass "$imp documents termination canonization handoff" \
  || err "$imp missing termination handoff documentation"

# 5. /yoke:ask — adaptive read against the registered memory (Part 3 of
#    the bedrock canonical-memory port retired the query.sh shell-out;
#    the skill now resolves via Part 1's resolve-memory.sh and reads
#    the filesystem directly).
ask="skills/ask/SKILL.md"
grep -qE 'query-traces|query-trace' "$ask" \
  && pass "$ask references the query-traces directory" \
  || err "$ask does not declare query trace"
grep -q "resolve-memory.sh" "$ask" \
  && pass "$ask resolves the active memory via Part 1's lib" \
  || err "$ask does not reference resolve-memory.sh"

ask_allowed=$(awk '/^allowed-tools:/{print; exit}' "$ask" || true)
if echo "$ask_allowed" | grep -qw "Task"; then
  err "$ask allowed-tools includes Task (should not spawn subagents)"
else
  pass "$ask does not spawn subagents (no Task)"
fi

# 6. canonization-criteria.sh against missing contracts.md
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
out=$(bash lib/canonical-memory/canonization-criteria.sh --working-memory "$tmpdir" 2>&1) || true
echo "$out" | grep -q "candidates: \[\]" \
  && pass "canonization-criteria.sh handles missing contracts.md" \
  || err "canonization-criteria.sh did not handle missing file: $out"

# 7. canonization-criteria.sh against synthetic single-contract → ≥1 candidate
mkdir -p "$tmpdir/.yoke"
cat > "$tmpdir/.yoke/contracts.md" <<'EOF'
# Sprint contracts

## Contract c1
- id: "c1"
- topic: "interpretation of FR-1"
- decision: "FR-1 means doing the thing once per request"
- rationale: "request-scoped per Acceptance Contract"
- cycle: 2
EOF
out=$(bash lib/canonical-memory/canonization-criteria.sh --working-memory "$tmpdir/.yoke" 2>&1) || true
if echo "$out" | grep -q "^candidates:" && echo "$out" | grep -q "id: c1"; then
  pass "canonization-criteria.sh emits ≥1 candidate from synthetic contract"
else
  err "canonization-criteria.sh did not emit expected candidate: $out"
fi
echo "$out" | grep -q "impact: low" \
  && pass "default candidate is low-impact" \
  || err "default candidate impact unexpected: $out"

# 8. Non-contradiction filter
cat > "$tmpdir/.yoke/contracts.md" <<'EOF'
## Contract c1
- topic: "FR-1"
- decision: "relax FR-1 — skip checking it for now"
- rationale: "moving fast"
- cycle: 1
EOF
out=$(bash lib/canonical-memory/canonization-criteria.sh --working-memory "$tmpdir/.yoke" 2>&1) || true
echo "$out" | grep -q "candidates: \[\]" \
  && pass "canonization-criteria.sh filters out contradictory contracts" \
  || err "canonization-criteria.sh did not filter contradictory: $out"

# 9. Performance — synthesize 100 contracts (proxy for scale)
contracts="$tmpdir/.yoke/contracts.md"
echo "# Sprint contracts" > "$contracts"
for i in $(seq 1 100); do
  cat >> "$contracts" <<EOF

## Contract c${i}
- topic: "topic ${i}"
- decision: "decision ${i}"
- rationale: "rationale ${i}"
- cycle: ${i}
EOF
done
start=$(date +%s)
bash lib/canonical-memory/canonization-criteria.sh --working-memory "$tmpdir/.yoke" > /dev/null 2>&1
end=$(date +%s)
elapsed=$((end - start))
[ "$elapsed" -lt 5 ] \
  && pass "canonization-criteria.sh runs in ${elapsed}s on 100 contracts" \
  || err "canonization-criteria.sh too slow: ${elapsed}s"

# 10-12. The propose-write.sh primitive was retired in Part 4 of the
# bedrock canonical-memory port. Impact-class routing now lives in
# skills/preserve/SKILL.md Phase 3. The remaining checks verify the
# new SKILL.md declares the routing rules. Original tests are deleted
# — propose-write.sh no longer exists.

pre="skills/preserve/SKILL.md"
grep -qE 'CI checks gate|auto-merge.*after CI|auto-merge after CI' "$pre" \
  && pass "$pre documents low-impact auto-merge after CI" \
  || err "$pre missing low-impact auto-merge documentation"

grep -qE 'veto window' "$pre" \
  && pass "$pre documents medium-impact veto window" \
  || err "$pre missing medium-impact veto window documentation"

grep -qE 'no-auto-merge|auto-merge: never|auto-merge.*never' "$pre" \
  && pass "$pre documents high/regulatory no-auto-merge" \
  || err "$pre missing high/regulatory no-auto-merge documentation"

grep -qE 'CODEOWNERS|Compliance' "$pre" \
  && pass "$pre routes regulatory writes to Compliance" \
  || err "$pre missing regulatory Compliance routing"

# Block all remaining propose-write.sh tests in this sprint by stubbing
# a no-op that always passes. (The original logic referenced a file
# that no longer exists.)
true_test() { true; }

# Skip the original propose-write.sh assertions (lines below would have
# tested the deleted primitive's flags and outputs).
if false; then
set +e
bash lib/canonical-memory/propose-write.sh > /dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] \
  && pass "propose-write.sh exits 2 on missing --candidate" \
  || err "propose-write.sh wrong exit on missing args (got $rc)"

# 11. propose-write.sh — invalid impact rejection
cat > "$tmpdir/bad-impact-candidate.yaml" <<'EOF'
- id: cBad
  impact: nonsense
  content_path: "policies/test.md"
  reason: "test bad"
  content_excerpt: "test entry"
EOF
set +e
bash lib/canonical-memory/propose-write.sh --candidate "$tmpdir/bad-impact-candidate.yaml" --dry-run > /dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 4 ] \
  && pass "propose-write.sh exits 4 on unknown impact value" \
  || err "propose-write.sh did not reject unknown impact (got $rc)"

# 12. propose-write.sh dry-run with low-impact candidate (auto-canonize-at-termination Part 6 DoD #4)
cat > "$tmpdir/low-impact-candidate.yaml" <<'EOF'
- id: cLow
  impact: low
  content_path: "divergences/cLow.md"
  reason: "test divergence pattern"
  content_excerpt: "test decision"
EOF
out=$(bash lib/canonical-memory/propose-write.sh --candidate "$tmpdir/low-impact-candidate.yaml" --repo-url "https://github.com/test/canonical" --dry-run 2>&1) || true
echo "$out" | grep -qi "would" \
  && pass "propose-write.sh dry-run produces 'would …' lines (auto-canonize at termination uses dry-run in tests)" \
  || err "propose-write.sh dry-run output unexpected: $out"
echo "$out" | grep -q "yoke-proposal" \
  && pass "propose-write.sh dry-run mentions yoke-proposal label" \
  || err "propose-write.sh missing yoke-proposal label in dry-run output"
echo "$out" | grep -q "impact-low" \
  && pass "propose-write.sh dry-run mentions impact-low label" \
  || err "propose-write.sh missing impact-low label in dry-run output"
echo "$out" | grep -qi "auto-merge" \
  && pass "propose-write.sh dry-run mentions auto-merge config" \
  || err "propose-write.sh missing auto-merge in dry-run output"
fi  # end-skip block opened earlier (Part 4 retired propose-write.sh)

# 13. /yoke:ask trace contract (Part 3): the SKILL document declares the
#     YAML trace shape that lands in .yoke/query-traces/<slug>.md. The
#     standalone query.sh path was retired; runtime trace verification
#     is exercised by tests/smoke/ask-no-clone.test.sh.
grep -qE 'mode: ask' "$ask" \
  && pass "/yoke:ask trace declares 'mode: ask' value" \
  || err "/yoke:ask trace missing 'mode: ask'"
grep -q 'entities_read' "$ask" \
  && pass "/yoke:ask trace records entities_read count" \
  || err "/yoke:ask trace missing entities_read field"
grep -q 'capped' "$ask" \
  && pass "/yoke:ask trace records capping flag" \
  || err "/yoke:ask trace missing capped flag"
grep -q 'invoker' "$ask" \
  && pass "/yoke:ask trace records invoker" \
  || err "/yoke:ask trace missing invoker"

# 14. Anti-scope: status skill still placeholder.
# Part 6 of the bedrock canonical-memory port (2026-04-25) extended
# /yoke:status with bedrock's healthcheck surface.
if grep -qE 'Read-only|read-only contract' skills/status/SKILL.md; then
  pass "skills/status/SKILL.md declares read-only contract (Part 6 extension)"
else
  err "skills/status/SKILL.md missing read-only declaration"
fi

# 15. Sprint regressions
echo "--- Regressions ---"
for sprint in 2 3 4; do
  bash "tests/smoke/sprint-${sprint}.test.sh" > "/tmp/sp${sprint}-regression.log" 2>&1 \
    && pass "Sprint-${sprint} smoke still PASS" \
    || err "Sprint-${sprint} regressed: $(tail -3 /tmp/sp${sprint}-regression.log)"
done

echo "--- Result ---"
if [ "$fail" -eq 0 ]; then
  echo "PASS"
  exit 0
else
  echo "FAIL ($fail check(s) failed)"
  exit 1
fi
