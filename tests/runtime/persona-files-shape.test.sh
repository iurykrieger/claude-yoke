#!/usr/bin/env bash
# shellcheck shell=bash
#
# persona-files-shape.test.sh — Sprint 01 / Task t02 / Acceptance Contract
# Scenario 2 + FR-1.
#
# Asserts that the three shipped persona files at plugin-root
# (`agents/sr-eng.md`, `agents/sr-qa.md`, `agents/sr-staff.md`) carry the
# extended frontmatter schema specified in
# `.yoke/specs/2026-05-01-agent-council.md` `### Persona spec frontmatter`.
#
# Test contract (binding for this file):
#   - exit 0 when every persona file parses with the expected schema.
#   - exit non-zero with a `wm: persona-files-shape violation:`-prefixed
#     stderr line naming the offending file plus key otherwise.
#
# Discovery: this test is enumerated by Sprint 01 Task t02's
# `**Acceptance criterion:**` line and by Acceptance Contract Scenario 2's
# `Then` clause.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
AGENTS_DIR="${REPO_ROOT}/agents"

violation() {
  printf 'wm: persona-files-shape violation: %s\n' "$1" >&2
  exit 1
}

# Extract the YAML frontmatter body of <file> (between the first and
# second `---` delimiter lines).
extract_frontmatter() {
  local file="$1"
  awk '
    BEGIN          { in_fm = 0; seen = 0 }
    /^---[[:space:]]*$/ {
      if (!seen) { in_fm = 1; seen = 1; next }
      if (in_fm) { in_fm = 0; exit }
    }
    in_fm { print }
  ' "$file"
}

# Returns 0 if `<key>:` is present at top level of the frontmatter body.
key_present() {
  local key="$1" fm="$2"
  printf '%s\n' "$fm" | awk -v key="$key" '
    $0 ~ "^"key":" { found = 1; exit }
    END { exit (found ? 0 : 1) }
  '
}

# Echoes the scalar value of `<key>:` on a single-line entry. Empty
# output means "not a single-line scalar" (e.g. block-list opener).
scalar_value() {
  local key="$1" fm="$2"
  printf '%s\n' "$fm" | awk -v key="$key" '
    $0 ~ "^"key":" {
      line = $0
      sub("^"key":[[:space:]]*", "", line)
      sub(/[[:space:]]+$/, "", line)
      print line
      exit
    }
  '
}

assert_file_shape() {
  local file="$1" persona="$2"
  [[ -f "$file" ]] || violation "${persona}: file missing at ${file}"

  local fm
  fm="$(extract_frontmatter "$file")"
  [[ -n "$fm" ]] || violation "${persona}: missing YAML frontmatter at ${file}"

  local key
  for key in name description tools objective sensor-toolkit; do
    if ! key_present "$key" "$fm"; then
      violation "${persona}: missing required key '${key}' in ${file}"
    fi
  done

  # `name:` value must equal the persona id (one of sr-eng / sr-qa / sr-staff).
  local name_value
  name_value="$(scalar_value name "$fm")"
  # strip wrapping quotes
  name_value="${name_value%\"}"
  name_value="${name_value#\"}"
  name_value="${name_value%\'}"
  name_value="${name_value#\'}"
  if [[ "$name_value" != "$persona" ]]; then
    violation "${persona}: name field '${name_value}' does not match persona id '${persona}' in ${file}"
  fi

  # `tools:` must be a non-empty single-line scalar (Claude Code
  # comma-separated list shape).
  local tools_value
  tools_value="$(scalar_value tools "$fm")"
  [[ -n "$tools_value" ]] || violation "${persona}: tools field is empty or a block in ${file}"

  # `sensor-toolkit:` must be a YAML list (block-style or flow-style).
  # Detect by looking for `- ` items below the key, or `[`-prefix scalar.
  local toolkit_inline
  toolkit_inline="$(scalar_value sensor-toolkit "$fm")"
  if [[ -n "$toolkit_inline" ]]; then
    # Inline value is acceptable only when it is `[]` or `[...]` (flow-style list).
    if [[ ! "$toolkit_inline" =~ ^\[.*\]$ ]]; then
      violation "${persona}: sensor-toolkit must be a YAML list (block '- ' items or inline '[...]'), got scalar '${toolkit_inline}' in ${file}"
    fi
  else
    # Block-style: at least one `- ` item must follow the key. Allow
    # an explicit empty list spelled `[]` (handled above) but disallow
    # a fully-empty key with no items at all.
    if ! printf '%s\n' "$fm" | awk '
      BEGIN { state = 0 }
      $0 ~ /^sensor-toolkit:/ { state = 1; next }
      state == 1 && /^[[:space:]]*-[[:space:]]/ { found = 1; exit }
      state == 1 && /^[A-Za-z_-]+:/ { exit }
      state == 1 && /^[[:space:]]*$/ { next }
      END { exit (found ? 0 : 1) }
    '; then
      violation "${persona}: sensor-toolkit is empty or malformed in ${file}"
    fi
  fi
}

# Sr Staff specifically must carry `review-skill: /review`.
assert_sr_staff_review_skill() {
  local file="${AGENTS_DIR}/sr-staff.md"
  local review
  review="$(awk '/^---$/{c++;next} c==1' "$file" | grep -E '^review-skill: ' || true)"
  if [[ -z "$review" ]] || ! printf '%s' "$review" | grep -q '/review'; then
    violation "sr-staff: review-skill must default to '/review' in ${file} (got '${review}')"
  fi
}

assert_file_shape "${AGENTS_DIR}/sr-eng.md"   sr-eng
assert_file_shape "${AGENTS_DIR}/sr-qa.md"    sr-qa
assert_file_shape "${AGENTS_DIR}/sr-staff.md" sr-staff
assert_sr_staff_review_skill

exit 0
