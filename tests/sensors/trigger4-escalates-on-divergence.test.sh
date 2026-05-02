#!/usr/bin/env bash
# shellcheck shell=bash
#
# trigger4-escalates-on-divergence.test.sh — Sprint 02 / Task t04 / AC Scenario 9 + FR-3.
#
# Engineers a cap-exhausted council fixture and asserts:
#
#   1. lib/runtime/council.sh phase-b on the fixture exits 10 (trigger-4)
#      and emits a YAML summary with exit_status: trigger-4.
#   2. lib/runtime/trigger-4.sh render against the merged view + the
#      fixture's last-arbiter-verdict.json produces a markdown message
#      that contains:
#         - both flagged persona pairs (sr-eng × sr-qa, sr-qa × sr-staff)
#         - the arbiter verdict summary line (consensus=false ...)
#         - the directive line (`ratify` + `rework needed`)
#   3. lib/ralph-loop/escalate.sh --reason divergence
#      --council-merged-view <merged> --council-arbiter-verdict <verdict>
#      writes a Trigger-4 packet that references the rendered message
#      via council_message_path.
#
# Test contract (binding for this file):
#   - exit 0 when every documented case behaves as specified.
#   - exit non-zero with a `wm: trigger4-sensor violation:`-prefixed
#     stderr line naming the failing case otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
COUNCIL_HELPER="${REPO_ROOT}/lib/runtime/council.sh"
TRIGGER_HELPER="${REPO_ROOT}/lib/runtime/trigger-4.sh"
MERGE_HELPER="${REPO_ROOT}/lib/runtime/council-merge.sh"
ESCALATE="${REPO_ROOT}/lib/ralph-loop/escalate.sh"
FIXTURE="${REPO_ROOT}/tests/runtime/fixtures/trigger4-two-pairs-divergent"

violation() {
  printf 'wm: trigger4-sensor violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "${COUNCIL_HELPER}" ]] || violation "council helper missing"
[[ -f "${TRIGGER_HELPER}" ]] || violation "trigger-4 helper missing"
[[ -f "${MERGE_HELPER}" ]] || violation "council-merge helper missing"
[[ -f "${ESCALATE}" ]] || violation "escalate.sh missing"
[[ -d "${FIXTURE}" ]] || violation "trigger4 fixture missing"
[[ -f "${FIXTURE}/last-arbiter-verdict.json" ]] || violation "fixture last-arbiter-verdict.json missing"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Step 1: produce the merged view.
MERGED="${TMP_DIR}/merged-view.md"
bash "${MERGE_HELPER}" merge "${FIXTURE}" >"${MERGED}"
[[ -s "${MERGED}" ]] || violation "merged view is empty"

# Step 2: render Trigger 4 message.
RENDERED="${TMP_DIR}/trigger4-message.md"
RC=0
YOKE_COUNCIL_ROUND_CAP=3 \
  bash "${TRIGGER_HELPER}" render "${MERGED}" "${FIXTURE}/last-arbiter-verdict.json" "${RENDERED}" \
    >/dev/null 2>"${TMP_DIR}/render.err" || RC=$?
[[ "${RC}" == "0" ]] \
  || violation "trigger-4 render returned ${RC}; expected 0 (stderr: $(tr '\n' ' ' < "${TMP_DIR}/render.err"))"
[[ -s "${RENDERED}" ]] || violation "rendered message is empty"

# Required content checks
grep -Fq 'sr-eng × sr-qa' "${RENDERED}" \
  || violation "rendered message missing 'sr-eng × sr-qa' (got: $(head -n 30 "${RENDERED}" | tr '\n' ' '))"
grep -Fq 'sr-qa × sr-staff' "${RENDERED}" \
  || violation "rendered message missing 'sr-qa × sr-staff' (got: $(head -n 30 "${RENDERED}" | tr '\n' ' '))"
grep -Fq 'consensus=false' "${RENDERED}" \
  || violation "rendered message missing 'consensus=false' summary"
grep -Fq 'direct-contradiction' "${RENDERED}" \
  || violation "rendered message missing 'direct-contradiction' label"
grep -Fq 'importance-disagreement' "${RENDERED}" \
  || violation "rendered message missing 'importance-disagreement' label"
grep -Fq 'ratify' "${RENDERED}" \
  || violation "rendered message missing the 'ratify' directive token"
grep -Fq 'rework needed' "${RENDERED}" \
  || violation "rendered message missing the 'rework needed' directive token"

# Step 3: escalate.sh writes a Trigger-4 packet referencing the rendered message.
PACKET_DIR="${TMP_DIR}/packet-dir"
mkdir -p "${PACKET_DIR}/.yoke/runtime"
# escalate.sh expects to run inside a .yoke/-rooted dir; cd there.
PUSHD_PWD="$(pwd)"
cd "${PACKET_DIR}"
RC=0
bash "${ESCALATE}" \
  --reason divergence \
  --category quality-policies-broken \
  --council-merged-view "${MERGED}" \
  --council-arbiter-verdict "${FIXTURE}/last-arbiter-verdict.json" \
  >"${TMP_DIR}/packet.out" 2>"${TMP_DIR}/packet.err" || RC=$?
cd "${PUSHD_PWD}"
[[ "${RC}" == "0" ]] \
  || violation "escalate.sh returned ${RC}; expected 0 (stderr: $(tr '\n' ' ' < "${TMP_DIR}/packet.err"))"
PACKET_FILE="${PACKET_DIR}/.yoke/runtime/.trigger4-packet.yaml"
[[ -f "${PACKET_FILE}" ]] || violation "Trigger-4 packet not written at ${PACKET_FILE}"
grep -q '^trigger: 4$' "${PACKET_FILE}" \
  || violation "packet missing 'trigger: 4' line"
grep -q '^reason: divergence$' "${PACKET_FILE}" \
  || violation "packet missing 'reason: divergence' line"
grep -q '^council_message_path:' "${PACKET_FILE}" \
  || violation "packet missing council_message_path field (got: $(grep -E '^[a-z_]+:' "${PACKET_FILE}" | tr '\n' ' '))"
grep -q '^council_merged_view_path:' "${PACKET_FILE}" \
  || violation "packet missing council_merged_view_path field"
grep -q '^council_arbiter_verdict_path:' "${PACKET_FILE}" \
  || violation "packet missing council_arbiter_verdict_path field"

# Step 4: phase-b against the cap-exhausted upstream fixture surfaces trigger-4.
ARBITER_STUB="${TMP_DIR}/arbiter-stub.sh"
cat >"${ARBITER_STUB}" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
round="$2"
printf '{"round": %s, "consensus": false, "contradictions": [{"personas": ["sr-eng","sr-qa"], "summary": "force trigger-4", "evidence": "stub", "category": "direct-contradiction"}], "tone_only_pairs": []}\n' "$round"
STUB
chmod +x "${ARBITER_STUB}"

PHASE_B_CYCLE_DIR="${TMP_DIR}/phase-b-cycle"
mkdir -p "${PHASE_B_CYCLE_DIR}"
cp "${REPO_ROOT}/tests/runtime/fixtures/phase-b-cap-exhausted/sr-eng.md"   "${PHASE_B_CYCLE_DIR}/sr-eng.md"
cp "${REPO_ROOT}/tests/runtime/fixtures/phase-b-cap-exhausted/sr-qa.md"    "${PHASE_B_CYCLE_DIR}/sr-qa.md"
cp "${REPO_ROOT}/tests/runtime/fixtures/phase-b-cap-exhausted/sr-staff.md" "${PHASE_B_CYCLE_DIR}/sr-staff.md"

PHASE_B_OUT="${TMP_DIR}/phase-b.out"
RC=0
YOKE_ARBITER_CMD="${ARBITER_STUB}" \
  bash "${COUNCIL_HELPER}" phase-b "test-slug" "0" "${PHASE_B_CYCLE_DIR}" \
    >"${PHASE_B_OUT}" 2>/dev/null || RC=$?
[[ "${RC}" == "10" ]] || violation "phase-b on cap-exhausted fixture returned ${RC}; expected 10"
grep -q '^exit_status: trigger-4$' "${PHASE_B_OUT}" \
  || violation "phase-b output missing 'exit_status: trigger-4' (got: $(tr '\n' ' ' < "${PHASE_B_OUT}"))"

exit 0
