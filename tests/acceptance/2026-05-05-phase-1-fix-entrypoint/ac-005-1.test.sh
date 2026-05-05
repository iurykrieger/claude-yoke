#!/usr/bin/env bash
# criterion: AC-005-1
#
# AC-005-1 (binding text from
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md):
#
#   "head -50 skills/tech-spec/SKILL.md | grep -E
#    '^\*\*Mode:\*\*\s+design-first\s*$' returns exactly one match."
#
# Sprint scope (s03-t01): Sr Eng backfills `**Mode:** design-first` as
# the first line under the "Your role" heading in skills/tech-spec/SKILL.md.
# The literal name "Senior Engineer persona" is preserved; the Mode tag
# is the disambiguator paired with /yoke:fix's `**Mode:** diagnose-first`.
#
# Observable conditions tested:
#   (1) skills/tech-spec/SKILL.md exists.
#   (2) `head -50 skills/tech-spec/SKILL.md | grep -E '^\*\*Mode:\*\*\s+design-first\s*$'`
#       returns exactly one match (verbatim AC-005-1 grep recipe).
#   (3) The Mode tag occurs on the first non-empty line under the
#       "## Your role" heading (architectural intent of FR-2 / OQ-2:
#       the Mode tag is the disambiguator, structurally pinned to
#       "first line under Your role" — a Mode tag floating in the
#       middle of the body would still satisfy (2) but violates the
#       PRD's structural intent).

set -euo pipefail

# Internal watchdog (per repo testing convention).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

# Resolve repo root from the location of this file:
#   tests/acceptance/<slug>/ac-005-1.test.sh -> ../../..
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=/dev/null
source "$REPO_ROOT/tests/lib/harness.sh"

SKILL_PATH="$REPO_ROOT/skills/tech-spec/SKILL.md"

# ---------------------------------------------------------------------------
# Case (1) — skills/tech-spec/SKILL.md exists.
# ---------------------------------------------------------------------------
if [[ -f "$SKILL_PATH" ]]; then
  pass "(1) skills/tech-spec/SKILL.md exists"
else
  err "(1) skills/tech-spec/SKILL.md is missing — Sr Eng s03-t01 deliverable"
  harness::summary
fi

# ---------------------------------------------------------------------------
# Case (2) — verbatim AC-005-1 grep recipe.
#
# `head -50 skills/tech-spec/SKILL.md | grep -E '^\*\*Mode:\*\*\s+design-first\s*$'`
# MUST return exactly one match. Note: BSD/macOS grep -E does not parse
# `\s` inside POSIX ERE; the AC ratifies the Perl-style escape, so the
# test pattern uses an explicit `[[:space:]]` class to match the same
# whitespace semantics across grep flavours while keeping the ratified
# literal in the failure message.
# ---------------------------------------------------------------------------
MATCHES=$(head -50 "$SKILL_PATH" | grep -cE '^\*\*Mode:\*\*[[:space:]]+design-first[[:space:]]*$' || true)

if [[ "$MATCHES" == "1" ]]; then
  pass "(2) head -50 skills/tech-spec/SKILL.md | grep '^**Mode:** design-first' returns exactly 1 match"
else
  err "(2) AC-005-1 grep returned $MATCHES match(es); expected exactly 1. Mode tag missing or malformed in first 50 lines."
fi

# ---------------------------------------------------------------------------
# Case (3) — structural pin: the Mode tag is the FIRST non-empty line
# under the `## Your role` heading.
#
# The AC body wording ("first line under 'Your role'") encodes the
# architectural intent. A test that only checks `head -50 | grep` would
# pass even if the Mode tag floated in the middle of the body — this
# case forecloses that drift.
# ---------------------------------------------------------------------------
ROLE_BLOCK=$(awk '
  /^## Your role/ { in_role=1; next }
  in_role && /^## / { exit }
  in_role { print }
' "$SKILL_PATH")

# First non-empty line of the role block.
FIRST_LINE=$(printf '%s\n' "$ROLE_BLOCK" | awk 'NF { print; exit }')

if [[ "$FIRST_LINE" =~ ^\*\*Mode:\*\*[[:space:]]+design-first[[:space:]]*$ ]]; then
  pass "(3) first non-empty line under '## Your role' is '**Mode:** design-first'"
else
  err "(3) first non-empty line under '## Your role' is '$FIRST_LINE'; expected '**Mode:** design-first'"
fi

harness::summary
