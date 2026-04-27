#!/bin/bash
# ack-sensors.sh — implementation behind /yoke:ack-sensors.
#
# Modes:
#   catalog (default) — enumerate every sensor available for the host
#       project. v0.4.0 surfaces only `CLAUDE.md`-derived sensors;
#       additional discoverers (package.json, Makefile, pyproject.toml)
#       ship in Part 4.
#   readiness <acceptance-contract-path> — verify every sensor referenced
#       by the contract has a well-formed `.yoke/sensors/<id>.md` file
#       (rewritten in sensor-cost-tiering Part 2; previously verified
#       binary-on-PATH against the inline `## Sensors` block).
#   upsert <acceptance-contract-path> — create / update
#       `.yoke/sensors/<id>.md` files from the contract's
#       `## Sensors registry` block and `Sensors: [...]` references.
#       Field-level merge: only `applies_to` is refreshed from the
#       contract; author edits to caveats, calibration notes, explicit
#       `tier:` overrides, and `runs:` history are preserved verbatim.
#       Idempotent — running it twice with no contract changes produces
#       no file modifications.
#
#       Source PRD: .vibeflow/prds/sensor-cost-tiering.md
#
# Usage:
#   bash lib/sensors/ack-sensors.sh [--mode catalog | readiness | upsert] [<contract>]
#
# Output:
#   stdout — structured YAML (see SKILL.md for the schema per mode)
#   stderr — diagnostics
#
# Exit codes:
#   0 — operation succeeded
#   2 — usage error
#   3 — Acceptance Contract not found (readiness / upsert only)
#   4 — at least one sensor file is missing or malformed (readiness),
#       or registry / reference validation failed (upsert)
#
# Determinism: catalog output is sorted by (category, source, command)
# under LC_ALL=C, so repeated invocations on the same project are
# byte-identical. Upsert is idempotent — files are rewritten only when
# their merged content differs from the on-disk content.

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
# Shared helpers (readiness + upsert)
# ---------------------------------------------------------------------------

# Required-arg check used by both readiness and upsert.
require_contract_arg() {
  local mode_label="$1"
  if [ -z "$contract" ]; then
    echo "Error: --mode ${mode_label} requires an <acceptance-contract-path> argument." >&2
    exit 2
  fi
  if [ ! -f "$contract" ]; then
    echo "Error: Acceptance Contract not found at '${contract}'." >&2
    exit 3
  fi
}

# Extract the YAML block under `## Sensors registry` (between ```yaml
# and ```). One block per contract; emits empty string when absent.
extract_registry_yaml() {
  awk '
    /^## Sensors registry/ { in_section = 1; next }
    in_section && /^## / { in_section = 0 }
    in_section && /^```yaml[[:space:]]*$/ { in_block = 1; next }
    in_section && /^```[[:space:]]*$/ && in_block { in_block = 0 }
    in_block { print }
  ' "$contract"
}

# Parse the registry YAML block into TSV: <id>\t<command>\t<class>.
# Emits one row per registered sensor; rows where any field is missing
# are emitted with empty fields so the caller can validate.
parse_registry_tsv() {
  awk '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    function flush() {
      if (id != "") { printf "%s\t%s\t%s\n", id, cmd, cls }
      id = ""; cmd = ""; cls = ""
    }
    BEGIN { id = ""; cmd = ""; cls = "" }
    /^[[:space:]]*-[[:space:]]+id:/ {
      flush()
      v = $0; sub(/^[[:space:]]*-[[:space:]]+id:[[:space:]]*/, "", v); id = trim(v)
      next
    }
    /^[[:space:]]+command:/ {
      v = $0; sub(/^[[:space:]]+command:[[:space:]]*/, "", v); cmd = trim(v)
      next
    }
    /^[[:space:]]+class:/ {
      v = $0; sub(/^[[:space:]]+class:[[:space:]]*/, "", v); cls = trim(v)
      next
    }
    END { flush() }
  '
}

# Parse contract scenarios for (sensor-id, task-id) pairs.
# Walks each `Task: <task-id>` line and the *next* `Sensors: [...]`
# line that follows it. Emits TSV: <sensor-id>\t<task-id>.
parse_scenario_sensor_pairs() {
  awk '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    /^Task:[[:space:]]*/ {
      task = $0; sub(/^Task:[[:space:]]*/, "", task); task = trim(task)
      next
    }
    /^Sensors:[[:space:]]*\[/ {
      line = $0
      sub(/^Sensors:[[:space:]]*\[/, "", line)
      sub(/\][[:space:]]*$/, "", line)
      n = split(line, ids, ",")
      for (i = 1; i <= n; i++) {
        s = trim(ids[i])
        if (s != "" && task != "") {
          printf "%s\t%s\n", s, task
        }
      }
      next
    }
  ' "$contract"
}

# Parse a sensor file's frontmatter (between the first two `---`).
# Echoes the frontmatter content. Returns non-zero if the file lacks
# the delimiters.
extract_sensor_frontmatter() {
  local file="$1"
  awk '
    BEGIN { count = 0 }
    /^---[[:space:]]*$/ { count++; if (count == 2) exit; next }
    count == 1 { print }
  ' "$file"
}

# Verify a sensor file is well-formed: frontmatter delimiters present,
# required keys present (id, command, class, applies_to, runs).
# Returns 0 on success, non-zero on any defect (and prints nothing —
# the caller emits the structured violation).
sensor_file_well_formed() {
  local file="$1"
  [ -f "$file" ] || return 1
  local fm
  fm="$(extract_sensor_frontmatter "$file")"
  [ -n "$fm" ] || return 1
  local key
  for key in id command class applies_to runs; do
    printf '%s\n' "$fm" | grep -qE "^${key}:" || return 1
  done
  return 0
}

# Render a sensor.md from the template, substituting frontmatter values.
# Args: <id> <command> <class> <tier> <applies_to_csv>
# Echoes the rendered file content to stdout.
#
# applies_to_csv is a comma-separated list of task ids (no spaces);
# rendered as a YAML flow list `[id1, id2]` for compactness.
render_sensor_file() {
  local id="$1"
  local cmd="$2"
  local cls="$3"
  local tier="$4"
  local applies_csv="$5"
  local template="${plugin_root}/templates/sensor.md"

  if [ ! -f "$template" ]; then
    echo "Error: sensor template not found at ${template}" >&2
    exit 2
  fi

  local applies_yaml
  if [ -z "$applies_csv" ]; then
    applies_yaml="[]"
  else
    # Build `[id1, id2, ...]`.
    applies_yaml="[$(printf '%s' "$applies_csv" | sed 's/,/, /g')]"
  fi

  # Substitute frontmatter placeholders. The template's HTML-comment
  # guidance is preserved verbatim — it documents schema for the
  # author who later opens the per-sensor file.
  awk -v id="$id" -v cmd="$cmd" -v cls="$cls" -v tier="$tier" -v applies="$applies_yaml" '
    /^id: <sensor-id>$/                  { print "id: " id; next }
    /^command: <shell command>$/         { print "command: " cmd; next }
    /^class: <computational \| inferential>$/ { print "class: " cls; next }
    /^tier: <cheap \| expensive>$/       { print "tier: " tier; next }
    /^applies_to: \[\]$/                 { print "applies_to: " applies; next }
    /^# <human-readable sensor name>$/   { print "# " id; next }
    { print }
  ' "$template"
}

# Update only `applies_to` in an existing sensor file, preserving
# everything else byte-for-byte. Atomic write via tmp + mv.
update_applies_to() {
  local file="$1"
  local applies_csv="$2"

  local applies_yaml
  if [ -z "$applies_csv" ]; then
    applies_yaml="[]"
  else
    applies_yaml="[$(printf '%s' "$applies_csv" | sed 's/,/, /g')]"
  fi

  local tmp="${file}.tmp.$$"
  awk -v applies="$applies_yaml" '
    BEGIN { fm = 0 }
    /^---[[:space:]]*$/ {
      fm++
      print
      next
    }
    fm == 1 && /^applies_to:/ {
      print "applies_to: " applies
      next
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

# Emit a structured YAML failure block for a single sensor.
# Args: <id> <expected> <actual> <reason> <correction>
emit_failure() {
  printf '  - sensor: "%s"\n' "$1"
  printf '    expected: "%s"\n' "$2"
  printf '    actual: "%s"\n' "$3"
  printf '    reason: "%s"\n' "$4"
  printf '    correction: "%s"\n' "$5"
}

# Compute applies_to CSV for a sensor id from scenario pairs.
# Args: <sensor-id> <pairs-tsv>
# Echoes a comma-separated, sorted-unique list of task ids, or empty.
applies_to_for() {
  local id="$1"
  local pairs="$2"
  printf '%s\n' "$pairs" \
    | awk -v target="$id" -F'\t' '$1 == target { print $2 }' \
    | LC_ALL=C sort -u \
    | paste -sd, -
}

# ---------------------------------------------------------------------------
# Readiness mode (rewritten in Part 2 — checks per-sensor files now)
# ---------------------------------------------------------------------------
readiness_mode() {
  require_contract_arg "readiness"

  # Collect the union of registered ids and id-references from scenarios.
  local registry_tsv pairs_tsv
  registry_tsv="$(extract_registry_yaml | parse_registry_tsv)"
  pairs_tsv="$(parse_scenario_sensor_pairs)"

  local referenced_ids
  referenced_ids="$(
    {
      printf '%s\n' "$registry_tsv" | awk -F'\t' '$1 != "" { print $1 }'
      printf '%s\n' "$pairs_tsv"    | awk -F'\t' '$1 != "" { print $1 }'
    } | LC_ALL=C sort -u
  )"

  if [ -z "$referenced_ids" ]; then
    printf 'status: ready\nsensors: []\nfailures: []\n'
    return 0
  fi

  local sensor_yaml=""
  local failure_yaml=""
  local any_missing=0
  local sensors_dir=".yoke/sensors"
  local id file exists_str parses_str

  while IFS= read -r id; do
    [ -z "$id" ] && continue
    file="${sensors_dir}/${id}.md"

    if [ ! -f "$file" ]; then
      any_missing=1
      exists_str="false"
      parses_str="false"
      sensor_yaml+="  - id: \"${id}\""$'\n'
      sensor_yaml+="    path: \"${file}\""$'\n'
      sensor_yaml+="    exists: ${exists_str}"$'\n'
      sensor_yaml+="    parses: ${parses_str}"$'\n'
      failure_yaml+="$(emit_failure \
        "$id" \
        "file at ${file}" \
        "missing" \
        "sensor file not found" \
        "run \`/yoke:ack-sensors --mode upsert ${contract}\`")"$'\n'
      continue
    fi

    exists_str="true"
    if sensor_file_well_formed "$file"; then
      parses_str="true"
      sensor_yaml+="  - id: \"${id}\""$'\n'
      sensor_yaml+="    path: \"${file}\""$'\n'
      sensor_yaml+="    exists: ${exists_str}"$'\n'
      sensor_yaml+="    parses: ${parses_str}"$'\n'
    else
      any_missing=1
      parses_str="false"
      sensor_yaml+="  - id: \"${id}\""$'\n'
      sensor_yaml+="    path: \"${file}\""$'\n'
      sensor_yaml+="    exists: ${exists_str}"$'\n'
      sensor_yaml+="    parses: ${parses_str}"$'\n'
      failure_yaml+="$(emit_failure \
        "$id" \
        "well-formed frontmatter (id, command, class, applies_to, runs)" \
        "missing keys or delimiters" \
        "sensor file is malformed" \
        "edit ${file} or re-run \`/yoke:ack-sensors --mode upsert ${contract}\`")"$'\n'
    fi
  done <<< "$referenced_ids"

  if [ "$any_missing" -eq 0 ]; then
    printf 'status: ready\nsensors:\n%sfailures: []\n' "$sensor_yaml"
    return 0
  fi

  printf 'status: not-ready\nsensors:\n%sfailures:\n%s' "$sensor_yaml" "$failure_yaml"
  exit 4
}

# ---------------------------------------------------------------------------
# Upsert mode — create / update .yoke/sensors/<id>.md from contract
# ---------------------------------------------------------------------------
upsert_mode() {
  require_contract_arg "upsert"

  local registry_tsv pairs_tsv
  registry_tsv="$(extract_registry_yaml | parse_registry_tsv)"
  pairs_tsv="$(parse_scenario_sensor_pairs)"

  # Validate: every scenario reference must have a registry entry.
  local registered_ids referenced_ids unregistered
  registered_ids="$(printf '%s\n' "$registry_tsv" | awk -F'\t' '$1 != "" { print $1 }' | LC_ALL=C sort -u)"
  referenced_ids="$(printf '%s\n' "$pairs_tsv"    | awk -F'\t' '$1 != "" { print $1 }' | LC_ALL=C sort -u)"
  unregistered="$(LC_ALL=C comm -23 \
    <(printf '%s\n' "$referenced_ids") \
    <(printf '%s\n' "$registered_ids"))"

  if [ -n "$unregistered" ]; then
    printf 'status: error\nupserted: []\nfailures:\n' >&2
    while IFS= read -r id; do
      [ -z "$id" ] && continue
      emit_failure \
        "$id" \
        "registry entry under \`## Sensors registry\` in ${contract}" \
        "missing" \
        "sensor referenced in a scenario but not declared in the registry" \
        "add \`- id: ${id}\n    command: <cmd>\n    class: <computational|inferential>\` under \`## Sensors registry\`" >&2
    done <<< "$unregistered"
    exit 4
  fi

  # Validate registry entries themselves.
  local malformed=0
  local malformed_yaml=""
  while IFS=$'\t' read -r id cmd cls; do
    [ -z "$id" ] && continue
    if [ -z "$cmd" ] || [ -z "$cls" ]; then
      malformed=1
      malformed_yaml+="$(emit_failure \
        "$id" \
        "command and class fields populated" \
        "command='${cmd}', class='${cls}'" \
        "registry entry has empty command or class" \
        "fill the missing field in \`## Sensors registry\` of ${contract}")"$'\n'
      continue
    fi
    case "$cls" in
      computational|inferential) ;;
      *)
        malformed=1
        malformed_yaml+="$(emit_failure \
          "$id" \
          "class: computational | inferential" \
          "class: ${cls}" \
          "registry entry has unknown class" \
          "set class to computational or inferential in \`## Sensors registry\` of ${contract}")"$'\n'
        ;;
    esac
  done <<< "$registry_tsv"

  if [ "$malformed" -ne 0 ]; then
    printf 'status: error\nupserted: []\nfailures:\n%s' "$malformed_yaml" >&2
    exit 4
  fi

  # Materialize / update each registered sensor.
  mkdir -p ".yoke/sensors"
  local upserted_yaml=""
  local id cmd cls applies_csv default_tier file action

  while IFS=$'\t' read -r id cmd cls; do
    [ -z "$id" ] && continue
    applies_csv="$(applies_to_for "$id" "$pairs_tsv")"
    file=".yoke/sensors/${id}.md"

    if [ "$cls" = "inferential" ]; then
      default_tier="expensive"
    else
      default_tier="cheap"
    fi

    if [ ! -f "$file" ]; then
      # Create from template.
      local tmp="${file}.tmp.$$"
      render_sensor_file "$id" "$cmd" "$cls" "$default_tier" "$applies_csv" > "$tmp"
      mv "$tmp" "$file"
      action="created"
    else
      # Field-level merge: only refresh applies_to. Preserve everything
      # else (command, class, tier, body, runs) byte-for-byte. If the
      # current applies_to already matches the desired one, do nothing
      # (idempotency: don't bump mtime).
      local current_applies desired_yaml
      current_applies="$(extract_sensor_frontmatter "$file" \
        | awk -F': ' '/^applies_to:/ { sub(/^applies_to:[[:space:]]*/, "", $0); print $0; exit }')"
      if [ -z "$applies_csv" ]; then
        desired_yaml="[]"
      else
        desired_yaml="[$(printf '%s' "$applies_csv" | sed 's/,/, /g')]"
      fi
      if [ "$current_applies" = "$desired_yaml" ]; then
        action="unchanged"
      else
        update_applies_to "$file" "$applies_csv"
        action="updated"
      fi
    fi

    upserted_yaml+="  - id: \"${id}\""$'\n'
    upserted_yaml+="    path: \"${file}\""$'\n'
    upserted_yaml+="    action: ${action}"$'\n'
  done <<< "$registry_tsv"

  if [ -z "$upserted_yaml" ]; then
    printf 'status: ok\nupserted: []\nfailures: []\n'
  else
    printf 'status: ok\nupserted:\n%sfailures: []\n' "$upserted_yaml"
  fi
}

case "$mode" in
  catalog)   catalog_mode ;;
  readiness) readiness_mode ;;
  upsert)    upsert_mode ;;
  *)
    echo "Error: unknown --mode value '${mode}'. Use 'catalog', 'readiness', or 'upsert'." >&2
    exit 2
    ;;
esac
