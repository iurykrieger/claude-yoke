#!/usr/bin/env bash
# resolve-pool.sh
#
# Sensor-pool resolution helper for Phase 3 (`/yoke:acceptance-criteria`).
# Parses an Acceptance Criteria document's `## Sensor pool` block and
# verifies that every listed sensor ID resolves to a `.yoke/sensors/<id>.md`
# file. Refusing ratification when any pool entry fails to resolve is a
# fail-closed gate per the v4.0.0 cutover binding.
#
# Cites concepts/yoke-pattern-sensors for the sensor-as-first-class-
# persistent-artifact invariant: every sensor referenced by a binding
# artifact MUST have a per-sensor file at `.yoke/sensors/<id>.md`.
#
# Usage:
#   source lib/sensors/resolve-pool.sh
#   resolve_sensor_pool <artifact-path> [<sensors-dir>]
#
# Arguments:
#   <artifact-path>  Path to the Acceptance Criteria document under
#                    `.yoke/acceptance-criteria/<slug>.md`.
#   <sensors-dir>    Optional override for the sensor catalogue
#                    directory. Defaults to `.yoke/sensors/`.
#
# Exit codes:
#   0  Every pool entry resolved (or the pool is empty — the calling
#      skill enforces the non-empty contract).
#   2  Invalid arguments / artifact missing / sensors-dir missing.
#   3  At least one pool entry failed to resolve. One stderr line per
#      unresolved id, prefixed `wm: sensor pool unresolved: <id>`.
#
# Stdout (on success):
#   `resolved: <N>` where N is the count of resolved IDs.

set -u

resolve_sensor_pool() {
  local artifact="${1:-}"
  local sensors_dir="${2:-.yoke/sensors}"

  if [ -z "$artifact" ]; then
    echo "wm: resolve_sensor_pool: artifact path required" >&2
    return 2
  fi
  if [ ! -f "$artifact" ]; then
    echo "wm: resolve_sensor_pool: artifact not found: $artifact" >&2
    return 2
  fi
  if [ ! -d "$sensors_dir" ]; then
    echo "wm: resolve_sensor_pool: sensors directory not found: $sensors_dir" >&2
    return 2
  fi

  # Extract the `## Sensor pool` block — every line between that H2 and
  # the next `^## ` heading (or EOF). Pure awk + bash 3-compatible
  # indexed arrays; no bash-4-only built-ins.
  local block
  block=$(awk '
    /^## Sensor pool[[:space:]]*$/ { in_block = 1; next }
    in_block && /^## / { in_block = 0 }
    in_block { print }
  ' "$artifact")

  # Parse one sensor ID per `^- ` bullet line. Strip leading `- ` and any
  # trailing whitespace / inline annotations after the id (e.g.
  # `- lint  # optional comment`). The id itself follows the
  # kebab-case-or-underscore convention enforced by `.yoke/sensors/`
  # filenames.
  local -a ids=()
  local line id
  while IFS= read -r line; do
    case "$line" in
      "- "*)
        # Strip leading `- `.
        id="${line#- }"
        # Trim leading/trailing whitespace.
        id="${id## }"
        id="${id%% *}"
        # Discard markdown emphasis (`- **lint**` → `lint`).
        id="${id//\*/}"
        # Discard backticks (`- \`lint\`` → `lint`).
        id="${id//\`/}"
        if [ -n "$id" ]; then
          ids+=("$id")
        fi
        ;;
    esac
  done <<< "$block"

  local resolved=0
  local unresolved=0
  for id in "${ids[@]}"; do
    if [ -f "$sensors_dir/$id.md" ]; then
      resolved=$((resolved + 1))
    else
      echo "wm: sensor pool unresolved: $id" >&2
      unresolved=$((unresolved + 1))
    fi
  done

  if [ "$unresolved" -gt 0 ]; then
    echo "wm: $unresolved of ${#ids[@]} pool entries unresolved" >&2
    return 3
  fi

  printf 'resolved: %d\n' "$resolved"
  return 0
}

# Allow direct invocation: `bash lib/sensors/resolve-pool.sh <path> [<dir>]`
if [ "${BASH_SOURCE[0]:-$0}" = "${0}" ]; then
  resolve_sensor_pool "$@"
fi
