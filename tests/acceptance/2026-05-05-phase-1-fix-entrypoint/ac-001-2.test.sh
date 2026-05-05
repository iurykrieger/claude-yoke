#!/usr/bin/env bash
# criterion: AC-001-2
#
# AC-001-2 (binding text from
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md):
#
#   "The persona body's first line under 'Your role' matches the regex
#    `^\*\*Mode:\*\*\s+diagnose-first\s*$` exactly, enforced by a
#    tests/sensors/persona-mode-tag.test.sh sensor that scans both
#    skills/fix/SKILL.md and skills/tech-spec/SKILL.md."
#
# Sprint scope (s03-t04 for /yoke:fix; s03-t01 for /yoke:tech-spec):
# both skills carry a Mode tag on the first line under "## Your role".
# The persona-mode-tag sensor (s03-t02) is the implementation; this
# binding test pins the regex against BOTH skill bodies directly so a
# regression in either leaks here even if the sensor catalog drifts.
#
# Observable conditions tested:
#   (1) skills/fix/SKILL.md exists and the first non-empty line under
#       its "## Your role" heading matches `^**Mode:** diagnose-first$`.
#   (2) skills/tech-spec/SKILL.md exists and the first non-empty line
#       under its "## Your role" heading matches `^**Mode:** design-first$`.
#   (3) The literal regex from AC-001-2 (with `\s` translated to
#       `[[:space:]]` for portable ERE) returns exactly one match on
#       the first 50 lines of skills/fix/SKILL.md (parallel to the
#       AC-005-1 grep recipe).

set -euo pipefail

# Internal watchdog (per repo testing convention).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

# Resolve repo root from the location of this file.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=/dev/null
source "$REPO_ROOT/tests/lib/harness.sh"

FIX_SKILL="$REPO_ROOT/skills/fix/SKILL.md"
TECH_SKILL="$REPO_ROOT/skills/tech-spec/SKILL.md"

# Helper: extract the first non-empty line under "## Your role" from a
# skill body. Returns empty string if the section is absent.
first_line_under_role() {
  local file="$1"
  awk '
    /^## Your role/ { in_role=1; next }
    in_role && /^## / { exit }
    in_role && NF { print; exit }
  ' "$file"
}

# ---------------------------------------------------------------------------
# Case (1) — skills/fix/SKILL.md opens its persona block with
# `**Mode:** diagnose-first` on the first line under "## Your role".
# ---------------------------------------------------------------------------
if [[ ! -f "$FIX_SKILL" ]]; then
  err "(1) skills/fix/SKILL.md is missing — Sr Eng s03-t04 deliverable"
else
  FIX_FIRST=$(first_line_under_role "$FIX_SKILL")
  if [[ "$FIX_FIRST" =~ ^\*\*Mode:\*\*[[:space:]]+diagnose-first[[:space:]]*$ ]]; then
    pass "(1) skills/fix/SKILL.md first line under '## Your role' is '**Mode:** diagnose-first'"
  else
    err "(1) skills/fix/SKILL.md first line under '## Your role' is '$FIX_FIRST'; expected '**Mode:** diagnose-first'"
  fi
fi

# ---------------------------------------------------------------------------
# Case (2) — skills/tech-spec/SKILL.md opens with `**Mode:** design-first`.
# Mirrors AC-005-1 but with the structural pin (first line under
# "## Your role"). Pinned here as well so a regression on either side
# is visible to AC-001-2 even if the AC-005-1 test drifts.
# ---------------------------------------------------------------------------
if [[ ! -f "$TECH_SKILL" ]]; then
  err "(2) skills/tech-spec/SKILL.md is missing"
else
  TECH_FIRST=$(first_line_under_role "$TECH_SKILL")
  if [[ "$TECH_FIRST" =~ ^\*\*Mode:\*\*[[:space:]]+design-first[[:space:]]*$ ]]; then
    pass "(2) skills/tech-spec/SKILL.md first line under '## Your role' is '**Mode:** design-first'"
  else
    err "(2) skills/tech-spec/SKILL.md first line under '## Your role' is '$TECH_FIRST'; expected '**Mode:** design-first'"
  fi
fi

# ---------------------------------------------------------------------------
# Case (3) — verbatim AC-001-2 regex against the first 50 lines of
# skills/fix/SKILL.md (parallel to AC-005-1's grep recipe shape).
# ---------------------------------------------------------------------------
if [[ -f "$FIX_SKILL" ]]; then
  MATCHES=$(head -50 "$FIX_SKILL" | grep -cE '^\*\*Mode:\*\*[[:space:]]+diagnose-first[[:space:]]*$' || true)
  if [[ "$MATCHES" == "1" ]]; then
    pass "(3) head -50 skills/fix/SKILL.md | grep '^**Mode:** diagnose-first' returns exactly 1 match"
  else
    err "(3) AC-001-2 regex returned $MATCHES match(es) on skills/fix/SKILL.md; expected exactly 1"
  fi
else
  err "(3) skills/fix/SKILL.md is missing — cannot run regex check"
fi

harness::summary
