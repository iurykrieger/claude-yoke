#!/usr/bin/env bash
# shellcheck shell=bash
#
# council-phase-b.test.sh — Sprint 02 / Task t02 / AC Scenario 7 + FR-3.
#
# Exercises `lib/runtime/council.sh phase-b` against three branch
# fixtures and asserts the YAML summary on stdout matches the expected
# branch outcome.
#
#   1. phase-b-quiescence/        → exit 0, exit_status: consensus, rounds_consumed: 1, replica counts [0]
#   2. phase-b-arbiter-consensus/ → exit 0, exit_status: consensus, rounds_consumed: 1, replica counts [≥1] (arbiter says consensus)
#   3. phase-b-cap-exhausted/     → exit 10, exit_status: trigger-4, rounds_consumed: <cap>
#
# Test contract (binding for this file):
#   - exit 0 when every documented case behaves as specified.
#   - exit non-zero with a `wm: phase-b-test violation:`-prefixed
#     stderr line naming the failing case otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
HELPER="${REPO_ROOT}/lib/runtime/council.sh"
FIXTURES_DIR="${REPO_ROOT}/tests/runtime/fixtures"

violation() {
  printf 'wm: phase-b-test violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "${HELPER}" ]] || violation "council helper missing at ${HELPER}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

SLUG="2026-05-01-agent-council"
CYCLE="0"

# Stub arbiter that emits a deterministic JSON verdict by reading a
# pre-canned response under the cycle dir at <cycle-dir>/.arbiter-canned.json.
# The test populates this file to force the arbiter into the desired branch.
ARBITER_STUB="${TMP_DIR}/arbiter-stub.sh"
cat >"${ARBITER_STUB}" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
# argv: <merged-view> <round>
merged="$1"
round="$2"
# The merged view sits inside a tmp file produced by council.sh;
# the test driver injects a YOKE_ARBITER_CANNED env var pointing at
# the canned JSON for this fixture branch.
if [[ -n "${YOKE_ARBITER_CANNED:-}" && -f "${YOKE_ARBITER_CANNED}" ]]; then
  cat "${YOKE_ARBITER_CANNED}"
else
  printf '{"round": %s, "consensus": false, "contradictions": [{"personas":["sr-eng","sr-qa"], "summary":"unresolved", "evidence":"<from %s>", "category":"direct-contradiction"}], "tone_only_pairs": []}\n' "$round" "$merged"
fi
STUB
chmod +x "${ARBITER_STUB}"

assert_yaml_field() {
  local file="$1"
  local key="$2"
  local expected="$3"
  local got
  got="$(grep -E "^${key}:" "${file}" | head -n 1 | sed -E "s/^${key}:[[:space:]]*//; s/[[:space:]]+$//")"
  if [[ "${got}" != "${expected}" ]]; then
    violation "expected '${key}: ${expected}' in ${file}; got '${key}: ${got}'"
  fi
}

# Helper: copy a fixture into a scratch cycle dir under the tmp tree.
materialize_cycle() {
  local fixture="$1"
  local dest="$2"
  mkdir -p "${dest}"
  cp "${FIXTURES_DIR}/${fixture}/sr-eng.md"   "${dest}/sr-eng.md"
  cp "${FIXTURES_DIR}/${fixture}/sr-qa.md"    "${dest}/sr-qa.md"
  cp "${FIXTURES_DIR}/${fixture}/sr-staff.md" "${dest}/sr-staff.md"
}

# Case 1 — phase-b-quiescence: round 1 has zero réplicas → consensus.
CASE1_CYCLE_DIR="${TMP_DIR}/case1-cycle"
materialize_cycle "phase-b-quiescence" "${CASE1_CYCLE_DIR}"
CASE1_OUT="${TMP_DIR}/case1.out"
CASE1_ERR="${TMP_DIR}/case1.err"
RC=0
YOKE_ARBITER_CMD="${ARBITER_STUB}" \
  bash "${HELPER}" phase-b "${SLUG}" "${CYCLE}" "${CASE1_CYCLE_DIR}" \
    >"${CASE1_OUT}" 2>"${CASE1_ERR}" || RC=$?
[[ "${RC}" == "0" ]] \
  || violation "phase-b on quiescence fixture returned ${RC}; expected 0 (stderr: $(tr '\n' ' ' < "${CASE1_ERR}"))"
assert_yaml_field "${CASE1_OUT}" "exit_status" "consensus"
assert_yaml_field "${CASE1_OUT}" "rounds_consumed" "1"
assert_yaml_field "${CASE1_OUT}" "per_round_replica_counts" "[0]"

# Case 2 — phase-b-arbiter-consensus: round 1 has réplicas, arbiter consensus.
CASE2_CYCLE_DIR="${TMP_DIR}/case2-cycle"
materialize_cycle "phase-b-arbiter-consensus" "${CASE2_CYCLE_DIR}"
CASE2_CANNED="${TMP_DIR}/case2-canned.json"
cat >"${CASE2_CANNED}" <<'EOF'
{"round": 1, "consensus": true, "contradictions": [], "tone_only_pairs": [{"personas": ["sr-eng","sr-qa"], "summary": "phrasing differs but no semantic gap"}]}
EOF
CASE2_OUT="${TMP_DIR}/case2.out"
CASE2_ERR="${TMP_DIR}/case2.err"
RC=0
YOKE_ARBITER_CMD="${ARBITER_STUB}" \
  YOKE_ARBITER_CANNED="${CASE2_CANNED}" \
  bash "${HELPER}" phase-b "${SLUG}" "${CYCLE}" "${CASE2_CYCLE_DIR}" \
    >"${CASE2_OUT}" 2>"${CASE2_ERR}" || RC=$?
[[ "${RC}" == "0" ]] \
  || violation "phase-b on arbiter-consensus fixture returned ${RC}; expected 0 (stderr: $(tr '\n' ' ' < "${CASE2_ERR}"))"
assert_yaml_field "${CASE2_OUT}" "exit_status" "consensus"
assert_yaml_field "${CASE2_OUT}" "rounds_consumed" "1"
# At least one round had a replica
if grep -Eq 'per_round_replica_counts: \[0\]$' "${CASE2_OUT}"; then
  violation "arbiter-consensus fixture should have per_round_replica_counts >= [1]; got '$(grep per_round_replica_counts "${CASE2_OUT}")'"
fi

# Case 3 — phase-b-cap-exhausted: every round fails → trigger-4 at cap.
CASE3_CYCLE_DIR="${TMP_DIR}/case3-cycle"
materialize_cycle "phase-b-cap-exhausted" "${CASE3_CYCLE_DIR}"
CASE3_CANNED="${TMP_DIR}/case3-canned.json"
cat >"${CASE3_CANNED}" <<'EOF'
{"round": 1, "consensus": false, "contradictions": [{"personas": ["sr-eng","sr-qa"], "summary": "test result claim contradicts", "evidence": "from merged view", "category": "direct-contradiction"}], "tone_only_pairs": []}
EOF
CASE3_OUT="${TMP_DIR}/case3.out"
CASE3_ERR="${TMP_DIR}/case3.err"
RC=0
YOKE_ARBITER_CMD="${ARBITER_STUB}" \
  YOKE_ARBITER_CANNED="${CASE3_CANNED}" \
  bash "${HELPER}" phase-b "${SLUG}" "${CYCLE}" "${CASE3_CYCLE_DIR}" \
    >"${CASE3_OUT}" 2>"${CASE3_ERR}" || RC=$?
[[ "${RC}" == "10" ]] \
  || violation "phase-b on cap-exhausted fixture returned ${RC}; expected 10 (stderr: $(tr '\n' ' ' < "${CASE3_ERR}"))"
assert_yaml_field "${CASE3_OUT}" "exit_status" "trigger-4"
# rounds_consumed should equal the configured cap (default 3)
assert_yaml_field "${CASE3_OUT}" "rounds_consumed" "3"
grep -q '^last_arbiter_verdict_path:' "${CASE3_OUT}" \
  || violation "phase-b on cap-exhausted should emit last_arbiter_verdict_path; got: $(tr '\n' ' ' < "${CASE3_OUT}")"

exit 0
