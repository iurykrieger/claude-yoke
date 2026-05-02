#!/usr/bin/env bash
# shellcheck shell=bash
#
# sr-eng-prompt-shape.test.sh — Sprint 03 / Task t01 / Acceptance Contract
# Scenario 10 + FR-5.
#
# Asserts that `agents/sr-eng.md`'s body carries the four prompt
# sections required by the persona retooling (Objective; Phase A —
# implement and write happy-path unit tests; Phase B; Anti-scope) plus
# the explicit anti-scope clauses (no acceptance tests, no /review,
# no canonical-memory consult for architectural patterns).
#
# Test contract (binding for this file):
#   - exit 0 when every required section + clause is present.
#   - exit non-zero with a `wm: sr-eng-prompt-shape violation:`-prefixed
#     stderr line naming the missing piece otherwise.
#
# Discovery: enumerated by Sprint 03 Task t01's `**Acceptance criterion:**`
# line and by Acceptance Contract Scenario 10's `Then` clause.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
PERSONA_FILE="${REPO_ROOT}/agents/sr-eng.md"

violation() {
  printf 'wm: sr-eng-prompt-shape violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "${PERSONA_FILE}" ]] \
  || violation "persona file missing at ${PERSONA_FILE}"

# Extract only the body (everything after the second `---` line).
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

# (1) Objective preamble — "ship working code".
assert_regex '^## Objective — ship working code' "objective preamble heading"
assert_contains 'ship working code' "objective preamble"
assert_contains 'happy-path unit tests' "objective preamble"

# (2) Phase A — implement and write happy-path unit tests.
assert_regex '^## Phase A — implement and write happy-path unit tests' "Phase A heading"
assert_contains 'tests/acceptance/' "Phase A — anti-scope reminder"
assert_contains 'sr-eng-objective-distinct-from-validator' "Phase A — sensor cite"

# (3) Phase B section.
assert_regex '^## Phase B — flag contradictions' "Phase B heading"
assert_contains 'réplica' "Phase B — réplica term"
assert_contains 'consensus' "Phase B — convergence term"

# (4) Anti-scope section with the required clauses.
assert_regex '^## Anti-scope' "Anti-scope heading"
assert_contains 'Never write acceptance-contract-anchored tests' "anti-scope: no acceptance tests"
assert_contains 'Never invoke `/review`' "anti-scope: no /review"
assert_contains 'Never consult canonical memory for architectural patterns' "anti-scope: no canonical-memory architectural consult"
assert_contains 'Never write canonical memory' "anti-scope: no canonical-memory writes"

# Roles pattern citation in the body header.
assert_contains 'concepts/yoke-pattern-roles' "roles-pattern citation"

exit 0
