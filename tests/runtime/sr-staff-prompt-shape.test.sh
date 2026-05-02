#!/usr/bin/env bash
# shellcheck shell=bash
#
# sr-staff-prompt-shape.test.sh — Sprint 03 / Task t03 / Acceptance Contract
# Scenario 12 + FR-5.
#
# Asserts that `agents/sr-staff.md`'s body carries the five prompt
# sections required by the persona retooling (Objective; Phase A —
# review-skill invocation; Phase A — architectural assessment lens;
# Phase B; Anti-scope) plus the explicit anti-scope clauses (no
# production code edits, no test authorship, no autonomous
# /ultrareview).
#
# Test contract (binding for this file):
#   - exit 0 when every required section + clause is present.
#   - exit non-zero with a `wm: sr-staff-prompt-shape violation:`-prefixed
#     stderr line naming the missing piece otherwise.
#
# Discovery: enumerated by Sprint 03 Task t03's `**Acceptance criterion:**`
# line and by Acceptance Contract Scenario 12's `Then` clause.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
PERSONA_FILE="${REPO_ROOT}/agents/sr-staff.md"

violation() {
  printf 'wm: sr-staff-prompt-shape violation: %s\n' "$1" >&2
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

# (1) Objective preamble — "prove the architecture wrong".
assert_regex '^## Objective — prove the architecture wrong' "objective preamble heading"
assert_contains 'prove the architecture wrong' "objective preamble"
assert_contains 'long-term-sustainability lens' "objective preamble — sustainability framing"

# (2) Phase A — review-skill invocation + canonical-memory consult.
assert_regex '^## Phase A — invoke review-skill and consult canonical memory' "Phase A invocation heading"
assert_contains 'exactly once per Phase A' "Phase A — exactly-one review invocation rule"
assert_contains '/yoke:search-canonical-memory' "Phase A — canonical-memory facade name"
assert_contains '### Review output' "Phase A — review-output subsection name"

# (3) Phase A — architectural assessment lens.
assert_regex '^## Phase A — architectural assessment lens' "Phase A assessment heading"
assert_contains 'longevity' "assessment lens: longevity"
assert_contains 'coupling' "assessment lens: coupling"
assert_contains 'future-extensibility' "assessment lens: future-extensibility"
assert_contains 'pattern alignment' "assessment lens: pattern alignment"
assert_contains 'sustainability' "assessment lens: sustainability"

# (4) Phase B section.
assert_regex '^## Phase B — flag contradictions' "Phase B heading"
assert_contains 'importance-disagreement' "Phase B — disagreement classification"

# (5) Anti-scope section with required clauses.
assert_regex '^## Anti-scope' "Anti-scope heading"
assert_contains 'Never modify production code' "anti-scope: no production-code edits"
assert_contains 'Never write tests' "anti-scope: no test authorship"
assert_contains 'Never invoke `/ultrareview` autonomously' "anti-scope: no autonomous /ultrareview"
assert_contains 'Never write canonical memory' "anti-scope: no canonical-memory writes"

# Roles + memory-model pattern citations in the body header.
assert_contains 'concepts/yoke-pattern-roles' "roles-pattern citation"
assert_contains 'concepts/yoke-pattern-memory-model' "memory-model pattern citation"

exit 0
