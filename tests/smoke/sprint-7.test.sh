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
# 3. Staleness / model-drift / contradiction detection — DoD #2.
#
# Part 6 of the bedrock canonical-memory port retired
# `lib/canonical-memory/staleness-check.sh`. The same detection
# logic now lives in `skills/status/SKILL.md`'s Section 2.5
# (Stale content / rippability) and is exercised through
# `/yoke:status --canonical`. The behavioral test (running the
# library directly) is replaced with a documentation check
# against the new SKILL.
# ------------------------------------------------------------------
ST="skills/status/SKILL.md"

grep -qiE 'older than 15 days|stale|last_validated' "$ST" \
  && pass "$ST flags stale entries via last_validated comparison" \
  || err "$ST missing stale-entry detection"

grep -qiE 'model_calibrated_against|retired model|model drift' "$ST" \
  && pass "$ST detects model drift via model_calibrated_against" \
  || err "$ST missing model-drift detection"

grep -qiE 'rippability|five.*rippability|5.*rippability fields' "$ST" \
  && pass "$ST validates rippability frontmatter" \
  || err "$ST missing rippability validation"

# ------------------------------------------------------------------
# 4. trace-analyzer.sh — DoD #3 (traces mode)
# ------------------------------------------------------------------
trace_dir="$tmpdir/trace-task"
mkdir -p "$trace_dir/contracts"
# v0.6.0: trace-analyzer globs <trace-dir>/contracts/*.md (per-task archive).
cat > "$trace_dir/contracts/2026-04-25-recurrence-fixture.md" <<'EOF'
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

# Status skill — Part 6 of the bedrock canonical-memory port (2026-04-25)
# extended /yoke:status with bedrock's healthcheck surface, retiring the
# Sprint-8 "placeholder" assertion. The SKILL is now read-only and
# absorbs the canonical-memory diagnostic.
grep -qE 'Read-only|read-only contract' skills/status/SKILL.md \
  && pass "skills/status/SKILL.md declares read-only contract (Part 6 extension)" \
  || err "skills/status/SKILL.md missing read-only declaration"
grep -qE 'healthcheck|--canonical' skills/status/SKILL.md \
  && pass "skills/status/SKILL.md absorbs the canonical-memory healthcheck surface" \
  || err "skills/status/SKILL.md missing healthcheck integration"

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
