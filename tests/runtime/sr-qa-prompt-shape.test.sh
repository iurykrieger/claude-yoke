#!/usr/bin/env bash
# shellcheck shell=bash
#
# sr-qa-prompt-shape.test.sh — Sprint 03 / Task t02 / Acceptance Contract
# Scenario 11 + FR-5.
#
# Asserts that `agents/sr-qa.md`'s body carries the five prompt sections
# required by the persona retooling (Objective; Phase A — write tests;
# Phase A — judge sensors; Phase B; Anti-scope) plus the explicit
# anti-scope clauses (no production code edits, no /review).
#
# Test contract (binding for this file):
#   - exit 0 when every required section + clause is present.
#   - exit non-zero with a `wm: sr-qa-prompt-shape violation:`-prefixed
#     stderr line naming the missing piece otherwise.
#
# Discovery: enumerated by Sprint 03 Task t02's `**Acceptance criterion:**`
# line and by Acceptance Contract Scenario 11's `Then` clause.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
PERSONA_FILE="${REPO_ROOT}/agents/sr-qa.md"

violation() {
  printf 'wm: sr-qa-prompt-shape violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "${PERSONA_FILE}" ]] \
  || violation "persona file missing at ${PERSONA_FILE}"

body() {
  awk '/^---$/{c++;next} c>=2' "${PERSONA_FILE}"
}

assert_contains() {
  local needle="$1" label="$2"
  if ! body | grep -qF "$needle"; then
    violation "${label}: missing literal '${needle}' in body"
  fi
}

assert_regex() {
  local pattern="$1" label="$2"
  if ! body | grep -Eq "$pattern"; then
    violation "${label}: missing pattern /${pattern}/ in body"
  fi
}

# (1) Objective preamble — "prove the code wrong".
assert_regex '^## Objective — prove the code wrong' "objective preamble heading"
assert_contains 'prove the code wrong' "objective preamble"
assert_contains 'binding Acceptance Contract' "objective preamble"

# (2) Phase A — test-writing under tests/acceptance/<contract-slug>/.
assert_regex '^## Phase A — write acceptance-contract-anchored tests' "Phase A test-writing heading"
assert_contains 'tests/acceptance/<contract-slug>/<criterion-id>.test.sh' "Phase A — test path shape"
assert_contains '# criterion: <id>' "Phase A — header comment shape"

# (3) Phase A — judging via sensor toolkit.
assert_regex '^## Phase A — judge the cycle' "Phase A judging heading"
assert_contains 'PASS | PARTIAL | FAIL' "Phase A — verdict shape"
assert_contains 'fix_instruction' "Phase A — verdict field"

# (4) Phase B section.
assert_regex '^## Phase B — flag contradictions' "Phase B heading"
assert_contains 'réplica' "Phase B — réplica term"

# (5) Anti-scope section with required clauses.
assert_regex '^## Anti-scope' "Anti-scope heading"
assert_contains 'Never modify production code' "anti-scope: no production-code edits"
assert_contains 'Never invoke `/review`' "anti-scope: no /review"
assert_contains 'Never relax the binding Acceptance Contract' "anti-scope: never relax the contract"

# Roles pattern citation in the body header.
assert_contains 'concepts/yoke-pattern-roles' "roles-pattern citation"

exit 0
