#!/bin/bash
# host-actor.sh — host-project actor name resolution from .yoke/config.yaml.
#
# Sourced by lib/canonical-memory/write-promoted-concept.sh and any other
# code path that needs to resolve the canonical actor name for the host
# project (the actor that promoted concepts will hang `applies_to:` to and
# bidirectionally backlink from).
#
# Single helper:
#
#   wm_host_actor_name [<config-path>]
#       Echoes the canonical actor name for the host project.
#
#       Resolution order:
#         1. `host.actor_name` field in <config-path> (default
#            .yoke/config.yaml) — honored verbatim if present.
#         2. Default = kebab-case of `host.project_name` (same file).
#         3. If neither field is set, derive from the basename of the
#            current working directory (kebab-cased), and write the
#            derived value back into the config file as `host.actor_name`
#            so future reads are stable. First-use seeding is idempotent.
#
#       The helper writes the default into config on first use only —
#       if `host.actor_name` is already set (even to the same value),
#       it is honored verbatim with no write. The user can hand-edit
#       the field at any time; subsequent runs honor that edit.
#
# Source PRD/Spec:
#   .yoke/prds/2026-04-27-sprint-contract-promotion.md
#   .yoke/specs/2026-04-27-sprint-contract-promotion.md (s01-t03)
#   .yoke/acceptance-contracts/2026-04-27-sprint-contract-promotion.md
#       (Scenario 3 — `host.actor_name` resolution)
#
# Error contract: failures emit "wm: <message>" to stderr and return non-zero.
# Callers should run with `set -euo pipefail` to honor failures.

# Idempotent re-source guard.
if [[ -n "${_WM_HOST_ACTOR_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly _WM_HOST_ACTOR_LOADED=1

# Default config path — overridable per-call.
_WM_HOST_ACTOR_DEFAULT_CONFIG=".yoke/config.yaml"

# _wm_host_actor_kebab <string>
#   Echoes a kebab-cased lowercase version of <string>: ASCII alnum runs
#   joined by `-`, leading/trailing `-` stripped. Mirrors the conventional
#   kebab transform used by /yoke:bootstrap and slug producers elsewhere
#   in the framework.
_wm_host_actor_kebab() {
    local s="${1:-}"
    [[ -n "$s" ]] || return 0
    # Lowercase, replace runs of non-alnum with single `-`, strip edges.
    printf '%s' "$s" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -e 's/[^a-z0-9]\{1,\}/-/g' \
              -e 's/^-//' \
              -e 's/-$//'
}

# _wm_host_actor_read_field <config-path> <field>
#   Reads a top-level dotted field from a flat YAML file. Supports the
#   `host.<field>` shape we need: `host:` block at column 0 with a
#   `  <field>: "<value>"` (quoted) or `  <field>: <value>` (bare) child.
#   Echoes the value with quotes stripped, or empty if the field is
#   absent. This is intentionally minimal — no full YAML parser is
#   pulled in (matches the rest of yoke's bash-only style).
_wm_host_actor_read_field() {
    local config="$1"
    local field="$2"
    [[ -f "$config" ]] || return 0
    awk -v field="$field" '
        BEGIN { in_host = 0 }
        /^host:[[:space:]]*$/ { in_host = 1; next }
        # Any other top-level key closes the host block.
        /^[^[:space:]#]/ { in_host = 0 }
        in_host == 1 {
            line = $0
            # Match `  <field>:` (allow leading whitespace).
            sub(/^[[:space:]]+/, "", line)
            if (index(line, field ":") == 1) {
                v = substr(line, length(field) + 2)
                sub(/^[[:space:]]+/, "", v)
                # Strip surrounding double or single quotes.
                if (v ~ /^".*"$/) v = substr(v, 2, length(v) - 2)
                else if (v ~ /^.*$/) {
                    if (substr(v, 1, 1) == "\x27" && substr(v, length(v), 1) == "\x27") {
                        v = substr(v, 2, length(v) - 2)
                    }
                }
                print v
                exit
            }
        }
    ' "$config"
}

# _wm_host_actor_write_default <config-path> <actor-name>
#   Idempotently sets `host.actor_name: "<actor-name>"` inside the config
#   file. If the file is missing, creates it with a minimal `host:` block.
#   If a `host:` block exists without `actor_name`, appends the field at
#   the end of the block. If `host.actor_name` already exists, this
#   function is a no-op (caller verifies absence first).
_wm_host_actor_write_default() {
    local config="$1"
    local actor="$2"
    local config_dir
    config_dir="$(dirname "$config")"
    mkdir -p "$config_dir"

    if [[ ! -f "$config" ]]; then
        cat > "$config" <<EOF
# .yoke/config.yaml — Yoke configuration for this project
# Auto-seeded by lib/working-memory/host-actor.sh::wm_host_actor_name
# on first use. Hand-edit the host.actor_name field below to override.

host:
  actor_name: "${actor}"
EOF
        return 0
    fi

    # File exists. If it already has a `host:` block, append actor_name
    # under it (after the last `host:`-block child line). Else append a
    # fresh `host:` block at the bottom.
    if grep -q '^host:[[:space:]]*$' "$config"; then
        # Insert `  actor_name: "<actor>"` immediately after the `host:` line.
        # Use awk to build a new file atomically.
        local tmp
        tmp="$(mktemp)"
        awk -v actor="$actor" '
            BEGIN { inserted = 0 }
            /^host:[[:space:]]*$/ {
                print
                print "  actor_name: \"" actor "\""
                inserted = 1
                next
            }
            { print }
        ' "$config" > "$tmp"
        mv "$tmp" "$config"
    else
        # Append a fresh host block at EOF.
        printf '\nhost:\n  actor_name: "%s"\n' "$actor" >> "$config"
    fi
}

# wm_host_actor_name [<config-path>]
#   Echoes the host-project's canonical actor name. See file header.
wm_host_actor_name() {
    local config="${1:-$_WM_HOST_ACTOR_DEFAULT_CONFIG}"

    # 1. honor host.actor_name verbatim if set
    local actor
    actor="$(_wm_host_actor_read_field "$config" "actor_name")"
    if [[ -n "$actor" ]]; then
        printf '%s' "$actor"
        return 0
    fi

    # 2. default = kebab-case of host.project_name
    local project_name
    project_name="$(_wm_host_actor_read_field "$config" "project_name")"
    if [[ -n "$project_name" ]]; then
        actor="$(_wm_host_actor_kebab "$project_name")"
    fi

    # 3. fallback: kebab-case of CWD basename
    if [[ -z "$actor" ]]; then
        actor="$(_wm_host_actor_kebab "$(basename "$PWD")")"
    fi

    if [[ -z "$actor" ]]; then
        echo "wm: wm_host_actor_name could not derive a host actor name (empty config and empty CWD basename)" >&2
        return 1
    fi

    # First-use seeding: write the derived default back into config.
    _wm_host_actor_write_default "$config" "$actor"
    printf '%s' "$actor"
}
