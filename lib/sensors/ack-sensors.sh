#!/bin/bash
# ack-sensors.sh — implementation behind /yoke:ack-sensors.
#
# Modes:
#   catalog (default) — enumerate every sensor available for the host
#       project. v0.4.0 surfaces only `CLAUDE.md`-derived sensors;
#       additional discoverers (package.json, Makefile, pyproject.toml)
#       ship in Part 4.
#   readiness <acceptance-contract-path> — verify every sensor declared
#       under `## Sensors > ### Computational` in the contract is
#       reachable on $PATH.
#
# Usage:
#   bash lib/sensors/ack-sensors.sh [--mode catalog | readiness] [<contract>]
#
# Output:
#   stdout — structured YAML (see SKILL.md for the schema per mode)
#   stderr — diagnostics
#
# Exit codes:
#   0 — catalog or readiness ran successfully
#   2 — usage error
#   3 — Acceptance Contract not found (readiness only)
#   4 — at least one sensor's binary is missing (readiness only)
#
# Determinism: catalog output is sorted by (category, source, command)
# under LC_ALL=C, so repeated invocations on the same project are
# byte-identical.

set -euo pipefail

mode="catalog"
contract=""

while [ $# -gt 0 ]; do
  case "$1" in
    --mode)
      if [ $# -lt 2 ]; then
        echo "Error: --mode requires a value." >&2
        exit 2
      fi
      mode="$2"
      shift 2
      ;;
    --mode=*)
      mode="${1#--mode=}"
      shift
      ;;
    -h|--help)
      sed -n '2,/^# Determinism/p' "$0" >&2 || true
      exit 0
      ;;
    *)
      if [ -z "$contract" ]; then
        contract="$1"
        shift
      else
        echo "Error: unexpected argument: $1" >&2
        exit 2
      fi
      ;;
  esac
done

# Resolve plugin root from this script's location: lib/sensors/ → ../..
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_root="$(cd "${script_dir}/../.." && pwd)"

# ---------------------------------------------------------------------------
# Catalog mode
# ---------------------------------------------------------------------------
catalog_mode() {
  local claude_md="${PWD}/CLAUDE.md"
  local pkg_json="${PWD}/package.json"
  local makefile="${PWD}/Makefile"
  local pyproject="${PWD}/pyproject.toml"

  # Discoverer ordering matters for dedup precedence: when two
  # discoverers emit the same (category, command) tuple, the first one
  # wins. CLAUDE.md is curated by the human, so it leads. Then alpha
  # by source name: makefile → package-json → pyproject.
  local d_claude="${plugin_root}/lib/sensors/discover-from-claude-md.sh"
  local d_make="${plugin_root}/lib/sensors/discover-from-makefile.sh"
  local d_pkg="${plugin_root}/lib/sensors/discover-from-package-json.sh"
  local d_pyp="${plugin_root}/lib/sensors/discover-from-pyproject.sh"

  if [ ! -f "$d_claude" ]; then
    echo "Error: claude-md discoverer not found at ${d_claude}" >&2
    exit 2
  fi

  # Each discoverer exits 0 even when its source file is missing (best-
  # effort posture). Concatenate their YAML outputs.
  local raw_claude raw_make raw_pkg raw_pyp
  raw_claude="$(bash "$d_claude" "$claude_md")"
  raw_make="$( [ -f "$d_make" ] && bash "$d_make" "$makefile" || printf 'sensors: []\nnotes: []\n' )"
  raw_pkg="$(  [ -f "$d_pkg"  ] && bash "$d_pkg"  "$pkg_json" || printf 'sensors: []\nnotes: []\n' )"
  raw_pyp="$(  [ -f "$d_pyp"  ] && bash "$d_pyp"  "$pyproject" || printf 'sensors: []\nnotes: []\n' )"

  local raw
  raw="$(printf '%s\n%s\n%s\n%s\n' "$raw_claude" "$raw_make" "$raw_pkg" "$raw_pyp")"

  # Each discoverer emits a YAML envelope:
  #   sensors:
  #     - category: testing
  #       command: "npm test"
  #       source: claude-md
  #     ... entries (3 lines each)
  #   notes:
  #     - "..."  (or `notes: []`)
  #
  # We extract entries from all four, sort under LC_ALL=C by
  # (category, source, command), and dedup on (category, command) —
  # keeping first-seen (which respects the discoverer ordering above).
  # Notes are unioned and emitted at the end.

  local entries notes
  entries="$(printf '%s\n' "$raw" | awk '
    /^  - category:/ { in_e=1; buf=$0 ORS; next }
    in_e && /^    command:/ { buf=buf $0 ORS; next }
    in_e && /^    source:/  { buf=buf $0 ORS; print buf; buf=""; in_e=0; next }
  ')"

  # Collect non-empty notes lines from any discoverer that emitted them.
  # Filter out "<file> not found" notes — they are boilerplate, not
  # actionable signal (a host project legitimately may not have a
  # Makefile, package.json, or pyproject.toml). Real warnings
  # (multi-line values, inline tables, etc.) still surface.
  notes="$(printf '%s\n' "$raw" | awk '
    /^notes:[[:space:]]*\[/ { next }                  # `notes: []` skipped
    /^notes:[[:space:]]*$/  { in_notes=1; next }
    in_notes && /^[A-Za-z_][A-Za-z0-9_]*:/ { in_notes=0 }
    in_notes && /^[[:space:]]*-[[:space:]]+/ {
      if ($0 ~ /not found at/) next
      print
    }
  ')"

  if [ -z "$entries" ]; then
    printf 'sensors: []\n'
  else
    printf 'sensors:\n'
    # Flatten each 3-line block to a single TSV line, sort under
    # LC_ALL=C, then dedup on (category, command) keeping first-seen.
    # Discoverer ordering in the input stream determines first-seen
    # precedence: CLAUDE.md → makefile → package-json → pyproject.
    printf '%s' "$entries" | awk '
      BEGIN { RS=""; OFS="\t" }
      {
        cat=""; cmd=""; src=""
        n = split($0, lines, "\n")
        for (i=1; i<=n; i++) {
          if (lines[i] ~ /^  - category:/) { v=lines[i]; sub(/^  - category: */, "", v); cat=v }
          else if (lines[i] ~ /^    command:/) { v=lines[i]; sub(/^    command: */, "", v); cmd=v }
          else if (lines[i] ~ /^    source:/)  { v=lines[i]; sub(/^    source: */, "", v); src=v }
        }
        # Emit: discoverer-order \t cat \t src \t cmd \t cmd \t src
        # Field 1 (NR) is preserved through sort so dedup respects
        # input order within a (cat, cmd) group.
        if (cat != "") printf "%06d\t%s\t%s\t%s\t%s\t%s\n", NR, cat, src, cmd, cmd, src
      }
    ' | LC_ALL=C sort -t$'\t' -k2,2 -k4,4 -k1,1n | awk -F'\t' '
      # Dedup on (category, command) = ($2, $4). Keep first-seen.
      {
        key = $2 "\t" $4
        if (!(key in seen)) {
          seen[key] = 1
          print $0
        }
      }
    ' | LC_ALL=C sort -t$'\t' -k2,2 -k3,3 -k4,4 | awk -F'\t' '{
      # Final emission order: (category, source, command).
      printf "  - category: %s\n    command: %s\n    source: %s\n", $2, $5, $6
    }'
  fi

  if [ -n "$notes" ]; then
    printf 'notes:\n'
    printf '%s\n' "$notes"
  else
    printf 'notes: []\n'
  fi
}

# ---------------------------------------------------------------------------
# Readiness mode
# ---------------------------------------------------------------------------
readiness_mode() {
  if [ -z "$contract" ]; then
    echo "Error: --mode readiness requires an <acceptance-contract-path> argument." >&2
    exit 2
  fi
  if [ ! -f "$contract" ]; then
    echo "Error: Acceptance Contract not found at '${contract}'." >&2
    exit 3
  fi

  local sensors_block
  sensors_block="$(awk '
    /^## Sensors[[:space:]]*$/ { in_sensors = 1; next }
    in_sensors && /^## / && !/^## Sensors/ { in_sensors = 0 }
    in_sensors && /^### Computational[[:space:]]*$/ { in_comp = 1; next }
    in_sensors && in_comp && /^### / { in_comp = 0 }
    in_sensors && in_comp { print }
  ' "$contract")"

  if [ -z "$sensors_block" ]; then
    printf 'status: ready\nsensors: []\nfailures: []\n'
    return 0
  fi

  local sensor_yaml=""
  local failure_yaml=""
  local any_missing=0
  local sensor_name command_str leading_bin

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+([^:]+):[[:space:]]*\`([^\`]+)\` ]]; then
      sensor_name="$(echo "${BASH_REMATCH[1]}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
      command_str="${BASH_REMATCH[2]}"
    else
      continue
    fi

    leading_bin="$(echo "$command_str" | awk '{print $1}')"

    if command -v "$leading_bin" >/dev/null 2>&1; then
      sensor_yaml+="  - sensor: \"${sensor_name}\""$'\n'
      sensor_yaml+="    command: \"${command_str}\""$'\n'
      sensor_yaml+="    binary: \"${leading_bin}\""$'\n'
      sensor_yaml+="    reachable: true"$'\n'
    else
      any_missing=1
      sensor_yaml+="  - sensor: \"${sensor_name}\""$'\n'
      sensor_yaml+="    command: \"${command_str}\""$'\n'
      sensor_yaml+="    binary: \"${leading_bin}\""$'\n'
      sensor_yaml+="    reachable: false"$'\n'

      failure_yaml+="  - sensor: \"${sensor_name}\""$'\n'
      failure_yaml+="    command: \"${command_str}\""$'\n'
      failure_yaml+="    expected: \"on-PATH\""$'\n'
      failure_yaml+="    actual: \"missing\""$'\n'
      failure_yaml+="    reason: \"binary not found: ${leading_bin}\""$'\n'
    fi
  done <<< "$sensors_block"

  if [ "$any_missing" -eq 0 ]; then
    printf 'status: ready\nsensors:\n%sfailures: []\n' "$sensor_yaml"
    return 0
  fi

  printf 'status: not-ready\nsensors:\n%sfailures:\n%s' "$sensor_yaml" "$failure_yaml"
  exit 4
}

case "$mode" in
  catalog)   catalog_mode ;;
  readiness) readiness_mode ;;
  *)
    echo "Error: unknown --mode value '${mode}'. Use 'catalog' or 'readiness'." >&2
    exit 2
    ;;
esac
