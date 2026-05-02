#!/usr/bin/env bash
# shellcheck shell=bash
#
# round-cap-config.test.sh — Sprint 02 / Task t02 / AC Scenario 7 + FR-3.
#
# Asserts that `lib/runtime/council.sh` honors the
# `overrides.runtime.council_rounds_max` value in `.yoke/config.yaml`,
# defaulting to 3 when absent.
#
# Test contract (binding):
#   - `council.sh round-cap` against an absent config returns 3.
#   - `council.sh round-cap` against a config with the override set to 1
#     returns 1.
#   - `council.sh round-cap` against a config with the override set to 5
#     returns 5.
#   - When the round cap is 1 and the cap-exhausted fixture is driven
#     through `phase-b`, rounds_consumed is exactly 1.
#   - When the round cap is 5 and the cap-exhausted fixture is driven
#     through `phase-b`, rounds_consumed is exactly 5.
#
# On any failure: emit `wm: round-cap-test violation:` stderr line and exit non-zero.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
HELPER="${REPO_ROOT}/lib/runtime/council.sh"
FIXTURES_DIR="${REPO_ROOT}/tests/runtime/fixtures"

violation() {
  printf 'wm: round-cap-test violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "${HELPER}" ]] || violation "council helper missing at ${HELPER}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Case 1 — default 3 when no config present.
RC=0
DEFAULT_CAP="$(YOKE_CONFIG_PATH="${TMP_DIR}/no-such-config.yaml" \
  bash "${HELPER}" round-cap)" || RC=$?
[[ "${RC}" == "0" ]] || violation "round-cap returned ${RC} on absent config; expected 0"
DEFAULT_CAP="$(printf '%s' "${DEFAULT_CAP}" | tr -d '[:space:]')"
[[ "${DEFAULT_CAP}" == "3" ]] || violation "round-cap on absent config was '${DEFAULT_CAP}'; expected 3"

# Case 2 — override to 1.
CONFIG_1="${TMP_DIR}/config-1.yaml"
cat >"${CONFIG_1}" <<'EOF'
yoke_version: "2.0.0"
overrides:
  runtime:
    council_rounds_max: 1
EOF
CAP_1="$(YOKE_CONFIG_PATH="${CONFIG_1}" bash "${HELPER}" round-cap)"
CAP_1="$(printf '%s' "${CAP_1}" | tr -d '[:space:]')"
[[ "${CAP_1}" == "1" ]] || violation "round-cap with override=1 was '${CAP_1}'; expected 1"

# Case 3 — override to 5.
CONFIG_5="${TMP_DIR}/config-5.yaml"
cat >"${CONFIG_5}" <<'EOF'
yoke_version: "2.0.0"
overrides:
  runtime:
    council_rounds_max: 5
EOF
CAP_5="$(YOKE_CONFIG_PATH="${CONFIG_5}" bash "${HELPER}" round-cap)"
CAP_5="$(printf '%s' "${CAP_5}" | tr -d '[:space:]')"
[[ "${CAP_5}" == "5" ]] || violation "round-cap with override=5 was '${CAP_5}'; expected 5"

# Case 4 — phase-b respects override=1 (loop hits cap after exactly 1 round).
ARBITER_STUB="${TMP_DIR}/arbiter-stub.sh"
cat >"${ARBITER_STUB}" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
round="$2"
printf '{"round": %s, "consensus": false, "contradictions": [{"personas": ["sr-eng","sr-qa"], "summary": "force trigger-4", "evidence": "stub", "category": "direct-contradiction"}], "tone_only_pairs": []}\n' "$round"
STUB
chmod +x "${ARBITER_STUB}"

CASE4_CYCLE_DIR="${TMP_DIR}/case4-cycle"
mkdir -p "${CASE4_CYCLE_DIR}"
cp "${FIXTURES_DIR}/phase-b-cap-exhausted/sr-eng.md" "${CASE4_CYCLE_DIR}/sr-eng.md"
cp "${FIXTURES_DIR}/phase-b-cap-exhausted/sr-qa.md" "${CASE4_CYCLE_DIR}/sr-qa.md"
cp "${FIXTURES_DIR}/phase-b-cap-exhausted/sr-staff.md" "${CASE4_CYCLE_DIR}/sr-staff.md"

CASE4_OUT="${TMP_DIR}/case4.out"
RC=0
YOKE_CONFIG_PATH="${CONFIG_1}" \
  YOKE_ARBITER_CMD="${ARBITER_STUB}" \
  bash "${HELPER}" phase-b "test-slug" "0" "${CASE4_CYCLE_DIR}" \
    >"${CASE4_OUT}" 2>/dev/null || RC=$?
[[ "${RC}" == "10" ]] || violation "phase-b on cap=1 returned ${RC}; expected 10 (trigger-4)"
ROUNDS_CONSUMED="$(grep -E '^rounds_consumed:' "${CASE4_OUT}" | sed -E 's/.*: //; s/[[:space:]]+$//')"
[[ "${ROUNDS_CONSUMED}" == "1" ]] || violation "phase-b on cap=1 consumed ${ROUNDS_CONSUMED} rounds; expected 1"

# Case 5 — phase-b respects override=5 (loop hits cap after exactly 5 rounds).
CASE5_CYCLE_DIR="${TMP_DIR}/case5-cycle"
mkdir -p "${CASE5_CYCLE_DIR}"
# Build a slice file that has réplica sections for rounds 1..5.
for persona in sr-eng sr-qa sr-staff; do
  {
    printf -- '---\nauthor: %s\ncycle: 0\nphase: b\n---\n\n' "${persona}"
    printf -- '## Phase A — own progress\n\nauthor: %s\n\n' "${persona}"
    for r in 1 2 3 4 5; do
      printf -- '## Phase B round %s — readings\n\nRound %s readings.\n\n' "${r}" "${r}"
      printf -- '## Phase B round %s — réplica\n\nRound %s replica from %s.\n\n' "${r}" "${r}" "${persona}"
    done
  } > "${CASE5_CYCLE_DIR}/${persona}.md"
done

CASE5_OUT="${TMP_DIR}/case5.out"
RC=0
YOKE_CONFIG_PATH="${CONFIG_5}" \
  YOKE_ARBITER_CMD="${ARBITER_STUB}" \
  bash "${HELPER}" phase-b "test-slug" "0" "${CASE5_CYCLE_DIR}" \
    >"${CASE5_OUT}" 2>/dev/null || RC=$?
[[ "${RC}" == "10" ]] || violation "phase-b on cap=5 returned ${RC}; expected 10"
ROUNDS_CONSUMED="$(grep -E '^rounds_consumed:' "${CASE5_OUT}" | sed -E 's/.*: //; s/[[:space:]]+$//')"
[[ "${ROUNDS_CONSUMED}" == "5" ]] || violation "phase-b on cap=5 consumed ${ROUNDS_CONSUMED} rounds; expected 5"

exit 0
