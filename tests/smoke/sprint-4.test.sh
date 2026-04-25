#!/bin/bash
# tests/smoke/sprint-4.test.sh
#
# Sprint 4 smoke test — validates the basic ralph-loop artifacts:
#   - Implementation Agent (agents/implementation.md)
#   - Validation Agent (agents/validation.md)
#   - /yoke:implement skill
#   - lib/ralph-loop/orchestrate.sh (preflight, append-contract, check-contradiction)
#   - hooks/post-iteration.sh (snapshot + counter)
#   - templates/progress.md, templates/contracts.md
#
# This sprint ships pre-Sprint-6 (no hard bounds). The smoke runs the
# DETERMINISTIC parts of the loop only; the agentic parts (Implementation
# Agent + Validation Agent dialogue) require Claude Code runtime.
#
# Always wrap CI invocations in `timeout 600 bash tests/smoke/sprint-4.test.sh`.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- Sprint 4 smoke ---"

# 1. Subagent files present and substantive
for agent in agents/implementation.md agents/validation.md; do
  if [ ! -f "$agent" ]; then
    err "missing $agent"
    continue
  fi
  if [ "$(wc -l < "$agent")" -gt 50 ]; then
    pass "$agent substantive (>50 lines)"
  else
    err "$agent looks like a placeholder"
  fi
done

# 2. Implementation Agent declares no-modify rule on upstream artifacts.
# The phrase spans multiple lines in the file, so flatten with `tr` first.
# Use `.*` (any char including period) — the path tokens contain periods.
flat=$(tr '\n' ' ' < agents/implementation.md)
echo "$flat" | grep -qE "Never modify.*prd\.md.*tech-spec\.md.*acceptance-contract\.md" \
  && pass "Implementation Agent declares no-modify rule on upstream artifacts" \
  || err "Implementation Agent does not declare no-modify rule"

# 3. Validation Agent declares structured-verdict requirement
grep -qF "structured JSON verdict" agents/validation.md \
  && pass "Validation Agent requires structured JSON verdicts" \
  || err "Validation Agent does not declare structured-verdict rule"

# 4. Implementation/Validation Agents distinct from Generator/Validator (DoD #5)
impl_gen_diff_output=$(diff agents/implementation.md agents/generator.md 2>/dev/null || true)
impl_gen_diff=$(printf '%s' "$impl_gen_diff_output" | wc -l | tr -d ' ')
val_validator_diff_output=$(diff agents/validation.md agents/validator.md 2>/dev/null || true)
val_validator_diff=$(printf '%s' "$val_validator_diff_output" | wc -l | tr -d ' ')

[ "$impl_gen_diff" -gt 50 ] \
  && pass "Implementation Agent distinct from Generator (diff=$impl_gen_diff lines)" \
  || err "Implementation Agent not distinct from Generator (diff=$impl_gen_diff)"
[ "$val_validator_diff" -gt 50 ] \
  && pass "Validation Agent distinct from Validator (diff=$val_validator_diff lines)" \
  || err "Validation Agent not distinct from Validator (diff=$val_validator_diff)"

# 5. /yoke:implement skill valid
sk="skills/implement/SKILL.md"
[ -f "$sk" ] || err "missing $sk"
awk 'BEGIN{c=0; n=0; d=0} /^---$/{c++; next} c==1 && /^name:/{n=1} c==1 && /^description:/{d=1} END{exit (n && d) ? 0 : 1}' "$sk" \
  && pass "$sk frontmatter valid" \
  || err "$sk missing name/description"

grep -qF "Task tool" "$sk" \
  && pass "$sk references the Task tool (skill invokes subagents)" \
  || err "$sk does not declare Task-tool usage"

# 6. orchestrate.sh subcommands
[ -x "lib/ralph-loop/orchestrate.sh" ] || err "lib/ralph-loop/orchestrate.sh not executable"

# 6a. Help works
out=$(bash lib/ralph-loop/orchestrate.sh help 2>&1) || true
echo "$out" | grep -q "preflight" \
  && pass "orchestrate.sh help mentions preflight" \
  || err "orchestrate.sh help broken: $out"

# 6b. Unknown subcommand → exit 2
set +e
bash lib/ralph-loop/orchestrate.sh unknown-cmd > /dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] \
  && pass "orchestrate.sh exits 2 on unknown subcommand" \
  || err "orchestrate.sh did not exit 2 on unknown subcommand (got $rc)"

# 7. Preflight: missing .yoke/ → exit 3
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

pushd "$tmpdir" > /dev/null
set +e
bash "$PLUGIN_ROOT/lib/ralph-loop/orchestrate.sh" preflight > /dev/null 2>&1
rc=$?
set -e
popd > /dev/null
[ "$rc" -eq 3 ] \
  && pass "preflight exits 3 when .yoke/ is missing" \
  || err "preflight wrong exit on missing .yoke/ (got $rc)"

# 8. Preflight: .yoke/ exists but artifacts missing → exit 4
mkdir -p "$tmpdir/.yoke"
echo "yoke_version: 0.4.0" > "$tmpdir/.yoke/config.yaml"
pushd "$tmpdir" > /dev/null
set +e
bash "$PLUGIN_ROOT/lib/ralph-loop/orchestrate.sh" preflight > /dev/null 2>&1
rc=$?
set -e
popd > /dev/null
[ "$rc" -eq 4 ] \
  && pass "preflight exits 4 when upstream artifacts are missing" \
  || err "preflight wrong exit on missing artifacts (got $rc)"

# 9. Preflight: artifacts present and approved → exit 0
cat > "$tmpdir/.yoke/prd.md" <<'EOF'
# PRD: test
> Status: approved
EOF
cat > "$tmpdir/.yoke/tech-spec.md" <<'EOF'
# Tech Spec: test
> Status: approved
EOF
cat > "$tmpdir/.yoke/acceptance-contract.md" <<'EOF'
# Acceptance Contract: test
> Status: ratified

## Functional requirements
- FR-1: do thing — sensor: linter

## Use cases (BDD scenarios)

### Scenario 1 — basic flow

## Sensors

### Computational
- linter: `bash -c "echo ok"`
EOF
pushd "$tmpdir" > /dev/null
out=$(bash "$PLUGIN_ROOT/lib/ralph-loop/orchestrate.sh" preflight 2>&1) || true
popd > /dev/null
echo "$out" | grep -q "ok" \
  && pass "preflight succeeds with full state" \
  || err "preflight should succeed: $out"

# 10. append-contract appends a YAML fragment
cat > "$tmpdir/contract-fragment.yaml" <<'EOF'
- id: c1
  topic: "interpretation of FR-1"
  decision: "FR-1 means doing the thing once per request"
  rationale: "Acceptance Contract criterion FR-1 is request-scoped"
  timestamp: "2026-04-25T00:00:00Z"
  agents_involved: [implementation, validation]
  cycle: 1
EOF
pushd "$tmpdir" > /dev/null
bash "$PLUGIN_ROOT/lib/ralph-loop/orchestrate.sh" append-contract "$tmpdir/contract-fragment.yaml" > /dev/null
popd > /dev/null
[ -f "$tmpdir/.yoke/contracts.md" ] && grep -q "FR-1 means doing the thing" "$tmpdir/.yoke/contracts.md" \
  && pass "append-contract writes to .yoke/contracts.md" \
  || err "append-contract did not write contract"

# 11. check-contradiction: clean case → exit 0
pushd "$tmpdir" > /dev/null
out=$(bash "$PLUGIN_ROOT/lib/ralph-loop/orchestrate.sh" check-contradiction 2>&1) || true
popd > /dev/null
echo "$out" | grep -q "ok" \
  && pass "check-contradiction passes on clean state" \
  || err "check-contradiction should pass: $out"

# 12. check-contradiction: contradictory sprint contract → exit 10
cat >> "$tmpdir/.yoke/contracts.md" <<'EOF'

## Contract c2
- id: c2
- topic: "FR-1"
- decision: "relax FR-1 — skip checking it for now"
- rationale: "moving fast"
- cycle: 2
EOF
pushd "$tmpdir" > /dev/null
set +e
bash "$PLUGIN_ROOT/lib/ralph-loop/orchestrate.sh" check-contradiction > /dev/null 2>&1
rc=$?
set -e
popd > /dev/null
[ "$rc" -eq 10 ] \
  && pass "check-contradiction detects relax/skip verbs against criteria (exit 10)" \
  || err "check-contradiction missed contradiction (exit $rc)"

# 12b. check-contradiction false-positive regression: relax-class verbs
# applied to a non-criterion subject (e.g., a removed file) must NOT
# trip even when a criterion is mentioned later in the same decision
# text. Prior loose co-occurrence heuristic falsely flagged this.
tmp_fp="$(mktemp -d)"
trap 'rm -rf "$tmpdir" "$tmp_fp"' EXIT
mkdir -p "$tmp_fp/.yoke"
cat > "$tmp_fp/.yoke/config.yaml" <<'EOF'
yoke_version: 1.0.0
EOF
for art in prd tech-spec; do
  cat > "$tmp_fp/.yoke/${art}.md" <<EOF
> Status: approved
EOF
done
cat > "$tmp_fp/.yoke/acceptance-contract.md" <<'EOF'
> Status: ratified
- FR-6 — client component consumes all five actions.
EOF
cat > "$tmp_fp/.yoke/contracts.md" <<'EOF'
## Contract c4
- id: c4
- topic: "Refinements to FR-6 satisfaction"
- decision: "the boundary file is removed; FR-6/FR-7 stays satisfied via the new consumer"
- rationale: "in-envelope refactor"
- cycle: 4
EOF
pushd "$tmp_fp" > /dev/null
set +e
out=$(bash "$PLUGIN_ROOT/lib/ralph-loop/orchestrate.sh" check-contradiction 2>&1)
rc=$?
set -e
popd > /dev/null
[ "$rc" -eq 0 ] && echo "$out" | grep -q "ok" \
  && pass "check-contradiction does not false-positive on file-removed mentions (exit 0)" \
  || err "check-contradiction false-positive on '<file> is removed; FR-6 stays satisfied' (exit $rc): $out"
rm -rf "$tmp_fp"
trap 'rm -rf "$tmpdir"' EXIT

# 13. post-iteration.sh: missing .yoke/ → exit 3
empty="$(mktemp -d)"
pushd "$empty" > /dev/null
set +e
bash "$PLUGIN_ROOT/hooks/post-iteration.sh" > /dev/null 2>&1
rc=$?
set -e
popd > /dev/null
rm -rf "$empty"
[ "$rc" -eq 3 ] \
  && pass "post-iteration exits 3 without .yoke/" \
  || err "post-iteration wrong exit without .yoke/ (got $rc)"

# 14. post-iteration.sh: increments counter and snapshots
pushd "$tmpdir" > /dev/null
out=$(bash "$PLUGIN_ROOT/hooks/post-iteration.sh" "$tmpdir/.yoke/acceptance-contract.md" 2>&1) || true
popd > /dev/null
echo "$out" | grep -q "cycle=1" \
  && pass "post-iteration starts cycle counter at 1" \
  || err "post-iteration cycle counter wrong: $out"

pushd "$tmpdir" > /dev/null
bash "$PLUGIN_ROOT/hooks/post-iteration.sh" "$tmpdir/.yoke/acceptance-contract.md" > /dev/null
popd > /dev/null
counter=$(cat "$tmpdir/.yoke/.cycle-counter")
[ "$counter" = "2" ] \
  && pass "post-iteration counter monotonically increments" \
  || err "post-iteration counter did not increment: $counter"

[ -f "$tmpdir/.yoke/.snapshots/cycle-1.yaml" ] \
  && pass "post-iteration creates snapshot file" \
  || err "post-iteration did not create snapshot"

# 15. Templates: progress + contracts have proper YAML-in-markdown shape
grep -q "## Cycle 0" templates/progress.md \
  && pass "templates/progress.md has Cycle 0 section" \
  || err "templates/progress.md missing Cycle 0"
grep -q "## Cycle 1" templates/progress.md \
  && pass "templates/progress.md has Cycle 1 example" \
  || err "templates/progress.md missing Cycle 1 example"
grep -q "## Contract" templates/contracts.md \
  && pass "templates/contracts.md has Contract section" \
  || err "templates/contracts.md missing Contract section"
grep -q "agents_involved" templates/contracts.md \
  && pass "templates/contracts.md has agents_involved field" \
  || err "templates/contracts.md missing agents_involved"

# 16–17. Anti-scope assertions on items advanced by Sprint 6
# (check-hard-bounds.sh, escalate.sh) dropped per deferred-anti-scope
# design rule.
pass "Sprint-4 Sprint-6-territory anti-scope deferred to per-sprint smokes"

# 18–20. Anti-scope items advanced by later sprints are dropped per the
# deferred-anti-scope design rule:
#   - propose-write.sh, agents/orchestrator.md → Sprint 5
#   - skills/canonize → Sprint 5
#   - skills/drift-sense → Sprint 7
# Only items that stay constant through v1.0 are asserted here.
if grep -q "placeholder" skills/status/SKILL.md; then
  pass "skills/status/SKILL.md still placeholder (advanced only in Sprint 8)"
else
  err "skills/status/SKILL.md was modified — anti-scope violation"
fi

# 21. Sprint-3 regression: verify-acceptance.sh still works
echo "--- Sprint-3 regression check ---"
bash tests/smoke/sprint-3.test.sh > /tmp/sp3-regression.log 2>&1 \
  && pass "Sprint-3 smoke still PASS (regression)" \
  || err "Sprint-3 regressed: $(tail -5 /tmp/sp3-regression.log)"

# 22. Sprint-2 regression
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
