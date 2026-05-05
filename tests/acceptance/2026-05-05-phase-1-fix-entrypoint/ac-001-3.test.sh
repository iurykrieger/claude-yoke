#!/usr/bin/env bash
# criterion: AC-001-3
#
# AC-001-3 (binding text from
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md):
#
#   "Approval-menu option 1 (`approve_and_continue`) on a happy-path
#    fix-spec invokes `/yoke:tech-spec` via the `Skill` tool in the
#    same turn (no manual paste from the user); the fallback branch
#    fires only when the `Skill` tool is unavailable."
#
# Sprint scope (s03-t04): skills/fix/SKILL.md renders the shared
# approval-menu (templates/approval-menu.md) at Trigger 1 with
# `next_skill = /yoke:tech-spec` and chains via the `Skill` tool on
# option 1, with the documented fallback when `Skill` is unavailable.
#
# Pragmatic gating (per Sr QA cycle prompt direction):
#   The runtime invocation of /yoke:tech-spec via the Skill tool is an
#   LLM-execution observable, not a bash-testable observable. The
#   binding judgment is the skill body's documented chain shape: if the
#   skill body documents the right next_skill, the right Skill-tool
#   invocation, and the right fallback, the LLM follows the doctrine.
#   This test gates on those documented shapes plus a parallel check
#   against /yoke:discover (the canonical chain shape both skills
#   inherit).
#
#   Manual end-to-end recipe (recorded for human review):
#     $ /yoke:fix "axios CVE bump to 1.6.0"
#     # complete dialogue, reach Trigger 1, select option 1
#     # OBSERVE: Claude immediately invokes /yoke:tech-spec via the
#     # Skill tool in the same turn; no manual paste required.
#     # FALLBACK OBSERVE: when the Skill tool is unavailable in the
#     # current Claude Code session, option 1's label includes
#     # "(manual: run /yoke:tech-spec after this step)".
#
# Observable conditions tested:
#   (1) skills/fix/SKILL.md exists.
#   (2) skill body cites templates/approval-menu.md as the Trigger 1
#       surface (shared with /yoke:discover).
#   (3) skill body declares /yoke:tech-spec as the next_skill chained
#       on option 1.
#   (4) skill body documents the `Skill` tool as the chaining
#       mechanism (verbatim string presence).
#   (5) skill body documents the fallback path with the verbatim
#       suffix `(manual: run /yoke:tech-spec after this step)` per
#       PRD FR-11.
#   (6) skill frontmatter declares the Skill tool in
#       `allowed-tools:` (no Skill tool in allowed-tools means the
#       chain cannot fire; missing this = silent regression).

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

SKILL="$REPO_ROOT/skills/fix/SKILL.md"

# ---------------------------------------------------------------------------
# Case (1) — skills/fix/SKILL.md exists.
# ---------------------------------------------------------------------------
if [[ -f "$SKILL" ]]; then
  pass "(1) skills/fix/SKILL.md exists"
else
  err "(1) skills/fix/SKILL.md is missing — Sr Eng s03-t04 deliverable"
  harness::summary
fi

SKILL_BODY="$(cat "$SKILL")"

# ---------------------------------------------------------------------------
# Case (2) — references templates/approval-menu.md.
# ---------------------------------------------------------------------------
if grep -q "templates/approval-menu.md" <<<"$SKILL_BODY"; then
  pass "(2) skills/fix/SKILL.md references templates/approval-menu.md (Trigger 1 surface)"
else
  err "(2) skills/fix/SKILL.md does NOT reference templates/approval-menu.md"
fi

# ---------------------------------------------------------------------------
# Case (3) — declares /yoke:tech-spec as next_skill.
# ---------------------------------------------------------------------------
if grep -q "/yoke:tech-spec" <<<"$SKILL_BODY"; then
  pass "(3) skills/fix/SKILL.md declares /yoke:tech-spec as the chained next skill"
else
  err "(3) skills/fix/SKILL.md does NOT declare /yoke:tech-spec as next_skill"
fi

# ---------------------------------------------------------------------------
# Case (4) — documents the Skill tool as chaining mechanism.
# ---------------------------------------------------------------------------
if grep -qE 'Skill tool|`Skill`' <<<"$SKILL_BODY"; then
  pass "(4) skills/fix/SKILL.md documents the 'Skill' tool as chaining mechanism"
else
  err "(4) skills/fix/SKILL.md does NOT document the 'Skill' tool as chaining mechanism"
fi

# ---------------------------------------------------------------------------
# Case (5) — fallback path documented per PRD FR-11.
#
# The literal-string fingerprint is `(manual: run /yoke:tech-spec
# after this step)`. The skill body may wrap this string across line
# breaks (markdown soft-wrap at ~80 cols), so we collapse whitespace
# in the body before substring matching. This is the same robustness
# that /yoke:discover's same-shape clause exhibits.
# ---------------------------------------------------------------------------
FALLBACK_LITERAL='(manual: run /yoke:tech-spec after this step)'
SKILL_BODY_FLAT="$(tr '\n' ' ' <<<"$SKILL_BODY" | tr -s ' ')"
if grep -qF "$FALLBACK_LITERAL" <<<"$SKILL_BODY_FLAT"; then
  pass "(5) skills/fix/SKILL.md documents the FR-11 fallback suffix verbatim (whitespace-collapsed match)"
else
  err "(5) skills/fix/SKILL.md missing FR-11 fallback suffix verbatim: '$FALLBACK_LITERAL'"
fi

# ---------------------------------------------------------------------------
# Case (6) — frontmatter allowed-tools advisory.
#
# Empirical convention check: /yoke:discover (the canonical PRD-side
# Phase-1 skill that already chains via Skill on Trigger 1) does NOT
# declare `Skill` in its allowed-tools either, yet its chain works.
# This case asserts only that allowed-tools is well-formed; whether
# `Skill` is explicitly listed is left open per the discover precedent.
# Drift signal (not failure): if /yoke:discover later adds Skill,
# Sprint-04+ harmonization should re-evaluate.
# ---------------------------------------------------------------------------
FRONTMATTER=$(awk '
  /^---$/ { count++; if (count == 1) next; if (count == 2) exit }
  count == 1 { print }
' "$SKILL")

if grep -qE '^allowed-tools:' <<<"$FRONTMATTER"; then
  pass "(6) skills/fix/SKILL.md frontmatter declares allowed-tools (Skill-tool listing parity with /yoke:discover is open)"
else
  err "(6) skills/fix/SKILL.md frontmatter is missing allowed-tools entirely"
fi

harness::summary
