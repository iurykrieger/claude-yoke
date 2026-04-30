#!/usr/bin/env bash
# tests/sensors/dispatch-by-type.test.sh — permanent CI-gated test for
# the type-aware dispatch path in hooks/verify-acceptance.sh.
#
# Asserts:
#   - The marker file `/tmp/yoke-dispatch-marker-comp` exists post-run
#     (i.e., the computational sensor's `command: touch ...` ran via
#     shell dispatch).
#   - The inferential verdict JSON exists at the deterministic path
#     `.yoke/runtime/.judge-verdicts/cycle-0/<criterion>--<sensor>.json`
#     post-run (i.e., the inferential dispatch path emitted a verdict
#     envelope, even if it's the placeholder until a coordinator
#     overwrites it).
#   - The verdict JSON parses as JSON containing `confidence` (numeric)
#     and `supporting_quotes` (list).
#
# The test isolates execution under a tempdir so the host project's
# real `.yoke/` is not polluted: the fixture sensors are copied into
# the tempdir's `.yoke/sensors/`, the fixture contract into
# `.yoke/acceptance-contracts/`, and the hook is invoked with that
# tempdir as CWD.
#
# Source PRD: .yoke/prds/2026-04-30-sensor-harness-realignment.md
# (Sprint 3, t03). Permanent — runs in the CI gate (Sprint 3 t06).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE_DIR="${REPO_ROOT}/tests/fixtures/dispatch-by-type"
MARKER="/tmp/yoke-dispatch-marker-comp"

FAIL=0
fail() { echo "FAIL: $*" >&2; FAIL=1; }
pass() { echo "PASS: $*"; }

echo "--- dispatch-by-type permanent test ---"

# ---------------------------------------------------------------------------
# Setup: isolated working tree under /tmp.
# ---------------------------------------------------------------------------
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/yoke-dispatch-test.XXXXXX")"
cleanup() {
  rm -rf "$WORK_DIR"
  rm -f "$MARKER"
}
trap cleanup EXIT

# Pre-clean any stale marker.
rm -f "$MARKER"

# Mirror the host project's directory layout enough that
# verify-acceptance.sh resolves `.yoke/sensors/<id>.md` and the
# verdict-output directory under `.yoke/runtime/.judge-verdicts/`.
mkdir -p "$WORK_DIR/.yoke/sensors" \
         "$WORK_DIR/.yoke/acceptance-contracts" \
         "$WORK_DIR/.yoke/runtime"

cp "$FIXTURE_DIR/sensors/dispatch-marker-comp.md" "$WORK_DIR/.yoke/sensors/"
cp "$FIXTURE_DIR/sensors/dispatch-marker-inf.md" "$WORK_DIR/.yoke/sensors/"

# Use the fixture contract directly (the hook resolves it from the
# explicit path argument; no slug indirection needed).
CONTRACT_PATH="$FIXTURE_DIR/contracts/dispatch-fixture.md"

# ---------------------------------------------------------------------------
# Run the hook from inside the isolated tree against the fixture
# contract; filter by criterion 'Scenario 1' so only the fixture
# sensors fire. Cycle counter defaults to 0 (no .yoke/runtime/.cycle-counter
# in the fixture), so verdict files land under
# .yoke/runtime/.judge-verdicts/cycle-0/.
# ---------------------------------------------------------------------------
(
  cd "$WORK_DIR"
  bash "$REPO_ROOT/hooks/verify-acceptance.sh" "$CONTRACT_PATH" --criterion "Scenario 1" >/dev/null 2>&1
) || { fail "verify-acceptance.sh exited non-zero against fixture contract"; }

# ---------------------------------------------------------------------------
# Assertion 1: computational dispatch ran the shell command.
# ---------------------------------------------------------------------------
if [ -f "$MARKER" ]; then
  pass "computational dispatch executed the shell command (marker exists at $MARKER)"
else
  fail "computational dispatch did not run the shell command (marker not found at $MARKER)"
fi

# ---------------------------------------------------------------------------
# Assertion 2: inferential dispatch emitted a verdict file.
# ---------------------------------------------------------------------------
verdict_glob="$WORK_DIR/.yoke/runtime/.judge-verdicts/cycle-0/*dispatch-marker-inf*.json"
verdict_file=""
for vf in $verdict_glob; do
  [ -f "$vf" ] && { verdict_file="$vf"; break; }
done
if [ -z "$verdict_file" ]; then
  fail "inferential dispatch did not emit a verdict file matching ${verdict_glob}"
else
  pass "inferential dispatch emitted verdict file: $(basename "$verdict_file")"

  # ---------------------------------------------------------------------------
  # Assertion 3: verdict JSON parses with confidence (numeric) and
  # supporting_quotes (list).
  # ---------------------------------------------------------------------------
  if command -v python3 >/dev/null 2>&1; then
    py=python3
  elif command -v python >/dev/null 2>&1; then
    py=python
  else
    py=""
  fi

  if [ -n "$py" ]; then
    parse_out=$("$py" - "$verdict_file" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
except Exception as e:
    print(f"PARSE_ERROR: {e}")
    sys.exit(1)
if not isinstance(d, dict):
    print("PARSE_ERROR: not an object")
    sys.exit(1)
if "confidence" not in d:
    print("MISSING: confidence")
    sys.exit(1)
if not isinstance(d["confidence"], (int, float)) or isinstance(d["confidence"], bool):
    print(f"NON_NUMERIC: confidence={d['confidence']!r}")
    sys.exit(1)
if "supporting_quotes" not in d:
    print("MISSING: supporting_quotes")
    sys.exit(1)
if not isinstance(d["supporting_quotes"], list):
    print(f"NON_LIST: supporting_quotes={type(d['supporting_quotes']).__name__}")
    sys.exit(1)
print("OK")
PY
    ) && parse_ok=1 || parse_ok=0
    if [ "$parse_ok" = "1" ] && [ "$parse_out" = "OK" ]; then
      pass "verdict JSON has confidence (numeric) and supporting_quotes (list)"
    else
      fail "verdict JSON failed shape check: $parse_out"
    fi
  else
    # Fallback heuristic: grep for the keys.
    if grep -q '"confidence"' "$verdict_file" && grep -q '"supporting_quotes"' "$verdict_file"; then
      pass "verdict JSON has confidence and supporting_quotes (heuristic match — python unavailable)"
    else
      fail "verdict JSON missing confidence or supporting_quotes (heuristic match)"
    fi
  fi
fi

if [ "$FAIL" -eq 0 ]; then
  echo "--- dispatch-by-type: ALL PASS ---"
  exit 0
else
  echo "--- dispatch-by-type: FAILURES ABOVE ---" >&2
  exit 1
fi
