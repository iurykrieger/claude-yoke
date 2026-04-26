#!/bin/bash
# verify-acceptance.sh — runs the sensors declared in the active task's
# Acceptance Contract and emits structured per-criterion results.
#
# Usage: verify-acceptance.sh [<acceptance-contract-path>] [options]
#
# Options:
#   --criterion <id>          Run only sensors mapped to <id>. <id> matches
#                             either a "Scenario N" heading or an "FR-N"
#                             functional-requirement bullet in the contract.
#                             Default (no flag): full-suite run.
#   --concurrency <N>         Override sensor parallelism. <N> must be a
#                             positive integer. Default resolves from
#                             .yoke/config.yaml's runtime.sensor_concurrency,
#                             or 4. Set 1 for a strictly serial run
#                             (used by MERGE-READY check).
#   --fragments-dir <path>    Persist per-sensor fragment YAML files at
#                             <path>/<safe-sensor-id>.yaml. Caller owns the
#                             directory's lifetime. Without the flag a
#                             tempdir is created and cleaned up at exit.
#
# Default contract path: resolved via lib/working-memory/paths.sh::wm_acceptance_contract_path
#                        (i.e., .yoke/acceptance-contracts/<slug>.md, where <slug>
#                        comes from .yoke/.current).
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
# Per-criterion mapping (used by --criterion):
#   - Scenario blocks carry `Sensors: [name1, name2, ...]`.
#   - FR bullets carry `Sensor: name.` (single sensor).
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

# Locate paths helper relative to this hook (so cwd doesn't matter).
hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/working-memory/paths.sh
source "${hook_dir}/../lib/working-memory/paths.sh"

# --- argument parsing -------------------------------------------------------

contract=""
filter_criterion=""
explicit_concurrency=""
fragments_dir=""

while [ $# -gt 0 ]; do
  case "$1" in
    --criterion)
      filter_criterion="${2:-}"
      if [ -z "$filter_criterion" ]; then
        echo "Error: --criterion requires a value." >&2
        exit 2
      fi
      shift 2
      ;;
    --concurrency)
      explicit_concurrency="${2:-}"
      if ! [[ "$explicit_concurrency" =~ ^[0-9]+$ ]] || [ "$explicit_concurrency" -lt 1 ]; then
        echo "Error: --concurrency requires a positive integer." >&2
        exit 2
      fi
      shift 2
      ;;
    --fragments-dir)
      fragments_dir="${2:-}"
      if [ -z "$fragments_dir" ]; then
        echo "Error: --fragments-dir requires a path." >&2
        exit 2
      fi
      shift 2
      ;;
    --*)
      echo "Error: unknown option '$1'." >&2
      exit 2
      ;;
    *)
      if [ -z "$contract" ]; then
        contract="$1"
      else
        echo "Error: unexpected positional argument '$1'." >&2
        exit 2
      fi
      shift
      ;;
  esac
done

if [ -z "$contract" ]; then
  contract="$(wm_acceptance_contract_path)" || exit 3
fi

if [ ! -f "$contract" ]; then
  echo "Error: Acceptance Contract not found at '$contract'." >&2
  exit 3
fi

# --- concurrency knob -------------------------------------------------------
# Resolves runtime.sensor_concurrency from .yoke/config.yaml, falling back to
# default 4. Inlined per spec ("helper-vs-inline decision deferred to
# implementation"). Coordinator passes --concurrency 1 for the MERGE-READY
# serial sweep.
yoke_sensor_concurrency() {
  local default=4
  local config=".yoke/config.yaml"
  if [ -f "$config" ]; then
    local val
    val=$(awk '
      /^runtime:[[:space:]]*$/ { in_rt = 1; next }
      in_rt && /^[A-Za-z_]/ { in_rt = 0 }
      in_rt && /^[[:space:]]+sensor_concurrency:/ {
        sub(/.*sensor_concurrency:[[:space:]]*/, "")
        sub(/[[:space:]]+$/, "")
        sub(/[[:space:]]*#.*$/, "")
        print
        exit
      }
    ' "$config" 2>/dev/null || true)
    if [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -ge 1 ]; then
      printf '%s' "$val"
      return 0
    fi
  fi
  printf '%s' "$default"
}

if [ -n "$explicit_concurrency" ]; then
  concurrency="$explicit_concurrency"
else
  concurrency="$(yoke_sensor_concurrency)"
fi

# --- fragments dir setup ----------------------------------------------------
cleanup_fragments=0
if [ -z "$fragments_dir" ]; then
  fragments_dir="$(mktemp -d)"
  cleanup_fragments=1
else
  mkdir -p "$fragments_dir"
fi

# Single trap that cleans up only the auto-generated tempdir.
cleanup() {
  if [ "$cleanup_fragments" -eq 1 ] && [ -d "$fragments_dir" ]; then
    rm -rf "$fragments_dir"
  fi
}
trap cleanup EXIT

# --- sensor block extraction ------------------------------------------------
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

# --- criterion → sensor names ----------------------------------------------
# Returns a newline-separated list of sensor names mapped to <criterion>.
# Empty output means "no mapping" (caller falls back / emits empty results).
sensors_for_criterion() {
  local criterion="$1"
  local raw

  # Scenario form: "### Scenario N — name" followed by "Sensors: [a, b, c]"
  raw=$(awk -v crit="$criterion" '
    /^###[[:space:]]+Scenario[[:space:]]+/ {
      heading = $0
      sub(/^###[[:space:]]+/, "", heading)
      n = split(heading, parts, /[[:space:]]+/)
      sid = parts[1] " " parts[2]
      if (sid == crit) { in_scenario = 1 } else { in_scenario = 0 }
      next
    }
    /^##[[:space:]]/ || /^###[[:space:]]/ { in_scenario = 0 }
    in_scenario && /^Sensors:/ {
      sub(/^Sensors:[[:space:]]*\[/, "")
      sub(/\][[:space:]]*$/, "")
      print
      exit
    }
  ' "$contract")

  if [ -n "$raw" ]; then
    echo "$raw" | tr ',' '\n' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' | grep -v '^$' || true
    return 0
  fi

  # FR form: "- [ ] **FR-N** — requirement. Sensor: name."
  raw=$(grep -E "\\*\\*${criterion}\\*\\*" "$contract" 2>/dev/null | head -1 || true)
  if [ -n "$raw" ]; then
    echo "$raw" | sed -nE 's/.*Sensor:[[:space:]]*([^.[:space:]]+)\.?.*/\1/p'
  fi
}

# --- per-sensor execution function (exported for xargs subshells) -----------
run_one_sensor() {
  local sensor_name="$1"
  local command_str="$2"
  local fragment_file="$3"

  local leading_bin status exit_code output_excerpt reason sensor_output
  leading_bin=$(echo "$command_str" | awk '{print $1}')
  status=""
  exit_code=-1
  output_excerpt=""
  reason=""

  if ! command -v "$leading_bin" >/dev/null 2>&1; then
    status="skip"
    reason="binary not found: $leading_bin"
  else
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
    output_excerpt=$(echo "$sensor_output" | grep -v '^[[:space:]]*$' | head -5 || true)
  fi

  # Inline YAML escape (kept inside the function so xargs subshells have it).
  esc() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/}
    printf '%s' "$s"
  }

  cat > "$fragment_file" <<EOF
  - sensor: "$(esc "$sensor_name")"
    command: "$(esc "$command_str")"
    status: $status
    exit_code: $exit_code
    output_excerpt: "$(esc "$output_excerpt")"
    reason: "$(esc "$reason")"
EOF
}
export -f run_one_sensor

# --- build sensor pair list (name|command) and apply --criterion filter ----
sensor_pairs=()
while IFS= read -r line; do
  [ -z "$line" ] && continue
  if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+([^:]+):[[:space:]]*\`([^\`]+)\` ]]; then
    sensor_name=$(echo "${BASH_REMATCH[1]}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    command_str="${BASH_REMATCH[2]}"
    sensor_pairs+=("${sensor_name}|${command_str}")
  fi
done <<< "$sensors_block"

if [ -n "$filter_criterion" ]; then
  allowed=$(sensors_for_criterion "$filter_criterion" || true)
  filtered_pairs=()
  if [ -n "$allowed" ] && [ "${#sensor_pairs[@]}" -gt 0 ]; then
    while IFS= read -r allowed_name; do
      [ -z "$allowed_name" ] && continue
      for pair in "${sensor_pairs[@]}"; do
        name="${pair%%|*}"
        if [ "$name" = "$allowed_name" ]; then
          filtered_pairs+=("$pair")
          break
        fi
      done
    done <<< "$allowed"
  fi
  if [ "${#filtered_pairs[@]}" -gt 0 ]; then
    sensor_pairs=("${filtered_pairs[@]}")
  else
    sensor_pairs=()
  fi
fi

# --- safe-filename helper (used by both serial and parallel paths) ----------
safe_filename() {
  echo "$1" | tr -c '[:alnum:]_.-' '_'
}

# --- run sensors (parallel via xargs -P, or serial when concurrency==1) ----
# When concurrency>1 we fan out via xargs -P; each subshell calls
# run_one_sensor (exported above) and writes to its own fragment file.
# When concurrency==1 we still write fragments but iterate inline so the
# MERGE-READY serial sweep is straightforward and predictable.
if [ "${#sensor_pairs[@]}" -gt 0 ]; then
  if [ "$concurrency" -eq 1 ]; then
    for pair in "${sensor_pairs[@]}"; do
      [ -z "$pair" ] && continue
      name="${pair%%|*}"
      cmd="${pair#*|}"
      fragment_file="${fragments_dir}/$(safe_filename "$name").yaml"
      run_one_sensor "$name" "$cmd" "$fragment_file"
    done
  else
    # Null-delimited fanout to xargs; -I {} substitutes the whole pair into
    # the bash -c invocation as $1.
    export FRAGMENTS_DIR="$fragments_dir"
    printf '%s\0' "${sensor_pairs[@]}" \
      | xargs -0 -I {} -P "$concurrency" bash -c '
          pair="$1"
          name="${pair%%|*}"
          cmd="${pair#*|}"
          safe=$(echo "$name" | tr -c "[:alnum:]_.-" "_")
          run_one_sensor "$name" "$cmd" "$FRAGMENTS_DIR/$safe.yaml"
        ' _ {}
    unset FRAGMENTS_DIR
  fi
fi

# --- merge fragments deterministically (alphabetical by sensor-id) ---------
echo "results:"
if [ -d "$fragments_dir" ]; then
  # LC_ALL=C sort guarantees byte-order regardless of locale.
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    cat "$f"
  done < <(find "$fragments_dir" -maxdepth 1 -type f -name '*.yaml' 2>/dev/null | LC_ALL=C sort)
fi

exit 0
