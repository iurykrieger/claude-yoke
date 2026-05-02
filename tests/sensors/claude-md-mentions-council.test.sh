#!/usr/bin/env bash
# shellcheck shell=bash
#
# claude-md-mentions-council.test.sh — Sprint 04 / Task t02 /
# Acceptance Contract Scenario 14 + FR-7.
#
# Asserts that CLAUDE.md (the project-internal coding-agent guidance)
# describes the v3.0 agent council architecture by carrying every
# token below as a literal substring:
#
#   - "agent council"
#   - "Sr Eng"
#   - "Sr QA"
#   - "Sr Staff"
#   - "Phase A"
#
# Test contract (binding for this file):
#   - exit 0 when every token above is present in CLAUDE.md.
#   - exit non-zero with a `wm: claude-md-mentions-council
#     violation:`-prefixed stderr line naming the missing token
#     otherwise.
#
# Discovery: this test is enumerated by Sprint 04 Task t02's
# `**Validation:**` line and by Acceptance Contract Scenario 14's
# `Then` clause + FR-7 `### Validation > tests-sensors`.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"

violation() {
  printf 'wm: claude-md-mentions-council violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "${CLAUDE_MD}" ]] \
  || violation "CLAUDE.md not found at ${CLAUDE_MD}"

# Required tokens, one per line; spaces preserved.
REQUIRED_TOKENS=(
  'agent council'
  'Sr Eng'
  'Sr QA'
  'Sr Staff'
  'Phase A'
)

for token in "${REQUIRED_TOKENS[@]}"; do
  if ! grep -qF -- "${token}" "${CLAUDE_MD}"; then
    violation "CLAUDE.md is missing the literal token '${token}'"
  fi
done

exit 0
