#!/bin/bash
# tests/smoke/sprint-3.test.sh
#
# Sprint 3 smoke test — validates the Acceptance Contract phase artifacts:
#   - Validator subagent
#   - /yoke:acceptance-contract skill
#   - lib/sensors/discover-from-claude-md.sh
#   - hooks/verify-acceptance.sh
#   - templates/acceptance-contract.md (with binding statement)
#
# Pre-Sprint-6: this test does NOT invoke any ralph loop. External `timeout`
# is therefore not strictly required, but use one in CI as a precaution.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- Sprint 3 smoke ---"

# 1. Validator subagent file present and substantive
val="agents/validator.md"
[ -f "$val" ] || err "missing $val"
[ "$(wc -l < "$val")" -gt 50 ] \
  && pass "$val substantive (>50 lines)" \
  || err "$val looks like a placeholder"

# 2. /yoke:acceptance-contract SKILL.md valid
sk="skills/acceptance-contract/SKILL.md"
[ -f "$sk" ] || err "missing $sk"
awk 'BEGIN{c=0; n=0; d=0} /^---$/{c++; next} c==1 && /^name:/{n=1} c==1 && /^description:/{d=1} END{exit (n && d) ? 0 : 1}' "$sk" \
  && pass "$sk frontmatter valid" \
  || err "$sk missing name/description"

# Skill aborts on missing PRD or Tech Spec — verifiable by looking for the abort messages
grep -q "PRD missing or unapproved" "$sk" \
  && pass "$sk handles missing PRD" \
  || err "$sk does not declare missing-PRD abort"
grep -q "Tech Spec missing or unapproved" "$sk" \
  && pass "$sk handles missing Tech Spec" \
  || err "$sk does not declare missing-Tech-Spec abort"

# 3. Acceptance Contract template has binding statement and the right sections
tpl="templates/acceptance-contract.md"
grep -q "Binding statement" "$tpl"               && pass "$tpl has binding statement"               || err "$tpl missing binding statement"
grep -q "## Use cases (BDD scenarios)" "$tpl"    && pass "$tpl has BDD scenarios section"          || err "$tpl missing BDD scenarios"
grep -q "## Functional requirements" "$tpl"      && pass "$tpl has FR section"                     || err "$tpl missing FR"
grep -q "## Applicable policies" "$tpl"          && pass "$tpl has policies section"               || err "$tpl missing policies"
grep -q "### Computational" "$tpl"               && pass "$tpl has Computational sensors section" || err "$tpl missing Computational sensors"
grep -q "### Inferential" "$tpl"                 && pass "$tpl has Inferential sensors section"   || err "$tpl missing Inferential sensors"

# 4. discover-from-claude-md.sh against synthetic CLAUDE.md states
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# 4a. CLAUDE.md missing
out=$(bash lib/sensors/discover-from-claude-md.sh "$tmpdir/missing.md" 2>&1) || true
echo "$out" | grep -q "sensors: \[\]" \
  && echo "$out" | grep -q "CLAUDE.md not found" \
  && pass "discover-from-claude-md.sh handles missing file" \
  || err "discover-from-claude-md.sh did not handle missing CLAUDE.md: $out"

# 4b. CLAUDE.md present but no marked sections
cat > "$tmpdir/no-sections.md" <<'EOF'
# Project

Some random project guidance with no Yoke-recognized headings.
EOF
out=$(bash lib/sensors/discover-from-claude-md.sh "$tmpdir/no-sections.md" 2>&1) || true
echo "$out" | grep -q "sensors: \[\]" \
  && echo "$out" | grep -q "no commands discovered" \
  && pass "discover-from-claude-md.sh handles missing sections" \
  || err "discover-from-claude-md.sh did not handle missing sections: $out"

# 4c. CLAUDE.md with Testing + Linting + Build (≥3 categories per DoD #3)
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

# Verify ≥3 categories per DoD #3
distinct_categories=$(echo "$out" | grep -oE 'category: [a-z]+' | sort -u | wc -l | tr -d ' ')
[ "$distinct_categories" -ge 3 ] \
  && pass "discover extracts ≥3 categories ($distinct_categories)" \
  || err "discover extracted only $distinct_categories categories"

# Verify command extraction picks first backticked segment
echo "$out" | grep -q 'command: "npm test"' \
  && pass "discover extracts first backticked command" \
  || err "discover did not extract 'npm test' verbatim: $out"

# 5. verify-acceptance.sh against a synthetic Acceptance Contract
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

# Pass case
echo "$out" | grep -A2 '^  - sensor: "linter"' | grep -q 'status: pass' \
  && pass "verify-acceptance pass case correct" \
  || err "verify-acceptance did not report pass for linter: $out"

# Skip case
echo "$out" | grep -A2 '^  - sensor: "skipme"' | grep -q 'status: skip' \
  && pass "verify-acceptance skip case correct" \
  || err "verify-acceptance did not skip missing binary: $out"

# Fail case
echo "$out" | grep -A2 '^  - sensor: "failer"' | grep -q 'status: fail' \
  && pass "verify-acceptance fail case correct" \
  || err "verify-acceptance did not report fail: $out"

# Stdin-isolation regression — a sensor that reads stdin must not consume
# the parent loop's pending bullets. Without `</dev/null` on `bash -c`,
# `head -n 99` slurps the rest of the heredoc and the loop terminates
# before runs-after-stdin-eater is iterated.
echo "$out" | grep -q '^  - sensor: "runs-after-stdin-eater"' \
  && pass "verify-acceptance isolates child stdin (regression)" \
  || err "verify-acceptance leaked parent stdin to bash -c — sensor truncation: $out"

# Missing contract → exit 3
if bash hooks/verify-acceptance.sh "$tmpdir/missing-contract.md" 2>/dev/null; then
  err "verify-acceptance did not exit non-zero on missing contract"
else
  pass "verify-acceptance exits non-zero on missing contract"
fi

# 6. Validator distinct from Generator (DoD #2 — verifiable by prompt diff)
val_size=$(wc -c < "agents/validator.md")
gen_size=$(wc -c < "agents/generator.md")
# `diff` exits 1 when files differ, so capture into a variable with `|| true`
# to avoid aborting under `set -e`.
diff_output=$(diff "agents/validator.md" "agents/generator.md" 2>/dev/null || true)
diff_lines=$(printf '%s' "$diff_output" | wc -l | tr -d ' ')
[ "$val_size" -gt 1500 ] && [ "$gen_size" -gt 1500 ] && [ "$diff_lines" -gt 50 ] \
  && pass "Validator prompt distinct from Generator (val=$val_size, gen=$gen_size, diff=$diff_lines lines)" \
  || err "Validator/Generator prompts not sufficiently distinct (val=$val_size, gen=$gen_size, diff=$diff_lines)"

# 7. Validator never modifies PRD/Tech Spec (DoD #7) — declared in agent.
# Use -E to allow `.` to match any character (the file uses backticks
# around paths: `Never modify ` + backtick + `.yoke/prd.md` + …).
grep -qE "Never modify .*\.yoke/prd\.md.*or .*\.yoke/tech-spec\.md" "agents/validator.md" \
  && pass "Validator declares no-modify rule for PRD/Tech Spec" \
  || err "Validator does not declare no-modify rule for PRD/Tech Spec"

# 8–10. Anti-scope (point-in-time at Sprint-3 completion): only assert
# placeholders for items that NO LATER sprint advances within v1.0.
#
# Items advanced by later sprints (so we DO NOT check them here):
#   - Implementation Agent → Sprint 4
#   - Validation Agent → Sprint 4
#   - post-iteration.sh / pre-implementation.sh → Sprint 4
#   - lib/ralph-loop/orchestrate.sh → Sprint 4
#   - Orchestrator placeholder → Sprint 5 (moves it)
#   - check-hard-bounds.sh / escalate.sh → Sprint 6
#
# Each sprint's own smoke + audit enforces its anti-scope at the time
# of writing; cross-sprint regression here only checks artifacts that
# stay constant through v1.0.
pass "Sprint-3 anti-scope: assertions deferred to per-sprint smokes (intentional design)"

# 11. Anti-scope assertions on advanced items dropped per deferred-anti-scope
# design rule (graph.sh advanced in Sprint 6, propose-write.sh in Sprint 5).
pass "Sprint-3 cross-sprint anti-scope deferred to per-sprint smokes (intentional design)"

# 12. Sprint-2 regression — query.sh still works.
# Use a fresh empty subdir (the shared $tmpdir was populated by earlier
# checks in this script).
empty_dir="$tmpdir/empty-for-regression"
mkdir -p "$empty_dir"
out=$(bash lib/canonical-memory/query.sh "anything" "$empty_dir" 2>&1) || true
echo "$out" | grep -qi "no entries yet" \
  && pass "Sprint 2 query.sh still works (regression check)" \
  || err "Sprint 2 query.sh regressed: $out"

echo "--- Result ---"
if [ "$fail" -eq 0 ]; then
  echo "PASS"
  exit 0
else
  echo "FAIL ($fail check(s) failed)"
  exit 1
fi
