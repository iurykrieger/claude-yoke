#!/bin/bash
# discover-from-claude-md.sh — parse the host project's CLAUDE.md for
# `## Testing`, `## Linting`, `## Build` sections (case-insensitive) and
# emit a structured YAML sensor list to stdout.
#
# Usage: discover-from-claude-md.sh [<path-to-claude-md>]
#
# Default path: ./CLAUDE.md
#
# Convention: each section contains markdown bullet lines. The first
# backticked segment in each bullet is treated as the runnable command.
# Example:
#
#   ## Testing
#   - `npm test` — run unit tests
#   - `pytest tests/` — run Python tests
#
# Output (YAML):
#
#   sensors:
#     - category: testing
#       command: "npm test"
#       source: claude-md
#     - category: testing
#       command: "pytest tests/"
#       source: claude-md
#
# If no marked sections are found (or CLAUDE.md is missing):
#
#   sensors: []
#   notes:
#     - "<reason>"
#
# The Validator must ask the user directly when sensors are empty.
#
# Exit codes:
#   0 — discovery ran (with or without findings)
#   2 — usage error

set -euo pipefail

claude_md="${1:-./CLAUDE.md}"

if [ ! -f "$claude_md" ]; then
  cat <<'EOF'
sensors: []
notes:
  - "CLAUDE.md not found. Validator must ask the user."
EOF
  exit 0
fi

# Categories Yoke recognizes (canonical lowercase names). Header matching
# is case-insensitive (done inside awk with tolower()).
categories=(testing linting build)

# Extract bullet lines from a given section. Section is delimited by `## `
# headings. We capture lines that look like markdown bullets. Heading
# matching is case-insensitive.
extract_section_commands() {
  local file="$1"
  local heading="$2"   # canonical lowercase name

  awk -v h="$heading" '
    BEGIN { pat = "^## " h "[[:space:]]*$" }
    {
      lower = tolower($0)
      if (lower ~ pat) { in_section = 1; next }
      if (in_section && $0 ~ /^## /) { in_section = 0 }
      if (in_section && /^[[:space:]]*[-*][[:space:]]+/) print
    }
  ' "$file"
}

# Parse a bullet line into the first backticked command. Skips bullets
# that don't contain a backticked command. Echoes the command text or
# empty.
extract_command_from_bullet() {
  local line="$1"
  if [[ "$line" =~ \`([^\`]+)\` ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

# Build the YAML output.
output=""
found_any=0

for category in "${categories[@]}"; do
  bullets=$(extract_section_commands "$claude_md" "$category")
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    cmd=$(extract_command_from_bullet "$line")
    if [ -n "$cmd" ]; then
      # Escape any backslash and double quote for safe YAML
      escaped=${cmd//\\/\\\\}
      escaped=${escaped//\"/\\\"}
      output+="  - category: ${category}"$'\n'
      output+="    command: \"${escaped}\""$'\n'
      output+="    source: claude-md"$'\n'
      found_any=1
    fi
  done <<< "$bullets"
done

if [ "$found_any" -eq 0 ]; then
  cat <<'EOF'
sensors: []
notes:
  - "CLAUDE.md found but no commands discovered under '## Testing', '## Linting', or '## Build' sections. Validator must ask the user."
EOF
  exit 0
fi

printf 'sensors:\n%s' "$output"
exit 0
