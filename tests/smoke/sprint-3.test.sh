#!/bin/bash
# tests/smoke/sprint-3.test.sh
#
# Sprint 3 smoke test — validates the Acceptance Contract phase
# artifacts (refreshed in v1.1.0 to skills-only spec phase):
#   - /yoke:acceptance-contract skill (Validator persona inline, no Task)
#   - lib/sensors/discover-from-claude-md.sh
#   - hooks/verify-acceptance.sh
#   - templates/acceptance-contract.md (with binding statement)
#
# Pre-Sprint-6: this test does NOT invoke any ralph loop. External
# `timeout` is not strictly required, but use one in CI as a precaution.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- Sprint 3 smoke ---"

# 1. /yoke:acceptance-contract SKILL.md valid
sk="skills/acceptance-contract/SKILL.md"
[ -f "$sk" ] || err "missing $sk"
awk 'BEGIN{c=0; n=0; d=0} /^---$/{c++; next} c==1 && /^name:/{n=1} c==1 && /^description:/{d=1} END{exit (n && d) ? 0 : 1}' "$sk" \
  && pass "$sk frontmatter valid" \
  || err "$sk missing name/description"

# 2. v1.1 — /yoke:acceptance-contract does NOT include Task in
#    allowed-tools (DoD #2 of runtime-only-agents-part-2).
allowed_line=$(awk '/^allowed-tools:/{print; exit}' "$sk" || true)
if [ -z "$allowed_line" ]; then
  err "$sk missing allowed-tools field"
elif echo "$allowed_line" | grep -qw "Task"; then
  err "$sk allowed-tools includes Task — Validator persona should be inline: $allowed_line"
else
  pass "$sk allowed-tools excludes Task (skill-only)"
fi

# 3. v1.1 — Validator persona embedded inline (no "Spawn agents/validator.md")
if grep -q "Spawn .agents/validator" "$sk" || grep -q "Invoke the Validator subagent" "$sk"; then
  err "$sk still references Validator subagent spawn (should be inline)"
else
  pass "$sk drops Validator-subagent-spawn references"
fi
if grep -qE "Validator persona|Your role .*persona" "$sk"; then
  pass "$sk embeds Validator persona inline"
else
  err "$sk does not declare an inline Validator persona"
fi

# 4. Pre-flight: skill aborts on missing PRD or Tech Spec
grep -q "PRD missing or unapproved" "$sk" \
  && pass "$sk handles missing PRD" \
  || err "$sk does not declare missing-PRD abort"
grep -q "Tech Spec missing or unapproved" "$sk" \
  && pass "$sk handles missing Tech Spec" \
  || err "$sk does not declare missing-Tech-Spec abort"

# 5. Trigger-3 binding prompt printed verbatim
grep -q "Trigger 3 — Acceptance Contract ratification" "$sk" \
  && pass "$sk prints Trigger-3 binding prompt" \
  || err "$sk missing Trigger-3 binding prompt"

# 6. Sensor discovery preserved (DoD #2 — sensor discovery still fires)
grep -q "lib/sensors/discover-from-claude-md.sh" "$sk" \
  && pass "$sk invokes sensor-discovery script" \
  || err "$sk does not invoke sensor-discovery script"

# 7. Acceptance Contract template has binding statement and right sections
tpl="templates/acceptance-contract.md"
grep -q "Binding statement" "$tpl"               && pass "$tpl has binding statement"               || err "$tpl missing binding statement"
grep -q "## Use cases (BDD scenarios)" "$tpl"    && pass "$tpl has BDD scenarios section"          || err "$tpl missing BDD scenarios"
grep -q "## Functional requirements" "$tpl"      && pass "$tpl has FR section"                     || err "$tpl missing FR"
grep -q "## Applicable policies" "$tpl"          && pass "$tpl has policies section"               || err "$tpl missing policies"
grep -q "### Computational" "$tpl"               && pass "$tpl has Computational sensors section" || err "$tpl missing Computational sensors"
grep -q "### Inferential" "$tpl"                 && pass "$tpl has Inferential sensors section"   || err "$tpl missing Inferential sensors"

# 8. discover-from-claude-md.sh against synthetic CLAUDE.md states
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# 8a. CLAUDE.md missing
out=$(bash lib/sensors/discover-from-claude-md.sh "$tmpdir/missing.md" 2>&1) || true
echo "$out" | grep -q "sensors: \[\]" \
  && echo "$out" | grep -q "CLAUDE.md not found" \
  && pass "discover-from-claude-md.sh handles missing file" \
  || err "discover-from-claude-md.sh did not handle missing CLAUDE.md: $out"

# 8b. CLAUDE.md present but no marked sections
cat > "$tmpdir/no-sections.md" <<'EOF'
# Project

Some random project guidance with no Yoke-recognized headings.
EOF
out=$(bash lib/sensors/discover-from-claude-md.sh "$tmpdir/no-sections.md" 2>&1) || true
echo "$out" | grep -q "sensors: \[\]" \
  && echo "$out" | grep -q "no commands discovered" \
  && pass "discover-from-claude-md.sh handles missing sections" \
  || err "discover-from-claude-md.sh did not handle missing sections: $out"

# 8c. CLAUDE.md with Testing + Linting + Build (≥3 categories)
cat > "$tmpdir/full.md" <<'EOF'
# Project

## Testing
- `npm test` — run unit tests
- `pytest tests/` — Python tests

## Linting
- `npm run lint` — eslint over src/

## Build
- `npm run build` — production build
EOF
out=$(bash lib/sensors/discover-from-claude-md.sh "$tmpdir/full.md" 2>&1) || true
testing_count=$(echo "$out" | grep -c 'category: testing' || true)
linting_count=$(echo "$out" | grep -c 'category: linting' || true)
build_count=$(echo "$out" | grep -c 'category: build' || true)
[ "$testing_count" -ge 1 ] && pass "discover finds testing sensors ($testing_count)" || err "discover missed testing sensors"
[ "$linting_count" -ge 1 ] && pass "discover finds linting sensors ($linting_count)" || err "discover missed linting sensors"
[ "$build_count"  -ge 1 ] && pass "discover finds build sensors ($build_count)"   || err "discover missed build sensors"

distinct_categories=$(echo "$out" | grep -oE 'category: [a-z]+' | sort -u | wc -l | tr -d ' ')
[ "$distinct_categories" -ge 3 ] \
  && pass "discover extracts ≥3 categories ($distinct_categories)" \
  || err "discover extracted only $distinct_categories categories"

echo "$out" | grep -q 'command: "npm test"' \
  && pass "discover extracts first backticked command" \
  || err "discover did not extract 'npm test' verbatim: $out"

# 9. verify-acceptance.sh against a synthetic Acceptance Contract
contract="$tmpdir/acceptance-contract.md"
cat > "$contract" <<'EOF'
# Acceptance Contract — test

## Sensors

### Computational
- linter: `bash -c "echo lint_ok"`
- type-check: `bash -c "echo type_ok"`
- skipme: `nonexistent-binary-xyz123 --version`
- failer: `bash -c "echo bad >&2; exit 1"`
- stdin-eater: `head -n 99`
- runs-after-stdin-eater: `bash -c "echo after_ok"`

### Inferential
EOF

out=$(bash hooks/verify-acceptance.sh "$contract" 2>&1) || true
echo "$out" | grep -q '^results:' \
  && pass "verify-acceptance.sh emits 'results:' header" \
  || err "verify-acceptance.sh did not emit results header: $out"

echo "$out" | grep -A2 '^  - sensor: "linter"' | grep -q 'status: pass' \
  && pass "verify-acceptance pass case correct" \
  || err "verify-acceptance did not report pass for linter: $out"

echo "$out" | grep -A2 '^  - sensor: "skipme"' | grep -q 'status: skip' \
  && pass "verify-acceptance skip case correct" \
  || err "verify-acceptance did not skip missing binary: $out"

echo "$out" | grep -A2 '^  - sensor: "failer"' | grep -q 'status: fail' \
  && pass "verify-acceptance fail case correct" \
  || err "verify-acceptance did not report fail: $out"

echo "$out" | grep -q '^  - sensor: "runs-after-stdin-eater"' \
  && pass "verify-acceptance isolates child stdin (regression)" \
  || err "verify-acceptance leaked parent stdin to bash -c — sensor truncation: $out"

if bash hooks/verify-acceptance.sh "$tmpdir/missing-contract.md" 2>/dev/null; then
  err "verify-acceptance did not exit non-zero on missing contract"
else
  pass "verify-acceptance exits non-zero on missing contract"
fi

# 10. Sprint-2 regression
bash tests/smoke/sprint-2.test.sh > /tmp/sp2-regression.log 2>&1 \
  && pass "Sprint-2 smoke still PASS (regression)" \
  || err "Sprint-2 regressed: $(tail -5 /tmp/sp2-regression.log)"

echo "--- Result ---"
if [ "$fail" -eq 0 ]; then
  echo "PASS"
  exit 0
else
  echo "FAIL ($fail check(s) failed)"
  exit 1
fi
