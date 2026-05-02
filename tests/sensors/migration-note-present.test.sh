#!/usr/bin/env bash
# shellcheck shell=bash
#
# migration-note-present.test.sh — Sprint 04 / Task t02 / Acceptance
# Contract Scenario 14 + FR-7.
#
# Asserts that the v2.x → v3.0 migration note is shipped as a
# distinct doc file with the literal one-line migration text plus a
# pointer to the architecture docs, and that the prior v1.x → v2.0
# migration runbook remains untouched on disk:
#
#   1. docs/migration-v2-to-v3.md exists.
#   2. docs/migration-v2-to-v3.md contains the literal one-line
#      migration note: "drain in-flight v2.x cycles before upgrading".
#   3. docs/migration-v2-to-v3.md references docs/architecture.md
#      (so readers can find the council protocol diagram).
#   4. docs/migration-v1-to-v2.md still exists (v1→v2 docs intact).
#   5. docs/architecture.md mentions "Council protocol" at least
#      once (the FR-7 cross-check that the architecture doc reflects
#      the v3.0 cutover).
#
# Test contract (binding for this file):
#   - exit 0 when every assertion above holds.
#   - exit non-zero with a `wm: migration-note-present violation:`-
#     prefixed stderr line naming the offending check otherwise.
#
# Discovery: this test is enumerated by Sprint 04 Task t02's
# `**Validation:**` line and by Acceptance Contract Scenario 14's
# `Then` clause + FR-7 `### Validation > tests-sensors`.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

V2_TO_V3="${REPO_ROOT}/docs/migration-v2-to-v3.md"
V1_TO_V2="${REPO_ROOT}/docs/migration-v1-to-v2.md"
ARCH="${REPO_ROOT}/docs/architecture.md"

violation() {
  printf 'wm: migration-note-present violation: %s\n' "$1" >&2
  exit 1
}

# 1: v2-to-v3 doc exists.
[[ -f "${V2_TO_V3}" ]] \
  || violation "${V2_TO_V3} not found"

# 2: literal one-line migration note present.
NOTE='drain in-flight v2.x cycles before upgrading'
if ! grep -qF -- "${NOTE}" "${V2_TO_V3}"; then
  violation "literal migration note '${NOTE}' is missing from docs/migration-v2-to-v3.md"
fi

# 3: pointer to architecture docs present.
if ! grep -qE 'docs/architecture\.md' "${V2_TO_V3}"; then
  violation "docs/migration-v2-to-v3.md does not reference docs/architecture.md"
fi

# 4: v1-to-v2 doc still on disk.
[[ -f "${V1_TO_V2}" ]] \
  || violation "docs/migration-v1-to-v2.md is missing; v1→v2 docs MUST remain intact"

# 5: docs/architecture.md mentions Council protocol.
[[ -f "${ARCH}" ]] \
  || violation "${ARCH} not found"

if ! grep -qF 'Council protocol' "${ARCH}"; then
  violation "docs/architecture.md does not mention 'Council protocol'"
fi

exit 0
