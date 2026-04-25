#!/bin/bash
# tests/smoke/sprint-5.test.sh
#
# Sprint 5 smoke — Orchestrator skill (3 modes), canonization criteria,
# git-native low-impact PR path.
#
# Real-flow PR creation requires `gh` authenticated against a test repo.
# Smoke uses --dry-run to avoid network/auth dependencies.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- Sprint 5 smoke ---"

# 1. Orchestrator skill exists at the new location (PRD v0 amendment)
orch="skills/orchestrator/SKILL.md"
[ -f "$orch" ] || err "missing $orch"
[ "$(wc -l < "$orch")" -gt 50 ] && pass "$orch substantive (>50 lines)" || err "$orch looks like a placeholder"
awk 'BEGIN{c=0; n=0; d=0} /^---$/{c++; next} c==1 && /^name:/{n=1} c==1 && /^description:/{d=1} END{exit (n && d) ? 0 : 1}' "$orch" \
  && pass "$orch frontmatter valid" \
  || err "$orch missing name/description"

# 2. Three modes declared (DoD #1)
for mode in mediator runtime-coordinator canonizer; do
  if grep -qF "[orchestrator:$mode]" "$orch"; then
    pass "$orch declares $mode mode token"
  else
    err "$orch missing $mode mode declaration"
  fi
done

# 3. /yoke:canonize SKILL real (DoD #4)
sk="skills/canonize/SKILL.md"
[ -f "$sk" ] || err "missing $sk"
grep -q "canonization-criteria" "$sk" \
  && pass "$sk references canonization-criteria.sh" \
  || err "$sk does not reference canonization-criteria"
grep -q "propose-write" "$sk" \
  && pass "$sk references propose-write.sh" \
  || err "$sk does not reference propose-write"
grep -qF "[orchestrator:canonizer]" "$sk" \
  && pass "$sk declares canonizer mode" \
  || err "$sk missing canonizer mode declaration"

# 4. /yoke:ask updated for mediation (DoD #2)
ask="skills/ask/SKILL.md"
grep -q "query-trace" "$ask" \
  && pass "$ask references .yoke/query-trace.md" \
  || err "$ask does not declare query trace"
grep -qF "[orchestrator:mediator]" "$ask" \
  && pass "$ask declares mediator mode" \
  || err "$ask missing mediator mode declaration"
grep -qF -- "--trace" "$ask" \
  && pass "$ask invokes query.sh with --trace" \
  || err "$ask does not call query.sh with --trace"

# 5. canonization-criteria.sh against missing contracts.md
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
out=$(bash lib/canonical-memory/canonization-criteria.sh --working-memory "$tmpdir" 2>&1) || true
echo "$out" | grep -q "candidates: \[\]" \
  && pass "canonization-criteria.sh handles missing contracts.md" \
  || err "canonization-criteria.sh did not handle missing file: $out"

# 6. canonization-criteria.sh against synthetic single-contract → ≥1 candidate
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
  pass "canonization-criteria.sh emits ≥1 candidate from synthetic contract (DoD #4)"
else
  err "canonization-criteria.sh did not emit expected candidate: $out"
fi
echo "$out" | grep -q "impact: low" \
  && pass "default candidate is low-impact" \
  || err "default candidate impact unexpected: $out"

# 7. Non-contradiction filter (criterion 5)
cat > "$tmpdir/.yoke/contracts.md" <<'EOF'
## Contract c1
- topic: "FR-1"
- decision: "relax FR-1 — skip checking it for now"
- rationale: "moving fast"
- cycle: 1
EOF
out=$(bash lib/canonical-memory/canonization-criteria.sh --working-memory "$tmpdir/.yoke" 2>&1) || true
echo "$out" | grep -q "candidates: \[\]" \
  && pass "canonization-criteria.sh filters out contradictory contracts (criterion 5)" \
  || err "canonization-criteria.sh did not filter contradictory: $out"

# 8. Performance — synthesize 100 contracts (proxy for 1000-entry scale)
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
  && pass "canonization-criteria.sh runs in ${elapsed}s on 100 contracts (target <5s on 1000)" \
  || err "canonization-criteria.sh too slow: ${elapsed}s"

# 9. propose-write.sh — usage error
set +e
bash lib/canonical-memory/propose-write.sh > /dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] \
  && pass "propose-write.sh exits 2 on missing --candidate" \
  || err "propose-write.sh wrong exit on missing args (got $rc)"

# 10. propose-write.sh — invalid impact rejection.
# Originally checked Sprint-5 only-low scope; Sprint 6 expanded to 4 classes.
# Now verify unknown impact values are still rejected with exit 4.
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
  && pass "propose-write.sh exits 4 on unknown impact value (cross-sprint robustness)" \
  || err "propose-write.sh did not reject unknown impact (got $rc)"

# 11. propose-write.sh dry-run with low-impact candidate (DoD #5)
cat > "$tmpdir/low-impact-candidate.yaml" <<'EOF'
- id: cLow
  impact: low
  content_path: "divergences/cLow.md"
  reason: "test divergence pattern"
  content_excerpt: "test decision"
EOF
out=$(bash lib/canonical-memory/propose-write.sh --candidate "$tmpdir/low-impact-candidate.yaml" --repo-url "https://github.com/test/canonical" --dry-run 2>&1) || true
echo "$out" | grep -qi "would" \
  && pass "propose-write.sh dry-run produces 'would …' lines" \
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

# 12. query.sh --trace flag writes trace entries (DoD #2)
empty_canon="$tmpdir/empty-canon"
mkdir -p "$empty_canon"
trace_path="$tmpdir/.yoke/query-trace.md"
rm -f "$trace_path"
bash lib/canonical-memory/query.sh --trace "$trace_path" --invoker "test" "anything" "$empty_canon" > /dev/null 2>&1 || true
[ -f "$trace_path" ] \
  && pass "query.sh --trace creates the trace file" \
  || err "query.sh did not create trace file"
grep -q "mode: mediator" "$trace_path" \
  && pass "trace entry declares mediator mode" \
  || err "trace entry missing mediator mode"
grep -q "invoker: \"test\"" "$trace_path" \
  && pass "trace entry records invoker" \
  || err "trace entry missing invoker"
grep -q "matches: 0" "$trace_path" \
  && pass "trace entry records match count" \
  || err "trace entry missing match count"
grep -q "notes: \"empty-memory\"" "$trace_path" \
  && pass "trace entry notes empty-memory state" \
  || err "trace entry missing empty-memory note"

# 13. agents/orchestrator.md deleted (Sprint 5 moves it to skills/orchestrator/)
[ ! -f "agents/orchestrator.md" ] \
  && pass "agents/orchestrator.md deleted (moved to skills/orchestrator/ per PRD v0 amendment)" \
  || err "agents/orchestrator.md still exists — should be deleted in Sprint 5"

# 14. Anti-scope: status skill still placeholder. drift-sense advanced
# in Sprint 7, so it is dropped here per deferred-anti-scope.
if grep -q "placeholder" skills/status/SKILL.md; then
  pass "skills/status/SKILL.md still placeholder (advanced only in Sprint 8)"
else
  err "skills/status/SKILL.md was modified — anti-scope violation"
fi

# 15–16. Anti-scope assertions on items advanced by Sprint 6
# (check-hard-bounds.sh, escalate.sh, graph.sh) dropped per
# deferred-anti-scope design rule.
pass "Sprint-5 Sprint-6-territory anti-scope deferred to per-sprint smokes"

# 17. Sprint regressions
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
