#!/bin/bash
# paths.sh — working-memory path resolution for the host project's .yoke/.
#
# Single source of truth for where every working-memory artifact lives on
# disk. Sourced by skills that need to read or write inside .yoke/.
#
# Layout (host project's .yoke/):
#   .yoke/
#   ├── config.yaml                          # versioned
#   ├── .gitignore                           # versioned
#   ├── .current                             # gitignored, per-worktree
#   ├── prds/<slug>.md                       # versioned archive
#   ├── tech-specs/<slug>.md                 # versioned archive
#   ├── acceptance-contracts/<slug>.md       # versioned archive
#   ├── contracts/<slug>.md                  # versioned archive
#   ├── query-traces/<slug>.md               # versioned archive
#   └── runtime/                             # gitignored
#       ├── progress.md
#       ├── .cycle-counter
#       ├── .trigger4-packet.yaml
#       └── .snapshots/cycle-N.yaml
#
# Slug format: <YYYY-MM-DD>-<slug>, full filename (without .md) regex:
#   ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]{0,49}$
#
# Error contract: failures emit "wm: <message>" to stderr and return non-zero.
# Callers should run with `set -euo pipefail` to honor failures.
#
# Usage:
#   source lib/working-memory/paths.sh
#   slug="$(wm_active_slug)"
#   prd="$(wm_prd_path "$slug")"
#   tech="$(wm_tech_spec_path)"            # uses active slug when no arg

# Idempotent re-source guard.
if [[ -n "${_WM_PATHS_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly _WM_PATHS_LOADED=1

readonly WM_ROOT=".yoke"
readonly WM_CURRENT_FILE="${WM_ROOT}/.current"
readonly WM_RUNTIME_DIR="${WM_ROOT}/runtime"
readonly WM_SLUG_REGEX='^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]{0,49}$'
readonly WM_ARCHIVE_CATEGORIES=(prds tech-specs acceptance-contracts contracts query-traces)

# --- slug validation --------------------------------------------------------

wm_validate_slug() {
    local slug="${1:-}"
    if [[ "$slug" =~ $WM_SLUG_REGEX ]]; then
        return 0
    fi
    echo "wm: invalid slug: '$slug' (expected <YYYY-MM-DD>-<kebab-slug>, ≤50 chars after the date prefix)" >&2
    return 1
}

# --- active-task pointer ----------------------------------------------------

wm_active_slug() {
    if [[ ! -f "$WM_CURRENT_FILE" ]]; then
        echo "wm: no active task; run \`/yoke:discover\` first" >&2
        return 1
    fi
    local slug
    slug="$(tr -d '[:space:]' < "$WM_CURRENT_FILE")"
    wm_validate_slug "$slug" || return 1
    printf '%s' "$slug"
}

wm_set_active() {
    local slug="${1:-}"
    wm_validate_slug "$slug" || return 1
    mkdir -p "$WM_ROOT"
    printf '%s' "$slug" > "$WM_CURRENT_FILE"
}

wm_clear_active() {
    rm -f "$WM_CURRENT_FILE"
}

# --- archive paths ----------------------------------------------------------

_wm_archive_path() {
    local category="$1"
    local slug="${2:-}"
    if [[ -z "$slug" ]]; then
        slug="$(wm_active_slug)" || return 1
    else
        wm_validate_slug "$slug" || return 1
    fi
    printf '%s/%s/%s.md' "$WM_ROOT" "$category" "$slug"
}

wm_prd_path()                  { _wm_archive_path "prds" "${1:-}"; }
wm_tech_spec_path()            { _wm_archive_path "tech-specs" "${1:-}"; }
wm_acceptance_contract_path()  { _wm_archive_path "acceptance-contracts" "${1:-}"; }
wm_contracts_path()            { _wm_archive_path "contracts" "${1:-}"; }
wm_query_trace_path()          { _wm_archive_path "query-traces" "${1:-}"; }

# --- collision detection ----------------------------------------------------

# Returns 0 if any archive category contains <slug>.md; 1 if free or empty.
# Does not validate the slug — pair with wm_validate_slug at the boundary.
wm_slug_in_use() {
    local slug="${1:-}"
    [[ -n "$slug" ]] || return 1
    local cat
    for cat in "${WM_ARCHIVE_CATEGORIES[@]}"; do
        if [[ -e "${WM_ROOT}/${cat}/${slug}.md" ]]; then
            return 0
        fi
    done
    return 1
}

# --- runtime paths ----------------------------------------------------------

wm_runtime_dir()           { printf '%s' "$WM_RUNTIME_DIR"; }
wm_progress_path()         { printf '%s/progress.md' "$WM_RUNTIME_DIR"; }
wm_cycle_counter_path()    { printf '%s/.cycle-counter' "$WM_RUNTIME_DIR"; }
wm_snapshots_dir()         { printf '%s/.snapshots' "$WM_RUNTIME_DIR"; }
wm_trigger4_packet_path()  { printf '%s/.trigger4-packet.yaml' "$WM_RUNTIME_DIR"; }

# --- runtime wipe -----------------------------------------------------------

# Removes the contents of .yoke/runtime/ but keeps the directory itself.
# Idempotent: creates the directory if absent.
wm_wipe_runtime() {
    if [[ -d "$WM_RUNTIME_DIR" ]]; then
        find "$WM_RUNTIME_DIR" -mindepth 1 -delete
    else
        mkdir -p "$WM_RUNTIME_DIR"
    fi
}

# --- listing ----------------------------------------------------------------

# Echoes one slug per line, sorted lexically (= chronologically because of
# the date prefix). Empty output when no archived tasks exist.
wm_list_archived_slugs() {
    local prds_dir="${WM_ROOT}/prds"
    [[ -d "$prds_dir" ]] || return 0
    (
        shopt -s nullglob
        local f
        for f in "$prds_dir"/*.md; do
            basename "$f" .md
        done
    ) | sort
}
