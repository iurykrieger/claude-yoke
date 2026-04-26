#!/bin/bash
# discover-from-package-json.sh — parse a host project's `package.json`
# `scripts` block and emit a structured YAML sensor list to stdout.
#
# Usage: discover-from-package-json.sh [<path-to-package-json>]
# Default path: ./package.json
#
# Classification (prefix-match on script name, lowercase):
#   testing:  test*, unit*, e2e*
#   linting:  lint*, eslint*, ruff*, mypy*, flake8*, prettier*
#   build:    build*, compile*, bundle*
#   other:    everything else (surfaced unclassified)
#
# Best-effort posture: malformed JSON, missing file, empty `scripts` →
# `sensors: []` plus a `notes:` warning. Never exits non-zero (except
# on usage error). Uses only bash 4 + POSIX awk/sed — no `jq`, no
# Python.
#
# Output (YAML):
#
#   sensors:
#     - category: testing
#       command: "npm run test"
#       source: package-json
#     ... entries
#   notes:
#     - "<warning, when applicable>"
#
# Or:
#
#   sensors: []
#   notes:
#     - "<reason>"
#
# Exit codes:
#   0 — discovery ran (with or without findings)
#   2 — usage error

set -euo pipefail

pkg_json="${1:-./package.json}"

emit_empty() {
  cat <<EOF
sensors: []
notes:
  - "$1"
EOF
}

if [ ! -f "$pkg_json" ]; then
  emit_empty "package.json not found at '$pkg_json'."
  exit 0
fi

# Extract the contents of the top-level "scripts" object. We use a
# narrow line-based regex (not full JSON parsing) — multi-line values
# are not supported and surface as a `notes:` warning per discoverer's
# best-effort posture.
#
# The awk script tracks brace depth from the opening `{` of "scripts":
# it copies every line strictly inside that object until depth returns
# to zero.

scripts_block="$(awk '
  /"scripts"[[:space:]]*:[[:space:]]*\{/ {
    in_scripts = 1
    # Initialize depth based on this line: count { and } here only
    # (post the "scripts": { match).
    rest = $0
    sub(/.*"scripts"[[:space:]]*:[[:space:]]*\{/, "", rest)
    n_open  = gsub(/\{/, "{", rest)
    n_close = gsub(/\}/, "}", rest)
    depth = 1 + n_open - n_close
    print rest
    next
  }
  in_scripts {
    n_open  = gsub(/\{/, "{", $0)
    n_close = gsub(/\}/, "}", $0)
    depth += n_open - n_close
    if (depth <= 0) {
      # Strip from the closing } onward and emit the prefix.
      pos = index($0, "}")
      if (pos > 0) print substr($0, 1, pos - 1)
      in_scripts = 0
      exit
    }
    print
  }
' "$pkg_json")"

if [ -z "$scripts_block" ]; then
  emit_empty "package.json has no \"scripts\" block (or it is empty)."
  exit 0
fi

# Classify a script name into one of: testing, linting, build, other.
classify() {
  local name_lc="$1"
  case "$name_lc" in
    test*|unit*|e2e*)                                       echo testing  ;;
    lint*|eslint*|ruff*|mypy*|flake8*|prettier*)            echo linting  ;;
    build*|compile*|bundle*)                                 echo build    ;;
    *)                                                       echo other    ;;
  esac
}

declare -a sensor_lines
declare multiline_warning=0

# Parse `"name": "value"` per line. Multi-line values produce a warning.
while IFS= read -r line; do
  # Skip blank-ish lines.
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue

  if [[ "$line" =~ \"([^\"]+)\"[[:space:]]*:[[:space:]]*\"((\\.|[^\"\\])*)\"([[:space:]]*,)?[[:space:]]*$ ]]; then
    script_name="${BASH_REMATCH[1]}"
    script_value="${BASH_REMATCH[2]}"
  elif [[ "$line" =~ \"([^\"]+)\"[[:space:]]*:[[:space:]]*\" ]]; then
    # Detected a name: "..." pair that doesn't close on the same line:
    # multi-line value. Skip and warn.
    multiline_warning=1
    continue
  else
    continue
  fi

  category="$(classify "$(echo "$script_name" | tr '[:upper:]' '[:lower:]')")"

  # The actual command Yoke runs is `npm run <script>` (canonical npm
  # invocation, even if the underlying value uses yarn/pnpm/bun — those
  # tooling differences live in the host project, not the catalog).
  cmd="npm run ${script_name}"

  sensor_lines+=("  - category: ${category}")
  sensor_lines+=("    command: \"${cmd}\"")
  sensor_lines+=("    source: package-json")
done <<< "$scripts_block"

if [ "${#sensor_lines[@]}" -eq 0 ]; then
  if [ "$multiline_warning" -eq 1 ]; then
    emit_empty "package.json scripts contained only multi-line values (unsupported); discoverer skipped them."
  else
    emit_empty "package.json scripts block parsed but no scripts matched the bullet shape."
  fi
  exit 0
fi

printf 'sensors:\n'
printf '%s\n' "${sensor_lines[@]}"

if [ "$multiline_warning" -eq 1 ]; then
  cat <<'EOF'
notes:
  - "Some scripts had multi-line values and were skipped (unsupported by this discoverer)."
EOF
else
  printf 'notes: []\n'
fi

exit 0
