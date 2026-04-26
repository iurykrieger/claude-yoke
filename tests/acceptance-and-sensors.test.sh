#!/usr/bin/env bash
# tests/acceptance-and-sensors.test.sh
#
# Sensor discovery + acceptance verification:
#   - lib/sensors/discover-from-claude-md.sh extracts ≥2 testing sensors
#     from examples/greenfield-payment-service/CLAUDE.md
#   - hooks/verify-acceptance.sh runs against the example contract,
#     produces structured output (sensor schema fields), and exits with a
#     code consistent with its declared contract (0 = verification ran)
#   - the structured output is NOT a generic "tests failed" / "build
#     broken" message (per conventions.md sensor rules)
#
# The example project is reused as the canonical fixture per the spec.

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

cd "$PLUGIN_ROOT"

EXAMPLE_DIR="examples/greenfield-payment-service"
EXAMPLE_CLAUDE="$EXAMPLE_DIR/CLAUDE.md"
EXAMPLE_CONTRACT="$EXAMPLE_DIR/.yoke/acceptance-contract.md"

# ---------------------------------------------------------------------
# (1) discover-from-claude-md.sh extracts ≥2 testing sensors
# ---------------------------------------------------------------------
if [ ! -f "$EXAMPLE_CLAUDE" ]; then
  err "fixture missing: $EXAMPLE_CLAUDE"
  harness::summary
fi

discover_out=""
discover_exit=0
discover_out=$(bash lib/sensors/discover-from-claude-md.sh "$EXAMPLE_CLAUDE" 2>&1) \
  || discover_exit=$?

if [ "$discover_exit" -eq 0 ]; then
  pass "discover-from-claude-md.sh exits 0 against the example fixture"
else
  err "discover-from-claude-md.sh exit_code=$discover_exit"
fi

testing_count=$(echo "$discover_out" | grep -c 'category: testing' || true)
if [ "$testing_count" -ge 2 ]; then
  pass "discover-from-claude-md.sh extracts $testing_count testing sensors from example (≥2)"
else
  err "discover-from-claude-md.sh extracted $testing_count testing sensors (expected ≥2)"
fi

# ---------------------------------------------------------------------
# (2) verify-acceptance.sh runs against the example contract
# ---------------------------------------------------------------------
if [ ! -f "$EXAMPLE_CONTRACT" ]; then
  err "fixture missing: $EXAMPLE_CONTRACT"
  harness::summary
fi

verify_out=""
verify_exit=0
verify_out=$(bash hooks/verify-acceptance.sh "$EXAMPLE_CONTRACT" 2>&1) \
  || verify_exit=$?

# verify-acceptance.sh contract: exit 0 = verification ran (regardless
# of individual sensor outcomes).
if [ "$verify_exit" -eq 0 ]; then
  pass "verify-acceptance.sh exits 0 (verification ran) per declared contract"
else
  err "verify-acceptance.sh exit_code=$verify_exit (expected 0)"
fi

# Structured output: sensor schema fields must be present.
if echo "$verify_out" | grep -q '^results:' \
  && echo "$verify_out" | grep -qE 'sensor:|status:|exit_code:'; then
  pass "verify-acceptance.sh emits structured YAML (results, sensor, status, exit_code)"
else
  err "verify-acceptance.sh output is not structured per the sensor schema"
fi

# Output must NOT be a generic "tests failed" / "build broken" message.
if echo "$verify_out" | grep -qiE '^tests failed$|^build broken$|^all tests failed$' ; then
  err "verify-acceptance.sh emits generic message (sensor bug per conventions.md)"
else
  pass "verify-acceptance.sh output is not generic (per conventions.md sensor rules)"
fi

harness::summary
