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
#   --tier <cheap|expensive|all>
#                             Filter executed sensors by cost tier (sensor-
#                             cost-tiering Part 3). Tier is resolved per
#                             sensor by reading `.yoke/sensors/<id>.md`
#                             frontmatter (with class-based default —
#                             computational → cheap, inferential →
#                             expensive). Orthogonal to `--criterion`;
#                             both filters combine by intersection. Only
#                             meaningful for new-format contracts (`## Sensors
#                             registry`); old-format contracts have no tier
#                             metadata and reject `--tier cheap|expensive`.
#                             Default (no flag) preserves current full-suite
#                             behavior; `--tier all` is explicit and
#                             equivalent.
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
#                        comes from .yoke/runtime/.current).
#
# Sensor source-of-truth (sensor-cost-tiering Part 1+):
#
#   * **New format** — contract uses `## Sensors registry` block + `Sensors:
#     [<id>]` references. Each sensor's command/class/tier lives in
#     `.yoke/sensors/<id>.md`. Read by this hook when the contract has the
#     registry section.
#   * **Old format** — contract uses inline `## Sensors > ### Computational`
#     block:
#
#       ## Sensors
#
#       ### Computational
#       - linter: `npm run lint`
#       - type-check: `mypy --strict`
#
#     Read by this hook when the registry section is absent. No tier
#     metadata; `--tier cheap|expensive` is rejected against old-format
#     contracts with a structured violation pointing at `/yoke:ack-sensors
#     --mode upsert <contract>`.
#
# Per-criterion mapping (used by --criterion, both formats):
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
#   4 — Acceptance Contract has no sensor section (neither old nor new
#       format), or `--tier cheap|expensive` was passed against an
#       old-format contract, or a referenced `.yoke/sensors/<id>.md` is
#       missing or malformed under tier filtering.

set -euo pipefail

# Locate paths helper relative to this hook (so cwd doesn't matter).
hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/working-memory/paths.sh
source "${hook_dir}/../lib/working-memory/paths.sh"

# --- argument parsing -------------------------------------------------------

contract=""
filter_criterion=""
filter_tier="all"
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
    --tier)
      filter_tier="${2:-}"
      case "$filter_tier" in
        cheap|expensive|all) ;;
        "")
          echo "Error: --tier requires a value." >&2
          exit 2
          ;;
        *)
          # Structured violation per sensors.md back-pressure.
          echo "Error: unknown --tier value '${filter_tier}'." >&2
          echo "  expected: cheap | expensive | all" >&2
          echo "  correction: re-run with --tier cheap, --tier expensive, --tier all, or omit the flag." >&2
          exit 2
          ;;
      esac
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

# --- ack-sensors readiness pre-flight ---------------------------------------
# Delegate sensor discovery + reachability to /yoke:ack-sensors --mode
# readiness (single source of truth, same parser used by humans during
# Trigger 3 and by other tooling that needs the catalog/manifest). This
# call is informational on the hook's serial / xargs parallel path —
# the per-sensor `command -v` check inside run_one_sensor remains
# authoritative for the actual reachability decision (xargs subshells
# don't share state with this top-level call). When ack-sensors is
# missing or returns an unexpected exit, we log to stderr and continue
# so legacy CI consumers never see a regression.
ack_sensors="${hook_dir}/../lib/sensors/ack-sensors.sh"
if [ -f "$ack_sensors" ]; then
  set +e
  bash "$ack_sensors" --mode readiness "$contract" >/dev/null 2>&1
  ack_readiness_code=$?
  set -e
  if [ "$ack_readiness_code" -ne 0 ] && [ "$ack_readiness_code" -ne 4 ]; then
    echo "verify-acceptance: ack-sensors readiness returned exit ${ack_readiness_code}; continuing with hook-local discovery." >&2
  fi
fi

# --- contract format detection ----------------------------------------------
# New format (sensor-cost-tiering Part 1+) puts sensor metadata in
# `.yoke/sensors/<id>.md` files and references them from the contract via a
# `## Sensors registry` block + `Sensors: [<id>]` lines in scenarios.
# Old format keeps inline bullets under `## Sensors > ### Computational`.
# Both formats are supported here; new format is preferred when present.
contract_format=""
if grep -qE '^## Sensors registry[[:space:]]*$' "$contract"; then
  contract_format="new"
fi

sensors_block=$(awk '
  /^## Sensors[[:space:]]*$/ { in_sensors = 1; next }
  in_sensors && /^## / && !/^## Sensors/ { in_sensors = 0 }
  in_sensors && /^### Computational[[:space:]]*$/ { in_comp = 1; next }
  in_sensors && in_comp && /^### / { in_comp = 0 }
  in_sensors && in_comp { print }
' "$contract")

if [ -z "$contract_format" ] && [ -n "$sensors_block" ]; then
  contract_format="old"
fi

if [ -z "$contract_format" ]; then
  echo "Error: Acceptance Contract has no sensor section." >&2
  echo "  expected: '## Sensors registry' (new format) or '## Sensors > ### Computational' (old format)" >&2
  echo "  correction: add a registry block or run \`/yoke:ack-sensors --mode upsert ${contract}\`." >&2
  exit 4
fi

# Tier filtering requires the new format (sensor files have tier metadata).
if [ "$filter_tier" != "all" ] && [ "$contract_format" = "old" ]; then
  echo "Error: --tier ${filter_tier} requires the new contract format with '## Sensors registry'." >&2
  echo "  expected: contract with '## Sensors registry' and per-sensor files in .yoke/sensors/" >&2
  echo "  actual: contract uses old-format inline '## Sensors > ### Computational' block" >&2
  echo "  correction: migrate the contract to the new format and run \`/yoke:ack-sensors --mode upsert ${contract}\`." >&2
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
# Parallel map: sensor_tier[<name>] = cheap|expensive|"" (empty for old
# format / unresolved). Used by the --tier filter below.
declare -A sensor_tier=()

sensor_pairs=()
if [ "$contract_format" = "old" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+([^:]+):[[:space:]]*\`([^\`]+)\` ]]; then
      sensor_name=$(echo "${BASH_REMATCH[1]}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
      command_str="${BASH_REMATCH[2]}"
      sensor_pairs+=("${sensor_name}|${command_str}")
    fi
  done <<< "$sensors_block"
else
  # New format: extract registered ids from `## Sensors registry` YAML
  # block and load command + class + tier from each `.yoke/sensors/<id>.md`.
  registry_ids=$(awk '
    /^## Sensors registry/ { in_section = 1; next }
    in_section && /^## / { in_section = 0 }
    in_section && /^```yaml[[:space:]]*$/ { in_block = 1; next }
    in_section && /^```[[:space:]]*$/ && in_block { in_block = 0 }
    in_block && /^[[:space:]]*-[[:space:]]+id:/ {
      v = $0
      sub(/^[[:space:]]*-[[:space:]]+id:[[:space:]]*/, "", v)
      sub(/[[:space:]]+$/, "", v)
      print v
    }
  ' "$contract")

  while IFS= read -r id; do
    [ -z "$id" ] && continue
    sensor_file=".yoke/sensors/${id}.md"
    if [ ! -f "$sensor_file" ]; then
      # Skip silently when --tier is `all` (or omitted) and we are
      # processing a registered sensor whose file is missing — readiness
      # mode is the right place to surface that. But surface a hard
      # failure when the user explicitly asked for tier filtering, since
      # tier resolution requires the file.
      if [ "$filter_tier" != "all" ]; then
        echo "Error: sensor file missing for registered id '${id}'." >&2
        echo "  expected: ${sensor_file}" >&2
        echo "  actual: file not found" >&2
        echo "  correction: run \`/yoke:ack-sensors --mode upsert ${contract}\`." >&2
        exit 4
      fi
      continue
    fi

    fm=$(awk '
      BEGIN { count = 0 }
      /^---[[:space:]]*$/ { count++; if (count == 2) exit; next }
      count == 1 { print }
    ' "$sensor_file")

    sensor_command=$(printf '%s\n' "$fm" \
      | awk -F': ' '/^command:/ { sub(/^command:[[:space:]]*/, "", $0); print $0; exit }')
    sensor_class=$(printf '%s\n' "$fm" \
      | awk -F': ' '/^class:/ { sub(/^class:[[:space:]]*/, "", $0); print $0; exit }')
    sensor_tier_val=$(printf '%s\n' "$fm" \
      | awk -F': ' '/^tier:/ { sub(/^tier:[[:space:]]*/, "", $0); print $0; exit }')

    if [ -z "$sensor_command" ] || [ -z "$sensor_class" ]; then
      if [ "$filter_tier" != "all" ]; then
        echo "Error: sensor file '${sensor_file}' is malformed." >&2
        echo "  expected: command and class fields populated in frontmatter" >&2
        echo "  actual: command='${sensor_command}', class='${sensor_class}'" >&2
        echo "  correction: edit ${sensor_file} or re-run \`/yoke:ack-sensors --mode upsert ${contract}\`." >&2
        exit 4
      fi
      continue
    fi

    # Class-based default when tier is absent.
    if [ -z "$sensor_tier_val" ]; then
      if [ "$sensor_class" = "inferential" ]; then
        sensor_tier_val="expensive"
      else
        sensor_tier_val="cheap"
      fi
    fi

    sensor_pairs+=("${id}|${sensor_command}")
    sensor_tier["$id"]="$sensor_tier_val"
  done <<< "$registry_ids"
fi

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

# --- apply --tier filter (new format only; old format errors out earlier) --
if [ "$filter_tier" != "all" ] && [ "${#sensor_pairs[@]}" -gt 0 ]; then
  filtered_pairs=()
  for pair in "${sensor_pairs[@]}"; do
    name="${pair%%|*}"
    pair_tier="${sensor_tier[$name]:-}"
    if [ "$pair_tier" = "$filter_tier" ]; then
      filtered_pairs+=("$pair")
    fi
  done
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
