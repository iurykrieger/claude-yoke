#!/bin/bash
# append-runs.sh — append a per-cycle run entry to each executed sensor's
# `.yoke/sensors/<id>.md` `runs:` history, applying the N=20 retention cap.
#
# Source PRD: .yoke/prds/2026-04-27-sensor-cost-tiering.md
#
# Usage:
#   bash lib/sensors/append-runs.sh <snapshot-yaml> <cycle> <criterion>
#
# The snapshot is `verify-acceptance.sh`'s output (results: list of sensors).
# For each sensor in the snapshot:
#   * Locate `.yoke/sensors/<sensor>.md`. Skip silently if not registered
#     (sensor exists in the snapshot but has no per-sensor file).
#   * Append one entry to its `runs:` block:
#       - {cycle: <N>, started_at: <iso8601>, status: <pass|fail|skip>,
#          criterion: "<id>", duration_ms: <int>, evidence_snippet: "<...>"}
#   * Cap the `runs:` list at the most recent CAP=20 entries; oldest roll
#     off on overflow.
#   * Atomic write via tmp + mv.
#
# Constraint: `runs:` MUST be the last frontmatter key in the per-sensor
# file. Everything between `runs:` and the closing `---` is treated as
# `runs:` content; any other frontmatter key after `runs:` will be
# clobbered. The Part-1 template puts `runs:` last by design.
#
# Exit codes:
#   0  success
#   2  usage error
#   3  snapshot not found

set -euo pipefail

CAP=20

usage() {
  echo "Usage: $0 <snapshot.yaml> <cycle> <criterion>" >&2
  exit 2
}

[ $# -eq 3 ] || usage
snapshot="$1"
cycle="$2"
criterion="$3"

[ -f "$snapshot" ] || {
  echo "Error: snapshot not found: $snapshot" >&2
  exit 3
}

[[ "$cycle" =~ ^[0-9]+$ ]] || {
  echo "Error: cycle must be a non-negative integer (got '${cycle}')." >&2
  exit 2
}

started_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

sensors_dir=".yoke/sensors"

# YAML escape for double-quoted scalars: backslashes and double quotes.
yaml_esc() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/ }
  s=${s//$'\r'/}
  printf '%s' "$s"
}

# Append one new runs entry to <sensor-file>, applying CAP.
# Args:
#   $1 sensor-file
#   $2 new-entry-line  (single line starting with "  - {")
append_one() {
  local file="$1"
  local entry="$2"
  local tmp="${file}.tmp.$$"

  # Three-zone split:
  #   prefix    — everything before the `runs:` line in frontmatter
  #   in_runs   — collected `  - {...}` lines (old entries)
  #   suffix    — closing `---` and the body, verbatim
  #
  # `runs:` is required to be the last frontmatter key. The closing
  # `---` ends the in-runs zone.
  local prefix="" old_entries="" suffix=""
  local state="prefix"

  # Use a heredoc-friendly loop. IFS empty preserves leading spaces.
  while IFS= read -r line || [ -n "$line" ]; do
    case "$state" in
      prefix)
        if [[ "$line" =~ ^runs: ]]; then
          state="in_runs"
        else
          prefix+="$line"$'\n'
        fi
        ;;
      in_runs)
        if [[ "$line" =~ ^---[[:space:]]*$ ]]; then
          suffix+="$line"$'\n'
          state="suffix"
        elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]+\{ ]]; then
          old_entries+="$line"$'\n'
        fi
        # ignore blank lines and stray content inside the runs zone
        ;;
      suffix)
        suffix+="$line"$'\n'
        ;;
    esac
  done < "$file"

  if [ "$state" = "prefix" ]; then
    # No `runs:` found — sensor file is malformed for this purpose.
    echo "Error: ${file} has no \`runs:\` key in frontmatter." >&2
    return 1
  fi

  # Combine old entries with the new one and cap at CAP.
  local all_entries="${old_entries}${entry}"$'\n'
  local capped
  capped="$(printf '%s' "$all_entries" \
              | grep -E '^[[:space:]]*-[[:space:]]+\{' \
              | tail -n "$CAP")"

  {
    printf '%s' "$prefix"
    printf 'runs:\n'
    printf '%s\n' "$capped"
    printf '%s' "$suffix"
  } > "$tmp"

  mv "$tmp" "$file"
}

# Iterate over per-sensor results in the snapshot. The snapshot YAML
# format (from verify-acceptance.sh):
#
#   results:
#     - sensor: "<name>"
#       command: "<cmd>"
#       status: pass|fail|skip
#       exit_code: <int>
#       output_excerpt: "<...>"
#       reason: "<...>"
#
# Emit TSV lines: <name>\t<status>\t<output_excerpt>
sensor_records="$(awk '
  function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
  /^[[:space:]]*-[[:space:]]+sensor:/ {
    if (cur_name != "") {
      printf "%s\t%s\t%s\n", cur_name, cur_status, cur_excerpt
    }
    line = $0
    sub(/^[[:space:]]*-[[:space:]]+sensor:[[:space:]]*"?/, "", line)
    sub(/"?[[:space:]]*$/, "", line)
    cur_name = trim(line)
    cur_status = ""
    cur_excerpt = ""
    next
  }
  /^[[:space:]]+status:/ {
    line = $0
    sub(/^[[:space:]]+status:[[:space:]]*/, "", line)
    cur_status = trim(line)
    next
  }
  /^[[:space:]]+output_excerpt:/ {
    line = $0
    sub(/^[[:space:]]+output_excerpt:[[:space:]]*"?/, "", line)
    sub(/"?[[:space:]]*$/, "", line)
    cur_excerpt = trim(line)
    next
  }
  END {
    if (cur_name != "") {
      printf "%s\t%s\t%s\n", cur_name, cur_status, cur_excerpt
    }
  }
' "$snapshot")"

if [ -z "$sensor_records" ]; then
  # Empty snapshot — nothing to append.
  exit 0
fi

# Truncate evidence to ~200 chars in YAML form, after escaping quotes.
truncate_evidence() {
  local s="$1"
  s="$(yaml_esc "$s")"
  # Use head -c on raw bytes; UTF-8 multi-byte chars may be split, but
  # this is a snippet, not a verbatim store. Add an ellipsis when truncated.
  local cut
  cut="$(printf '%s' "$s" | head -c 200)"
  if [ "${#s}" -gt "${#cut}" ]; then
    cut="${cut}…"
  fi
  printf '%s' "$cut"
}

while IFS=$'\t' read -r name status excerpt; do
  [ -z "$name" ] && continue
  sensor_file="${sensors_dir}/${name}.md"
  [ -f "$sensor_file" ] || continue

  evidence="$(truncate_evidence "$excerpt")"
  criterion_esc="$(yaml_esc "$criterion")"

  if [ -n "$evidence" ]; then
    entry="  - {cycle: ${cycle}, started_at: \"${started_at}\", status: ${status}, criterion: \"${criterion_esc}\", evidence_snippet: \"${evidence}\"}"
  else
    entry="  - {cycle: ${cycle}, started_at: \"${started_at}\", status: ${status}, criterion: \"${criterion_esc}\"}"
  fi

  append_one "$sensor_file" "$entry"
done <<< "$sensor_records"
