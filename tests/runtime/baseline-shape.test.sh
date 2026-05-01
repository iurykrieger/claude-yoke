#!/usr/bin/env bash
# shellcheck shell=bash
#
# baseline-shape.test.sh — Sprint 01 / Task t01 / Acceptance Contract
# Scenario 1 + FR-8.
#
# Asserts that `.yoke/specs/2026-05-01-agent-council.md` carries a
# `## Baseline metrics` section with at least three post-merge SHA
# samples and a kLoC denominator value, per PRD Resolved 9.
#
# Test contract (binding for this file):
#   - exit 0 when the spec contains the section AND the section
#     parses with the expected shape.
#   - exit non-zero with a `wm: baseline-shape violation:`-prefixed
#     stderr line naming the missing piece otherwise.
#
# Discovery: this test is enumerated by Sprint 01 Task t01's
# `**Acceptance criterion:**` line, by Acceptance Contract Scenario 1's
# `Then` clause, and is gated by the `drift-baseline-captured` sensor
# (`.yoke/sensors/drift-baseline-captured.md`) when the harness sweeps
# Sprint 01.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
SPEC_PATH="${REPO_ROOT}/.yoke/specs/2026-05-01-agent-council.md"

violation() {
  printf 'wm: baseline-shape violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "${SPEC_PATH}" ]] \
  || violation "spec not found at ${SPEC_PATH}"

# Exactly one `## Baseline metrics` heading is required.
HEADING_COUNT="$(grep -c '^## Baseline metrics$' "${SPEC_PATH}" || true)"
[[ "${HEADING_COUNT}" == "1" ]] \
  || violation "expected exactly one '## Baseline metrics' heading; found ${HEADING_COUNT}"

# Extract the section body: from '## Baseline metrics' up to (but not
# including) the next '## ' top-level heading or the file end.
SECTION_BODY="$(awk '
  /^## Baseline metrics$/ { capture = 1; next }
  capture && /^## / { capture = 0 }
  capture { print }
' "${SPEC_PATH}")"

[[ -n "${SECTION_BODY}" ]] \
  || violation "'## Baseline metrics' section body is empty"

# At least three SHA samples, one per `**SHA \`<short>\`` bullet.
SHA_SAMPLES="$(printf '%s\n' "${SECTION_BODY}" | grep -cE '^- \*\*SHA `[0-9a-f]{7,40}`' || true)"
if [[ "${SHA_SAMPLES}" -lt 3 ]]; then
  violation "expected at least 3 SHA samples; found ${SHA_SAMPLES}"
fi

# kLoC denominator must appear at least once in the section body.
if ! printf '%s\n' "${SECTION_BODY}" | grep -qE 'kLoC denominator: [0-9]+(\.[0-9]+)?'; then
  violation "expected at least one 'kLoC denominator: <number>' line in the section"
fi

# Every per-SHA sample carries a `findings density: <number> / kLoC` line.
DENSITY_LINES="$(printf '%s\n' "${SECTION_BODY}" | grep -cE 'findings density: [0-9]+(\.[0-9]+)? / kLoC' || true)"
if [[ "${DENSITY_LINES}" -lt 3 ]]; then
  violation "expected at least 3 'findings density: <number> / kLoC' lines (one per sample); found ${DENSITY_LINES}"
fi

# Averaged baseline subsection must exist.
if ! printf '%s\n' "${SECTION_BODY}" | grep -q '^### Averaged baseline$'; then
  violation "expected an '### Averaged baseline' subsection"
fi

# Averaged-baseline subsection MUST cite an average kLoC denominator.
if ! printf '%s\n' "${SECTION_BODY}" | grep -qE 'average kLoC denominator.*[0-9]+(\.[0-9]+)?'; then
  violation "expected the averaged-baseline subsection to cite an 'average kLoC denominator'"
fi

# Top-three findings categories line is required (per PRD Resolved 9 — the
# section MAY name the categories or explicitly state "none surfaced", but
# it MUST address the question).
if ! printf '%s\n' "${SECTION_BODY}" | grep -qiE 'top three findings categories'; then
  violation "expected a 'top three findings categories' enumeration in the section"
fi

exit 0
