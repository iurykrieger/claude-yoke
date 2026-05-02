#!/bin/bash
# agent-config.sh — per-role / per-mode model resolution for Yoke runtime.
#
# The /yoke:implement coordinator sources this helper at preflight, then
# passes the resolved `model: <id>` to every Task call when spawning the
# council persona subagents and the termination-time Orchestrator.
#
# v3.0 council protocol (Sprint 04 of the agent-council PRD): the
# legacy v2.x runtime role tokens (the binary-loop pair plus the two
# non-canonize orchestrator modes) are retired. The surviving role
# tokens are:
#
#   - council personas (sr-eng, sr-qa, sr-staff)              → inherit session model
#   - council-arbiter (contradiction-detection JSON verdict)  → inherit session model
#   - orchestrator.canonize (Model C governance writes)       → inherit session model
#   - default                                                  → inherit session model
#
# Personas inherit the session model by default — the council protocol
# relies on the parallel-persona richness, not on per-persona model
# pinning. Hosts that need to pin specific personas can override under
# `runtime.models.<role>` in `.yoke/config.yaml` (e.g.
# `runtime.models.sr-eng: claude-sonnet-4-6`).
#
# Resolution order for `yoke_resolve_model <role>`:
#   1. `.yoke/config.yaml` overrides under `runtime.models.<role>`
#      (or `runtime.models.orchestrator.<mode>` for orchestrator modes —
#      currently only `canonize` is recognized).
#   2. Built-in defaults (all empty in v3.0 — every recognized role
#      inherits the user's session model unless explicitly overridden).
#   3. Empty result means "do not pin; inherit the user's session model".
#
# Recognized roles (string arg to yoke_resolve_model):
#   sr-eng
#   sr-qa
#   sr-staff
#   council-arbiter
#   orchestrator.canonize
#   default
#
# Why per-mode pinning for orchestrator: canonize writes canonical memory
# under Model C governance — quality is king there. Downgrading the
# canonize call would erode governance judgment, so the default is to
# inherit the session model (top-tier).
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
    for role in sr-eng sr-qa sr-staff council-arbiter orchestrator.canonize; do
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
        sr-eng|sr-qa|sr-staff|council-arbiter|orchestrator.canonize|default)
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
#       <role>: <value>                        # for sr-eng|sr-qa|sr-staff|council-arbiter|default
#       orchestrator:
#         <mode>: <value>                      # for orchestrator.<mode> (currently only canonize)
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
