#!/bin/bash
# paths.sh — working-memory path resolution for the host project's .yoke/.
#
# Single source of truth for where every working-memory artifact lives on
# disk. Sourced by skills that need to read or write inside .yoke/.
#
# Layout (host project's .yoke/):
#   .yoke/
#   ├── config.yaml                                # versioned
#   ├── .gitignore                                 # versioned
#   ├── .current                                   # gitignored, per-worktree
#   ├── prds/<slug>.md                             # versioned archive
#   ├── specs/<slug>.md                            # versioned archive  (tech-spec-task-split sprint index)
#   ├── tasks/<slug>-s<NN>-t<MM>.md                # versioned archive  (tech-spec-task-split per-task body)
#   ├── acceptance-contracts/<slug>.md             # versioned archive
#   ├── contracts/<slug>.md                        # versioned archive
#   └── runtime/                                   # gitignored
#       ├── progress.md
#       ├── .cycle-counter
#       ├── .trigger4-packet.yaml
#       └── .snapshots/cycle-N.yaml
#
# Slug format: <YYYY-MM-DD>-<slug>, full filename (without .md) regex:
#   ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]{0,49}$
#
# Task-ID format (filename without .md inside tasks/):
#   <slug>-s<NN>-t<MM>, where <NN> and <MM> are 2-digit zero-padded
#   positive integers (sprint number / task-within-sprint number).
#   Padding makes lexical sort equal positional order.
#
# Error contract: failures emit "wm: <message>" to stderr and return non-zero.
# Callers should run with `set -euo pipefail` to honor failures.
#
# Usage:
#   source lib/working-memory/paths.sh
#   slug="$(wm_active_slug)"
#   prd="$(wm_prd_path "$slug")"
#   spec="$(wm_spec_path)"                  # uses active slug when no arg
#   t11="$(wm_task_path "$slug" 1 1)"       # .yoke/tasks/<slug>-s01-t01.md
#   wm_list_task_paths "$slug"              # one path per line, sorted

# Idempotent re-source guard.
if [[ -n "${_WM_PATHS_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly _WM_PATHS_LOADED=1

readonly WM_ROOT=".yoke"
readonly WM_CURRENT_FILE="${WM_ROOT}/.current"
readonly WM_RUNTIME_DIR="${WM_ROOT}/runtime"
readonly WM_SLUG_REGEX='^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]{0,49}$'
readonly WM_TASK_NUM_REGEX='^[1-9][0-9]{0,2}$'
readonly WM_ARCHIVE_CATEGORIES=(prds specs tasks acceptance-contracts contracts)

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
wm_spec_path()                 { _wm_archive_path "specs" "${1:-}"; }
wm_acceptance_contract_path()  { _wm_archive_path "acceptance-contracts" "${1:-}"; }
wm_contracts_path()            { _wm_archive_path "contracts" "${1:-}"; }

# wm_task_path "<slug>" <sprint> <task>
#   echoes .yoke/tasks/<slug>-s<NN>-t<MM>.md (zero-padded to 2 digits)
#   on success; emits a `wm:`-prefixed message and returns non-zero on
#   any of: missing/invalid slug, non-numeric sprint, non-numeric task,
#   sprint or task <= 0, sprint or task > 999.
wm_task_path() {
    local slug="${1:-}"
    local sprint="${2:-}"
    local task="${3:-}"
    if [[ -z "$slug" ]]; then
        slug="$(wm_active_slug)" || return 1
    else
        wm_validate_slug "$slug" || return 1
    fi
    if [[ -z "$sprint" || -z "$task" ]]; then
        echo "wm: wm_task_path requires <slug> <sprint> <task>; got slug='$slug' sprint='$sprint' task='$task'" >&2
        return 1
    fi
    if [[ ! "$sprint" =~ $WM_TASK_NUM_REGEX ]]; then
        echo "wm: invalid sprint number: '$sprint' (expected positive integer 1..999)" >&2
        return 1
    fi
    if [[ ! "$task" =~ $WM_TASK_NUM_REGEX ]]; then
        echo "wm: invalid task number: '$task' (expected positive integer 1..999)" >&2
        return 1
    fi
    printf '%s/%s/%s-s%02d-t%02d.md' "$WM_ROOT" "tasks" "$slug" "$sprint" "$task"
}

# wm_list_task_paths "<slug>"
#   echoes one task-file path per line, lexically sorted (= positional
#   order via the s<NN>-t<MM> suffix). Empty output when the slug has
#   no task files. Exits non-zero only on slug-validation failure.
wm_list_task_paths() {
    local slug="${1:-}"
    if [[ -z "$slug" ]]; then
        slug="$(wm_active_slug)" || return 1
    else
        wm_validate_slug "$slug" || return 1
    fi
    local tasks_dir="${WM_ROOT}/tasks"
    [[ -d "$tasks_dir" ]] || return 0
    (
        shopt -s nullglob
        local f
        for f in "${tasks_dir}/${slug}"-s*-t*.md; do
            printf '%s\n' "$f"
        done
    ) | sort
}

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

# wm_judge_verdict_dir "<slug>" "<cycle>"
#   echoes .yoke/runtime/.judge-verdicts/cycle-<N>/ for the given cycle.
#   Inferential-sensor verdicts written by semantic-judge agents spawned
#   by /yoke:implement live here, one JSON file per criterion. The
#   Validator reads from cycle <N-1> (Model A lag-by-one).
wm_judge_verdict_dir() {
    local slug="${1:-}"
    local cycle="${2:-}"
    if [[ -z "$slug" ]]; then
        slug="$(wm_active_slug)" || return 1
    else
        wm_validate_slug "$slug" || return 1
    fi
    if [[ -z "$cycle" || ! "$cycle" =~ ^[0-9]+$ ]]; then
        echo "wm: wm_judge_verdict_dir requires <slug> <cycle> (non-negative integer); got slug='$slug' cycle='$cycle'" >&2
        return 1
    fi
    printf '%s/.judge-verdicts/cycle-%d' "$WM_RUNTIME_DIR" "$cycle"
}

# wm_judge_verdict_path "<slug>" "<cycle>" "<criterion-id>" "<sensor-id>"
#   echoes .yoke/runtime/.judge-verdicts/cycle-<N>/<criterion>--<sensor>.json
#   for the given (criterion, sensor) pairing. /yoke:implement passes
#   this path to each spawned judge as the verdict-output target;
#   the Validator reads cycle <N-1>'s files in cycle <N>.
#
# Why criterion + sensor (not criterion alone): patterns/sensors.md's
# "Any-fail-wins aggregation" rule supports multiple inferential
# sensors mapping to the same Acceptance Contract criterion. Keying
# verdict files by criterion only would collide; pairing-keyed
# filenames preserve every judge's verdict.
#
# Sanitization: a sensor id may contain `/` (e.g. `semantic-judge/voice`)
# or other path-illegal characters; this helper rewrites every
# non-`[A-Za-z0-9_.-]` byte to `_` so the basename is always safe.
wm_judge_verdict_path() {
    local slug="${1:-}"
    local cycle="${2:-}"
    local criterion="${3:-}"
    local sensor="${4:-}"
    if [[ -z "$criterion" || -z "$sensor" ]]; then
        echo "wm: wm_judge_verdict_path requires <slug> <cycle> <criterion-id> <sensor-id>; got criterion='$criterion' sensor='$sensor'" >&2
        return 1
    fi
    local dir
    dir="$(wm_judge_verdict_dir "$slug" "$cycle")" || return 1
    local safe_criterion safe_sensor
    safe_criterion="${criterion//[^A-Za-z0-9_.-]/_}"
    safe_sensor="${sensor//[^A-Za-z0-9_.-]/_}"
    printf '%s/%s--%s.json' "$dir" "$safe_criterion" "$safe_sensor"
}

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
