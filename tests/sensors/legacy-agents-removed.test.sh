#!/usr/bin/env bash
# shellcheck shell=bash
#
# legacy-agents-removed.test.sh — Sprint 04 / Task t01 / Acceptance
# Contract Scenario 13 + FR-6.
#
# Asserts the v3.0 council-cutover removal of the legacy v2.x agent
# files plus the canonize-only narrowing of the surviving Orchestrator:
#
#   1. agents/generator.md does NOT exist on disk.
#   2. agents/validator.md does NOT exist on disk.
#   3. agents/orchestrator.md exists.
#   4. agents/orchestrator.md body has no legacy non-canonize mode
#      subsections (no `### Mode A`, `### Mode B`, `### Mode B —`,
#      `### Mode A —`, no body section headers naming the legacy
#      modes that the v3.0 cutover retired). The canonize section
#      MUST remain present.
#   5. The plugin manifest reports version 3.0.0.
#   6. lib/runtime/ and skills/implement/ contain ZERO matches for
#      the four legacy role tokens (generator, validator,
#      orchestrator-monitor, orchestrator-consult).
#
# Test contract (binding for this file):
#   - exit 0 when every assertion above holds.
#   - exit non-zero with a `wm: legacy-agents-removed violation:`-
#     prefixed stderr line naming the offending check otherwise.
#
# Discovery: this test is enumerated by Sprint 04 Task t01's
# `**Validation:**` line and by Acceptance Contract Scenario 13's
# `Then` clause.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

violation() {
  printf 'wm: legacy-agents-removed violation: %s\n' "$1" >&2
  exit 1
}

# 1 + 2: legacy agent files MUST NOT exist.
if [[ -e "${REPO_ROOT}/agents/generator.md" ]]; then
  violation "agents/generator.md still exists; expected deletion in Sprint 04 / FR-6"
fi
if [[ -e "${REPO_ROOT}/agents/validator.md" ]]; then
  violation "agents/validator.md still exists; expected deletion in Sprint 04 / FR-6"
fi

# 3: the orchestrator file MUST still exist (canonize survives).
ORCH="${REPO_ROOT}/agents/orchestrator.md"
[[ -f "${ORCH}" ]] \
  || violation "agents/orchestrator.md missing; canonize-only orchestrator MUST survive"

# 4: orchestrator body MUST NOT carry the legacy non-canonize mode
#    subsections that v2.x shipped. The v3.0 file keeps a single
#    canonize-mode body section. Detect any heading that names a
#    legacy mode and reject it.
if grep -qE '^###[[:space:]]+Mode[[:space:]]+A[[:space:]]+[—-][[:space:]]+Consult' "${ORCH}"; then
  violation "agents/orchestrator.md body still carries a legacy 'Mode A — Consult' subsection"
fi
if grep -qE '^###[[:space:]]+Mode[[:space:]]+B[[:space:]]+[—-][[:space:]]+Monitor' "${ORCH}"; then
  violation "agents/orchestrator.md body still carries a legacy 'Mode B — Monitor' subsection"
fi
# Headings that mention "consult" or "monitor" as a section name (not
# inside prose) are rejected too, regardless of letter prefix.
if grep -qE '^###[[:space:]]+.*[Cc]onsult.*$' "${ORCH}"; then
  violation "agents/orchestrator.md body still carries a Consult-named subsection heading"
fi
if grep -qE '^###[[:space:]]+.*[Mm]onitor.*$' "${ORCH}"; then
  violation "agents/orchestrator.md body still carries a Monitor-named subsection heading"
fi

# Canonize section MUST remain present.
if ! grep -qE '^###[[:space:]]+Canonize' "${ORCH}"; then
  violation "agents/orchestrator.md body lost its Canonize section heading"
fi

# 5: plugin manifest version pinned at 3.0.0.
PLUGIN_JSON="${REPO_ROOT}/.claude-plugin/plugin.json"
[[ -f "${PLUGIN_JSON}" ]] \
  || violation "${PLUGIN_JSON} not found"

if command -v jq >/dev/null 2>&1; then
  VERSION="$(jq -r '.version' "${PLUGIN_JSON}")"
else
  # Fallback: awk-based extraction. Matches `"version": "<v>"`.
  VERSION="$(awk -F'"' '/^[[:space:]]*"version"[[:space:]]*:/ { print $4; exit }' "${PLUGIN_JSON}")"
fi

if [[ "${VERSION}" != "3.0.0" ]]; then
  violation "plugin.json version is '${VERSION}'; expected '3.0.0'"
fi

# 6: zero residual legacy role tokens under lib/runtime/ + skills/implement/.
RESIDUAL_FILES="$(grep -lr 'generator\|validator\|orchestrator-monitor\|orchestrator-consult' \
  "${REPO_ROOT}/lib/runtime/" \
  "${REPO_ROOT}/skills/implement/" 2>/dev/null || true)"

if [[ -n "${RESIDUAL_FILES}" ]]; then
  printf 'wm: legacy-agents-removed violation: residual legacy role tokens under lib/runtime/ or skills/implement/:\n' >&2
  printf '%s\n' "${RESIDUAL_FILES}" >&2
  exit 1
fi

exit 0
