#!/usr/bin/env bash
# shellcheck shell=bash
#
# sr-staff-review-invocation.test.sh — Sprint 03 / Task t03 / Acceptance
# Contract Scenario 12 + FR-5.
#
# Asserts that on the realistic-task fixture, Sr Staff's slice file:
#   - contains exactly one `### Review output` subsection per Phase A
#     (a second invocation is a distinct-objective failure);
#   - contains at least one `/yoke:search-canonical-memory` query
#     record (canonical-memory consult is mandatory);
#   - contains zero `/ultrareview` tokens (autonomous invocation is a
#     PRD-Resolved-8 anti-scope violation);
#   - cites at least one ratified pattern from canonical memory by
#     name (matches `concepts/yoke-pattern-...` somewhere in the
#     architectural assessment).
#
# Test contract (binding for this file):
#   - exit 0 when every assertion holds against the fixture slice.
#   - exit non-zero with a `wm: sr-staff-review-invocation violation:`-prefixed
#     stderr line naming the offending piece otherwise.
#
# Discovery: enumerated by Sprint 03 Task t03's `**Acceptance criterion:**`
# line and by Acceptance Contract Scenario 12's `Then` clause.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
SLICE_FILE="${REPO_ROOT}/tests/runtime/fixtures/realistic-task/sr-staff.md"

violation() {
  printf 'wm: sr-staff-review-invocation violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "${SLICE_FILE}" ]] \
  || violation "Sr Staff fixture slice missing at ${SLICE_FILE}"

# Exactly one `### Review output` subsection.
REVIEW_COUNT="$(grep -cE '^### Review output\s*$' "${SLICE_FILE}" || true)"
if [[ "${REVIEW_COUNT}" != "1" ]]; then
  violation "expected exactly 1 '### Review output' subsection; found ${REVIEW_COUNT}"
fi

# At least one /yoke:search-canonical-memory query record.
QUERY_COUNT="$(grep -cE '/yoke:search-canonical-memory query:' "${SLICE_FILE}" || true)"
if [[ "${QUERY_COUNT}" -lt 1 ]]; then
  violation "expected ≥ 1 '/yoke:search-canonical-memory query:' record; found ${QUERY_COUNT}"
fi

# Zero `/ultrareview` tokens.
ULTRA_COUNT="$(grep -cF '/ultrareview' "${SLICE_FILE}" || true)"
if [[ "${ULTRA_COUNT}" != "0" ]]; then
  violation "expected zero '/ultrareview' tokens; found ${ULTRA_COUNT}"
fi

# At least one ratified pattern citation (concepts/yoke-pattern-*).
PATTERN_COUNT="$(grep -cE 'concepts/yoke-pattern-[a-z0-9-]+' "${SLICE_FILE}" || true)"
if [[ "${PATTERN_COUNT}" -lt 1 ]]; then
  violation "expected ≥ 1 'concepts/yoke-pattern-*' citation in architectural assessment; found ${PATTERN_COUNT}"
fi

exit 0
