#!/usr/bin/env bash
# criterion: AC-003-1 / sprint-02 generate-sprints-skill-exists
#
# Binding Acceptance Criteria (PRD US-003, ratified 2026-05-03T06:39:27Z):
#   "skills/generate-sprints/SKILL.md exists with frontmatter declaring
#    `name: generate-sprints`, an `argument-hint`, and an `allowed-tools`
#    list that includes `Read, Write, Edit, Bash, Skill`."
#
# Sprint-level anchor (.yoke/sprints/2026-05-03-generate-sprints-skill-s02.md):
#   - Functional acceptance criterion id: generate-sprints-skill-exists
#   - Sprint DoD line: `test -f skills/generate-sprints/SKILL.md` returns 0
#   - Task s02-t01 acceptance criterion: file exists AND `name`,
#     `argument-hint`, `allowed-tools` keys are present.
#
# Then-clause (binding):
#   1. `test -f skills/generate-sprints/SKILL.md` exits 0.
#   2. The frontmatter block (between the two `---` fences at the top)
#      contains the literal key `name: generate-sprints`.
#   3. The frontmatter contains a key `argument-hint:`.
#   4. The frontmatter contains a key `allowed-tools:` whose value
#      mentions every required tool (`Read`, `Write`, `Edit`, `Bash`,
#      `Skill`). The PRD US-003 list is `Read, Write, Edit, Bash,
#      Skill`; the sprint task body adds `Grep, Glob` — we assert the
#      PRD-binding list as the floor, allowing extra tools above it.
#
# Watchdog convention — keep the smoke-test guard.

set -euo pipefail

sleep 600 && kill -TERM $$ &
WATCHDOG_PID=$!
trap 'kill -TERM "${WATCHDOG_PID}" 2>/dev/null || true' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

SKILL="skills/generate-sprints/SKILL.md"
FAIL=0

# ---------------------------------------------------------------------------
# Then-clause part 1 — the file exists.
# ---------------------------------------------------------------------------
if [[ ! -f "$SKILL" ]]; then
  printf 'FAIL: %s does not exist (Sr Eng output pending; expected in s02-t01)\n' "$SKILL" >&2
  printf '\n--- Result ---\nFAIL: us-003-skill-frontmatter\n' >&2
  exit 1
fi
printf 'PASS: %s exists\n' "$SKILL"

# ---------------------------------------------------------------------------
# Extract the frontmatter block (everything between the first two `---`
# fences). We match the literal `^---$` line; awk emits only the body.
# ---------------------------------------------------------------------------
FM="$(awk '
  BEGIN { in_fm=0; emitted=0 }
  /^---[[:space:]]*$/ {
    if (in_fm == 0 && emitted == 0) { in_fm=1; next }
    if (in_fm == 1) { exit }
  }
  in_fm == 1 { print }
' "$SKILL")"

if [[ -z "$FM" ]]; then
  printf 'FAIL: %s has no frontmatter block (expected `---` fences at top)\n' "$SKILL" >&2
  FAIL=1
fi

# ---------------------------------------------------------------------------
# Then-clause part 2 — `name: generate-sprints` literal key.
# ---------------------------------------------------------------------------
if printf '%s\n' "$FM" | grep -qE '^name:[[:space:]]+generate-sprints[[:space:]]*$'; then
  printf 'PASS: frontmatter declares `name: generate-sprints`\n'
else
  printf 'FAIL: frontmatter missing `name: generate-sprints` literal\n' >&2
  FAIL=1
fi

# ---------------------------------------------------------------------------
# Then-clause part 3 — `argument-hint:` key present (value may be empty).
# ---------------------------------------------------------------------------
if printf '%s\n' "$FM" | grep -qE '^argument-hint:'; then
  printf 'PASS: frontmatter declares `argument-hint:`\n'
else
  printf 'FAIL: frontmatter missing `argument-hint:` key\n' >&2
  FAIL=1
fi

# ---------------------------------------------------------------------------
# Then-clause part 4 — `allowed-tools:` key present and mentions every
# required tool from the PRD US-003 binding list.
# ---------------------------------------------------------------------------
ALLOWED_LINE="$(printf '%s\n' "$FM" | grep -E '^allowed-tools:' || true)"
if [[ -z "$ALLOWED_LINE" ]]; then
  printf 'FAIL: frontmatter missing `allowed-tools:` key\n' >&2
  FAIL=1
else
  printf 'PASS: frontmatter declares `allowed-tools:`\n'
  for tool in Read Write Edit Bash Skill; do
    if printf '%s\n' "$ALLOWED_LINE" | grep -qE "\\b${tool}\\b"; then
      printf 'PASS: allowed-tools includes `%s`\n' "$tool"
    else
      printf 'FAIL: allowed-tools missing required tool `%s`\n' "$tool" >&2
      FAIL=1
    fi
  done
fi

if [[ "$FAIL" -ne 0 ]]; then
  printf '\n--- Result ---\nFAIL: us-003-skill-frontmatter\n' >&2
  exit 1
fi
printf '\n--- Result ---\nPASS: us-003-skill-frontmatter\n'
exit 0
