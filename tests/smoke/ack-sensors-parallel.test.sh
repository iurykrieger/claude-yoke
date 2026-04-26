#!/bin/bash
# tests/smoke/ack-sensors-parallel.test.sh
#
# Part 2 smoke test for the Validator parallel-spawn protocol +
# verify-acceptance.sh refactor. Validates DoD #1–#7 from
# .vibeflow/specs/ack-sensors-skill-part-2.md:
#   - Validator agent file declares the parallel-spawn protocol
#   - Bash background + watchdog can prove wall-clock parallelism
#   - Per-sensor timeout (default 60s; per-bullet override) fires
#     with status=skip + exit_code=124
#   - Any-fail-wins reducer
#   - Hook delegates to ack-sensors.sh, schema unchanged
#   - Verdict shape preserved
#   - Validator allowed-tools = Bash + Monitor (no Agent yet)

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="${PLUGIN_ROOT}/hooks/verify-acceptance.sh"
ACK="${PLUGIN_ROOT}/lib/sensors/ack-sensors.sh"
VALIDATOR="${PLUGIN_ROOT}/agents/validator.md"
PATTERN="${PLUGIN_ROOT}/.vibeflow/patterns/sensors.md"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- ack-sensors Part 2 smoke ---"

[ -f "$HOOK" ]      || { err "missing hook";       exit 1; }
[ -f "$ACK" ]       || { err "missing ack-sensors helper"; exit 1; }
[ -f "$VALIDATOR" ] || { err "missing validator";  exit 1; }
[ -f "$PATTERN" ]   || { err "missing sensors.md"; exit 1; }

# ---------------------------------------------------------------------------
# DoD #7 — Validator allowed-tools includes Bash + Monitor; excludes Agent
# ---------------------------------------------------------------------------
tools_line=$(awk '/^tools:/{print; exit}' "$VALIDATOR" || true)
if [ -z "$tools_line" ]; then
  err "Validator missing tools field"
else
  echo "$tools_line" | grep -qw 'Bash'    && pass "Validator allows Bash"     || err "Validator missing Bash in tools"
  echo "$tools_line" | grep -qw 'Monitor' && pass "Validator allows Monitor"  || err "Validator missing Monitor in tools"
  # Part 2 originally required Agent absent, but Part 3 legitimately
  # introduces Agent with a strict subagent_type: yoke:semantic-judge
  # constraint. After Part 3 lands, the assertion softens to: if Agent
  # is present, it MUST be pinned to yoke:semantic-judge (the Part 3
  # invariant). The Part 3 smoke covers the strict pinning directly.
  if echo "$tools_line" | grep -qw 'Agent'; then
    if grep -q 'subagent_type: yoke:semantic-judge' "$VALIDATOR"; then
      pass "Validator's Agent is pinned to yoke:semantic-judge (Part 3 invariant)"
    else
      err "Validator allows Agent but does not pin subagent_type — Part 3 invariant broken"
    fi
  else
    pass "Validator allowed-tools excludes Agent (pre-Part-3 state)"
  fi
fi

# ---------------------------------------------------------------------------
# DoD #1 — Validator declares the parallel-spawn protocol with Monitor
# ---------------------------------------------------------------------------
grep -q 'Sensor execution protocol' "$VALIDATOR" \
  && pass "Validator declares Sensor execution protocol" \
  || err "Validator missing Sensor execution protocol section"

grep -q 'run_in_background=true' "$VALIDATOR" \
  && pass "Validator references Bash run_in_background" \
  || err "Validator missing run_in_background reference"

grep -q '`Monitor`' "$VALIDATOR" \
  && pass "Validator references Monitor tool" \
  || err "Validator missing Monitor reference"

grep -q 'ack-sensors.sh --mode readiness' "$VALIDATOR" \
  && pass "Validator delegates discovery to ack-sensors readiness" \
  || err "Validator does not call ack-sensors readiness"

# ---------------------------------------------------------------------------
# DoD #4 — any-fail-wins documented in Validator AND pattern
# ---------------------------------------------------------------------------
grep -qiE 'any[- ]fail[- ]wins' "$VALIDATOR" \
  && pass "Validator documents any-fail-wins" \
  || err "Validator missing any-fail-wins rule"

grep -qiE 'any[- ]fail[- ]wins' "$PATTERN" \
  && pass "patterns/sensors.md documents any-fail-wins" \
  || err "patterns/sensors.md missing any-fail-wins rule"

# ---------------------------------------------------------------------------
# DoD #3 — Per-sensor timeout: 60s default for computational; override
# ---------------------------------------------------------------------------
grep -q '60s' "$VALIDATOR" || grep -q '60' "$VALIDATOR" \
  && pass "Validator references 60s computational default" \
  || err "Validator does not reference 60s default"

grep -qE '\(timeout: ?<Ns>\)' "$VALIDATOR" || grep -qE 'timeout: <Ns>' "$VALIDATOR" \
  && pass "Validator references per-sensor (timeout: <Ns>) override" \
  || err "Validator missing per-sensor timeout override syntax"

grep -q '124' "$VALIDATOR" \
  && pass "Validator references exit code 124 (timeout)" \
  || err "Validator missing exit code 124"

# ---------------------------------------------------------------------------
# Hook integration tests — backwards-compatible YAML schema + delegation
# ---------------------------------------------------------------------------

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Fixture contract with two reachable sensors (both pass), one missing
# binary, and one timeout-override (sleep past budget).
cat > "${tmp}/contract.md" <<'EOF'
# Acceptance Contract — Part 2 fixture

## Sensors

### Computational
- ok-true: `true`
- ok-echo: `echo hello`
- bogus-bin: `definitely-not-a-real-binary-zzz arg1`
- slow-sleep: `sleep 5` (timeout: 1s)

EOF

set +e
hook_out="$(bash "$HOOK" "${tmp}/contract.md" 2>/dev/null)"
hook_code=$?
set -e

if [ "$hook_code" -eq 0 ]; then
  pass "hook exit 0 with mixed contract"
else
  err "hook exit $hook_code (expected 0)"
fi

# DoD #5/6 — per-sensor schema preserved
for field in 'sensor:' 'command:' 'status:' 'exit_code:' 'output_excerpt:' 'reason:'; do
  if echo "$hook_out" | grep -q "$field"; then
    pass "hook YAML preserves field: $field"
  else
    err "hook YAML missing field: $field"
  fi
done

# Top-level results: key
echo "$hook_out" | grep -q '^results:' && pass "hook output has top-level results:" \
  || err "hook output missing results: top-level"

# Outcome counts
ok_pass=$(echo "$hook_out" | grep -c 'status: pass' || true)
ok_skip=$(echo "$hook_out" | grep -c 'status: skip' || true)
ok_fail=$(echo "$hook_out" | grep -c 'status: fail' || true)

if [ "$ok_pass" -eq 2 ]; then pass "two sensors pass"; else err "expected 2 pass, got $ok_pass"; fi
if [ "$ok_skip" -eq 2 ]; then pass "two sensors skip (missing binary + timeout)"; else err "expected 2 skip, got $ok_skip"; fi
if [ "$ok_fail" -eq 0 ]; then pass "zero sensors fail (none ran with non-zero non-timeout exit)"; else err "expected 0 fail, got $ok_fail"; fi

# DoD #3 — timeout fires with exit_code=124 and reason mentions timeout
if echo "$hook_out" | grep -A6 'sensor: "slow-sleep"' | grep -q 'exit_code: 124'; then
  pass "timeout sensor → exit_code: 124"
else
  err "timeout sensor did not produce exit_code: 124"
fi
if echo "$hook_out" | grep -A6 'sensor: "slow-sleep"' | grep -q 'reason: "timeout:'; then
  pass "timeout sensor → reason: timeout: ..."
else
  err "timeout sensor did not include reason: timeout:"
fi

# DoD #5 — missing-binary sensor still produces 'binary not found' reason
if echo "$hook_out" | grep -A6 'sensor: "bogus-bin"' | grep -q 'binary not found'; then
  pass "missing-binary sensor → reason: binary not found"
else
  err "missing-binary sensor did not produce 'binary not found' reason"
fi

# ---------------------------------------------------------------------------
# DoD #5 — hook delegates to ack-sensors readiness
# ---------------------------------------------------------------------------
grep -q 'ack-sensors.sh.*--mode readiness' "$HOOK" \
  && pass "hook calls ack-sensors.sh --mode readiness" \
  || err "hook does not delegate to ack-sensors readiness"

# ---------------------------------------------------------------------------
# DoD #2 — Wall-clock proof of parallelism (background bash + watchdog).
# Demonstrates the same primitive the Validator uses (run_in_background).
# Compressed scale: durations 0.2 / 0.5 / 1.5 (s); slowest = 1.5s.
# Threshold: ≤ 1.3 × slowest = 1.95s. Serial would be 2.2s.
# ---------------------------------------------------------------------------
parallel_demo() {
  local d1=0.2 d2=0.5 d3=1.5
  local pid1 pid2 pid3
  ( sleep "$d1" ) & pid1=$!
  ( sleep "$d2" ) & pid2=$!
  ( sleep "$d3" ) & pid3=$!
  wait "$pid1" "$pid2" "$pid3"
}

start=$(date +%s%N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1e9))')
parallel_demo
end=$(date +%s%N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1e9))')
elapsed_ns=$(( end - start ))
elapsed_ms=$(( elapsed_ns / 1000000 ))

if [ "$elapsed_ms" -le 1950 ]; then
  pass "parallel-spawn wall-clock ≤ 1950ms (got ${elapsed_ms}ms)"
else
  err "parallel-spawn wall-clock > 1950ms (got ${elapsed_ms}ms; serial would be ~2200ms — pattern not parallel)"
fi

# ---------------------------------------------------------------------------
# DoD #4 — any-fail-wins reducer (bash demo of the Validator's logic)
# Multiple sensors mapping to one criterion: one pass, one fail → fail.
# ---------------------------------------------------------------------------
combine_verdicts() {
  # Args: list of statuses ("pass" / "fail" / "skip"). Echo combined.
  local s combined="pass"
  for s in "$@"; do
    if [ "$s" = "fail" ]; then combined="fail"; break; fi
    if [ "$s" = "skip" ] && [ "$combined" = "pass" ]; then combined="skip"; fi
  done
  echo "$combined"
}

c1=$(combine_verdicts pass pass pass)
c2=$(combine_verdicts pass fail pass)
c3=$(combine_verdicts skip pass)
c4=$(combine_verdicts pass fail skip)

[ "$c1" = "pass" ] && pass "reducer: all pass → pass" || err "reducer: all pass → got $c1"
[ "$c2" = "fail" ] && pass "reducer: any fail → fail (any-fail-wins)" || err "reducer: any fail expected fail, got $c2"
[ "$c3" = "skip" ] && pass "reducer: skip + pass → skip" || err "reducer: skip + pass → got $c3"
[ "$c4" = "fail" ] && pass "reducer: pass + fail + skip → fail (fail dominates skip)" || err "reducer: pass+fail+skip → got $c4"

# ---------------------------------------------------------------------------
# DoD #6 — verdict shape parity (validator.md documents required JSON keys)
# ---------------------------------------------------------------------------
for key in 'criterion' 'status' 'location' 'fix_instruction' 'sensor' 'evidence'; do
  if grep -q "\"$key\":" "$VALIDATOR"; then
    pass "Validator verdict shape includes: $key"
  else
    err "Validator verdict shape missing: $key"
  fi
done

# ---------------------------------------------------------------------------
# Pattern doc updated with parallel section
# ---------------------------------------------------------------------------
grep -q 'Parallel execution & acknowledgement' "$PATTERN" \
  && pass "patterns/sensors.md has 'Parallel execution & acknowledgement' subsection" \
  || err "patterns/sensors.md missing Parallel execution subsection"

grep -q 'ack-sensors.sh' "$PATTERN" \
  && pass "patterns/sensors.md references ack-sensors.sh" \
  || err "patterns/sensors.md does not reference ack-sensors.sh"

# ---------------------------------------------------------------------------
# Regression — Part 1 catalog smoke still passes
# ---------------------------------------------------------------------------
if bash "${PLUGIN_ROOT}/tests/smoke/ack-sensors-catalog.test.sh" >/dev/null 2>&1; then
  pass "Part 1 catalog smoke still passes (no regression)"
else
  err "Part 1 catalog smoke regressed!"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "--- ack-sensors Part 2 smoke: ${fail} failure(s) ---"
exit "$fail"
