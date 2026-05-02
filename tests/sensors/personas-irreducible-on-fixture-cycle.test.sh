#!/usr/bin/env bash
# shellcheck shell=bash
#
# personas-irreducible-on-fixture-cycle.test.sh — Sprint 03 / FR-5.
#
# This is the sensor test for the inferential gating sensor
# `personas-irreducible-on-fixture` (referenced by Acceptance Contract
# FR-5 and by Sprint 03 task t01/t02/t03). The sensor proper is an
# inferential judge that scores each persona's slice on a binary basis
# (irreducible / prompt-tweak-equivalent); this *test* validates the
# structural floor that makes that judgement possible: the engineered
# fixture under `tests/runtime/fixtures/realistic-task/` carries three
# slices, each surfacing at least one finding from a lens the v2.x
# Generator/Validator prompt-tweak runtime provably could not produce
# without code changes (not just a prompt swap).
#
# The structural floor consists of:
#
#   - Sr Eng's slice carries `- file:` lines under `## Phase A — own
#     progress` AND mentions a unit-test path under `tests/runtime/` or
#     `tests/sensors/` AND does NOT reference `tests/acceptance/` (the
#     unit-tests-only discipline the v2.x Generator did not enforce
#     because the v2.x Generator wrote only progress.md, never tests).
#
#   - Sr QA's slice carries a `tests_authored:` block listing files
#     under `tests/acceptance/<contract-slug>/` AND emits one verdict
#     per criterion with the `criterion`/`status`/`fix_instruction`/
#     `sensor`/`evidence` shape (the contract-anchored test discipline
#     the v2.x Validator could not produce by prompt tweak — the v2.x
#     Validator emits judge-verdicts, not tests).
#
#   - Sr Staff's slice carries exactly one `### Review output`
#     subsection AND ≥ 1 `/yoke:search-canonical-memory` query record
#     AND ≥ 1 `concepts/yoke-pattern-...` citation AND zero
#     `/ultrareview` tokens (the review-skill + canonical-memory +
#     long-term-sustainability lens is genuinely new in v3.0; the v2.x
#     Orchestrator-monitor mode did not invoke a review-skill).
#
# Test contract (binding for this file):
#   - exit 0 when all three structural-floor assertions hold.
#   - exit non-zero with a `wm: personas-irreducible-on-fixture-cycle violation:`-prefixed
#     stderr line naming the offending persona + missing piece otherwise.
#
# Discovery: this test is the structural backbone of the
# `personas-irreducible-on-fixture` sensor cited by Acceptance Contract
# FR-5 (`### Validation` block, `tests-runtime` and `code-review` sub-
# bullets). The inferential `llm-as-judge` sub-bullet is an orthogonal
# semantic check.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
FIXTURE_DIR="${REPO_ROOT}/tests/runtime/fixtures/realistic-task"

violation() {
  printf 'wm: personas-irreducible-on-fixture-cycle violation: %s\n' "$1" >&2
  exit 1
}

[[ -d "${FIXTURE_DIR}" ]] \
  || violation "fixture directory missing at ${FIXTURE_DIR}"

# ---- Sr Eng slice assertions --------------------------------------------------
SR_ENG="${FIXTURE_DIR}/sr-eng.md"
[[ -f "${SR_ENG}" ]] \
  || violation "sr-eng: slice missing at ${SR_ENG}"

ENG_FILE_LINES="$(grep -cE '^- file:' "${SR_ENG}" || true)"
if [[ "${ENG_FILE_LINES}" -lt 1 ]]; then
  violation "sr-eng: expected ≥ 1 '- file:' line under '## Phase A — own progress'; found ${ENG_FILE_LINES}"
fi

# Names a unit-test path.
if ! grep -qE 'tests/(runtime|sensors|[a-z0-9-]+)/[^[:space:]]+\.test\.sh' "${SR_ENG}"; then
  violation "sr-eng: slice does not name any unit-test path under tests/runtime/ or tests/sensors/"
fi

# Does NOT reference tests/acceptance/ (Sr-Eng anti-scope).
if grep -q 'tests/acceptance/' "${SR_ENG}"; then
  violation "sr-eng: slice references tests/acceptance/ — anti-scope violation (acceptance tests are Sr QA's lane)"
fi

# ---- Sr QA slice assertions ---------------------------------------------------
SR_QA="${FIXTURE_DIR}/sr-qa.md"
[[ -f "${SR_QA}" ]] \
  || violation "sr-qa: slice missing at ${SR_QA}"

QA_TESTS_AUTHORED="$(grep -cE '^\s*-\s+tests/acceptance/[^/]+/[^/]+\.test\.sh\s*$' "${SR_QA}" || true)"
if [[ "${QA_TESTS_AUTHORED}" -lt 3 ]]; then
  violation "sr-qa: expected ≥ 3 acceptance-contract-anchored test entries under tests/acceptance/<slug>/; found ${QA_TESTS_AUTHORED}"
fi

# Per-criterion verdict shape (criterion / status / fix_instruction).
# Each field may appear as a YAML scalar (`<key>:`) or as the first
# entry of a YAML list item (`- <key>:`); accept either shape.
for field in 'criterion:' 'status:' 'fix_instruction:' 'sensor:' 'evidence:'; do
  if ! grep -qE "^\s*-?\s*${field}" "${SR_QA}"; then
    violation "sr-qa: missing structured verdict field '${field}' in slice"
  fi
done

# At least one PASS / PARTIAL / FAIL verdict.
if ! grep -qE '^\s*status:\s+(PASS|PARTIAL|FAIL)' "${SR_QA}"; then
  violation "sr-qa: no structured 'status:' line in {PASS,PARTIAL,FAIL} found in slice"
fi

# ---- Sr Staff slice assertions ------------------------------------------------
SR_STAFF="${FIXTURE_DIR}/sr-staff.md"
[[ -f "${SR_STAFF}" ]] \
  || violation "sr-staff: slice missing at ${SR_STAFF}"

REVIEW_COUNT="$(grep -cE '^### Review output\s*$' "${SR_STAFF}" || true)"
if [[ "${REVIEW_COUNT}" != "1" ]]; then
  violation "sr-staff: expected exactly 1 '### Review output' subsection; found ${REVIEW_COUNT}"
fi

QUERY_COUNT="$(grep -cE '/yoke:search-canonical-memory query:' "${SR_STAFF}" || true)"
if [[ "${QUERY_COUNT}" -lt 1 ]]; then
  violation "sr-staff: expected ≥ 1 '/yoke:search-canonical-memory query:' record; found ${QUERY_COUNT}"
fi

PATTERN_COUNT="$(grep -cE 'concepts/yoke-pattern-[a-z0-9-]+' "${SR_STAFF}" || true)"
if [[ "${PATTERN_COUNT}" -lt 1 ]]; then
  violation "sr-staff: expected ≥ 1 'concepts/yoke-pattern-*' citation; found ${PATTERN_COUNT}"
fi

ULTRA_COUNT="$(grep -cF '/ultrareview' "${SR_STAFF}" || true)"
if [[ "${ULTRA_COUNT}" != "0" ]]; then
  violation "sr-staff: expected zero '/ultrareview' tokens; found ${ULTRA_COUNT}"
fi

exit 0
