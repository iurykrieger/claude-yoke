#!/bin/bash
# verify-acceptance.sh — runs the sensors declared in
# .yoke/acceptance-contract.md and emits structured per-criterion results.
#
# Usage: verify-acceptance.sh [<acceptance-contract-path>]
# Default path: .yoke/acceptance-contract.md
#
# v0.3.0 supports only "shell command" sensor types (e.g. `npm test`,
# `pytest`). Richer sensor types (structural fixtures, inferential
# semantic judges with rubrics) ship in later sprints.
#
# Sensors are extracted from the "## Sensors > ### Computational" section
# of the Acceptance Contract; the Validator (Sprint 3) writes them in this
# shape:
#
#   ## Sensors
#
#   ### Computational
#   - linter: `npm run lint`
#   - type-check: `mypy --strict`
#   - structural: `pytest tests/contracts/`
#   - unit: `pytest tests/unit/`
#
# Each bullet's first backticked segment is the command Yoke will run.
#
# Output (YAML to stdout):
#
#   results:
#     - sensor: "linter"
#       command: "npm run lint"
#       status: pass | fail | skip
#       exit_code: <int>
#       output_excerpt: "<first ~5 non-empty lines, joined with \n>"
#       reason: "<why skip, when applicable>"
#
# Exit codes:
#   0 — verification ran (regardless of individual sensor outcomes)
#   2 — usage error
#   3 — Acceptance Contract not found
#   4 — Acceptance Contract has no Sensors > Computational section

set -euo pipefail

contract="${1:-.yoke/acceptance-contract.md}"

if [ ! -f "$contract" ]; then
  echo "Error: Acceptance Contract not found at '$contract'." >&2
  exit 3
fi

# Extract the "Computational" sensors block under "## Sensors".
sensors_block=$(awk '
  /^## Sensors[[:space:]]*$/ { in_sensors = 1; next }
  in_sensors && /^## / && !/^## Sensors/ { in_sensors = 0 }
  in_sensors && /^### Computational[[:space:]]*$/ { in_comp = 1; next }
  in_sensors && in_comp && /^### / { in_comp = 0 }
  in_sensors && in_comp { print }
' "$contract")

if [ -z "$sensors_block" ]; then
  echo "Error: Acceptance Contract has no '## Sensors > ### Computational' section." >&2
  exit 4
fi

# Helper: escape a string for safe single-line YAML double-quoted scalar.
# Handles backslashes, double quotes, and newlines.
escape_yaml() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/}
  printf '%s' "$s"
}

echo "results:"

# Iterate over bullet lines that match `- <name>: \`<command>\`` shape.
while IFS= read -r line; do
  [ -z "$line" ] && continue

  if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+([^:]+):[[:space:]]*\`([^\`]+)\` ]]; then
    sensor_name=$(echo "${BASH_REMATCH[1]}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    command_str="${BASH_REMATCH[2]}"
  else
    continue
  fi

  # Determine the leading binary; if it's not on PATH, skip the sensor.
  leading_bin=$(echo "$command_str" | awk '{print $1}')

  status=""
  exit_code=-1
  output_excerpt=""
  reason=""

  if ! command -v "$leading_bin" >/dev/null 2>&1; then
    status="skip"
    reason="binary not found: $leading_bin"
  else
    # Detach from the parent loop's stdin (the `<<< "$sensors_block"`
    # here-string). A sensor command that reads stdin would otherwise
    # consume pending bullets and silently truncate the run.
    set +e
    sensor_output=$(bash -c "$command_str" </dev/null 2>&1)
    exit_code=$?
    set -e

    if [ "$exit_code" -eq 0 ]; then
      status="pass"
    else
      status="fail"
      reason="exit_code=$exit_code"
    fi
    # Truncate output to first 5 non-empty lines.
    output_excerpt=$(echo "$sensor_output" | grep -v '^[[:space:]]*$' | head -5 || true)
  fi

  cat <<EOF
  - sensor: "$(escape_yaml "$sensor_name")"
    command: "$(escape_yaml "$command_str")"
    status: $status
    exit_code: $exit_code
    output_excerpt: "$(escape_yaml "$output_excerpt")"
    reason: "$(escape_yaml "$reason")"
EOF
done <<< "$sensors_block"

exit 0
