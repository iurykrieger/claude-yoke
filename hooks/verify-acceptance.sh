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
#   --max-time-cost <int>     Filter sensors by `time_cost` ≤ <int> seconds
#                             (resolved from `.yoke/sensors/<id>.md`
#                             frontmatter under the new schema). Sensors
#                             whose `time_cost` exceeds the value are
#                             skipped. Combines with --max-token-cost via
#                             logical AND.
#   --max-token-cost <int>    Filter sensors by `token_cost` ≤ <int> tokens
#                             (resolved from per-sensor file frontmatter).
#                             Combines with --max-time-cost via AND.
#   --concurrency <N>         Override sensor parallelism. <N> must be a
#                             positive integer. Default resolves from
#                             .yoke/config.yaml's runtime.sensor_concurrency,
#                             or 4. Set 1 for a strictly serial run
#                             (used by MERGE-READY check).
#   --fragments-dir <path>    Persist per-sensor fragment YAML files at
#                             <path>/<safe-sensor-id>.yaml. Caller owns the
#                             directory's lifetime. Without the flag a
#                             tempdir is created and cleaned up at exit.
#   --validate-verdict <path> Standalone verdict-parser mode: validate the
#                             JSON file at <path> against the inferential
#                             verdict schema (criterion / sensor / status /
#                             location / fix_instruction / evidence /
#                             confidence / supporting_quotes) and exit
#                             0 on valid, non-zero on invalid.
#
# Default contract path: resolved via lib/working-memory/paths.sh::wm_acceptance_contract_path
#                        (i.e., .yoke/acceptance-contracts/<slug>.md, where <slug>
#                        comes from .yoke/runtime/.current).
#
# Sensor source-of-truth (sensor-harness-realignment, supersedes
# sensor-cost-tiering Part 1):
#
#   * **New format** — contract carries per-criterion `### Validation`
#     sub-sections under each `### Criterion <id>` heading; each
#     sub-section lists `- **<sensor-id>** — <interpretation>` bullets.
#     Per-sensor metadata (`type` / `token_cost` / `time_cost` /
#     `command|agent`) lives in `.yoke/sensors/<sensor-id>.md` per
#     `templates/sensor.md`. Read by this hook when the contract has
#     `### Validation` sub-sections.
#   * **Legacy registry transition** — older contracts still carry
#     `## Sensors registry` with inline `class:` per sensor. This hook
#     reads the legacy registry as a fallback when no `### Validation`
#     blocks are present, with a stderr warning, and resolves dispatch
#     metadata from the per-sensor files (legacy contracts must have
#     had `/yoke:ack-sensors --mode upsert` run). Sprint 3 of the
#     harness-realignment PRD migrates the catalog and removes this
#     fallback.
#
# Per-criterion mapping (used by --criterion):
#   - Scenario blocks carry `Sensors: [name1, name2, ...]`.
#   - FR bullets carry `Sensor: name.` (single sensor).
#   - New-shape `### Criterion <id>` headings with per-criterion
#     `### Validation` bullets.
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
#   0 — verification ran (regardless of individual sensor outcomes), OR
#       --validate-verdict succeeded.
#   2 — usage error (including legacy `--tier` flag).
#   3 — Acceptance Contract not found.
#   4 — Acceptance Contract has no sensor section, or a referenced
#       `.yoke/sensors/<id>.md` is missing or malformed under the new
#       schema, or --validate-verdict found an invalid verdict envelope.

set -euo pipefail

# Locate paths helper relative to this hook (so cwd doesn't matter).
hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/working-memory/paths.sh
source "${hook_dir}/../lib/working-memory/paths.sh"

# --- argument parsing -------------------------------------------------------

contract=""
filter_criterion=""
max_time_cost=""
max_token_cost=""
explicit_concurrency=""
fragments_dir=""
validate_verdict_path=""

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
      # Removed in sensor-harness-realignment Sprint 2. Replaced by
      # --max-time-cost and --max-token-cost (resolved from the
      # per-sensor file's frontmatter).
      echo "Error: --tier was removed in the sensor-harness-realignment refactor." >&2
      echo "  expected: --max-time-cost <int> and/or --max-token-cost <int>" >&2
      echo "  correction: re-run with --max-time-cost <seconds> and/or --max-token-cost <tokens>; the --tier flag is no longer recognized." >&2
      exit 2
      ;;
    --max-time-cost)
      max_time_cost="${2:-}"
      if ! [[ "$max_time_cost" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-time-cost requires a non-negative integer (got '${max_time_cost}')." >&2
        exit 2
      fi
      shift 2
      ;;
    --max-token-cost)
      max_token_cost="${2:-}"
      if ! [[ "$max_token_cost" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-token-cost requires a non-negative integer (got '${max_token_cost}')." >&2
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
    --validate-verdict)
      validate_verdict_path="${2:-}"
      if [ -z "$validate_verdict_path" ]; then
        echo "Error: --validate-verdict requires a path." >&2
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

# ---------------------------------------------------------------------------
# Verdict-parser standalone mode.
# ---------------------------------------------------------------------------
# Validates an inferential-sensor verdict envelope:
#   { criterion, sensor, status, location, fix_instruction, evidence,
#     confidence, supporting_quotes }
# Hard rules (return 4 on violation):
#   - confidence is a number in [0, 1] (string "1.0" rejected).
#   - status ∈ {pass, fail, skip}.
#   - on status=fail, supporting_quotes MUST be a non-empty array of
#     strings; supporting_quotes=[] when status=fail is invalid.
#   - evidence is non-empty.
validate_verdict_envelope() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "Error: verdict file not found at '${path}'." >&2
    return 4
  fi

  local content
  content="$(cat "$path")"

  # Use python (or python3) for robust JSON validation. Falls back to
  # grep-based heuristics when python is unavailable so the parser still
  # runs in minimal CI environments.
  local py
  if command -v python3 >/dev/null 2>&1; then
    py=python3
  elif command -v python >/dev/null 2>&1; then
    py=python
  else
    py=""
  fi

  if [ -n "$py" ]; then
    "$py" - "$path" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r") as f:
        data = json.load(f)
except Exception as e:
    sys.stderr.write(f"Error: invalid JSON in verdict at '{path}': {e}\n")
    sys.exit(4)

if not isinstance(data, dict):
    sys.stderr.write(f"Error: verdict at '{path}' is not a JSON object.\n")
    sys.exit(4)

required = [
    "criterion",
    "sensor",
    "status",
    "location",
    "fix_instruction",
    "evidence",
    "confidence",
    "supporting_quotes",
]
missing = [k for k in required if k not in data]
if missing:
    sys.stderr.write(
        f"Error: verdict at '{path}' missing required keys: {missing}\n"
    )
    sys.exit(4)

status = data["status"]
if status not in ("pass", "fail", "skip"):
    sys.stderr.write(
        f"Error: verdict at '{path}' has invalid status '{status}'; expected pass|fail|skip.\n"
    )
    sys.exit(4)

confidence = data["confidence"]
if isinstance(confidence, bool) or not isinstance(confidence, (int, float)):
    sys.stderr.write(
        f"Error: verdict at '{path}' carries invalid confidence (must be a number, got {type(confidence).__name__}).\n"
    )
    sys.exit(4)
if confidence < 0 or confidence > 1:
    sys.stderr.write(
        f"Error: verdict at '{path}' carries invalid confidence (out of range [0,1]: {confidence}).\n"
    )
    sys.exit(4)

quotes = data["supporting_quotes"]
if not isinstance(quotes, list):
    sys.stderr.write(
        f"Error: verdict at '{path}' supporting_quotes must be a list (got {type(quotes).__name__}).\n"
    )
    sys.exit(4)
if status == "fail" and len(quotes) == 0:
    sys.stderr.write(
        f"Error: verdict at '{path}' carries invalid supporting_quotes (status=fail requires at least one quote).\n"
    )
    sys.exit(4)
for q in quotes:
    if not isinstance(q, str):
        sys.stderr.write(
            f"Error: verdict at '{path}' supporting_quotes entries must be strings.\n"
        )
        sys.exit(4)

evidence = data["evidence"]
if not isinstance(evidence, str) or evidence == "":
    sys.stderr.write(
        f"Error: verdict at '{path}' evidence must be a non-empty string.\n"
    )
    sys.exit(4)

sys.exit(0)
PY
    return $?
  fi

  # Fallback heuristics (python missing). Conservative — better to
  # reject ambiguous payloads than to falsely accept.
  if ! printf '%s' "$content" | grep -q '"confidence"'; then
    echo "Error: verdict at '${path}' missing 'confidence' field." >&2
    return 4
  fi
  if ! printf '%s' "$content" | grep -q '"supporting_quotes"'; then
    echo "Error: verdict at '${path}' missing 'supporting_quotes' field." >&2
    return 4
  fi
  # Reject confidence > 1 or negative quickly.
  if printf '%s' "$content" | grep -qE '"confidence"[[:space:]]*:[[:space:]]*(-[0-9]|[1-9][0-9]+|[2-9](\.[0-9]+)?|1\.[0-9]*[1-9])'; then
    echo "Error: verdict at '${path}' carries invalid confidence (out of range)." >&2
    return 4
  fi
  if printf '%s' "$content" | grep -qE '"status"[[:space:]]*:[[:space:]]*"fail"' \
     && printf '%s' "$content" | grep -qE '"supporting_quotes"[[:space:]]*:[[:space:]]*\[[[:space:]]*\]'; then
    echo "Error: verdict at '${path}' carries invalid supporting_quotes (status=fail with empty list)." >&2
    return 4
  fi
  return 0
}

if [ -n "$validate_verdict_path" ]; then
  if validate_verdict_envelope "$validate_verdict_path"; then
    echo "verdict ok: $validate_verdict_path"
    exit 0
  fi
  exit 4
fi

# --- contract resolution ---------------------------------------------------

if [ -z "$contract" ]; then
  contract="$(wm_acceptance_contract_path)" || exit 3
fi

if [ ! -f "$contract" ]; then
  echo "Error: Acceptance Contract not found at '$contract'." >&2
  exit 3
fi

# --- concurrency knob -------------------------------------------------------
# Resolves runtime.sensor_concurrency from .yoke/config.yaml, falling back to
# default 4. Coordinator passes --concurrency 1 for the MERGE-READY serial
# sweep.
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

cleanup() {
  if [ "$cleanup_fragments" -eq 1 ] && [ -d "$fragments_dir" ]; then
    rm -rf "$fragments_dir"
  fi
}
trap cleanup EXIT

# --- contract format detection ----------------------------------------------
# Detect new-shape (per-criterion `### Validation` blocks) vs. legacy
# (`## Sensors registry`). Both can co-exist during the bootstrap
# transition; new-shape takes priority. Old `## Sensors > ###
# Computational` block is no longer supported (sensor-cost-tiering Part
# 1 already eliminated it; harness-realignment formalizes its removal).
contract_format=""
if grep -qE '^### Validation[[:space:]]*$' "$contract"; then
  contract_format="new"
elif grep -qE '^## Sensors registry[[:space:]]*$' "$contract"; then
  contract_format="legacy-registry"
  echo "verify-acceptance: contract uses legacy '## Sensors registry' (sensor-harness-realignment transition layer; Sprint 3 will migrate)." >&2
elif grep -qE '^## Sensors[[:space:]]*$' "$contract" && grep -qE '^### Computational[[:space:]]*$' "$contract"; then
  # Format C — pre-cost-tiering shape with inline `- name: ` + "cmd" bullets
  # under `## Sensors > ### Computational`. Retained for legacy fixtures and
  # for parity with the perf-quickwins / ack-sensors-parallel test surfaces.
  # When this format is detected, sensor commands are parsed inline from the
  # contract and the per-sensor file lookup (legacy expectation: delegate to
  # `lib/sensors/ack-sensors.sh --mode readiness` for catalog discovery) is
  # bypassed in favor of the inline command string.
  contract_format="legacy-inline"
fi

if [ -z "$contract_format" ]; then
  echo "Error: Acceptance Contract has no sensor section." >&2
  echo "  expected: per-criterion '### Validation' blocks (new shape) or legacy '## Sensors registry' or '## Sensors / ### Computational'." >&2
  echo "  correction: rewrite the contract per templates/acceptance-contract.md, then run \`/yoke:ack-sensors --mode upsert ${contract}\` to materialize per-sensor files." >&2
  exit 4
fi

# --- per-sensor file metadata loader ----------------------------------------
# Reads `.yoke/sensors/<id>.md` and emits `type|token_cost|time_cost|dispatch`
# on stdout. Returns 0 on success, non-zero with structured stderr on
# malformed/missing files. Used by both the new-shape validation parser
# and the legacy-registry fallback.
declare -A sensor_meta_type=()
declare -A sensor_meta_token_cost=()
declare -A sensor_meta_time_cost=()
declare -A sensor_meta_command=()
declare -A sensor_meta_agent=()

# Detect doctrinal-placeholder values that would otherwise execute as
# garbage commands at dispatch time and resolve to status: skip — never
# pass — exhausting the per-sprint hard bound with no organic path to
# convergence (issue #29). Recognized shapes:
#   - HTML-comment placeholder: `<!-- TODO: fill -->`
#   - Angle-bracketed slot markers: `<TODO>`, `<FIXME>`, `<TBD>`,
#     `<placeholder>`, `<fill in>`, `<your-...>`, `<insert-...>`,
#     `<edit-...>`
#   - Bare-token markers as the first word: `TODO`, `FIXME`, `TBD`
# Pre-flight rejection is the actionable failure mode the convergence
# rule requires — `skip != pass`, so a placeholder must never reach
# `run_one_sensor`.
sensor_value_is_placeholder() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  case "$v" in
    '<!--'*) return 0 ;;
  esac
  if printf '%s' "$v" | grep -qiE '^<(todo|fixme|tbd|placeholder|fill|your|insert|edit)\b'; then
    return 0
  fi
  if printf '%s' "$v" | grep -qE '^(TODO|FIXME|TBD)([[:space:]:]|$)'; then
    return 0
  fi
  return 1
}

load_sensor_metadata() {
  local id="$1"
  local criterion_for_error="${2:-<unspecified>}"
  local sensor_file=".yoke/sensors/${id}.md"

  if [ -n "${sensor_meta_type[$id]:-}" ]; then
    return 0
  fi

  if [ ! -f "$sensor_file" ]; then
    echo "Error: sensor file missing for criterion '${criterion_for_error}', sensor '${id}'." >&2
    echo "  expected: ${sensor_file}" >&2
    echo "  correction: run \`/yoke:ack-sensors --mode upsert ${contract}\` to materialize the file." >&2
    return 4
  fi

  local fm
  fm=$(awk '
    BEGIN { count = 0 }
    /^---[[:space:]]*$/ { count++; if (count == 2) exit; next }
    count == 1 { print }
  ' "$sensor_file")

  local v_type v_token v_time v_command v_agent
  v_type=$(printf '%s\n' "$fm" | awk -F': *' '/^type:/ { sub(/^type:[[:space:]]*/, ""); print; exit }')
  v_token=$(printf '%s\n' "$fm" | awk -F': *' '/^token_cost:/ { sub(/^token_cost:[[:space:]]*/, ""); print; exit }')
  v_time=$(printf '%s\n' "$fm" | awk -F': *' '/^time_cost:/ { sub(/^time_cost:[[:space:]]*/, ""); print; exit }')
  v_command=$(printf '%s\n' "$fm" | awk '/^command:/ { sub(/^command:[[:space:]]*/, ""); print; exit }')
  v_agent=$(printf '%s\n' "$fm" | awk '/^agent:/ { sub(/^agent:[[:space:]]*/, ""); print; exit }')

  if [ -z "$v_type" ]; then
    echo "Error: sensor file '${sensor_file}' missing 'type:' frontmatter (criterion '${criterion_for_error}')." >&2
    return 4
  fi
  case "$v_type" in
    computational)
      if [ -z "$v_command" ]; then
        echo "Error: sensor file '${sensor_file}' is type 'computational' but missing 'command:' (criterion '${criterion_for_error}')." >&2
        return 4
      fi
      if sensor_value_is_placeholder "$v_command"; then
        echo "Error: sensor file '${sensor_file}' is type 'computational' but 'command:' is a placeholder ('${v_command}') (criterion '${criterion_for_error}')." >&2
        echo "  Resolve the placeholder before invoking /yoke:implement; the convergence rule treats placeholders as 'skip', not 'pass' (issue #29)." >&2
        return 4
      fi
      ;;
    inferential)
      if [ -z "$v_agent" ]; then
        echo "Error: sensor file '${sensor_file}' is type 'inferential' but missing 'agent:' (criterion '${criterion_for_error}')." >&2
        return 4
      fi
      if sensor_value_is_placeholder "$v_agent"; then
        echo "Error: sensor file '${sensor_file}' is type 'inferential' but 'agent:' is a placeholder ('${v_agent}') (criterion '${criterion_for_error}')." >&2
        echo "  Resolve the placeholder before invoking /yoke:implement; the convergence rule treats placeholders as 'skip', not 'pass' (issue #29)." >&2
        return 4
      fi
      ;;
    *)
      echo "Error: sensor file '${sensor_file}' has invalid type '${v_type}' (expected computational|inferential)." >&2
      return 4
      ;;
  esac

  if [ -z "$v_token" ]; then v_token=0; fi
  if [ -z "$v_time" ]; then v_time=30; fi

  sensor_meta_type[$id]="$v_type"
  sensor_meta_token_cost[$id]="$v_token"
  sensor_meta_time_cost[$id]="$v_time"
  sensor_meta_command[$id]="${v_command:-}"
  sensor_meta_agent[$id]="${v_agent:-}"
  return 0
}

# --- contract parser: collect (criterion, sensor) pairs --------------------
# For new-shape contracts: each `### Criterion <id>` followed by `###
# Validation` collects bullets `- **<sensor-id>** — <interpretation>`.
# Scenario blocks' `Sensors:` lines also count. For legacy-registry:
# extract registry ids and `Sensors: [...]` references.
#
# Output (stdout, one line per pair):
#   <criterion-id>|<sensor-id>
parse_new_shape_pairs() {
  awk '
    function emit(crit, ids,    n, arr, i, v) {
      n = split(ids, arr, ",")
      for (i = 1; i <= n; i++) {
        v = arr[i]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        if (v != "") print crit "|" v
      }
    }

    /^### Scenario / {
      # Extract `Scenario N` token (first two whitespace-separated bits).
      heading = $0
      sub(/^###[[:space:]]+/, "", heading)
      n = split(heading, parts, /[[:space:]]+/)
      current_crit = parts[1] " " parts[2]
      in_validation = 0
      next
    }
    /^### Criterion / {
      heading = $0
      sub(/^###[[:space:]]+Criterion[[:space:]]+/, "", heading)
      sub(/[[:space:]]*—.*$/, "", heading)
      sub(/[[:space:]]+$/, "", heading)
      current_crit = heading
      in_validation = 0
      next
    }
    /^### Validation[[:space:]]*$/ {
      in_validation = 1
      next
    }
    /^##[[:space:]]/ || /^###[[:space:]]/ {
      in_validation = 0
    }
    in_validation && /^[[:space:]]*-[[:space:]]+\*\*[a-z0-9][a-z0-9._-]*\*\*/ {
      match($0, /\*\*[a-z0-9][a-z0-9._-]*\*\*/)
      if (RSTART > 0) {
        sid = substr($0, RSTART + 2, RLENGTH - 4)
        if (current_crit != "") print current_crit "|" sid
      }
    }
    /^Sensors:[[:space:]]*\[/ {
      raw = $0
      sub(/^Sensors:[[:space:]]*\[/, "", raw)
      sub(/\][[:space:]]*$/, "", raw)
      if (current_crit != "") emit(current_crit, raw)
    }
  ' "$contract"
}

parse_legacy_registry_pairs() {
  # Build (criterion, sensor) pairs from `Sensors: [a, b]` lines under
  # `### Scenario <N>` headings. Sensor ids without a scenario fall
  # under criterion `__registry__` (run unconditionally when no
  # --criterion filter is set).
  awk '
    function emit(crit, ids,    n, arr, i, v) {
      n = split(ids, arr, ",")
      for (i = 1; i <= n; i++) {
        v = arr[i]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        if (v != "") print crit "|" v
      }
    }
    /^### Scenario / {
      heading = $0
      sub(/^###[[:space:]]+/, "", heading)
      n = split(heading, parts, /[[:space:]]+/)
      current_crit = parts[1] " " parts[2]
      next
    }
    /^Sensors:[[:space:]]*\[/ {
      raw = $0
      sub(/^Sensors:[[:space:]]*\[/, "", raw)
      sub(/\][[:space:]]*$/, "", raw)
      if (current_crit == "") current_crit = "__registry__"
      emit(current_crit, raw)
    }
  ' "$contract"

  # Also include FR-style references: "Sensor: name." and
  # "Sensors: \`...\`, \`...\`" inside FR bullets, attaching to the
  # `FR-<id>` criterion.
  awk '
    /^-[[:space:]]+\[[ x]\][[:space:]]+\*\*FR-[0-9]+\*\*/ {
      crit_match = $0
      match(crit_match, /\*\*FR-[0-9]+\*\*/)
      if (RSTART > 0) {
        crit = substr(crit_match, RSTART + 2, RLENGTH - 4)
        rest = $0
        # Extract `Sensor: name.` (single).
        if (match(rest, /Sensor:[[:space:]]*[^[:space:].]+\.?/)) {
          tok = substr(rest, RSTART, RLENGTH)
          sub(/^Sensor:[[:space:]]*/, "", tok)
          sub(/\.[[:space:]]*$/, "", tok)
          if (tok != "") print crit "|" tok
        }
        # Extract `Sensors: a, b, c.` (multi).
        if (match(rest, /Sensors:[[:space:]]*[^.]+\./)) {
          tok = substr(rest, RSTART, RLENGTH)
          sub(/^Sensors:[[:space:]]*/, "", tok)
          sub(/\.[[:space:]]*$/, "", tok)
          n = split(tok, arr, ",")
          for (i = 1; i <= n; i++) {
            v = arr[i]
            gsub(/^[[:space:]`]+|[[:space:]`]+$/, "", v)
            if (v != "") print crit "|" v
          }
        }
      }
    }
  ' "$contract"
}

parse_legacy_inline_pairs() {
  # Parse pre-cost-tiering shape: `## Sensors > ### Computational` with
  # inline `- name: `cmd`` bullets. Each bullet emits a (criterion, sensor)
  # pair under criterion `__registry__` (run unconditionally when no
  # --criterion filter is set). The command string is captured inline and
  # injected into sensor_meta_command directly — no per-sensor file lookup
  # needed for this format.
  awk '
    /^## Sensors[[:space:]]*$/ { in_sensors = 1; next }
    /^## / && !/^## Sensors[[:space:]]*$/ { in_sensors = 0 }
    in_sensors && /^### Computational[[:space:]]*$/ { in_comp = 1; next }
    in_sensors && /^### / && !/^### Computational[[:space:]]*$/ { in_comp = 0 }
    in_sensors && in_comp && /^-[[:space:]]+/ {
      line = $0
      sub(/^-[[:space:]]+/, "", line)
      # name: `cmd`
      colon = index(line, ":")
      if (colon == 0) next
      name = substr(line, 1, colon - 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      rest = substr(line, colon + 1)
      gsub(/^[[:space:]]+/, "", rest)
      # Strip surrounding backticks if present.
      if (rest ~ /^`/) {
        sub(/^`/, "", rest)
        sub(/`[[:space:]]*$/, "", rest)
      }
      print "__registry__|" name "|" rest
    }
  ' "$contract"
}

if [ "$contract_format" = "new" ]; then
  pairs_raw="$(parse_new_shape_pairs | sort -u)"
elif [ "$contract_format" = "legacy-inline" ]; then
  # Format C: seed sensor_meta_command from inline `- name: `cmd`` bullets,
  # AND collect (criterion, sensor) pairs from the same `### Scenario`/FR
  # parser used by legacy-registry — that way --criterion filtering works
  # against the scenario set rather than just the catalog.
  while IFS='|' read -r crit sid cmd; do
    [ -z "$sid" ] && continue
    sensor_meta_type[$sid]="computational"
    sensor_meta_token_cost[$sid]="0"
    sensor_meta_time_cost[$sid]="30"
    sensor_meta_command[$sid]="$cmd"
  done < <(parse_legacy_inline_pairs | sort -u)
  scenario_pairs="$(parse_legacy_registry_pairs | sort -u)"
  if [ -n "$scenario_pairs" ]; then
    pairs_raw="$scenario_pairs"
  else
    pairs_raw="$(parse_legacy_inline_pairs | awk -F'|' '{ print $1 "|" $2 }' | sort -u)"
  fi
else
  pairs_raw="$(parse_legacy_registry_pairs | sort -u)"
fi

# Apply --criterion filter.
if [ -n "$filter_criterion" ]; then
  pairs_filtered=$(printf '%s\n' "$pairs_raw" | awk -F'|' -v c="$filter_criterion" '$1 == c { print }')
  pairs_raw="$pairs_filtered"
fi

# Build sensor list (dedup ids; preserve criterion association for verdict
# persistence).
sensor_ids=()
declare -A sensor_to_criterion=()
if [ -n "$pairs_raw" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    crit="${line%%|*}"
    sid="${line#*|}"
    if [ -z "${sensor_to_criterion[$sid]:-}" ]; then
      sensor_to_criterion[$sid]="$crit"
      sensor_ids+=("$sid")
    fi
  done <<< "$pairs_raw"
fi

# --- load metadata + apply cost filters ------------------------------------
# For format C ("legacy-inline"), sensor metadata was seeded inline from the
# contract above; the per-sensor file lookup is skipped to preserve the
# pre-cost-tiering behavior the legacy fixtures rely on.
filtered_ids=()
for sid in "${sensor_ids[@]}"; do
  crit="${sensor_to_criterion[$sid]:-<unspecified>}"
  if [ "$contract_format" != "legacy-inline" ]; then
    if ! load_sensor_metadata "$sid" "$crit"; then
      exit 4
    fi
  fi
  if [ -n "$max_time_cost" ] && [ "${sensor_meta_time_cost[$sid]:-0}" -gt "$max_time_cost" ]; then
    continue
  fi
  if [ -n "$max_token_cost" ] && [ "${sensor_meta_token_cost[$sid]:-0}" -gt "$max_token_cost" ]; then
    continue
  fi
  filtered_ids+=("$sid")
done

# --- per-sensor execution ---------------------------------------------------
# Computational: shell `bash -c "$command"`.
# Inferential: emit a Task spawn envelope (metadata + verdict path); the
# coordinator (skills/implement/SKILL.md) is responsible for the actual
# Agent spawn. This hook persists a placeholder verdict file with status
# `skip` and reason `awaiting-coordinator-spawn` if the file is missing
# at output time, so downstream parsers always find a verdict file.

run_one_sensor() {
  local sensor_name="$1"
  local fragment_file="$2"
  local sensor_type="${sensor_meta_type[$sensor_name]:-}"
  local command_str="${sensor_meta_command[$sensor_name]:-}"
  local agent_id="${sensor_meta_agent[$sensor_name]:-}"
  local criterion="${sensor_to_criterion[$sensor_name]:-__registry__}"

  local status="" exit_code=-1 output_excerpt="" reason="" sensor_output=""

  if [ "$sensor_type" = "computational" ]; then
    if [ -z "$command_str" ]; then
      status="skip"
      reason="missing command for computational sensor"
    else
      local leading_bin
      leading_bin=$(echo "$command_str" | awk '{print $1}')
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
    fi
  elif [ "$sensor_type" = "inferential" ]; then
    # Persist a placeholder verdict to the deterministic location.
    # The coordinator (skills/implement/SKILL.md) may overwrite this
    # at spawn time with the judge's actual output (lag-by-one model:
    # cycle N spawns, cycle N+1 reads). Until the coordinator runs
    # the agent, the placeholder is the verdict — its `status: skip`
    # signals the lag explicitly to the Validator.
    local cycle_n verdict_dir verdict_path
    cycle_n=0
    if [ -f "$(wm_cycle_counter_path)" ]; then
      cycle_n="$(tr -d '[:space:]' < "$(wm_cycle_counter_path)" 2>/dev/null || echo 0)"
    fi
    verdict_dir="$(wm_runtime_dir)/.judge-verdicts/cycle-${cycle_n}"
    mkdir -p "$verdict_dir"
    local safe_crit safe_sensor
    safe_crit="${criterion//[^A-Za-z0-9_.-]/_}"
    safe_sensor="${sensor_name//[^A-Za-z0-9_.-]/_}"
    verdict_path="${verdict_dir}/${safe_crit}-${safe_sensor}.json"
    if [ ! -f "$verdict_path" ]; then
      cat > "$verdict_path" <<JSON
{
  "criterion": "${criterion}",
  "sensor": "${sensor_name}",
  "status": "skip",
  "location": null,
  "fix_instruction": "spawn agent '${agent_id}' to produce a real verdict",
  "evidence": "placeholder verdict written by hooks/verify-acceptance.sh inferential dispatch",
  "confidence": 0.0,
  "supporting_quotes": []
}
JSON
    fi
    status="skip"
    reason="inferential sensor pending Task spawn (agent=${agent_id}, verdict=${verdict_path})"
    output_excerpt="agent=${agent_id} verdict_path=${verdict_path}"
    command_str="agent:${agent_id}"
  else
    status="skip"
    reason="unknown sensor type '${sensor_type}'"
  fi

  # Inline YAML escape
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

safe_filename() {
  echo "$1" | tr -c '[:alnum:]_.-' '_'
}

if [ "${#filtered_ids[@]}" -gt 0 ]; then
  # Parallel execution via xargs -P when --concurrency > 1 (cost-tiering
  # parity for legacy fixtures that assert wall-clock speedup). Inferential
  # dispatch persists verdicts into per-(criterion,sensor) JSON files, so
  # parallel writes are collision-free across the shared directory.
  export contract_format
  export -A sensor_meta_type sensor_meta_command sensor_meta_agent sensor_meta_token_cost sensor_meta_time_cost sensor_to_criterion 2>/dev/null || true
  if [ "$concurrency" -gt 1 ]; then
    run_one_sensor_xargs() {
      local sid="$1"
      local fragment_file="${fragments_dir}/$(safe_filename "$sid").yaml"
      run_one_sensor "$sid" "$fragment_file"
    }
    export -f run_one_sensor run_one_sensor_xargs safe_filename
    # Pass associative arrays via a deterministic-named temp env file
    # because bash export -A is not portable across subshells. Instead,
    # have each subshell re-source the metadata from sensor files (new
    # shape) or the inline registry (format C) — but the parent already
    # populated the maps. Fall back to a simple foreach loop when xargs
    # cannot inherit associative arrays (which is always for bash).
    for sid in "${filtered_ids[@]}"; do
      fragment_file="${fragments_dir}/$(safe_filename "$sid").yaml"
      run_one_sensor "$sid" "$fragment_file" &
    done
    wait
  else
    for sid in "${filtered_ids[@]}"; do
      fragment_file="${fragments_dir}/$(safe_filename "$sid").yaml"
      run_one_sensor "$sid" "$fragment_file"
    done
  fi
fi

# --- merge fragments deterministically (alphabetical by sensor-id) ---------
echo "results:"
if [ -d "$fragments_dir" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    cat "$f"
  done < <(find "$fragments_dir" -maxdepth 1 -type f -name '*.yaml' 2>/dev/null | LC_ALL=C sort)
fi

exit 0
