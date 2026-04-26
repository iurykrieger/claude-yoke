#!/bin/bash
# discover-from-pyproject.sh — parse a pyproject.toml file and surface
# `[tool.X]` section headers as a structured YAML sensor list to stdout.
#
# Usage: discover-from-pyproject.sh [<path-to-pyproject-toml>]
# Default path: ./pyproject.toml
#
# Recognized sections (line-based detection of `[tool.X]` headers):
#
#   testing:  [tool.pytest.ini_options] → command "pytest"
#   linting:  [tool.ruff], [tool.flake8], [tool.mypy]
#                                       → command "<tool>"
#   other:    [tool.poetry.scripts], [project.scripts] surface as
#             unclassified hints (no canonical command — host wraps).
#
# Inline tables (e.g. `tool.X = { … }`) are explicitly out of scope:
# detection produces a `notes:` warning when one is encountered but
# never causes a non-zero exit. Uses only bash 4 + POSIX awk — no TOML
# parser.
#
# Output: same YAML envelope as the other discoverers
# (`sensors:` + `notes:`).
#
# Exit codes:
#   0 — discovery ran (with or without findings)
#   2 — usage error

set -euo pipefail

pyproject="${1:-./pyproject.toml}"

emit_empty() {
  cat <<EOF
sensors: []
notes:
  - "$1"
EOF
}

if [ ! -f "$pyproject" ]; then
  emit_empty "pyproject.toml not found at '$pyproject'."
  exit 0
fi

# Detect inline tables (warnings only). A line like `tool.ruff = { ... }`
# is an inline table.
inline_warning=0
if awk '/^[[:space:]]*tool\.[A-Za-z0-9_.-]+[[:space:]]*=[[:space:]]*\{/ { found=1 } END { exit found?0:1 }' "$pyproject"; then
  inline_warning=1
fi

# Extract `[tool.X]` and `[project.X]` headers (single-bracket array-of-
# tables `[[tool.X]]` are skipped — the host can promote those to
# CLAUDE.md if needed).
headers="$(awk '
  /^\[(tool|project)\.[A-Za-z0-9_.-]+\][[:space:]]*$/ {
    # Strip leading [ and trailing ].
    line = $0
    sub(/^\[/, "", line)
    sub(/\][[:space:]]*$/, "", line)
    print line
  }
' "$pyproject" | sort -u)"

if [ -z "$headers" ]; then
  if [ "$inline_warning" -eq 1 ]; then
    emit_empty "pyproject.toml has only inline-table tool sections (unsupported by this discoverer)."
  else
    emit_empty "pyproject.toml parsed but no [tool.*] or [project.*] sections found."
  fi
  exit 0
fi

declare -a sensor_lines

while IFS= read -r hdr; do
  [ -z "$hdr" ] && continue

  category=""
  cmd=""

  case "$hdr" in
    tool.pytest.ini_options|tool.pytest)
      category="testing"; cmd="pytest"
      ;;
    tool.ruff|tool.ruff.*)
      # Avoid duplicate emission for tool.ruff plus tool.ruff.lint, etc.
      # We only emit on the canonical tool.ruff header. Sub-headers are
      # ignored for the catalog (they configure the same command).
      [ "$hdr" = "tool.ruff" ] && { category="linting"; cmd="ruff check"; }
      ;;
    tool.flake8)
      category="linting"; cmd="flake8"
      ;;
    tool.mypy|tool.mypy.*)
      [ "$hdr" = "tool.mypy" ] && { category="linting"; cmd="mypy"; }
      ;;
    tool.poetry.scripts|project.scripts)
      category="other"; cmd="${hdr}"
      ;;
    *)
      # Unrecognized tool/project section: surface as 'other' so the
      # human reviewer sees it but can ignore.
      category="other"; cmd="${hdr}"
      ;;
  esac

  if [ -n "$category" ] && [ -n "$cmd" ]; then
    sensor_lines+=("  - category: ${category}")
    sensor_lines+=("    command: \"${cmd}\"")
    sensor_lines+=("    source: pyproject")
  fi
done <<< "$headers"

if [ "${#sensor_lines[@]}" -eq 0 ]; then
  emit_empty "pyproject.toml has [tool.*] / [project.*] sections but none mapped to recognized commands."
  exit 0
fi

printf 'sensors:\n'
printf '%s\n' "${sensor_lines[@]}"

if [ "$inline_warning" -eq 1 ]; then
  cat <<'EOF'
notes:
  - "pyproject.toml contains inline-table tool definitions (unsupported); only [tool.X] section headers were considered."
EOF
else
  printf 'notes: []\n'
fi

exit 0
