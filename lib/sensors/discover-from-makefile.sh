#!/bin/bash
# discover-from-makefile.sh — parse top-level Makefile targets and emit
# a structured YAML sensor list to stdout.
#
# Usage: discover-from-makefile.sh [<path-to-makefile>]
# Default path: ./Makefile
#
# Detection: lines anchored at BOL matching ^[A-Za-z][A-Za-z0-9_-]*: …
# (target rule), excluding `.PHONY:` and rule bodies (which start with
# a literal TAB). This rule is conservative: shell snippets containing
# `:` (e.g. `echo "key: value"`) live inside rule bodies and never
# match the BOL anchor.
#
# Classification (prefix-match on target name, lowercase):
#   testing:  test*, unit*, e2e*
#   linting:  lint*, check*
#   build:    build*, compile*
#   other:    everything else
#
# Best-effort posture: missing file, no targets → `sensors: []` plus a
# `notes:` warning. Never exits non-zero (except on usage error). Uses
# only bash 4 + POSIX awk — no external parsers.
#
# Output: same YAML envelope as the other discoverers
# (`sensors:` + `notes:`).
#
# Exit codes:
#   0 — discovery ran (with or without findings)
#   2 — usage error

set -euo pipefail

makefile="${1:-./Makefile}"

emit_empty() {
  cat <<EOF
sensors: []
notes:
  - "$1"
EOF
}

if [ ! -f "$makefile" ]; then
  emit_empty "Makefile not found at '$makefile'."
  exit 0
fi

# Extract target names. Match lines that begin with a letter, followed
# by [A-Za-z0-9_-]*, then a colon. Skip ".PHONY:" and lines whose first
# character is a tab (rule bodies).
targets="$(awk '
  /^[A-Za-z][A-Za-z0-9_-]*:/ {
    # Capture the target name before the first colon.
    n = index($0, ":")
    if (n > 0) {
      name = substr($0, 1, n - 1)
      if (name == ".PHONY") next
      print name
    }
  }
' "$makefile" | sort -u)"

if [ -z "$targets" ]; then
  emit_empty "Makefile parsed but no top-level targets found."
  exit 0
fi

classify() {
  local name_lc="$1"
  case "$name_lc" in
    test*|unit*|e2e*)            echo testing ;;
    lint*|check*)                 echo linting ;;
    build*|compile*)              echo build   ;;
    *)                            echo other   ;;
  esac
}

declare -a sensor_lines

while IFS= read -r target; do
  [ -z "$target" ] && continue
  category="$(classify "$(echo "$target" | tr '[:upper:]' '[:lower:]')")"
  cmd="make ${target}"
  sensor_lines+=("  - category: ${category}")
  sensor_lines+=("    command: \"${cmd}\"")
  sensor_lines+=("    source: makefile")
done <<< "$targets"

printf 'sensors:\n'
printf '%s\n' "${sensor_lines[@]}"
printf 'notes: []\n'

exit 0
