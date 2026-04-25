#!/bin/bash
# tests/smoke/sprint-7.test.sh
#
# Sprint 7 smoke — Phase 6 drift sensing across canonical memory and
# historical traces. Workflow YAML structure verified statically (cron
# job + permissions + idempotent flow). False-positive rate target
# checked by injecting clean baseline + synthetic stale items and
# computing rate.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- Sprint 7 smoke ---"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# ------------------------------------------------------------------
# 1. /yoke:drift-sense skill is real (placeholder gone)
# ------------------------------------------------------------------
sk="skills/drift-sense/SKILL.md"
[ -f "$sk" ] || err "missing $sk"
[ "$(wc -l < "$sk")" -gt 80 ] \
  && pass "$sk substantive (>80 lines)" \
  || err "$sk looks like a placeholder"
awk 'BEGIN{c=0; n=0; d=0} /^---$/{c++; next} c==1 && /^name:/{n=1} c==1 && /^description:/{d=1} END{exit (n && d) ? 0 : 1}' "$sk" \
  && pass "$sk frontmatter valid" \
  || err "$sk missing name/description"

# 2. All three modes documented (DoD #1, #2, #3)
for mode in codebase canonical-memory traces; do
  if grep -qF -- "--target $mode" "$sk" || grep -qF -- "\`--target $mode\`" "$sk"; then
    pass "$sk documents '--target $mode' mode"
  else
    err "$sk missing '--target $mode' mode"
  fi
done

# ------------------------------------------------------------------
# 3. staleness-check.sh — DoD #2 (canonical-memory mode)
# ------------------------------------------------------------------
canon="$tmpdir/canon"
mkdir -p "$canon/policies"

# Fresh entry: should NOT be flagged
recent_iso=$(date -u +%Y-%m-%d)
cat > "$canon/policies/fresh.md" <<EOF
---
ratified_at: ${recent_iso}
model_calibrated_against: claude-opus-4-7
last_validated: ${recent_iso}
traceability: "test"
impact_level: low
depends_on: []
supersedes: []
applies_to: []
contradicts_with: []
---
# fresh
recent entry
EOF

# Stale entry: last_validated > 30 days ago
old_iso="2026-01-01"
cat > "$canon/policies/stale.md" <<EOF
---
ratified_at: 2026-01-01
model_calibrated_against: claude-opus-4-7
last_validated: ${old_iso}
traceability: "test"
impact_level: low
depends_on: []
supersedes: []
applies_to: []
contradicts_with: []
---
# stale
old entry
EOF

# Model-drift entry: calibrated against a different model
cat > "$canon/policies/old-model.md" <<EOF
---
ratified_at: ${recent_iso}
model_calibrated_against: claude-sonnet-3
last_validated: ${recent_iso}
traceability: "test"
impact_level: low
depends_on: []
supersedes: []
applies_to: []
contradicts_with: []
---
# old-model
calibrated old
EOF

# Contradiction entry: contradicts_with → live entry
cat > "$canon/policies/contradiction-source.md" <<EOF
---
ratified_at: ${recent_iso}
model_calibrated_against: claude-opus-4-7
last_validated: ${recent_iso}
traceability: "test"
impact_level: low
depends_on: []
supersedes: []
applies_to: []
contradicts_with: ["policies/contradiction-target.md"]
---
# contradiction-source
EOF
cat > "$canon/policies/contradiction-target.md" <<EOF
---
ratified_at: ${recent_iso}
model_calibrated_against: claude-opus-4-7
last_validated: ${recent_iso}
traceability: "test"
impact_level: low
depends_on: []
supersedes: []
applies_to: []
contradicts_with: []
---
# contradiction-target
EOF

# Run staleness-check
out=$(bash lib/canonical-memory/staleness-check.sh --repo "$canon" --current-model claude-opus-4-7 --max-days 30 2>&1) || true

echo "$out" | grep -q "kind: stale" \
  && pass "staleness-check.sh detects stale entry (last_validated > max-days)" \
  || err "staleness-check did not detect stale entry: $out"
echo "$out" | grep -q "kind: model-drift" \
  && pass "staleness-check.sh detects model drift (calibrated ≠ current)" \
  || err "staleness-check did not detect model drift: $out"
echo "$out" | grep -q "kind: contradiction" \
  && pass "staleness-check.sh detects live contradiction" \
  || err "staleness-check did not detect contradiction: $out"

# Fresh entry should NOT appear in findings
fresh_count=$(echo "$out" | grep -c 'location: "policies/fresh.md"' || true)
[ "$fresh_count" -eq 0 ] \
  && pass "staleness-check.sh does NOT flag fresh, well-aligned entry (no false positive)" \
  || err "staleness-check produced false positive on fresh entry: $out"

# False-positive rate: of 4 entries, only 3 should be flagged (1 fresh = clean)
# Acceptable rate: 0% on synthetic test (target: <20%)
total_findings=$(echo "$out" | grep -c '^  - target: canonical-memory' || true)
expected_findings=3  # stale, model-drift, contradiction (live)
if [ "$total_findings" -ge "$expected_findings" ] && [ "$total_findings" -le $((expected_findings + 1)) ]; then
  pass "staleness-check.sh false-positive rate within target (<20%): $total_findings findings on synthetic input"
else
  err "staleness-check.sh finding count off ($total_findings, expected ~$expected_findings): $out"
fi

# ------------------------------------------------------------------
# 4. trace-analyzer.sh — DoD #3 (traces mode)
# ------------------------------------------------------------------
trace_dir="$tmpdir/trace-task"
mkdir -p "$trace_dir"
cat > "$trace_dir/contracts.md" <<'EOF'
# Sprint contracts

## Contract c1
- topic: "recurring-pattern-XYZ"
- decision: "x"
- rationale: "y"
- cycle: 1

## Contract c2
- topic: "recurring-pattern-XYZ"
- decision: "x"
- rationale: "y"
- cycle: 2

## Contract c3
- topic: "recurring-pattern-XYZ"
- decision: "x"
- rationale: "y"
- cycle: 3

## Contract c4
- topic: "one-off-thing"
- decision: "y"
- rationale: "z"
- cycle: 1
EOF

# Empty canonical (no entries match the recurring topic)
empty_canon="$tmpdir/empty-canon"
mkdir -p "$empty_canon"

out=$(bash lib/canonical-memory/trace-analyzer.sh --canonical "$empty_canon" --trace-dir "$trace_dir" --min-recurrence 3 2>&1) || true
echo "$out" | grep -q "kind: uncanonized-recurrence" \
  && pass "trace-analyzer.sh detects recurring topic ≥ min-recurrence" \
  || err "trace-analyzer did not detect recurrence: $out"
echo "$out" | grep -q "recurring-pattern-XYZ" \
  && pass "trace-analyzer.sh emits topic in finding location" \
  || err "trace-analyzer missing topic in finding: $out"

# One-off topic should NOT be flagged (count < min-recurrence=3)
echo "$out" | grep -q "one-off-thing" \
  && err "trace-analyzer flagged one-off topic (false positive)" \
  || pass "trace-analyzer correctly skips one-off topics"

# Already-canonized topic should NOT be flagged
populated_canon="$tmpdir/populated-canon"
mkdir -p "$populated_canon/divergences"
cat > "$populated_canon/divergences/recurring-pattern-XYZ.md" <<'EOF'
---
ratified_at: 2026-01-01
impact_level: low
---
# recurring-pattern-XYZ
already canonized — should not be flagged
EOF

out=$(bash lib/canonical-memory/trace-analyzer.sh --canonical "$populated_canon" --trace-dir "$trace_dir" --min-recurrence 3 2>&1) || true
echo "$out" | grep -q "kind: uncanonized-recurrence" \
  && err "trace-analyzer flagged already-canonized topic (false positive)" \
  || pass "trace-analyzer correctly skips already-canonized topics"

# ------------------------------------------------------------------
# 5. GitHub Actions workflow — DoD #4
# ------------------------------------------------------------------
wf=".github/workflows/yoke-drift-sense.yml"
[ -f "$wf" ] || err "missing $wf"

# Cron schedule daily
grep -qE "cron:[[:space:]]*\"0 6 \\* \\* \\*\"" "$wf" \
  && pass "$wf runs daily (cron 0 6 * * *)" \
  || err "$wf cron schedule unexpected"

# Permissions
grep -qE "issues:[[:space:]]*write" "$wf" \
  && pass "$wf declares issues:write permission" \
  || err "$wf missing issues:write permission"

# Idempotency check (SHA + last-signature comparison)
grep -q "drift-sense-last-signature" "$wf" \
  && pass "$wf is idempotent (compares findings signature)" \
  || err "$wf does not compare last-run signature (not idempotent)"

# Calls staleness-check and trace-analyzer scripts
grep -q "staleness-check.sh" "$wf" \
  && pass "$wf invokes staleness-check.sh" \
  || err "$wf missing staleness-check call"
grep -q "trace-analyzer.sh" "$wf" \
  && pass "$wf invokes trace-analyzer.sh" \
  || err "$wf missing trace-analyzer call"

# Posts to GitHub issue (gh issue create)
grep -q "gh issue create" "$wf" \
  && pass "$wf posts findings to GitHub issue" \
  || err "$wf does not create GitHub issue"

# yoke-drift-sense label
grep -q "yoke-drift-sense" "$wf" \
  && pass "$wf applies yoke-drift-sense label" \
  || err "$wf missing yoke-drift-sense label"

# ------------------------------------------------------------------
# 6. Scheduling-strategy doc — DoD #5
# ------------------------------------------------------------------
doc="docs/scheduling-strategy.md"
[ -f "$doc" ] || err "missing $doc"
grep -qF "GitHub Actions" "$doc" \
  && pass "$doc records GitHub Actions decision" \
  || err "$doc missing GitHub Actions decision"
grep -qE "cron|daemon" "$doc" \
  && pass "$doc documents fallback backends (cron / daemon)" \
  || err "$doc missing fallback notes"
grep -qF "GITHUB_TOKEN" "$doc" \
  && pass "$doc has credentials walkthrough" \
  || err "$doc missing credentials walkthrough"
grep -qF "yoke-drift-sense" "$doc" \
  && pass "$doc mentions yoke-drift-sense issue label setup" \
  || err "$doc missing label setup"

# ------------------------------------------------------------------
# 7. Anti-scope: no auto-merge of drift-sense propositions; ML detection absent
# ------------------------------------------------------------------
grep -qF "no auto-merging" "$sk" || grep -qF "no auto-merge" "$sk" || grep -qF "Do NOT auto-merge" "$sk" \
  && pass "drift-sense skill declares no auto-merge anti-pattern" \
  || err "drift-sense skill missing auto-merge anti-pattern"

# Status skill still placeholder (Sprint 8 territory)
grep -q "placeholder" skills/status/SKILL.md \
  && pass "skills/status/SKILL.md still placeholder (Sprint 8 territory)" \
  || err "status skill was modified — anti-scope violation"

# ------------------------------------------------------------------
# 8. Sprint regressions
# ------------------------------------------------------------------
echo "--- Regressions ---"
for sprint in 2 3 4 5 6; do
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
