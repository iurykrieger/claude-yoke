#!/usr/bin/env bash
# shellcheck shell=bash
#
# council-cycle-end-to-end.test.sh — Sprint 02 / AC Scenarios 6+7+8+9.
#
# End-to-end smoke for the v3.0 council protocol. Drives the dogfood
# fixture cycle through the runtime helpers (cycle.sh + council.sh +
# trigger-4.sh) end-to-end without spawning real Claude Code Tasks.
# The smoke covers two flows:
#
#   Flow A — consensus path: every persona stub writes a slice with
#            an empty Phase B round 1 réplica → council.sh exits with
#            consensus on round 1 (quiescence). Trigger 4 does not fire.
#
#   Flow B — divergence path: persona stubs encode unresolved
#            contradictions across all three rounds → council.sh exits
#            10 (trigger-4); trigger-4.sh render produces an escalation
#            message containing every flagged persona pair; escalate.sh
#            writes a Trigger-4 packet referencing the rendered message.
#
# Watchdog: the mandatory `sleep 600 && kill -TERM $$ &` guard per
# concepts/yoke-conventions caps the smoke at 10 minutes. The test
# completes deterministically in well under a second on real hardware;
# the watchdog is the safety net for ralph-loop iterations or
# subagent fan-out without hard bounds.
#
# Test contract (binding):
#   - exit 0 when both flows behave as specified.
#   - exit non-zero with `wm: council-smoke violation:`-prefixed
#     stderr line naming the failing flow otherwise.

set -euo pipefail

# Watchdog (concepts/yoke-conventions: smoke tests must use this guard).
sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM '"${WATCHDOG_PID}"' 2>/dev/null || true' EXIT

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

CYCLE_HELPER="${REPO_ROOT}/lib/runtime/cycle.sh"
COUNCIL_HELPER="${REPO_ROOT}/lib/runtime/council.sh"
TRIGGER_HELPER="${REPO_ROOT}/lib/runtime/trigger-4.sh"
MERGE_HELPER="${REPO_ROOT}/lib/runtime/council-merge.sh"
ESCALATE="${REPO_ROOT}/lib/ralph-loop/escalate.sh"
AGENTS_DIR="${REPO_ROOT}/agents"

violation() {
  printf 'wm: council-smoke violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "${CYCLE_HELPER}" ]] || violation "cycle.sh missing"
[[ -f "${COUNCIL_HELPER}" ]] || violation "council.sh missing"
[[ -f "${TRIGGER_HELPER}" ]] || violation "trigger-4.sh missing"
[[ -f "${MERGE_HELPER}" ]] || violation "council-merge.sh missing"
[[ -f "${ESCALATE}" ]] || violation "escalate.sh missing"
[[ -f "${AGENTS_DIR}/council-arbiter.md" ]] || violation "agents/council-arbiter.md missing"

TMP_DIR="$(mktemp -d)"
trap 'kill -TERM '"${WATCHDOG_PID}"' 2>/dev/null || true; rm -rf "'"${TMP_DIR}"'"' EXIT

SLUG="2026-05-01-agent-council"

# --- Flow A — consensus on quiescence ---------------------------------------

FLOW_A_DIR="${TMP_DIR}/flow-a"
FLOW_A_CYCLE_DIR="${FLOW_A_DIR}/.yoke/runtime/cycles/0"
FLOW_A_MARKER_DIR="${FLOW_A_DIR}/.yoke/runtime"
mkdir -p "${FLOW_A_CYCLE_DIR}" "${FLOW_A_MARKER_DIR}"

# Phase A pre-spawn: clear markers + validate persona files + emit list.
RC=0
PERSONAS="$(YOKE_AGENTS_DIR="${AGENTS_DIR}" \
            YOKE_MARKER_DIR="${FLOW_A_MARKER_DIR}" \
            bash "${CYCLE_HELPER}" pre-spawn "${SLUG}" "0")" \
  || RC=$?
[[ "${RC}" == "0" ]] || violation "Flow A pre-spawn returned ${RC}; expected 0"
[[ "${PERSONAS}" == "sr-eng
sr-qa
sr-staff" ]] || violation "Flow A pre-spawn persona list wrong: ${PERSONAS}"

# Spawn-equivalent: write a slice + marker per persona (as the SKILL.md
# Phase A persona Tasks would do under real /yoke:implement).
for persona in sr-eng sr-qa sr-staff; do
  cat >"${FLOW_A_CYCLE_DIR}/${persona}.md" <<EOF
---
author: ${persona}
cycle: 0
phase: b
---

## Phase A — own progress

author: ${persona}

- file: tests/smoke/council-cycle-end-to-end.test.sh
- intent: end-to-end smoke fixture for the council consensus path

## Phase B round 1 — readings

Read sr-eng, sr-qa, sr-staff slices. Consistent with own progress.

## Phase B round 1 — réplica

<!-- empty: no objection -->
EOF
  : >"${FLOW_A_MARKER_DIR}/.phase-a-done.${persona}"
done

# Phase A post-spawn: defensive wait-all.
RC=0
YOKE_AGENTS_DIR="${AGENTS_DIR}" \
  YOKE_MARKER_DIR="${FLOW_A_MARKER_DIR}" \
  YOKE_BARRIER_POLL_INTERVAL=0.05 \
  YOKE_BARRIER_TIMEOUT_SECONDS=2 \
  bash "${CYCLE_HELPER}" post-spawn "${SLUG}" "0" >/dev/null 2>"${TMP_DIR}/a-post.err" || RC=$?
[[ "${RC}" == "0" ]] || violation "Flow A post-spawn returned ${RC} (stderr: $(tr '\n' ' ' < "${TMP_DIR}/a-post.err"))"

# Phase B: stub arbiter is irrelevant here (zero réplicas → quiescence).
ARBITER_STUB="${TMP_DIR}/arbiter-stub.sh"
cat >"${ARBITER_STUB}" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '{"round": %s, "consensus": false, "contradictions": [{"personas": ["sr-eng","sr-qa"], "summary": "stub", "evidence": "stub", "category": "direct-contradiction"}], "tone_only_pairs": []}\n' "$2"
STUB
chmod +x "${ARBITER_STUB}"

FLOW_A_OUT="${TMP_DIR}/flow-a-phase-b.out"
RC=0
YOKE_ARBITER_CMD="${ARBITER_STUB}" \
  bash "${COUNCIL_HELPER}" phase-b "${SLUG}" "0" "${FLOW_A_CYCLE_DIR}" \
    >"${FLOW_A_OUT}" 2>/dev/null || RC=$?
[[ "${RC}" == "0" ]] || violation "Flow A phase-b returned ${RC}; expected 0 (consensus)"
grep -q '^exit_status: consensus$' "${FLOW_A_OUT}" \
  || violation "Flow A phase-b output missing exit_status: consensus"

# --- Flow B — divergence on cap exhausted -----------------------------------

FLOW_B_DIR="${TMP_DIR}/flow-b"
FLOW_B_CYCLE_DIR="${FLOW_B_DIR}/.yoke/runtime/cycles/0"
FLOW_B_MARKER_DIR="${FLOW_B_DIR}/.yoke/runtime"
mkdir -p "${FLOW_B_CYCLE_DIR}" "${FLOW_B_MARKER_DIR}"

# Reuse the cap-exhausted fixture for the divergent persona slices.
cp "${REPO_ROOT}/tests/runtime/fixtures/phase-b-cap-exhausted/sr-eng.md"   "${FLOW_B_CYCLE_DIR}/sr-eng.md"
cp "${REPO_ROOT}/tests/runtime/fixtures/phase-b-cap-exhausted/sr-qa.md"    "${FLOW_B_CYCLE_DIR}/sr-qa.md"
cp "${REPO_ROOT}/tests/runtime/fixtures/phase-b-cap-exhausted/sr-staff.md" "${FLOW_B_CYCLE_DIR}/sr-staff.md"
for persona in sr-eng sr-qa sr-staff; do
  : >"${FLOW_B_MARKER_DIR}/.phase-a-done.${persona}"
done

FLOW_B_OUT="${TMP_DIR}/flow-b-phase-b.out"
RC=0
YOKE_ARBITER_CMD="${ARBITER_STUB}" \
  bash "${COUNCIL_HELPER}" phase-b "${SLUG}" "0" "${FLOW_B_CYCLE_DIR}" \
    >"${FLOW_B_OUT}" 2>/dev/null || RC=$?
[[ "${RC}" == "10" ]] || violation "Flow B phase-b returned ${RC}; expected 10 (trigger-4)"
grep -q '^exit_status: trigger-4$' "${FLOW_B_OUT}" \
  || violation "Flow B phase-b output missing exit_status: trigger-4"
LAST_VERDICT_PATH="$(grep -E '^last_arbiter_verdict_path:' "${FLOW_B_OUT}" | sed -E 's/.*"(.+)"/\1/')"
[[ -n "${LAST_VERDICT_PATH}" ]] || violation "Flow B phase-b missing last_arbiter_verdict_path"
[[ -f "${LAST_VERDICT_PATH}" ]] || violation "Flow B last arbiter verdict file missing at ${LAST_VERDICT_PATH}"

# Render the council Trigger 4 message.
MERGED="${TMP_DIR}/flow-b-merged.md"
bash "${MERGE_HELPER}" merge "${FLOW_B_CYCLE_DIR}" >"${MERGED}"
RENDERED="${TMP_DIR}/flow-b-trigger4.md"
RC=0
YOKE_COUNCIL_ROUND_CAP=3 \
  bash "${TRIGGER_HELPER}" render "${MERGED}" "${LAST_VERDICT_PATH}" "${RENDERED}" \
    >/dev/null 2>"${TMP_DIR}/render.err" || RC=$?
[[ "${RC}" == "0" ]] || violation "Flow B trigger-4 render returned ${RC} (stderr: $(tr '\n' ' ' < "${TMP_DIR}/render.err"))"
grep -Fq 'sr-eng × sr-qa' "${RENDERED}" \
  || violation "Flow B rendered escalation missing 'sr-eng × sr-qa' pair"
grep -Fq 'consensus=false' "${RENDERED}" \
  || violation "Flow B rendered escalation missing arbiter summary 'consensus=false'"
grep -Fq 'ratify' "${RENDERED}" \
  || violation "Flow B rendered escalation missing the 'ratify' directive"

# Escalate writes the Trigger-4 packet.
PACKET_DIR="${TMP_DIR}/flow-b-packet"
mkdir -p "${PACKET_DIR}/.yoke/runtime"
PUSHD_PWD="$(pwd)"
cd "${PACKET_DIR}"
RC=0
bash "${ESCALATE}" \
  --reason divergence \
  --category quality-policies-broken \
  --council-merged-view "${MERGED}" \
  --council-arbiter-verdict "${LAST_VERDICT_PATH}" \
  >/dev/null 2>"${TMP_DIR}/packet.err" || RC=$?
cd "${PUSHD_PWD}"
[[ "${RC}" == "0" ]] || violation "Flow B escalate.sh returned ${RC}"
PACKET_FILE="${PACKET_DIR}/.yoke/runtime/.trigger4-packet.yaml"
[[ -f "${PACKET_FILE}" ]] || violation "Flow B Trigger-4 packet not written"
grep -q '^trigger: 4$' "${PACKET_FILE}" || violation "Flow B packet missing 'trigger: 4'"
grep -q '^reason: divergence$' "${PACKET_FILE}" || violation "Flow B packet missing 'reason: divergence'"

exit 0
