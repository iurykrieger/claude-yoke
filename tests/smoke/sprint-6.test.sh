#!/bin/bash
# tests/smoke/sprint-6.test.sh
#
# Sprint 6 smoke — hard bounds, 5 distinct trigger schemas, full Model C
# (medium veto window + high sync + regulatory CODEOWNERS), progressive
# disclosure subgraph queries.
#
# Real-flow PR creation requires `gh` authenticated against a test repo;
# smoke uses --dry-run for propose-write.sh paths.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- Sprint 6 smoke ---"

# ------------------------------------------------------------------
# 1. Hard bounds — check-hard-bounds.sh enforcement (DoD #1)
# ------------------------------------------------------------------
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.yoke"
mkdir -p "$tmpdir/.yoke/runtime/.snapshots"
echo "yoke_version: 0.6.0" > "$tmpdir/.yoke/config.yaml"

# 1a. No state files → no bound hit (exit 0)
pushd "$tmpdir" > /dev/null
set +e
bash "$PLUGIN_ROOT/hooks/check-hard-bounds.sh" > /dev/null 2>&1
rc=$?
set -e
popd > /dev/null
[ "$rc" -eq 0 ] \
  && pass "check-hard-bounds.sh exits 0 with no state (loop may continue)" \
  || err "check-hard-bounds.sh wrong exit on empty state (got $rc)"

# 1b. Cycle limit hit → exit 10
echo "8" > "$tmpdir/.yoke/runtime/.cycle-counter"
pushd "$tmpdir" > /dev/null
set +e
bash "$PLUGIN_ROOT/hooks/check-hard-bounds.sh" > /dev/null 2>&1
rc=$?
set -e
popd > /dev/null
[ "$rc" -eq 10 ] \
  && pass "check-hard-bounds.sh exits 10 when cycle limit reached" \
  || err "check-hard-bounds.sh wrong exit on cycle limit (got $rc)"

# 1c. Per-project override is honored (DoD #1)
cat > "$tmpdir/.yoke/config.yaml" <<'EOF'
yoke_version: 0.6.0
overrides:
  hard_bounds:
    cycles_max: 100
    timeout_seconds: 14400
    token_budget: 200000
EOF
echo "8" > "$tmpdir/.yoke/runtime/.cycle-counter"
pushd "$tmpdir" > /dev/null
set +e
bash "$PLUGIN_ROOT/hooks/check-hard-bounds.sh" > /dev/null 2>&1
rc=$?
set -e
popd > /dev/null
[ "$rc" -eq 0 ] \
  && pass "check-hard-bounds.sh honors per-project cycle override (cycles_max=100)" \
  || err "check-hard-bounds.sh did not honor override (got $rc with cycles=8/100)"

# 1d. Timeout limit hit → exit 10 (set start time far in past, default timeout)
echo "yoke_version: 0.6.0" > "$tmpdir/.yoke/config.yaml"
echo "1" > "$tmpdir/.yoke/runtime/.cycle-counter"
echo "$(($(date +%s) - 99999))" > "$tmpdir/.yoke/runtime/.loop-start"
pushd "$tmpdir" > /dev/null
set +e
bash "$PLUGIN_ROOT/hooks/check-hard-bounds.sh" > /dev/null 2>&1
rc=$?
set -e
popd > /dev/null
[ "$rc" -eq 10 ] \
  && pass "check-hard-bounds.sh exits 10 when timeout reached" \
  || err "check-hard-bounds.sh wrong exit on timeout (got $rc)"

# Reset state for subsequent tests
rm -f "$tmpdir/.yoke/runtime/.cycle-counter" "$tmpdir/.yoke/runtime/.loop-start" "$tmpdir/.yoke/runtime/.token-budget-used"

# ------------------------------------------------------------------
# 2. Trigger-4 escalation packet (DoD #2)
# ------------------------------------------------------------------

# 2a. escalate.sh requires --reason
set +e
bash "$PLUGIN_ROOT/lib/ralph-loop/escalate.sh" > /dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] \
  && pass "escalate.sh exits 2 without --reason" \
  || err "escalate.sh wrong exit without reason (got $rc)"

# 2b. escalate.sh emits structured packet for divergence
pushd "$tmpdir" > /dev/null
out=$(bash "$PLUGIN_ROOT/lib/ralph-loop/escalate.sh" --reason divergence --category quality-policies-broken --unresolved-contract "c1" 2>&1) || true
popd > /dev/null

echo "$out" | grep -qE "^trigger:[[:space:]]*4" \
  && pass "escalate.sh emits 'trigger: 4' header" \
  || err "escalate.sh missing trigger header: $out"
echo "$out" | grep -qE "^reason:[[:space:]]*divergence" \
  && pass "escalate.sh emits reason field" \
  || err "escalate.sh missing reason: $out"
echo "$out" | grep -qE "^divergence_category:[[:space:]]*quality-policies-broken" \
  && pass "escalate.sh emits divergence_category from --category" \
  || err "escalate.sh missing divergence_category: $out"
echo "$out" | grep -qE "unresolved_sprint_contract:[[:space:]]*\"c1\"" \
  && pass "escalate.sh emits unresolved_sprint_contract" \
  || err "escalate.sh missing unresolved contract: $out"

# Packet file persists
[ -f "$tmpdir/.yoke/runtime/.trigger4-packet.yaml" ] \
  && pass "escalate.sh writes packet to .yoke/runtime/.trigger4-packet.yaml" \
  || err "escalate.sh did not persist packet file"

# 2c. escalate.sh hard-bound packet includes state (cycles, timeout, etc.)
pushd "$tmpdir" > /dev/null
out=$(bash "$PLUGIN_ROOT/lib/ralph-loop/escalate.sh" --reason hard-bound --category cycles --cycles 8 --cycles-max 8 --elapsed 3600 --timeout 14400 --tokens 0 --token-budget 200000 2>&1) || true
popd > /dev/null
echo "$out" | grep -qE "divergence_category:[[:space:]]*hard-bound-cycles" \
  && pass "escalate.sh hard-bound packet has divergence_category=hard-bound-cycles" \
  || err "escalate.sh hard-bound divergence_category wrong: $out"
echo "$out" | grep -qE "cycles:[[:space:]]*8" \
  && pass "escalate.sh hard-bound packet includes cycle state" \
  || err "escalate.sh missing cycle state: $out"

# ------------------------------------------------------------------
# 3. Five distinct trigger schemas (DoD #3) — verify pairwise diff
# ------------------------------------------------------------------
# Each trigger emits a distinct shape:
#   T1 (PRD)              — declared in skills/discover/SKILL.md
#   T2 (Tech Spec)        — declared in skills/tech-spec/SKILL.md
#   T3 (Acceptance)       — declared in skills/acceptance-contract/SKILL.md
#   T4 (Divergence)       — emitted by lib/ralph-loop/escalate.sh
#   T5 (Canonization)     — emitted as PR by propose-write.sh
#
# We extract each trigger's signature lines and verify all are distinct.
trigger_schemas=$(mktemp)
{
  echo "T1: $(grep -oE 'Trigger 1[^\.]*' skills/discover/SKILL.md | head -1)"
  echo "T2: $(grep -oE 'Trigger 2[^\.]*' skills/tech-spec/SKILL.md | head -1)"
  echo "T3: $(grep -oE 'Trigger 3[^\.]*' skills/acceptance-contract/SKILL.md | head -1)"
  echo "T4: $(grep -oE 'Trigger-4 packet|trigger: 4' lib/ralph-loop/escalate.sh | head -1)"
  echo "T5: $(grep -oE 'yoke-proposal' lib/canonical-memory/propose-write.sh | head -1)"
} > "$trigger_schemas"

distinct_count=$(sort -u "$trigger_schemas" | wc -l | tr -d ' ')
[ "$distinct_count" -eq 5 ] \
  && pass "all 5 trigger schemas are distinct (5/5 unique signatures)" \
  || err "trigger schemas not all distinct ($distinct_count/5): $(cat "$trigger_schemas")"

rm -f "$trigger_schemas"

# Each trigger's expected option set is present in its respective skill
grep -qF "approve" skills/discover/SKILL.md && grep -qF "restart" skills/discover/SKILL.md \
  && pass "Trigger-1 schema has 'approve' and 'restart' options" \
  || err "Trigger-1 schema incomplete"
grep -qF "back to PRD" skills/tech-spec/SKILL.md \
  && pass "Trigger-2 schema has 'back to PRD' option" \
  || err "Trigger-2 schema missing 'back to PRD'"
grep -qF "ratify" skills/acceptance-contract/SKILL.md && grep -qF "back to Tech Spec" skills/acceptance-contract/SKILL.md \
  && pass "Trigger-3 schema has 'ratify' and 'back to Tech Spec' options" \
  || err "Trigger-3 schema incomplete"

# ------------------------------------------------------------------
# 4. Medium-impact veto window (DoD #4)
# ------------------------------------------------------------------
cat > "$tmpdir/medium-candidate.yaml" <<'EOF'
- id: cMed
  impact: medium
  content_path: "templates/foo.md"
  reason: "template refinement"
  content_excerpt: "test medium"
EOF

# Default 24h
out=$(bash lib/canonical-memory/propose-write.sh --candidate "$tmpdir/medium-candidate.yaml" --repo-url "https://github.com/test/canonical" --dry-run 2>&1) || true
echo "$out" | grep -q "impact-medium" \
  && pass "propose-write.sh applies impact-medium label for medium impact" \
  || err "propose-write.sh missing impact-medium label: $out"
echo "$out" | grep -qE "veto window 24h" \
  && pass "propose-write.sh medium-impact uses default 24h veto window" \
  || err "propose-write.sh medium veto window not 24h: $out"
echo "$out" | grep -qE "would post veto-window comment" \
  && pass "propose-write.sh medium-impact posts veto-window comment" \
  || err "propose-write.sh missing veto-window comment: $out"

# Override veto window via config
cat > "$tmpdir/.yoke/config.yaml" <<'EOF'
yoke_version: 0.6.0
canonical_memory:
  url: "https://github.com/test/canonical"
overrides:
  model_c:
    veto_window_hours: 48
EOF
pushd "$tmpdir" > /dev/null
out=$(bash "$PLUGIN_ROOT/lib/canonical-memory/propose-write.sh" --candidate "$tmpdir/medium-candidate.yaml" --dry-run 2>&1) || true
popd > /dev/null
echo "$out" | grep -qE "veto window 48h" \
  && pass "propose-write.sh medium-impact honors veto_window_hours override (48h)" \
  || err "propose-write.sh did not honor veto-window override: $out"

# ------------------------------------------------------------------
# 5. High-impact and regulatory paths (DoD #5)
# ------------------------------------------------------------------
cat > "$tmpdir/high-candidate.yaml" <<'EOF'
- id: cHigh
  impact: high
  content_path: "policies/foo.md"
  reason: "new MUST policy"
  content_excerpt: "test high"
EOF

out=$(bash lib/canonical-memory/propose-write.sh --candidate "$tmpdir/high-candidate.yaml" --repo-url "https://github.com/test/canonical" --dry-run 2>&1) || true
echo "$out" | grep -q "impact-high" \
  && pass "propose-write.sh applies impact-high label for high impact" \
  || err "propose-write.sh missing impact-high label"
echo "$out" | grep -qE "auto-merge: never" \
  && pass "propose-write.sh high-impact uses auto-merge: never" \
  || err "propose-write.sh high impact missing auto-merge: never: $out"

cat > "$tmpdir/regulatory-candidate.yaml" <<'EOF'
- id: cReg
  impact: regulatory
  content_path: "policies/regulatory/lgpd-art-46.md"
  reason: "LGPD compliance"
  content_excerpt: "test regulatory"
EOF
out=$(bash lib/canonical-memory/propose-write.sh --candidate "$tmpdir/regulatory-candidate.yaml" --repo-url "https://github.com/test/canonical" --dry-run 2>&1) || true
echo "$out" | grep -q "impact-regulatory" \
  && pass "propose-write.sh applies impact-regulatory label" \
  || err "propose-write.sh missing impact-regulatory label"
echo "$out" | grep -qE "Compliance.*CODEOWNERS|CODEOWNERS.*Compliance" \
  && pass "propose-write.sh regulatory-impact mentions CODEOWNERS routing" \
  || err "propose-write.sh missing CODEOWNERS note: $out"

# Unknown impact still rejected (exit 4)
cat > "$tmpdir/bad-candidate.yaml" <<'EOF'
- id: cBad
  impact: weird
  content_path: "x.md"
  reason: "test"
  content_excerpt: "x"
EOF
set +e
bash lib/canonical-memory/propose-write.sh --candidate "$tmpdir/bad-candidate.yaml" --dry-run > /dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 4 ] \
  && pass "propose-write.sh exits 4 on unknown impact value" \
  || err "propose-write.sh did not reject unknown impact (got $rc)"

# ------------------------------------------------------------------
# 6. Progressive disclosure subgraph (DoD #6)
# ------------------------------------------------------------------
canon_repo="$tmpdir/test-canon"
mkdir -p "$canon_repo/policies"

# Seed a small graph: A → B → C, D unrelated
cat > "$canon_repo/policies/a.md" <<'EOF'
---
ratified_at: 2026-01-01
impact_level: low
depends_on: ["policies/b.md"]
---
# A
EOF
cat > "$canon_repo/policies/b.md" <<'EOF'
---
ratified_at: 2026-01-01
impact_level: low
depends_on: ["policies/c.md"]
---
# B
EOF
cat > "$canon_repo/policies/c.md" <<'EOF'
---
ratified_at: 2026-01-01
impact_level: low
depends_on: []
---
# C
EOF
cat > "$canon_repo/policies/d.md" <<'EOF'
---
ratified_at: 2026-01-01
impact_level: low
---
# D unrelated to A
EOF

# 6a. graph.sh list-edges on A
out=$(bash lib/canonical-memory/graph.sh list-edges "$canon_repo" "policies/a.md" 2>&1) || true
echo "$out" | grep -q "depends_on:policies/b.md" \
  && pass "graph.sh list-edges extracts depends_on" \
  || err "graph.sh list-edges did not extract depends_on: $out"

# 6b. graph.sh subgraph traversal — depth 2 reaches C from A
out=$(bash lib/canonical-memory/graph.sh subgraph "$canon_repo" "policies/a.md" --depth 2 2>&1) || true
echo "$out" | grep -q "policies/a.md" \
  && pass "graph.sh subgraph includes seed (a.md)" \
  || err "graph.sh missing seed in subgraph: $out"
echo "$out" | grep -q "policies/b.md" \
  && pass "graph.sh subgraph reaches B from A (1 hop)" \
  || err "graph.sh did not reach b.md: $out"
echo "$out" | grep -q "policies/c.md" \
  && pass "graph.sh subgraph reaches C from A (2 hops)" \
  || err "graph.sh did not reach c.md: $out"
echo "$out" | grep -q "policies/d.md" \
  && err "graph.sh subgraph included d.md (should be unrelated)" \
  || pass "graph.sh subgraph correctly excludes unrelated d.md"

# 6c. query.sh --subgraph-depth N produces subgraph output.
# Use a query term unique to a.md so the seed-from-first-match is predictable.
echo "unique-seed-token-XYZ-a-only" >> "$canon_repo/policies/a.md"
out=$(bash lib/canonical-memory/query.sh --subgraph-depth 2 "unique-seed-token-XYZ-a-only" "$canon_repo" 2>&1) || true
# Subgraph from a.md (depth 2): a → b → c
if echo "$out" | grep -q "policies/a.md" && echo "$out" | grep -q "policies/b.md" && echo "$out" | grep -q "policies/c.md"; then
  pass "query.sh --subgraph-depth returns subgraph from seed (a, b, c reached)"
else
  err "query.sh subgraph mode did not return expected subgraph: $out"
fi

# 6d. Performance — synthesize 100-entry repo and verify subgraph query <2s
big_repo="$tmpdir/big-canon"
mkdir -p "$big_repo/policies"
for i in $(seq 1 100); do
  cat > "$big_repo/policies/entry${i}.md" <<EOF
---
ratified_at: 2026-01-01
impact_level: low
depends_on: []
---
# Entry ${i}
test content with token-${i}
EOF
done
start=$(date +%s)
bash lib/canonical-memory/query.sh --subgraph-depth 2 "token-50" "$big_repo" > /dev/null 2>&1
end=$(date +%s)
elapsed=$((end - start))
[ "$elapsed" -lt 2 ] \
  && pass "query.sh --subgraph-depth completes in ${elapsed}s on 100 entries (target <2s on 1000)" \
  || err "query.sh subgraph too slow on 100 entries: ${elapsed}s"

# ------------------------------------------------------------------
# 7. Orchestrator skill declares impact-classification rules (DoD #7 craftsmanship)
# ------------------------------------------------------------------
grep -qF "Impact classification rules" agents/orchestrator.md \
  && pass "agents/orchestrator.md documents impact-classification rules (craftsmanship gate)" \
  || err "Orchestrator subagent missing impact-classification rules"

# Each impact-class token must appear in the Orchestrator subagent (multi-line table).
all_classes=true
for cls in regulatory high medium low; do
  if ! grep -q "\`${cls}\`" agents/orchestrator.md; then
    all_classes=false
  fi
done
$all_classes \
  && pass "Orchestrator subagent enumerates all 4 impact classes (regulatory, high, medium, low)" \
  || err "Orchestrator subagent missing one or more impact classes"

# Architecture doc has Model C table
grep -qF "Model C" docs/architecture.md \
  && pass "docs/architecture.md has Model C section" \
  || err "docs/architecture.md missing Model C section"
grep -qF "CODEOWNERS" docs/canonical-memory-setup.md \
  && pass "docs/canonical-memory-setup.md documents CODEOWNERS for regulatory routing" \
  || err "docs/canonical-memory-setup.md missing CODEOWNERS section"

# ------------------------------------------------------------------
# 8. Anti-scope: status still placeholder. drift-sense advanced in
# Sprint 7, so it is dropped here per deferred-anti-scope rule.
# ------------------------------------------------------------------
if grep -q "placeholder" skills/status/SKILL.md; then
  pass "skills/status/SKILL.md still placeholder (Sprint 8 territory)"
else
  err "skills/status/SKILL.md was modified — anti-scope violation"
fi

# ------------------------------------------------------------------
# 9. Sprint regressions
# ------------------------------------------------------------------
echo "--- Regressions ---"
for sprint in 2 3 4 5; do
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
