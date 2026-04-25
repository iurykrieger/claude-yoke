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

# 3. /yoke:canonize — manual escape hatch (DoD #4 of Part 6).
sk="skills/canonize/SKILL.md"
[ -f "$sk" ] || err "missing $sk"

allowed_line=$(awk '/^allowed-tools:/{print; exit}' "$sk" || true)
echo "$allowed_line" | grep -qw "Task" \
  && pass "$sk allowed-tools includes Task (spawns Orchestrator subagent)" \
  || err "$sk missing Task in allowed-tools"

grep -qE "escape hatch|Manual canonization|Never auto-runs" "$sk" \
  && pass "$sk positions itself as a manual escape hatch" \
  || err "$sk does not position itself as an escape hatch"

grep -q "agents/orchestrator.md" "$sk" \
  && pass "$sk spawns the Orchestrator subagent" \
  || err "$sk does not spawn the Orchestrator subagent"

grep -qE "mode=canonize|canonize mode" "$sk" \
  && pass "$sk invokes canonize mode" \
  || err "$sk does not invoke canonize mode"

# 4. /yoke:implement issues auto-canonize handoff at loop termination
#    (DoD #4 of Part 6 — auto-canonize fires from /yoke:implement).
imp="skills/implement/SKILL.md"
grep -q "mode=canonize" "$imp" \
  && pass "$imp issues canonize handoff at loop termination (auto-canonize)" \
  || err "$imp missing auto-canonize termination handoff"

grep -qE "Termination handoff|termination canonization handoff|canonize handoff" "$imp" \
  && pass "$imp documents termination canonization handoff" \
  || err "$imp missing termination handoff documentation"

# 5. /yoke:ask — thin direct-call canonical-memory query
ask="skills/ask/SKILL.md"
grep -q "query-trace" "$ask" \
  && pass "$ask references .yoke/query-trace.md" \
  || err "$ask does not declare query trace"
grep -qF -- "--trace" "$ask" \
  && pass "$ask invokes query.sh with --trace" \
  || err "$ask does not call query.sh with --trace"

ask_allowed=$(awk '/^allowed-tools:/{print; exit}' "$ask" || true)
if echo "$ask_allowed" | grep -qw "Task"; then
  err "$ask allowed-tools includes Task (should be thin direct-call skill)"
else
  pass "$ask is a thin direct-call skill (no Task)"
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

# 10. propose-write.sh — usage error
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

# 13. query.sh --trace flag writes trace entries
empty_canon="$tmpdir/empty-canon"
mkdir -p "$empty_canon"
trace_path="$tmpdir/.yoke/query-trace.md"
rm -f "$trace_path"
bash lib/canonical-memory/query.sh --trace "$trace_path" --invoker "test" "anything" "$empty_canon" > /dev/null 2>&1 || true
[ -f "$trace_path" ] \
  && pass "query.sh --trace creates the trace file" \
  || err "query.sh did not create trace file"
grep -qE "mode: (mediator|ask)" "$trace_path" \
  && pass "trace entry declares query mode" \
  || err "trace entry missing query mode"
grep -q "invoker: \"test\"" "$trace_path" \
  && pass "trace entry records invoker" \
  || err "trace entry missing invoker"
grep -q "matches: 0" "$trace_path" \
  && pass "trace entry records match count" \
  || err "trace entry missing match count"
grep -q "notes: \"empty-memory\"" "$trace_path" \
  && pass "trace entry notes empty-memory state" \
  || err "trace entry missing empty-memory note"

# 14. Anti-scope: status skill still placeholder.
if grep -q "placeholder" skills/status/SKILL.md; then
  pass "skills/status/SKILL.md still placeholder (advanced only in Sprint 8)"
else
  err "skills/status/SKILL.md was modified — anti-scope violation"
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
