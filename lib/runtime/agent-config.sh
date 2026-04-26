#!/bin/bash
# agent-config.sh — per-role / per-mode model resolution for Yoke runtime.
#
# The /yoke:implement coordinator sources this helper at preflight, then
# passes the resolved `model: <id>` to every Task call when spawning the
# Generator, Validator, and Orchestrator subagents.
#
# Resolution order for `yoke_resolve_model <role>`:
#   1. `.yoke/config.yaml` overrides under `runtime.models.<role>`
#      (or `runtime.models.orchestrator.<mode>` for orchestrator modes).
#   2. Built-in defaults:
#        - validator                   → claude-sonnet-4-6
#        - orchestrator.consult        → claude-sonnet-4-6
#        - orchestrator.monitor        → claude-sonnet-4-6
#        - generator                   → "" (inherit session model)
#        - orchestrator.canonize       → "" (inherit session model)
#        - default                     → "" (inherit session model)
#   3. Empty result means "do not pin; inherit the user's session model".
#
# Recognized roles (string arg to yoke_resolve_model):
#   generator
#   validator
#   orchestrator.consult
#   orchestrator.monitor
#   orchestrator.canonize
#   default
#
# Why per-mode pinning for orchestrator: canonize writes canonical memory
# under Model C governance — quality is king there. Consult/monitor are
# retrieval + filter operations whose output is structurally bounded
# (subgraph excerpts, divergence flags), so a smaller model is safe.
#
# Idempotent re-source guard.
if [[ -n "${_YOKE_AGENT_CONFIG_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly _YOKE_AGENT_CONFIG_LOADED=1

# Default config path; callers may pass a second argument to override.
readonly _YOKE_DEFAULT_CONFIG=".yoke/config.yaml"

# --- public API -------------------------------------------------------------

# yoke_resolve_model <role> [<config-path>]
#   Echoes the resolved model identifier (or empty string). Never errors.
yoke_resolve_model() {
    local role="${1:-}"
    local config="${2:-${_YOKE_DEFAULT_CONFIG}}"
    local val=""

    if [[ -z "$role" ]]; then
        printf ''
        return 0
    fi

    if [[ -f "$config" ]]; then
        val=$(_yoke_yaml_lookup_model "$role" "$config")
    fi

    if [[ -z "$val" ]]; then
        val=$(_yoke_default_model "$role")
    fi

    # Strip surrounding quotes (single or double) and any trailing comment.
    val="${val#\"}"
    val="${val%\"}"
    val="${val#\'}"
    val="${val%\'}"
    printf '%s' "$val"
}

# yoke_log_resolved_models <log-path> [<config-path>]
#   Appends one `[task-spawn] role=<r> model=<m>` line per recognized
#   role to <log-path> for provenance. Append-only; safe across cycles.
#   Default coordinator location: `$(wm_runtime_dir)/.task-spawn-log`.
yoke_log_resolved_models() {
    local log_path="${1:-}"
    local config="${2:-${_YOKE_DEFAULT_CONFIG}}"

    if [[ -z "$log_path" ]]; then
        return 0
    fi

    mkdir -p "$(dirname "$log_path")"

    local role val
    for role in generator validator orchestrator.consult orchestrator.monitor orchestrator.canonize; do
        val="$(yoke_resolve_model "$role" "$config")"
        if [[ -z "$val" ]]; then
            val="<inherit-session>"
        fi
        printf '[task-spawn] role=%s model=%s\n' "$role" "$val" >> "$log_path"
    done
}

# --- internals --------------------------------------------------------------

_yoke_default_model() {
    local role="$1"
    case "$role" in
        validator|orchestrator.consult|orchestrator.monitor)
            printf 'claude-sonnet-4-6'
            ;;
        generator|orchestrator.canonize|default)
            printf ''
            ;;
        *)
            printf ''
            ;;
    esac
}

# Reads a value from runtime.models.<role> in the given YAML config.
# Supports two shapes:
#   runtime:
#     models:
#       <role>: <value>                        # for generator|validator|default
#       orchestrator:
#         <mode>: <value>                      # for orchestrator.<mode>
_yoke_yaml_lookup_model() {
    local role="$1" file="$2"

    if [[ "$role" == orchestrator.* ]]; then
        local submode="${role#orchestrator.}"
        awk -v sub_key="$submode" '
            /^runtime:[[:space:]]*$/                    { in_rt = 1; next }
            in_rt && /^[A-Za-z_]/                       { exit }
            in_rt && /^[[:space:]]{2}models:[[:space:]]*$/ { in_m = 1; next }
            in_m && /^[[:space:]]{2}[A-Za-z_-]+:/        { in_m = 0 }
            in_m && /^[[:space:]]{4}orchestrator:[[:space:]]*$/ { in_o = 1; next }
            in_m && /^[[:space:]]{4}[A-Za-z_-]+:/        { in_o = 0 }
            in_m && in_o && /^[[:space:]]{6}[A-Za-z_.-]+:/ {
                line = $0
                sub(/^[[:space:]]+/, "", line)
                if (substr(line, 1, length(sub_key)+1) == sub_key ":") {
                    sub(/^[^:]+:[[:space:]]*/, "", line)
                    sub(/[[:space:]]*#.*$/, "", line)
                    sub(/[[:space:]]+$/, "", line)
                    print line
                    exit
                }
            }
        ' "$file"
    else
        awk -v key="$role" '
            /^runtime:[[:space:]]*$/                    { in_rt = 1; next }
            in_rt && /^[A-Za-z_]/                       { exit }
            in_rt && /^[[:space:]]{2}models:[[:space:]]*$/ { in_m = 1; next }
            in_m && /^[[:space:]]{2}[A-Za-z_-]+:/        { in_m = 0 }
            in_m && /^[[:space:]]{4}[A-Za-z_.-]+:/ {
                line = $0
                sub(/^[[:space:]]+/, "", line)
                if (substr(line, 1, length(key)+1) == key ":") {
                    sub(/^[^:]+:[[:space:]]*/, "", line)
                    sub(/[[:space:]]*#.*$/, "", line)
                    sub(/[[:space:]]+$/, "", line)
                    print line
                    exit
                }
            }
        ' "$file"
    fi
}
