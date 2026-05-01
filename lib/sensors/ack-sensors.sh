#!/bin/bash
# ack-sensors.sh — implementation behind /yoke:ack-sensors.
#
# Modes:
#   catalog (default) — enumerate every sensor available for the host
#       project. v0.4.0 surfaces only `CLAUDE.md`-derived sensors;
#       additional discoverers (package.json, Makefile, pyproject.toml)
#       ship in Part 4.
#
#   readiness <sensor-file-path> — verify a single per-sensor file is
#       well-formed against the new harness-realignment schema:
#         frontmatter: id, type ∈ {computational,inferential},
#                      token_cost (int ≥ 0), time_cost (int ≥ 1),
#                      command (iff computational), agent (iff inferential).
#         body: ## How to run, ## Known issues, ## Frequent errors
#               (every bullet matches `- <pattern>: <fix>`); for
#               inferential, ## Calibration with sub-sections
#               ### Prompt, ### Rubric, ### Verdict schema.
#       Legacy fields (`class`, `tier`, `applies_to`, `runs`) cause
#       readiness to fail with stderr citation pointing at the field.
#       (Source PRD: .yoke/prds/2026-04-30-sensor-harness-realignment.md.)
#
#       Backward-compat shape: `readiness <acceptance-contract.md>` is
#       still accepted when the path looks like a contract (`.yoke/
#       acceptance-contracts/...` or contains `## Sensors registry` /
#       `### Validation`). In that case readiness verifies that every
#       referenced sensor id resolves to a well-formed sensor file.
#
#   upsert — walk every Acceptance Contract under
#       `<root>/.yoke/acceptance-contracts/` (or, with `--root <dir>`,
#       under `<dir>/contracts/`), extract every referenced sensor id
#       from the new `### Validation` blocks (and, for back-compat,
#       from the legacy `## Sensors registry` block), and materialize
#       any missing sensor file under `<root>/.yoke/sensors/<id>.md`
#       (or `<dir>/sensors/<id>.md` with `--root`) from
#       `templates/sensor.md`. Existing sensor files are NEVER touched
#       — curated body content is preserved verbatim. Defaults for new
#       files: `type: computational`, `token_cost: 0`, `time_cost: 30`.
#
# Usage:
#   bash lib/sensors/ack-sensors.sh [--mode catalog | readiness | upsert] \
#                                   [--root <dir>] [--sensor <id>] \
#                                   [<path>]
#
# Output:
#   stdout — structured YAML (see SKILL.md for the schema per mode)
#   stderr — diagnostics, with field citation on legacy-field rejection
#
# Exit codes:
#   0 — operation succeeded
#   2 — usage error
#   3 — sensor file / Acceptance Contract not found
#   4 — sensor file malformed (readiness) or upsert validation failed
#
# Determinism: catalog output is sorted by (category, source, command)
# under LC_ALL=C, so repeated invocations on the same project are
# byte-identical. Upsert is idempotent — files are never modified once
# created (curated content lives there).

set -euo pipefail

mode="catalog"
contract=""
sensor_filter=""
root_dir=""

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
    --sensor)
      if [ $# -lt 2 ]; then
        echo "Error: --sensor requires a value." >&2
        exit 2
      fi
      sensor_filter="$2"
      shift 2
      ;;
    --sensor=*)
      sensor_filter="${1#--sensor=}"
      shift
      ;;
    --root)
      if [ $# -lt 2 ]; then
        echo "Error: --root requires a value." >&2
        exit 2
      fi
      root_dir="$2"
      shift 2
      ;;
    --root=*)
      root_dir="${1#--root=}"
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
# Catalog mode (unchanged from sensor-cost-tiering Part 1)
# ---------------------------------------------------------------------------
catalog_mode() {
  local claude_md="${PWD}/CLAUDE.md"
  local pkg_json="${PWD}/package.json"
  local makefile="${PWD}/Makefile"
  local pyproject="${PWD}/pyproject.toml"

  local d_claude="${plugin_root}/lib/sensors/discover-from-claude-md.sh"
  local d_make="${plugin_root}/lib/sensors/discover-from-makefile.sh"
  local d_pkg="${plugin_root}/lib/sensors/discover-from-package-json.sh"
  local d_pyp="${plugin_root}/lib/sensors/discover-from-pyproject.sh"

  if [ ! -f "$d_claude" ]; then
    echo "Error: claude-md discoverer not found at ${d_claude}" >&2
    exit 2
  fi

  local raw_claude raw_make raw_pkg raw_pyp
  raw_claude="$(bash "$d_claude" "$claude_md")"
  raw_make="$( [ -f "$d_make" ] && bash "$d_make" "$makefile" || printf 'sensors: []\nnotes: []\n' )"
  raw_pkg="$(  [ -f "$d_pkg"  ] && bash "$d_pkg"  "$pkg_json" || printf 'sensors: []\nnotes: []\n' )"
  raw_pyp="$(  [ -f "$d_pyp"  ] && bash "$d_pyp"  "$pyproject" || printf 'sensors: []\nnotes: []\n' )"

  local raw
  raw="$(printf '%s\n%s\n%s\n%s\n' "$raw_claude" "$raw_make" "$raw_pkg" "$raw_pyp")"

  local entries notes
  entries="$(printf '%s\n' "$raw" | awk '
    /^  - category:/ { in_e=1; buf=$0 ORS; next }
    in_e && /^    command:/ { buf=buf $0 ORS; next }
    in_e && /^    source:/  { buf=buf $0 ORS; print buf; buf=""; in_e=0; next }
  ')"

  notes="$(printf '%s\n' "$raw" | awk '
    /^notes:[[:space:]]*\[/ { next }
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
        if (cat != "") printf "%06d\t%s\t%s\t%s\t%s\t%s\n", NR, cat, src, cmd, cmd, src
      }
    ' | LC_ALL=C sort -t$'\t' -k2,2 -k4,4 -k1,1n | awk -F'\t' '
      {
        key = $2 "\t" $4
        if (!(key in seen)) {
          seen[key] = 1
          print $0
        }
      }
    ' | LC_ALL=C sort -t$'\t' -k2,2 -k3,3 -k4,4 | awk -F'\t' '{
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
# Shared helpers
# ---------------------------------------------------------------------------

# Detect whether a path looks like an Acceptance Contract (vs a sensor
# file). Heuristic: contains either `## Sensors registry` or
# `### Validation` heading at column 0, OR sits under
# `.yoke/acceptance-contracts/`.
is_acceptance_contract_path() {
  local path="$1"
  case "$path" in
    *.yoke/acceptance-contracts/*) return 0 ;;
  esac
  # Cheap content sniff — first 200 lines is enough.
  if grep -qE '^(## Sensors registry|### Validation)$' "$path" 2>/dev/null; then
    return 0
  fi
  return 1
}

# Extract a sensor file's frontmatter (between the first two `---`).
extract_sensor_frontmatter() {
  awk '
    BEGIN { count = 0 }
    /^---[[:space:]]*$/ { count++; if (count == 2) exit; next }
    count == 1 { print }
  ' "$1"
}

# Extract a sensor file's body (after the second `---`).
extract_sensor_body() {
  awk '
    BEGIN { count = 0 }
    /^---[[:space:]]*$/ { count++; next }
    count >= 2 { print }
  ' "$1"
}

# Emit a structured YAML failure block.
# Args: <sensor-id> <expected> <actual> <reason> <correction>
emit_failure() {
  printf '  - sensor: "%s"\n' "$1"
  printf '    expected: "%s"\n' "$2"
  printf '    actual: "%s"\n' "$3"
  printf '    reason: "%s"\n' "$4"
  printf '    correction: "%s"\n' "$5"
}

# Validate a single sensor file against the new schema.
# Args: <path>
# Returns 0 if all checks pass; non-zero otherwise.
# Emits stderr diagnostics on failure, citing field/section.
validate_sensor_file() {
  local file="$1"
  local id

  if [ ! -f "$file" ]; then
    echo "Error: sensor file not found at '${file}'." >&2
    return 1
  fi

  # Frontmatter delimiters present?
  local fm body
  fm="$(extract_sensor_frontmatter "$file")"
  if [ -z "$fm" ]; then
    echo "Error: ${file}: missing or empty YAML frontmatter (expected '---' delimiters)." >&2
    return 1
  fi
  body="$(extract_sensor_body "$file")"

  # Reject legacy fields with explicit citation.
  local legacy_field
  for legacy_field in class tier applies_to runs; do
    if printf '%s\n' "$fm" | grep -qE "^${legacy_field}:"; then
      echo "Error: ${file}: legacy field '${legacy_field}:' is no longer supported." >&2
      echo "  Migrate to the new schema: type / token_cost / time_cost / command|agent." >&2
      echo "  See templates/sensor.md and .yoke/prds/2026-04-30-sensor-harness-realignment.md." >&2
      return 1
    fi
  done

  # Required fields.
  local id_val type_val token_cost_val time_cost_val command_val agent_val
  id_val="$(printf '%s\n' "$fm" | awk -F': *' '/^id:/ { sub(/^id:[[:space:]]*/, ""); print; exit }')"
  type_val="$(printf '%s\n' "$fm" | awk -F': *' '/^type:/ { sub(/^type:[[:space:]]*/, ""); print; exit }')"
  token_cost_val="$(printf '%s\n' "$fm" | awk -F': *' '/^token_cost:/ { sub(/^token_cost:[[:space:]]*/, ""); print; exit }')"
  time_cost_val="$(printf '%s\n' "$fm" | awk -F': *' '/^time_cost:/ { sub(/^time_cost:[[:space:]]*/, ""); print; exit }')"
  command_val="$(printf '%s\n' "$fm" | awk '/^command:/ { sub(/^command:[[:space:]]*/, ""); print; exit }')"
  agent_val="$(printf '%s\n' "$fm" | awk '/^agent:/ { sub(/^agent:[[:space:]]*/, ""); print; exit }')"

  if [ -z "$id_val" ]; then
    echo "Error: ${file}: missing required field 'id:'." >&2
    return 1
  fi
  if ! printf '%s' "$id_val" | grep -qE '^[a-z0-9][a-z0-9-]*$'; then
    echo "Error: ${file}: id '${id_val}' must match ^[a-z0-9][a-z0-9-]*$." >&2
    return 1
  fi
  id="$id_val"

  if [ -z "$type_val" ]; then
    echo "Error: ${file}: missing required field 'type:' (expected 'computational' or 'inferential')." >&2
    return 1
  fi
  case "$type_val" in
    computational|inferential) ;;
    *)
      echo "Error: ${file}: type '${type_val}' invalid (expected 'computational' or 'inferential')." >&2
      return 1
      ;;
  esac

  if [ -z "$token_cost_val" ]; then
    echo "Error: ${file}: missing required field 'token_cost:' (int ≥ 0)." >&2
    return 1
  fi
  if ! printf '%s' "$token_cost_val" | grep -qE '^[0-9]+$'; then
    echo "Error: ${file}: token_cost '${token_cost_val}' invalid (expected non-negative integer)." >&2
    return 1
  fi

  if [ -z "$time_cost_val" ]; then
    echo "Error: ${file}: missing required field 'time_cost:' (int ≥ 1)." >&2
    return 1
  fi
  if ! printf '%s' "$time_cost_val" | grep -qE '^[0-9]+$'; then
    echo "Error: ${file}: time_cost '${time_cost_val}' invalid (expected positive integer seconds)." >&2
    return 1
  fi
  if [ "$time_cost_val" -lt 1 ]; then
    echo "Error: ${file}: time_cost '${time_cost_val}' must be ≥ 1 second." >&2
    return 1
  fi

  if [ "$type_val" = "computational" ]; then
    if [ -z "$command_val" ]; then
      echo "Error: ${file}: type 'computational' requires 'command:' field (the shell invocation)." >&2
      return 1
    fi
    if [ -n "$agent_val" ]; then
      echo "Error: ${file}: type 'computational' must not declare 'agent:' (mutually exclusive with command)." >&2
      return 1
    fi
  else
    # inferential
    if [ -z "$agent_val" ]; then
      echo "Error: ${file}: type 'inferential' requires 'agent:' field (the subagent id)." >&2
      return 1
    fi
    if [ -n "$command_val" ]; then
      echo "Error: ${file}: type 'inferential' must not declare 'command:' (mutually exclusive with agent)." >&2
      return 1
    fi
  fi

  # ---- Body lint ----
  # All types: ## How to run, ## Known issues, ## Frequent errors
  # required, non-empty.
  local section
  for section in "How to run" "Known issues" "Frequent errors"; do
    if ! printf '%s\n' "$body" | grep -qE "^## ${section}\$"; then
      echo "Error: ${file}: missing required body header '## ${section}'." >&2
      return 1
    fi
    # Non-empty content under the section: at least one non-blank,
    # non-comment, non-header line follows the header before the next
    # ## or end-of-file.
    if ! body_section_non_empty "$body" "## ${section}"; then
      echo "Error: ${file}: body section '## ${section}' is empty." >&2
      return 1
    fi
  done

  # `## Frequent errors` bullet format — each non-blank, non-comment
  # line that begins with `- ` must match `- <pattern>: <fix>` with
  # both halves non-empty. Multi-line bullets are rejected (v0).
  if ! validate_frequent_errors_bullets "$body"; then
    echo "Error: ${file}: '## Frequent errors' contains malformed bullets (expected '- <pattern>: <fix>' single-line)." >&2
    return 1
  fi

  if [ "$type_val" = "inferential" ]; then
    if ! printf '%s\n' "$body" | grep -qE '^## Calibration$'; then
      echo "Error: ${file}: type 'inferential' requires '## Calibration' section." >&2
      return 1
    fi
    local sub
    for sub in "Prompt" "Rubric" "Verdict schema"; do
      if ! printf '%s\n' "$body" | grep -qE "^### ${sub}\$"; then
        echo "Error: ${file}: '## Calibration' missing required sub-section '### ${sub}'." >&2
        return 1
      fi
      if ! body_section_non_empty "$body" "### ${sub}"; then
        echo "Error: ${file}: Calibration sub-section '### ${sub}' is empty." >&2
        return 1
      fi
    done
  else
    # Computational sensors: warn if Calibration present (not fail).
    if printf '%s\n' "$body" | grep -qE '^## Calibration$'; then
      echo "Warning: ${file}: type 'computational' carries '## Calibration' section (typically inferential-only)." >&2
    fi
  fi

  return 0
}

# Check that a body section has non-empty content.
# Args: <body-text> <header-line, e.g. "## Frequent errors">
# Returns 0 if the section has at least one non-blank, non-comment,
# non-header content line before the next header at the same or
# higher level. The implementation is conservative: it scans the
# body line-by-line, switches into "in section" on header match, and
# accepts any line that is not blank, not an HTML comment, not a
# header start.
body_section_non_empty() {
  local body="$1"
  local header="$2"
  # Determine sibling-or-higher header pattern: `## ` for `## X`,
  # `## ` or `### ` boundary for `### X` (close on next `### ` or `## `).
  printf '%s\n' "$body" | awk -v hdr="$header" '
    BEGIN { in_section = 0; found = 0; level = 0 }
    {
      line = $0
      # Detect headers.
      if (line == hdr) {
        in_section = 1
        if (hdr ~ /^### /) { level = 3 } else { level = 2 }
        next
      }
      if (in_section) {
        if (level == 3 && (line ~ /^### / || line ~ /^## /)) { exit }
        if (level == 2 && line ~ /^## /) { exit }
        # Skip blank lines.
        if (line ~ /^[[:space:]]*$/) next
        # Skip HTML comments (single-line and start-of-multi-line).
        if (line ~ /^[[:space:]]*<!--/) {
          if (line !~ /-->/) { in_comment = 1 }
          next
        }
        if (in_comment) {
          if (line ~ /-->/) { in_comment = 0 }
          next
        }
        found = 1
        exit
      }
    }
    END { exit (found ? 0 : 1) }
  '
}

# Validate `## Frequent errors` bullets: each non-blank, non-comment
# line beginning with `- ` must match `- <pattern>: <fix>`.
validate_frequent_errors_bullets() {
  local body="$1"
  printf '%s\n' "$body" | awk '
    BEGIN { in_section = 0; in_comment = 0; bad = 0 }
    {
      line = $0
      if (line == "## Frequent errors") { in_section = 1; next }
      if (in_section && line ~ /^## /) { exit }
      if (!in_section) next
      if (line ~ /^[[:space:]]*$/) next
      if (line ~ /^[[:space:]]*<!--/) {
        if (line !~ /-->/) { in_comment = 1 }
        next
      }
      if (in_comment) {
        if (line ~ /-->/) { in_comment = 0 }
        next
      }
      # Only inspect lines starting with a bullet marker.
      if (line ~ /^- /) {
        if (line !~ /^- [^:]+: .+$/) {
          bad = 1
          exit
        }
      }
    }
    END { exit (bad ? 1 : 0) }
  '
}

# ---------------------------------------------------------------------------
# Acceptance-Contract sensor-id extraction (used by upsert and the
# back-compat readiness path).
# ---------------------------------------------------------------------------

# Extract every sensor id referenced by a contract. Two patterns:
#   1. New shape (post-t02): `### Validation` block with bullets
#      `- **<sensor-id>** — ...`.
#   2. Legacy `## Sensors registry` block (YAML `- id: <sensor-id>`).
# Stdin: contract path. Stdout: one id per line, sorted unique.
extract_contract_sensor_ids() {
  local contract_path="$1"
  {
    awk '
      /^### Validation[[:space:]]*$/ { in_v = 1; next }
      in_v && /^### / && !/^### Validation/ { in_v = 0 }
      in_v && /^## / { in_v = 0 }
      in_v && /^[[:space:]]*-[[:space:]]+\*\*[a-z0-9-]+\*\*/ {
        match($0, /\*\*[a-z0-9-]+\*\*/)
        if (RSTART > 0) {
          id = substr($0, RSTART + 2, RLENGTH - 4)
          print id
        }
      }
    ' "$contract_path"
    # Legacy registry — match `- id: <id>` blocks under `## Sensors registry`.
    awk '
      /^## Sensors registry/ { in_r = 1; next }
      in_r && /^## / && !/^## Sensors registry/ { in_r = 0 }
      in_r && /^[[:space:]]*-[[:space:]]+id:[[:space:]]*/ {
        v = $0
        sub(/^[[:space:]]*-[[:space:]]+id:[[:space:]]*/, "", v)
        sub(/[[:space:]]+$/, "", v)
        if (v != "") print v
      }
    ' "$contract_path"
    # Legacy `Sensors: [id1, id2]` scenario lines.
    awk '
      /^Sensors:[[:space:]]*\[/ {
        line = $0
        sub(/^Sensors:[[:space:]]*\[/, "", line)
        sub(/\][[:space:]]*$/, "", line)
        n = split(line, arr, ",")
        for (i = 1; i <= n; i++) {
          v = arr[i]
          sub(/^[[:space:]]+/, "", v)
          sub(/[[:space:]]+$/, "", v)
          if (v != "") print v
        }
      }
    ' "$contract_path"
  } | LC_ALL=C sort -u
}

# ---------------------------------------------------------------------------
# Readiness mode
# ---------------------------------------------------------------------------
readiness_mode() {
  if [ -z "$contract" ]; then
    echo "Error: --mode readiness requires a path argument (sensor file or Acceptance Contract)." >&2
    exit 2
  fi
  if [ ! -f "$contract" ]; then
    echo "Error: file not found at '${contract}'." >&2
    exit 3
  fi

  if is_acceptance_contract_path "$contract"; then
    readiness_for_contract "$contract"
  else
    readiness_for_sensor_file "$contract"
  fi
}

readiness_for_sensor_file() {
  local file="$1"
  if validate_sensor_file "$file"; then
    printf 'status: ready\nsensors:\n  - id: "%s"\n    path: "%s"\n    parses: true\nfailures: []\n' \
      "$(awk -F': *' '/^id:/ { sub(/^id:[[:space:]]*/, ""); print; exit }' "$file" || echo "")" \
      "$file"
    return 0
  fi
  exit 4
}

readiness_for_contract() {
  local contract_path="$1"
  local sensors_dir
  if [ -n "$root_dir" ]; then
    sensors_dir="${root_dir%/}/sensors"
  else
    sensors_dir=".yoke/sensors"
  fi

  local ids
  ids="$(extract_contract_sensor_ids "$contract_path")"

  # Apply --sensor filter if provided.
  if [ -n "$sensor_filter" ]; then
    ids="$(printf '%s\n' "$ids" | grep -F "$sensor_filter" || true)"
  fi

  if [ -z "$ids" ]; then
    printf 'status: ready\nsensors: []\nfailures: []\n'
    return 0
  fi

  local sensor_yaml="" failure_yaml=""
  local any_missing=0 id sf
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    sf="${sensors_dir}/${id}.md"
    if [ ! -f "$sf" ]; then
      any_missing=1
      sensor_yaml+="  - id: \"${id}\""$'\n'
      sensor_yaml+="    path: \"${sf}\""$'\n'
      sensor_yaml+="    exists: false"$'\n'
      sensor_yaml+="    parses: false"$'\n'
      failure_yaml+="$(emit_failure "$id" "file at ${sf}" "missing" "sensor file not found" "run \`/yoke:ack-sensors --mode upsert\`")"$'\n'
      continue
    fi
    if validate_sensor_file "$sf" 2>/dev/null; then
      sensor_yaml+="  - id: \"${id}\""$'\n'
      sensor_yaml+="    path: \"${sf}\""$'\n'
      sensor_yaml+="    exists: true"$'\n'
      sensor_yaml+="    parses: true"$'\n'
    else
      any_missing=1
      sensor_yaml+="  - id: \"${id}\""$'\n'
      sensor_yaml+="    path: \"${sf}\""$'\n'
      sensor_yaml+="    exists: true"$'\n'
      sensor_yaml+="    parses: false"$'\n'
      # Re-run validate so its stderr surfaces to the caller.
      validate_sensor_file "$sf" >/dev/null 2>&1 || true
      validate_sensor_file "$sf" 2>&1 1>/dev/null || true
      failure_yaml+="$(emit_failure "$id" "well-formed new-schema sensor file" "malformed" "sensor file fails new-schema validation" "edit ${sf} per templates/sensor.md")"$'\n'
    fi
  done <<< "$ids"

  if [ "$any_missing" -eq 0 ]; then
    printf 'status: ready\nsensors:\n%sfailures: []\n' "$sensor_yaml"
    return 0
  fi
  printf 'status: not-ready\nsensors:\n%sfailures:\n%s' "$sensor_yaml" "$failure_yaml"
  exit 4
}

# ---------------------------------------------------------------------------
# Upsert mode — create new sensor files; never touch existing ones.
# ---------------------------------------------------------------------------
upsert_mode() {
  # Default: walk every contract under <root>/.yoke/acceptance-contracts/
  # or, with --root <dir>, under <dir>/contracts/.
  local contracts_glob sensors_dir
  if [ -n "$root_dir" ]; then
    contracts_glob="${root_dir%/}/contracts"
    sensors_dir="${root_dir%/}/sensors"
  else
    contracts_glob=".yoke/acceptance-contracts"
    sensors_dir=".yoke/sensors"
  fi

  if [ ! -d "$contracts_glob" ]; then
    echo "Error: contracts directory '${contracts_glob}' not found." >&2
    exit 3
  fi

  mkdir -p "$sensors_dir"

  # Collect deduplicated id set across all contracts.
  local ids="" cf
  shopt -s nullglob
  for cf in "$contracts_glob"/*.md; do
    if [ -f "$cf" ]; then
      ids+="$(extract_contract_sensor_ids "$cf")"$'\n'
    fi
  done
  shopt -u nullglob
  ids="$(printf '%s\n' "$ids" | LC_ALL=C sort -u | grep -v '^$' || true)"

  # Sensor-id regex — matches `wm_sensor_path` in
  # lib/working-memory/paths.sh. Kebab-or-snake plus '.' / '-' / '_';
  # lower-case alnum start; ≤64 chars total. The path constructor
  # honors `--root` so we cannot dispatch through `wm_sensor_path`
  # directly — duplicating the validation regex here keeps the two
  # call sites in sync (any tightening must touch both).
  local sensor_id_regex='^[a-z0-9][a-z0-9_.-]{0,63}$'

  local upserted_yaml=""
  local failures_yaml=""
  local id sf action
  local invalid_count=0
  if [ -n "$ids" ]; then
    while IFS= read -r id; do
      [ -z "$id" ] && continue
      if [[ ! "$id" =~ $sensor_id_regex ]]; then
        # Structured failure per concepts/yoke-pattern-sensors —
        # sensor / expected / actual / reason / correction.
        failures_yaml+="  - sensor: \"${id}\""$'\n'
        failures_yaml+="    expected: \"sensor id matching ${sensor_id_regex}\""$'\n'
        failures_yaml+="    actual: \"${id}\""$'\n'
        failures_yaml+="    reason: \"sensor id contains characters outside the kebab-or-snake set (allowed: lower-case alnum start, then [a-z0-9_.-], ≤64 chars total). Whitespace, parentheses, and uppercase are rejected.\""$'\n'
        failures_yaml+="    correction: \"edit the contract to remove the invalid sensor reference (e.g. drop annotations from \`Sensors: [<id> (annotation)]\` or rename the registry entry); re-run upsert.\""$'\n'
        invalid_count=$((invalid_count + 1))
        continue
      fi
      sf="${sensors_dir}/${id}.md"
      if [ -f "$sf" ]; then
        action="unchanged"
      else
        render_new_sensor_file "$id" "computational" > "$sf"
        action="created"
      fi
      upserted_yaml+="  - id: \"${id}\""$'\n'
      upserted_yaml+="    path: \"${sf}\""$'\n'
      upserted_yaml+="    action: ${action}"$'\n'
    done <<< "$ids"
  fi

  if [ "$invalid_count" -gt 0 ]; then
    # Surface the same structured failures on stderr so callers piping
    # stdout into a parser still see the violation list. Exit 4 per
    # the upsert contract.
    {
      printf 'wm: ack-sensors --mode upsert rejected %d invalid sensor id(s):\n' "$invalid_count"
      printf '%s' "$failures_yaml"
    } >&2
    if [ -z "$upserted_yaml" ]; then
      printf 'status: error\nupserted: []\nfailures:\n%s' "$failures_yaml"
    else
      printf 'status: error\nupserted:\n%sfailures:\n%s' "$upserted_yaml" "$failures_yaml"
    fi
    exit 4
  fi

  if [ -z "$upserted_yaml" ]; then
    printf 'status: ok\nupserted: []\nfailures: []\n'
  else
    printf 'status: ok\nupserted:\n%sfailures: []\n' "$upserted_yaml"
  fi
}

# Render a fresh sensor file from `templates/sensor.md` for a given id.
# Defaults: type=computational, token_cost=0, time_cost=30,
# command=<!-- TODO: fill -->. Body sections inherit the template's
# placeholder comments, so readiness will warn until the human fills
# them.
render_new_sensor_file() {
  local id="$1"
  local type="${2:-computational}"
  local template="${plugin_root}/templates/sensor.md"

  if [ ! -f "$template" ]; then
    echo "Error: sensor template not found at ${template}" >&2
    exit 2
  fi

  local default_token_cost default_time_cost
  if [ "$type" = "inferential" ]; then
    default_token_cost=1000
    default_time_cost=60
  else
    default_token_cost=0
    default_time_cost=30
  fi

  awk -v id="$id" -v type="$type" -v token_cost="$default_token_cost" -v time_cost="$default_time_cost" '
    /^id: <kebab-case-id>$/             { print "id: " id; next }
    /^type: <computational \| inferential>$/ { print "type: " type; next }
    /^token_cost: 0$/                   { print "token_cost: " token_cost; next }
    /^time_cost: 30$/                   { print "time_cost: " time_cost; next }
    /^command: <shell command>$/ {
      if (type == "computational") {
        print "command: <!-- TODO: fill -->"
      } else {
        # Skip the command line; inferential gets agent instead.
        next
      }
      next
    }
    /^# agent: <subagent-id>$/ {
      if (type == "inferential") {
        print "agent: <!-- TODO: fill -->"
      } else {
        print
      }
      next
    }
    /^# command is required iff type: computational$/ {
      if (type == "computational") {
        print
      } else {
        next
      }
      next
    }
    /^# agent is required iff type: inferential .and command MUST be absent.$/ {
      if (type == "inferential") {
        print
      } else {
        print
      }
      next
    }
    /^# <human-readable sensor name>$/  { print "# " id; next }
    { print }
  ' "$template"
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
