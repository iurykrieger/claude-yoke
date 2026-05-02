#!/usr/bin/env bash
# shellcheck shell=bash
#
# dogfood-entry-shape.test.sh — Sprint 04 / Task t03 / Acceptance
# Contract Scenario 15.
#
# Asserts that .yoke/specs/2026-05-01-agent-council.md carries a
# single `## Dogfood entry point` section with the required shape:
#
#   1. Exactly one `## Dogfood entry point` heading.
#   2. The section contains a slug-shaped value matching the
#      `YYYY-MM-DD-<kebab>` (or `YYYY-MM-XX-<kebab>` when the day is
#      intentionally deferred for the follow-up PRD) form.
#   3. The section contains a rationale paragraph (a non-empty body
#      under a `### Rationale` subsection or equivalent prose block).
#   4. The section contains a handoff line — a sentence naming the
#      v3.0-dogfood follow-up PRD as the destination of the entry.
#
# Test contract (binding for this file):
#   - exit 0 when every assertion above holds.
#   - exit non-zero with a `wm: dogfood-entry-shape violation:`-
#     prefixed stderr line naming the offending check otherwise.
#
# Discovery: this test is enumerated by Sprint 04 Task t03's
# `**Validation:**` line and by Acceptance Contract Scenario 15's
# `Then` clause.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
SPEC_PATH="${REPO_ROOT}/.yoke/specs/2026-05-01-agent-council.md"

violation() {
  printf 'wm: dogfood-entry-shape violation: %s\n' "$1" >&2
  exit 1
}

[[ -f "${SPEC_PATH}" ]] \
  || violation "spec not found at ${SPEC_PATH}"

# 1: exactly one `## Dogfood entry point` heading.
HEADING_COUNT="$(grep -c '^## Dogfood entry point$' "${SPEC_PATH}" || true)"
[[ "${HEADING_COUNT}" == "1" ]] \
  || violation "expected exactly one '## Dogfood entry point' heading; found ${HEADING_COUNT}"

# Extract the section body — from the heading to the next H2 or EOF.
SECTION_BODY="$(awk '
  /^## Dogfood entry point$/ { capture = 1; next }
  capture && /^## / { capture = 0 }
  capture { print }
' "${SPEC_PATH}")"

[[ -n "${SECTION_BODY}" ]] \
  || violation "'## Dogfood entry point' section body is empty"

# 2: slug-shaped value present. The slug body convention is
# `YYYY-MM-DD-<kebab>`; the day digits MAY be `XX` when the
# follow-up PRD will pin the literal date downstream.
if ! printf '%s\n' "${SECTION_BODY}" \
     | grep -qE '[0-9]{4}-[0-9]{2}-([0-9]{2}|XX)-[a-z0-9]+(-[a-z0-9]+)+'; then
  violation "section is missing a slug-shaped value matching YYYY-MM-DD-<kebab> (XX day permitted)"
fi

# 3: rationale paragraph — accept either a `### Rationale` subsection
# or a `Rationale:` prose line followed by a non-empty paragraph.
HAS_RATIONALE=0
if printf '%s\n' "${SECTION_BODY}" | grep -qE '^### Rationale$'; then
  HAS_RATIONALE=1
fi
if printf '%s\n' "${SECTION_BODY}" | grep -qE '^[[:space:]]*Rationale:'; then
  HAS_RATIONALE=1
fi
if [[ "${HAS_RATIONALE}" -ne 1 ]]; then
  violation "section is missing a rationale paragraph (### Rationale subsection or 'Rationale:' line)"
fi

# 4: handoff line — accept either a `### Handoff` subsection or a
# prose line that explicitly cites the v3.0-dogfood follow-up PRD.
HAS_HANDOFF=0
if printf '%s\n' "${SECTION_BODY}" | grep -qiE '^###[[:space:]]+Handoff'; then
  HAS_HANDOFF=1
fi
if printf '%s\n' "${SECTION_BODY}" | grep -qiE 'v3\.0-dogfood follow-up PRD'; then
  HAS_HANDOFF=1
fi
if [[ "${HAS_HANDOFF}" -ne 1 ]]; then
  violation "section is missing a handoff line citing the v3.0-dogfood follow-up PRD"
fi

exit 0
