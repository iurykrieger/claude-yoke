#!/usr/bin/env bash
# shellcheck shell=bash
#
# sr-qa-test-directory.test.sh — Sprint 03 / Task t02 / Acceptance Contract
# Scenario 11 + FR-5.
#
# Asserts that Sr QA's lane — `tests/acceptance/<contract-slug>/` — is
# wired structurally as the binding test-authorship path:
#
#   1. The `tests/acceptance/` directory exists (Sprint 03 ships it
#      with a `.gitkeep` placeholder; Sr QA populates it at runtime).
#   2. The Sr QA persona prompt at `agents/sr-qa.md` names the binding
#      path shape `tests/acceptance/<contract-slug>/<criterion-id>.test.sh`
#      and the `# criterion: <id>` header comment shape.
#   3. The realistic-task fixture's Sr QA slice
#      (`tests/runtime/fixtures/realistic-task/sr-qa.md`) lists at least
#      three test files under `tests/acceptance/<slug>/` in its
#      `tests_authored:` block, each path matching the binding shape.
#
# Test contract (binding for this file):
#   - exit 0 when all three structural assertions hold.
#   - exit non-zero with a `wm: sr-qa-test-directory violation:`-prefixed
#     stderr line naming the missing piece otherwise.
#
# Discovery: enumerated by Sprint 03 Task t02's `**Acceptance criterion:**`
# line and by Acceptance Contract Scenario 11's `Then` clause.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
ACCEPTANCE_DIR="${REPO_ROOT}/tests/acceptance"
PERSONA_FILE="${REPO_ROOT}/agents/sr-qa.md"
FIXTURE_SLICE="${REPO_ROOT}/tests/runtime/fixtures/realistic-task/sr-qa.md"

violation() {
  printf 'wm: sr-qa-test-directory violation: %s\n' "$1" >&2
  exit 1
}

# (1) tests/acceptance/ directory exists with a placeholder.
[[ -d "${ACCEPTANCE_DIR}" ]] \
  || violation "tests/acceptance directory missing at ${ACCEPTANCE_DIR}"
[[ -f "${ACCEPTANCE_DIR}/.gitkeep" ]] \
  || violation "tests/acceptance/.gitkeep placeholder missing"

# (2) Persona prompt names the binding path shape + header shape.
[[ -f "${PERSONA_FILE}" ]] \
  || violation "Sr QA persona file missing at ${PERSONA_FILE}"

if ! grep -qF 'tests/acceptance/<contract-slug>/<criterion-id>.test.sh' "${PERSONA_FILE}"; then
  violation "Sr QA prompt missing binding path shape 'tests/acceptance/<contract-slug>/<criterion-id>.test.sh'"
fi

if ! grep -qF '# criterion: <id>' "${PERSONA_FILE}"; then
  violation "Sr QA prompt missing header-comment shape '# criterion: <id>'"
fi

# (3) Realistic-task fixture slice lists ≥ 3 test files matching the shape.
[[ -f "${FIXTURE_SLICE}" ]] \
  || violation "realistic-task Sr QA slice missing at ${FIXTURE_SLICE}"

# Count tests_authored: entries that match the binding shape
# tests/acceptance/<slug>/<criterion>.test.sh.
TEST_COUNT="$(
  grep -E '^\s*-\s+tests/acceptance/[^/]+/[^/]+\.test\.sh\s*$' "${FIXTURE_SLICE}" | wc -l | tr -d ' '
)"

if [[ "${TEST_COUNT}" -lt 3 ]]; then
  violation "expected ≥ 3 test files under tests/acceptance/<slug>/ in fixture Sr QA slice; found ${TEST_COUNT}"
fi

# Each authored test file path uses a contract slug, not a literal placeholder.
if grep -E '^\s*-\s+tests/acceptance/<' "${FIXTURE_SLICE}" >/dev/null 2>&1; then
  violation "fixture Sr QA slice contains placeholder path 'tests/acceptance/<...>' — must use a concrete slug"
fi

exit 0
