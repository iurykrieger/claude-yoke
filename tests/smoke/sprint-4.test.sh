#!/bin/bash
# tests/smoke/sprint-4.test.sh
#
# Sprint 4 smoke test — validates the parallel-spawn ralph-loop
# artifacts (refreshed in v1.1.0):
#   - 3 runtime subagents: agents/generator.md, agents/validator.md,
#     agents/orchestrator.md
#   - /yoke:implement skill (spawns 3 subagents per cycle in a single
#     concurrent Task batch + termination canonize handoff)
#   - lib/ralph-loop/orchestrate.sh (preflight, append-contract,
#     check-contradiction)
#   - hooks/post-iteration.sh (snapshot + counter)
#   - templates/progress.md, templates/contracts.md
#
# This sprint ships pre-Sprint-6 (no hard bounds enforced). The smoke
# runs the DETERMINISTIC parts of the loop only; the agentic
# parallel-spawn requires Claude Code runtime.
#
# Always wrap CI invocations in
# `timeout 600 bash tests/smoke/sprint-4.test.sh`.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PLUGIN_ROOT"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- Sprint 4 smoke ---"

# 1. v1.1 — agents/ contains exactly 3 files (runtime subagents only).
agent_count=$(ls agents/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$agent_count" = "3" ]; then
  pass "agents/ contains exactly 3 files (3-subagent topology)"
else
  err "agents/ should contain 3 files; found $agent_count"
fi

# 2. Each runtime subagent file present and substantive
for agent in agents/generator.md agents/validator.md agents/orchestrator.md; do
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

# 3. Generator declares no-modify rule on upstream artifacts.
flat=$(tr '\n' ' ' < agents/generator.md)
echo "$flat" | grep -qE "Never modify.*prds.*tech-specs.*acceptance-contracts" \
  && pass "Generator declares no-modify rule on upstream artifacts" \
  || err "Generator does not declare no-modify rule on upstream artifacts"

# 4. Validator declares structured-verdict requirement
grep -qF "structured JSON verdict" agents/validator.md \
  && pass "Validator requires structured JSON verdicts" \
  || err "Validator does not declare structured-verdict rule"

# 5. Orchestrator declares 3 modes (DoD: orchestrator subagent has
#    consult / monitor / canonize modes per Part 1 spec).
for mode in consult monitor canonize; do
  if grep -qF "[orchestrator:$mode]" agents/orchestrator.md; then
    pass "agents/orchestrator.md declares $mode mode token"
  else
    err "agents/orchestrator.md missing $mode mode declaration"
  fi
done

# 6. Orchestrator declares sole-writer authority for canonical memory
grep -q "sole writer of canonical memory" agents/orchestrator.md \
  && pass "Orchestrator declares sole-writer authority" \
  || err "Orchestrator does not declare sole-writer authority"

# 7. Generator and Validator never share runtime context (adversarial).
grep -q "Never share context with the Validator" agents/generator.md \
  && pass "Generator declares no-context-sharing with Validator" \
  || err "Generator missing no-context-sharing rule"
grep -q "Never share context with the Generator" agents/validator.md \
  && pass "Validator declares no-context-sharing with Generator" \
  || err "Validator missing no-context-sharing rule"

# 8. /yoke:implement skill valid
sk="skills/implement/SKILL.md"
[ -f "$sk" ] || err "missing $sk"
awk 'BEGIN{c=0; n=0; d=0} /^---$/{c++; next} c==1 && /^name:/{n=1} c==1 && /^description:/{d=1} END{exit (n && d) ? 0 : 1}' "$sk" \
  && pass "$sk frontmatter valid" \
  || err "$sk missing name/description"

# 9. v1.1 — /yoke:implement spawns 3 concurrent subagents per cycle in a
#    single assistant turn (Part 6 DoD #3).
allowed_line=$(awk '/^allowed-tools:/{print; exit}' "$sk" || true)
echo "$allowed_line" | grep -qw "Task" \
  && pass "/yoke:implement allowed-tools includes Task (spawns subagents)" \
  || err "/yoke:implement allowed-tools missing Task"

for agent in "agents/generator.md" "agents/validator.md" "agents/orchestrator.md"; do
  if grep -qF "$agent" "$sk"; then
    pass "/yoke:implement references $agent"
  else
    err "/yoke:implement does not reference $agent"
  fi
done

if grep -qE "single (assistant turn|concurrent Task|orchestration turn)" "$sk" || grep -q "three concurrent Task calls" "$sk"; then
  pass "/yoke:implement declares single-turn concurrent Task batch"
else
  err "/yoke:implement does not declare concurrent-Task-batch semantics"
fi

# 10. v1.1 — /yoke:implement issues termination canonize handoff
#     (Part 3 DoD #2; verifiable in Part 6 sprint-5 too).
grep -q "mode=canonize" "$sk" \
  && pass "/yoke:implement issues canonize handoff at termination" \
  || err "/yoke:implement missing termination canonize handoff"

# 11. orchestrate.sh subcommands
[ -x "lib/ralph-loop/orchestrate.sh" ] || err "lib/ralph-loop/orchestrate.sh not executable"

out=$(bash lib/ralph-loop/orchestrate.sh help 2>&1) || true
echo "$out" | grep -q "preflight" \
  && pass "orchestrate.sh help mentions preflight" \
  || err "orchestrate.sh help broken: $out"

set +e
bash lib/ralph-loop/orchestrate.sh unknown-cmd > /dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] \
  && pass "orchestrate.sh exits 2 on unknown subcommand" \
  || err "orchestrate.sh did not exit 2 on unknown subcommand (got $rc)"

# 12. Preflight: missing .yoke/ → exit 3
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

# 13. Preflight: .yoke/ exists but artifacts missing → exit 4
# v0.6.0: needs .yoke/.current with a valid slug; preflight then
# resolves wm_*_path and reports artifacts missing.
SLUG="2026-04-25-sprint-4-preflight"
mkdir -p "$tmpdir/.yoke"
echo "yoke_version: 1.1.0" > "$tmpdir/.yoke/config.yaml"
printf '%s' "$SLUG" > "$tmpdir/.yoke/.current"
pushd "$tmpdir" > /dev/null
set +e
bash "$PLUGIN_ROOT/lib/ralph-loop/orchestrate.sh" preflight > /dev/null 2>&1
rc=$?
set -e
popd > /dev/null
[ "$rc" -eq 4 ] \
  && pass "preflight exits 4 when upstream artifacts are missing" \
  || err "preflight wrong exit on missing artifacts (got $rc)"

# 14. Preflight: artifacts present and approved → exit 0
mkdir -p "$tmpdir/.yoke/prds" "$tmpdir/.yoke/tech-specs" "$tmpdir/.yoke/acceptance-contracts"
cat > "$tmpdir/.yoke/prds/$SLUG.md" <<'EOF'
# PRD: test
> Status: approved
EOF
cat > "$tmpdir/.yoke/tech-specs/$SLUG.md" <<'EOF'
# Tech Spec: test
> Status: approved
EOF
cat > "$tmpdir/.yoke/acceptance-contracts/$SLUG.md" <<'EOF'
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

# 15. append-contract appends a YAML fragment to .yoke/contracts/<slug>.md
cat > "$tmpdir/contract-fragment.yaml" <<'EOF'
- id: c1
  topic: "interpretation of FR-1"
  decision: "FR-1 means doing the thing once per request"
  rationale: "Acceptance Contract criterion FR-1 is request-scoped"
  timestamp: "2026-04-25T00:00:00Z"
  agents_involved: [generator, validator]
  cycle: 1
EOF
pushd "$tmpdir" > /dev/null
bash "$PLUGIN_ROOT/lib/ralph-loop/orchestrate.sh" append-contract "$tmpdir/contract-fragment.yaml" > /dev/null
popd > /dev/null
[ -f "$tmpdir/.yoke/contracts/$SLUG.md" ] && grep -q "FR-1 means doing the thing" "$tmpdir/.yoke/contracts/$SLUG.md" \
  && pass "append-contract writes to .yoke/contracts/<slug>.md" \
  || err "append-contract did not write contract"

# 16. check-contradiction: clean case → exit 0
pushd "$tmpdir" > /dev/null
out=$(bash "$PLUGIN_ROOT/lib/ralph-loop/orchestrate.sh" check-contradiction 2>&1) || true
popd > /dev/null
echo "$out" | grep -q "ok" \
  && pass "check-contradiction passes on clean state" \
  || err "check-contradiction should pass: $out"

# 17. check-contradiction: contradictory sprint contract → exit 10
cat >> "$tmpdir/.yoke/contracts/$SLUG.md" <<'EOF'

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

# 18. post-iteration.sh: missing .yoke/ → exit 3
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

# 19. post-iteration.sh: increments counter and snapshots (v0.6.0:
# runtime files live under .yoke/runtime/).
pushd "$tmpdir" > /dev/null
out=$(bash "$PLUGIN_ROOT/hooks/post-iteration.sh" "$tmpdir/.yoke/acceptance-contracts/$SLUG.md" 2>&1) || true
popd > /dev/null
echo "$out" | grep -q "cycle=1" \
  && pass "post-iteration starts cycle counter at 1" \
  || err "post-iteration cycle counter wrong: $out"

pushd "$tmpdir" > /dev/null
bash "$PLUGIN_ROOT/hooks/post-iteration.sh" "$tmpdir/.yoke/acceptance-contracts/$SLUG.md" > /dev/null
popd > /dev/null
counter=$(cat "$tmpdir/.yoke/runtime/.cycle-counter")
[ "$counter" = "2" ] \
  && pass "post-iteration counter monotonically increments" \
  || err "post-iteration counter did not increment: $counter"

[ -f "$tmpdir/.yoke/runtime/.snapshots/cycle-1.yaml" ] \
  && pass "post-iteration creates snapshot file" \
  || err "post-iteration did not create snapshot"

# 20. Templates: progress + contracts
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

# 21. Status skill — Part 6 of the bedrock canonical-memory port
#     (2026-04-25) extended /yoke:status with bedrock's healthcheck
#     surface. Verifies the read-only contract instead of the
#     historical placeholder marker.
if grep -qE 'Read-only|read-only contract' skills/status/SKILL.md; then
  pass "skills/status/SKILL.md declares read-only contract (Part 6 extension)"
else
  err "skills/status/SKILL.md missing read-only declaration"
fi

# 22. Sprint regressions
echo "--- Regressions ---"
bash tests/smoke/sprint-3.test.sh > /tmp/sp3-regression.log 2>&1 \
  && pass "Sprint-3 smoke still PASS (regression)" \
  || err "Sprint-3 regressed: $(tail -5 /tmp/sp3-regression.log)"
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
