#!/usr/bin/env bash
# tests/sensors/persona-mode-tag.test.sh — CI gate for the Mode-tag
# convention on engineering-flavored skill bodies.
#
# Walks every engineering-flavored skill body (initial in-scope catalog:
# skills/fix/SKILL.md and skills/tech-spec/SKILL.md) and asserts each
# declares a well-formed Mode tag matching the regex
#   ^\*\*Mode:\*\*\s+(diagnose-first|design-first|review-first|stabilize-first|rollback-first)\s*$
# on a line under the "## Your role" section heading, before the persona
# prose body. The vocabulary is open: future engineering skills may
# append values without re-ratification (PRD FR-2 / Spec Alt(b)).
#
# Source PRD: .yoke/prds/2026-05-05-phase-1-fix-entrypoint.md (FR-2).
# Binding Acceptance Criteria: .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md
#   (AC-001-2, AC-005-2 — enforced by this sensor).
#
# Structured-sensor-output contract (per concepts/yoke-pattern-sensors):
# every failure prints (a) the offending skill path, (b) the
# violation kind, (c) the corrective action.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# In-scope catalog. Append new engineering-flavored skills here as the
# vocabulary grows; the regex itself accepts new values without
# re-ratification, but the sensor walks an explicit catalog so a future
# engineering skill that forgets the Mode tag is caught.
SKILLS=(
  "skills/fix/SKILL.md"
  "skills/tech-spec/SKILL.md"
)

MODE_REGEX='^\*\*Mode:\*\*[[:space:]]+(diagnose-first|design-first|review-first|stabilize-first|rollback-first)[[:space:]]*$'

FAIL=0
CHECKED=0

fail() {
  echo "FAIL: $*" >&2
  FAIL=1
}

pass() {
  echo "PASS: $*"
}

echo "--- persona-mode-tag sensor ---"

for skill in "${SKILLS[@]}"; do
  if [ ! -f "$skill" ]; then
    fail "${skill}"
    echo "  violation: skill file does not exist on disk" >&2
    echo "  fix: create the skill body (mirror skills/discover/SKILL.md structurally) and add a '**Mode:** <value>' line on the first line under the '## Your role' section heading." >&2
    continue
  fi

  CHECKED=$((CHECKED + 1))

  # Find the "## Your role" line, then walk forward to the first
  # non-empty content line (skipping blank lines). That line MUST
  # match the Mode-tag regex.
  #
  # awk script:
  #   - On finding a line starting with "## Your role", flip a flag.
  #   - After the flag, skip empty lines.
  #   - The first non-empty line after the heading is the "candidate";
  #     print it and exit.
  candidate="$(awk '
    BEGIN { in_role = 0 }
    /^## Your role/ { in_role = 1; next }
    in_role == 1 {
      if ($0 ~ /^[[:space:]]*$/) { next }
      print $0
      exit
    }
  ' "$skill")"

  if [ -z "$candidate" ]; then
    fail "${skill}"
    echo "  violation: no '## Your role' section found, or the section has no non-empty body line." >&2
    echo "  fix: add a '## Your role' section, and place '**Mode:** <value>' on the first line under it (one of: diagnose-first | design-first | review-first | stabilize-first | rollback-first)." >&2
    continue
  fi

  if echo "$candidate" | grep -qE "$MODE_REGEX"; then
    pass "${skill}: well-formed Mode tag — '${candidate}'"
  else
    fail "${skill}"
    echo "  violation: first non-empty line under '## Your role' is not a well-formed Mode tag." >&2
    echo "  observed: ${candidate}" >&2
    echo "  fix: replace the first non-empty line under '## Your role' with one of:" >&2
    echo "    **Mode:** diagnose-first" >&2
    echo "    **Mode:** design-first" >&2
    echo "    **Mode:** review-first" >&2
    echo "    **Mode:** stabilize-first" >&2
    echo "    **Mode:** rollback-first" >&2
  fi
done

echo "--- persona-mode-tag: ${CHECKED} skills checked ---"

if [ "$FAIL" -eq 0 ]; then
  echo "--- persona-mode-tag: ALL PASS ---"
  exit 0
else
  echo "--- persona-mode-tag: FAILURES ABOVE ---" >&2
  exit 1
fi
