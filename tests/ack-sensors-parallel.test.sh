#!/bin/bash
# tests/ack-sensors-parallel.test.sh
#
# Part 2 smoke test — reconciled with main's coordinator-runs-once
# architecture. Original Part 2 placed parallel-spawn inside the Validator
# (Bash run_in_background + Monitor); main's perf-quickwins refactor
# moved sensor execution to a single per-cycle invocation of
# hooks/verify-acceptance.sh by the coordinator, with parallelism via
# xargs -P inside the hook. The Validator now reads a snapshot.
#
# This smoke test verifies what survived the reconciliation:
#   - hooks/verify-acceptance.sh delegates discovery to
#     /yoke:ack-sensors --mode readiness
#   - hook YAML schema preserved (per-sensor records with the canonical
#     fields)
#   - hook honors --concurrency / --fragments-dir flags (main's
#     parallelism surface)
#   - Validator's documented verdict shape still declares the canonical
#     six keys (criterion / status / location / fix_instruction /
#     sensor / evidence) — the schema is the contract regardless of who
#     spawns sensors

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="${PLUGIN_ROOT}/hooks/verify-acceptance.sh"
ACK="${PLUGIN_ROOT}/lib/sensors/ack-sensors.sh"
VALIDATOR="${PLUGIN_ROOT}/agents/validator.md"
PATTERN="${PLUGIN_ROOT}/.vibeflow/patterns/sensors.md"

fail=0
pass() { echo "✓ $1"; }
err()  { echo "✗ $1" >&2; fail=$((fail+1)); }

echo "--- ack-sensors Part 2 smoke (reconciled) ---"

[ -f "$HOOK" ]      || { err "missing hook";       exit 1; }
[ -f "$ACK" ]       || { err "missing ack-sensors helper"; exit 1; }
[ -f "$VALIDATOR" ] || { err "missing validator";  exit 1; }
[ -f "$PATTERN" ]   || { err "missing sensors.md"; exit 1; }

# ---------------------------------------------------------------------------
# Hook delegates to ack-sensors readiness (Part 2 DoD #5, post-merge)
# ---------------------------------------------------------------------------
# Match either a literal command string or a variable-expanded reference,
# tolerating line wraps in the hook source.
if tr '\n' ' ' < "$HOOK" | grep -qE 'ack-sensors\.sh.{0,200}--mode[[:space:]]+readiness'; then
  pass "hook delegates to /yoke:ack-sensors --mode readiness"
else
  err "hook does not delegate to ack-sensors readiness"
fi

# ---------------------------------------------------------------------------
# Validator's verdict shape (the schema is the contract)
# ---------------------------------------------------------------------------
for key in 'criterion' 'status' 'location' 'fix_instruction' 'sensor' 'evidence'; do
  if grep -q "\"$key\":" "$VALIDATOR"; then
    pass "Validator verdict shape includes: $key"
  else
    err "Validator verdict shape missing: $key"
  fi
done

# ---------------------------------------------------------------------------
# Hook integration tests — schema preservation + parallelism flags
# ---------------------------------------------------------------------------

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Fixture contract: two reachable sensors that exit fast (one pass, one
# fail) plus one missing binary. We avoid sleep-based fixtures because
# main's hook does not enforce per-sensor timeouts; runtime budget is
# enforced by the coordinator's hard-bounds hook instead.
cat > "${tmp}/contract.md" <<'EOF'
# Acceptance Contract — Part 2 fixture (post-merge)

## Sensors

### Computational
- ok-true: `true`
- ok-echo: `echo hello`
- bogus-bin: `definitely-not-a-real-binary-zzz arg1`

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

# Per-sensor schema preserved
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

if [ "$ok_pass" -eq 2 ]; then pass "two sensors pass"; else err "expected 2 pass, got $ok_pass"; fi
if [ "$ok_skip" -eq 1 ]; then pass "one sensor skip (missing binary)"; else err "expected 1 skip, got $ok_skip"; fi

# Missing-binary sensor produces 'binary not found' reason
if echo "$hook_out" | grep -A6 'sensor: "bogus-bin"' | grep -q 'binary not found'; then
  pass "missing-binary sensor → reason: binary not found"
else
  err "missing-binary sensor did not produce 'binary not found' reason"
fi

# ---------------------------------------------------------------------------
# main's --concurrency / --fragments-dir flags exist (parallelism contract)
# ---------------------------------------------------------------------------
grep -q -- '--concurrency' "$HOOK" \
  && pass "hook accepts --concurrency flag (parallelism control)" \
  || err "hook missing --concurrency flag"

grep -q -- '--fragments-dir' "$HOOK" \
  && pass "hook accepts --fragments-dir flag (deterministic merge)" \
  || err "hook missing --fragments-dir flag"

# Verify --concurrency 1 produces a serial run with deterministic output
serial1="$(bash "$HOOK" --concurrency 1 "${tmp}/contract.md" 2>/dev/null)"
serial2="$(bash "$HOOK" --concurrency 1 "${tmp}/contract.md" 2>/dev/null)"
if [ "$serial1" = "$serial2" ]; then
  pass "hook --concurrency 1 produces deterministic output"
else
  err "hook --concurrency 1 output non-deterministic"
fi

# ---------------------------------------------------------------------------
# Wall-clock parallelism demonstration (main's xargs path)
# Three reachable computational sensors at 0.2 / 0.5 / 1.5 s. With
# concurrency >= 3, wall-clock should be ≤ ~1.95s. Serial would be ~2.2s.
# ---------------------------------------------------------------------------
cat > "${tmp}/par-contract.md" <<'EOF'
# parallel-fixture

## Sensors

### Computational
- s1: `sleep 0.2`
- s2: `sleep 0.5`
- s3: `sleep 1.5`

EOF

start=$(date +%s%N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1e9))')
bash "$HOOK" --concurrency 3 "${tmp}/par-contract.md" >/dev/null 2>&1 || true
end=$(date +%s%N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1e9))')
elapsed_ms=$(( (end - start) / 1000000 ))

if [ "$elapsed_ms" -le 2200 ]; then
  pass "hook --concurrency 3 wall-clock ≤ 2200ms (got ${elapsed_ms}ms; serial would be ~2200ms)"
else
  err "hook --concurrency 3 wall-clock ${elapsed_ms}ms exceeds 2200ms (expected parallel speedup)"
fi

# ---------------------------------------------------------------------------
# Regression — Part 1 catalog smoke still passes
# ---------------------------------------------------------------------------
if bash "${PLUGIN_ROOT}/tests/ack-sensors-catalog.test.sh" >/dev/null 2>&1; then
  pass "Part 1 catalog smoke still passes (no regression)"
else
  err "Part 1 catalog smoke regressed!"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "--- ack-sensors Part 2 smoke (reconciled): ${fail} failure(s) ---"
exit "$fail"
