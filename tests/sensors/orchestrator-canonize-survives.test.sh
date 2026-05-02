#!/usr/bin/env bash
# shellcheck shell=bash
#
# orchestrator-canonize-survives.test.sh — Sprint 04 / Task t01 /
# Acceptance Contract Scenario 13 + FR-6.
#
# Asserts that the canonize-only Orchestrator survives the v3.0
# council cutover end-to-end:
#
#   1. agents/orchestrator.md exists.
#   2. agents/orchestrator.md frontmatter `description:` field
#      mentions `canonize` (the surviving mode token).
#   3. agents/orchestrator.md body has a Canonize section header.
#   4. The body references `/yoke:canonize` as the dispatch verb
#      (the v2.0.0 facade survives v3.0).
#   5. The /yoke:canonize skill itself exists at
#      skills/canonize/SKILL.md (the dispatch target is callable).
#
# Test contract (binding for this file):
#   - exit 0 when every assertion above holds.
#   - exit non-zero with a `wm: orchestrator-canonize-survives
#     violation:`-prefixed stderr line naming the offending check
#     otherwise.
#
# Discovery: this test is enumerated by Sprint 04 Task t01's
# `**Validation:**` line and by Acceptance Contract Scenario 13's
# `Then` clause + FR-6 `### Validation > tests-sensors`.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

violation() {
  printf 'wm: orchestrator-canonize-survives violation: %s\n' "$1" >&2
  exit 1
}

ORCH="${REPO_ROOT}/agents/orchestrator.md"
CANONIZE_SKILL="${REPO_ROOT}/skills/canonize/SKILL.md"

# 1: file exists.
[[ -f "${ORCH}" ]] \
  || violation "agents/orchestrator.md missing; canonize-only orchestrator MUST survive"

# Extract YAML frontmatter (between the first two lines that are
# exactly '---').
FRONTMATTER="$(awk '
  /^---$/ { fm = !fm; if (!fm) exit; next }
  fm { print }
' "${ORCH}")"

[[ -n "${FRONTMATTER}" ]] \
  || violation "agents/orchestrator.md is missing its YAML frontmatter block"

# 2: frontmatter description mentions `canonize`.
if ! printf '%s\n' "${FRONTMATTER}" | grep -qiE '^description:.*canonize'; then
  # Description may span lines; collapse and re-check.
  COLLAPSED="$(printf '%s\n' "${FRONTMATTER}" | tr '\n' ' ')"
  if ! printf '%s\n' "${COLLAPSED}" | grep -qiE 'description:.*canonize'; then
    violation "agents/orchestrator.md frontmatter description does not mention 'canonize'"
  fi
fi

# 3: body has a Canonize section header.
if ! grep -qE '^###[[:space:]]+Canonize' "${ORCH}"; then
  violation "agents/orchestrator.md body lacks a Canonize section heading (### Canonize ...)"
fi

# 4: body references /yoke:canonize as the dispatch verb.
if ! grep -q '/yoke:canonize' "${ORCH}"; then
  violation "agents/orchestrator.md body does not reference the /yoke:canonize dispatch verb"
fi

# 5: the /yoke:canonize skill is present at the documented path.
[[ -f "${CANONIZE_SKILL}" ]] \
  || violation "skills/canonize/SKILL.md missing; the /yoke:canonize dispatch target is broken"

exit 0
