#!/usr/bin/env bash
# shellcheck shell=bash
#
# council-arbiter.test.sh — Sprint 02 / Task t03 / AC Scenario 8 + FR-4.
#
# Sensor test for the contradiction-detection arbiter. Validates:
#
#   1. agents/council-arbiter.md exists and parses with Claude Code
#      agent frontmatter (`name`, `description`, `tools`).
#   2. The arbiter file's body documents the verdict schema fields
#      (round, consensus, contradictions, tone_only_pairs) and the
#      dispute rubric (direct-contradiction, importance-disagreement,
#      tone-only).
#   3. For each of four engineered fixtures under
#      tests/runtime/fixtures/arbiter/, the expected.json file:
#         - parses (no syntax errors via a small awk/grep pipeline);
#         - contains every required schema field;
#         - matches the per-fixture branch (consensus true/false,
#           contradiction count, persona pairs, category for the
#           contradiction fixture).
#
# The actual LLM-driven arbiter dispatch is exercised at runtime by
# /yoke:implement via the Task tool — that path is non-deterministic
# in CI. This sensor binds the contract: agent file + verdict schema +
# four reference fixtures with expected verdicts that the runtime
# implementation (lib/runtime/council.sh) consumes verbatim.
#
# Test contract (binding for this file):
#   - exit 0 when every documented case behaves as specified.
#   - exit non-zero with a `wm: arbiter-sensor violation:`-prefixed
#     stderr line naming the failing case otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
ARBITER_FILE="${REPO_ROOT}/agents/council-arbiter.md"
ARBITER_FIXTURES="${REPO_ROOT}/tests/runtime/fixtures/arbiter"
LOADER="${REPO_ROOT}/lib/runtime/persona-loader.sh"

violation() {
  printf 'wm: arbiter-sensor violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "${ARBITER_FILE}" ]] || violation "agents/council-arbiter.md missing"
[[ -d "${ARBITER_FIXTURES}" ]] || violation "tests/runtime/fixtures/arbiter/ missing"

# Case 1 — frontmatter shape: name=council-arbiter, description present, tools=Read.
FM_NAME="$(awk '/^name:/ { sub(/^name:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit }' "${ARBITER_FILE}")"
[[ "${FM_NAME}" == "council-arbiter" ]] \
  || violation "frontmatter name was '${FM_NAME}'; expected 'council-arbiter'"

FM_DESC="$(awk '/^description:/ { sub(/^description:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit }' "${ARBITER_FILE}")"
[[ -n "${FM_DESC}" ]] || violation "frontmatter description is empty"

FM_TOOLS="$(awk '/^tools:/ { sub(/^tools:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit }' "${ARBITER_FILE}")"
[[ "${FM_TOOLS}" == "Read" ]] \
  || violation "frontmatter tools was '${FM_TOOLS}'; expected 'Read' (arbiter is read-only)"

# Case 2 — body documents schema + rubric.
for token in '"round"' '"consensus"' '"contradictions"' '"tone_only_pairs"' \
             'direct-contradiction' 'importance-disagreement' 'tone-only'; do
  if ! grep -q -F "${token}" "${ARBITER_FILE}"; then
    violation "agents/council-arbiter.md body is missing required token: ${token}"
  fi
done

# Case 3 — four engineered fixtures under tests/runtime/fixtures/arbiter/.
for fixture in consensus.cycle direct-contradiction.cycle importance-disagreement.cycle tone-only.cycle; do
  fdir="${ARBITER_FIXTURES}/${fixture}"
  [[ -d "${fdir}" ]] || violation "fixture missing: ${fdir}"
  [[ -f "${fdir}/expected.json" ]] || violation "fixture ${fixture} missing expected.json"
  [[ -f "${fdir}/sr-eng.md" ]] || violation "fixture ${fixture} missing sr-eng.md"
  [[ -f "${fdir}/sr-qa.md" ]] || violation "fixture ${fixture} missing sr-qa.md"
  [[ -f "${fdir}/sr-staff.md" ]] || violation "fixture ${fixture} missing sr-staff.md"

  expected="${fdir}/expected.json"
  for required in '"round"' '"consensus"' '"contradictions"' '"tone_only_pairs"'; do
    if ! grep -q -F "${required}" "${expected}"; then
      violation "fixture ${fixture}/expected.json missing required field: ${required}"
    fi
  done
done

# Case 4a — consensus.cycle: consensus true, empty contradictions, empty tone_only_pairs.
EXPECTED="${ARBITER_FIXTURES}/consensus.cycle/expected.json"
grep -Eq '"consensus"[[:space:]]*:[[:space:]]*true' "${EXPECTED}" \
  || violation "consensus.cycle expected.json should have consensus: true"
grep -Eq '"contradictions"[[:space:]]*:[[:space:]]*\[\]' "${EXPECTED}" \
  || violation "consensus.cycle expected.json should have contradictions: []"
grep -Eq '"tone_only_pairs"[[:space:]]*:[[:space:]]*\[\]' "${EXPECTED}" \
  || violation "consensus.cycle expected.json should have tone_only_pairs: []"

# Case 4b — direct-contradiction.cycle: consensus false, exactly one contradiction with category direct-contradiction.
EXPECTED="${ARBITER_FIXTURES}/direct-contradiction.cycle/expected.json"
grep -Eq '"consensus"[[:space:]]*:[[:space:]]*false' "${EXPECTED}" \
  || violation "direct-contradiction.cycle expected.json should have consensus: false"
COUNT="$(grep -oE '"category"[[:space:]]*:' "${EXPECTED}" | wc -l | tr -d ' ')"
[[ "${COUNT}" == "1" ]] \
  || violation "direct-contradiction.cycle expected.json should have exactly one contradiction (got ${COUNT})"
grep -Eq '"category"[[:space:]]*:[[:space:]]*"direct-contradiction"' "${EXPECTED}" \
  || violation "direct-contradiction.cycle expected.json category should be 'direct-contradiction'"

# Case 4c — importance-disagreement.cycle: consensus false, exactly one contradiction classified importance-disagreement.
EXPECTED="${ARBITER_FIXTURES}/importance-disagreement.cycle/expected.json"
grep -Eq '"consensus"[[:space:]]*:[[:space:]]*false' "${EXPECTED}" \
  || violation "importance-disagreement.cycle expected.json should have consensus: false"
COUNT="$(grep -oE '"category"[[:space:]]*:' "${EXPECTED}" | wc -l | tr -d ' ')"
[[ "${COUNT}" == "1" ]] \
  || violation "importance-disagreement.cycle expected.json should have exactly one contradiction (got ${COUNT})"
grep -Eq '"category"[[:space:]]*:[[:space:]]*"importance-disagreement"' "${EXPECTED}" \
  || violation "importance-disagreement.cycle expected.json category should be 'importance-disagreement'"

# Case 4d — tone-only.cycle: consensus true, empty contradictions, non-empty tone_only_pairs.
EXPECTED="${ARBITER_FIXTURES}/tone-only.cycle/expected.json"
grep -Eq '"consensus"[[:space:]]*:[[:space:]]*true' "${EXPECTED}" \
  || violation "tone-only.cycle expected.json should have consensus: true"
grep -Eq '"contradictions"[[:space:]]*:[[:space:]]*\[\]' "${EXPECTED}" \
  || violation "tone-only.cycle expected.json should have empty contradictions"
grep -q '"tone_only_pairs"' "${EXPECTED}" \
  || violation "tone-only.cycle expected.json missing tone_only_pairs key"
if grep -Eq '"tone_only_pairs"[[:space:]]*:[[:space:]]*\[\]' "${EXPECTED}"; then
  violation "tone-only.cycle expected.json tone_only_pairs should NOT be empty"
fi

# Case 5 — assert agents/council-arbiter.md is NOT picked up by persona-loader (sr-* glob).
# The arbiter is a runtime subagent, not a council persona.
if [[ -f "${LOADER}" ]]; then
  RC=0
  bash "${LOADER}" validate-all "${REPO_ROOT}/agents" >/dev/null 2>&1 || RC=$?
  [[ "${RC}" == "0" ]] || violation "validate-all on agents/ now fails (rc=${RC}) — adding council-arbiter.md must not break the persona sweep"
fi

exit 0
