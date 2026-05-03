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
#   ├── prds/<slug>.md                             # versioned archive
#   ├── specs/<slug>.md                            # versioned archive  (cross-sprint architecture index)
#   ├── sprints/<slug>-s<NN>.md                    # versioned archive  (sprint-as-cycle per-sprint runtime bundle)
#   ├── acceptance-criteria/<slug>.md              # versioned archive  (v4.0.0 cutover from acceptance-contracts/)
#   ├── acceptance-contracts/<slug>.md             # legacy versioned archive (frozen historical files post v4.0.0; no helper resolves it)
#   ├── contracts/<slug>.md                        # versioned archive  (sprint contracts, runtime refinements)
#   ├── sensors/<sensor-id>.md                     # versioned archive  (project-scoped; not slug-keyed)
#   └── runtime/                                   # gitignored
#       ├── .current                               # per-worktree active-task pointer
#       ├── progress.md
#       ├── .cycle-counter
#       ├── .trigger4-packet.yaml
#       └── .snapshots/cycle-N.yaml
#
# Slug format: <YYYY-MM-DD>-<slug>, full filename (without .md) regex:
#   ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]{0,49}$
#
# Sprint-ID format (filename without .md inside sprints/):
#   <slug>-s<NN>, where <NN> is a 2-digit zero-padded positive integer
#   (sprint number 01..99). Padding makes lexical sort equal positional
#   order in `wm_list_sprint_paths`. Per the sprint-as-cycle PRD, sprint
#   files are runtime bundles consumed one-per-cycle by the ralph loop;
#   tasks-as-files were retired in sprint 4 of that PRD (the wm_task_*
#   helpers and the `tasks` archive category were hard-removed; tasks
#   now live as `### Task <ID>` anchors inside sprint files, not
#   standalone files).
#
# Error contract: failures emit "wm: <message>" to stderr and return non-zero.
# Callers should run with `set -euo pipefail` to honor failures.
#
# Usage:
#   source lib/working-memory/paths.sh
#   slug="$(wm_active_slug)"
#   prd="$(wm_prd_path "$slug")"
#   spec="$(wm_spec_path)"                  # uses active slug when no arg
#   s03="$(wm_sprint_path "$slug" 3)"       # .yoke/sprints/<slug>-s03.md
#   wm_list_sprint_paths "$slug"            # one sprint path per line, sorted

# Idempotent re-source guard.
if [[ -n "${_WM_PATHS_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly _WM_PATHS_LOADED=1

readonly WM_ROOT=".yoke"
readonly WM_RUNTIME_DIR="${WM_ROOT}/runtime"
readonly WM_CURRENT_FILE="${WM_RUNTIME_DIR}/.current"
readonly WM_SENSORS_DIR="${WM_ROOT}/sensors"
readonly WM_SLUG_REGEX='^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]{0,49}$'
# Sprint number range: 1..99 (zero-padded to 2 digits in filenames).
readonly WM_SPRINT_NUM_REGEX='^[1-9][0-9]?$'
# Sprint-ID regex: <slug>-s<NN> where <NN> is exactly 2 zero-padded digits.
# Padding to exactly 2 digits is what makes lexical sort equal positional
# order in wm_list_sprint_paths.
readonly WM_SPRINT_ID_REGEX='^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]{0,49}-s[0-9]{2}$'
# Sprint-as-cycle PRD: `tasks` was hard-removed in sprint 4; `sprints`
# is now the runtime-bundle archive category. Per-task files no longer
# exist on disk — tasks live as `### Task <ID>` anchors inside sprint
# files.
readonly WM_ARCHIVE_CATEGORIES=(prds specs sprints acceptance-criteria acceptance-contracts contracts)

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
    mkdir -p "$WM_RUNTIME_DIR"
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
wm_acceptance_criteria_path()  { _wm_archive_path "acceptance-criteria" "${1:-}"; }
wm_contracts_path()            { _wm_archive_path "contracts" "${1:-}"; }

# wm_acceptance_criteria_in_use "<slug>"
#   Returns 0 when .yoke/acceptance-criteria/<slug>.md exists, 1 otherwise.
#   Mirrors wm_slug_in_use's predicate shape, scoped to the AC archive.
wm_acceptance_criteria_in_use() {
    local slug="${1:-}"
    [[ -n "$slug" ]] || { wm_violation "wm_acceptance_criteria_in_use requires <slug>"; return 2; }
    local path
    path="$(wm_acceptance_criteria_path "$slug")" || return 1
    [[ -f "$path" ]]
}

# --- sprint paths -----------------------------------------------------------
#
# Per the sprint-as-cycle PRD (.yoke/prds/2026-04-27-sprint-as-cycle.md), the
# runtime atom is a per-sprint runtime bundle under
# .yoke/sprints/<slug>-s<NN>.md consumed one-per-cycle by the ralph loop.
# Sprint 4 of that PRD hard-removed the legacy wm_task_* helpers and the
# `tasks` archive category; tasks now live as `### Task <ID>` anchors
# inside sprint files (no filename concern).
#
# Cites concepts/yoke-pattern-memory-model for the working-memory archive
# layout invariants and concepts/yoke-pattern-sprint-runtime-bundle (drafted
# in sprint 4's preserve packet of the sprint-as-cycle PRD) for the runtime
# bundle shape.

# wm_sprint_path "<slug>" <sprint>
#   echoes .yoke/sprints/<slug>-s<NN>.md (zero-padded to 2 digits) on
#   success; emits a `wm:`-prefixed message and returns non-zero on any
#   of: missing/invalid slug, non-numeric sprint, sprint <= 0, sprint > 99.
wm_sprint_path() {
    local slug="${1:-}"
    local sprint="${2:-}"
    if [[ -z "$slug" ]]; then
        slug="$(wm_active_slug)" || return 1
    else
        wm_validate_slug "$slug" || return 1
    fi
    if [[ -z "$sprint" ]]; then
        echo "wm: wm_sprint_path requires <slug> <sprint>; got slug='$slug' sprint=''" >&2
        return 1
    fi
    if [[ ! "$sprint" =~ $WM_SPRINT_NUM_REGEX ]]; then
        echo "wm: invalid sprint number: '$sprint' (expected positive integer 1..99)" >&2
        return 1
    fi
    printf '%s/%s/%s-s%02d.md' "$WM_ROOT" "sprints" "$slug" "$sprint"
}

# wm_list_sprint_paths "<slug>"
#   echoes one sprint-file path per line, lexically sorted (= positional
#   order via the s<NN> suffix). Empty output when the slug has no
#   sprint files. Exits non-zero only on slug-validation failure.
wm_list_sprint_paths() {
    local slug="${1:-}"
    if [[ -z "$slug" ]]; then
        slug="$(wm_active_slug)" || return 1
    else
        wm_validate_slug "$slug" || return 1
    fi
    local sprints_dir="${WM_ROOT}/sprints"
    [[ -d "$sprints_dir" ]] || return 0
    (
        shopt -s nullglob
        local f
        for f in "${sprints_dir}/${slug}"-s*.md; do
            printf '%s\n' "$f"
        done
    ) | sort
}

# wm_validate_sprint_id "<id>"
#   exits 0 if <id> matches WM_SPRINT_ID_REGEX (i.e. <slug>-s<NN> with
#   exactly 2 zero-padded digits in <NN>); exits non-zero with a
#   `wm:`-prefixed diagnostic otherwise.
wm_validate_sprint_id() {
    local id="${1:-}"
    if [[ "$id" =~ $WM_SPRINT_ID_REGEX ]]; then
        return 0
    fi
    echo "wm: invalid sprint id: '$id' (expected <YYYY-MM-DD>-<kebab-slug>-s<NN> with NN zero-padded to 2 digits)" >&2
    return 1
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

# --- sensor paths -----------------------------------------------------------
#
# Sensors are first-class persistent artifacts in working memory, scoped to
# the host project (not per-task). Each sensor lives in
# .yoke/sensors/<sensor-id>.md with frontmatter + caveats body + runs history.
#
# Created/refreshed by `/yoke:ack-sensors --mode upsert`; read by
# `hooks/verify-acceptance.sh` and `agents/validator.md`; appended to by
# `skills/implement/SKILL.md` after each cycle.
#
# Source PRD: .yoke/prds/2026-04-27-sensor-cost-tiering.md
wm_sensors_dir() { printf '%s' "$WM_SENSORS_DIR"; }

# wm_sensor_path "<sensor-id>"
#   echoes .yoke/sensors/<sensor-id>.md for the given sensor id.
#   Sensor ids must match [a-z0-9][a-z0-9_.-]{0,63} — kebab-or-snake plus
#   '.' and trailing '-_.': lower-case alnum-start, ≤64 chars total.
#   Returns non-zero with a `wm:`-prefixed message on invalid id.
wm_sensor_path() {
    local id="${1:-}"
    if [[ -z "$id" ]]; then
        echo "wm: wm_sensor_path requires <sensor-id>" >&2
        return 1
    fi
    if [[ ! "$id" =~ ^[a-z0-9][a-z0-9_.-]{0,63}$ ]]; then
        echo "wm: invalid sensor id: '$id' (expected [a-z0-9][a-z0-9_.-]{0,63})" >&2
        return 1
    fi
    printf '%s/%s.md' "$WM_SENSORS_DIR" "$id"
}

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

# --- council cycle paths ----------------------------------------------------
#
# Per `.yoke/specs/2026-05-01-agent-council.md` Sprint 01 / Task t04 (and
# Acceptance Contract Scenario 4 / FR-2), each council cycle owns a flat
# directory at `.yoke/runtime/cycles/<N>/<persona>.md`. Each persona writes
# its own slice file there during Phase A; the deterministic merge helper at
# `lib/runtime/council-merge.sh` reads every slice file alphabetically and
# emits a structured read-only view for Phase B. Slice files live under the
# gitignored runtime directory (not under `.yoke/sprints/`) — they are
# per-cycle ephemeral working memory, not versioned archive.
#
# Cites concepts/yoke-pattern-memory-model for the working-memory archive
# layout invariants — slice files are runtime-tier (gitignored, ephemeral)
# and never promoted to the versioned archive.
#
# Persona-name format: lower-case alnum-start, ≤32 chars, kebab allowed
# (matches the persona file basenames under `agents/sr-*.md`). The regex
# is intentionally narrower than the slug regex to keep slice filenames
# short and obviously persona-shaped.

readonly WM_PERSONA_NAME_REGEX='^[a-z0-9][a-z0-9-]{0,31}$'

# wm_cycle_dir "<slug>" <cycle>
#   echoes .yoke/runtime/cycles/<N>/ for the given cycle. The trailing
#   slash is intentional — callers append `<persona>.md` directly.
#   Returns non-zero with a `wm:`-prefixed message on missing/invalid
#   slug or non-numeric cycle.
wm_cycle_dir() {
    local slug="${1:-}"
    local cycle="${2:-}"
    if [[ -z "$slug" ]]; then
        slug="$(wm_active_slug)" || return 1
    else
        wm_validate_slug "$slug" || return 1
    fi
    if [[ -z "$cycle" || ! "$cycle" =~ ^[0-9]+$ ]]; then
        echo "wm: wm_cycle_dir requires <slug> <cycle> (non-negative integer); got slug='$slug' cycle='$cycle'" >&2
        return 1
    fi
    printf '%s/cycles/%d' "$WM_RUNTIME_DIR" "$cycle"
}

# wm_persona_slice_path "<slug>" <cycle> "<persona>"
#   echoes .yoke/runtime/cycles/<N>/<persona>.md for the given persona.
#   Returns non-zero with a `wm:`-prefixed message on missing/invalid
#   slug, non-numeric cycle, or persona-name regex violation.
wm_persona_slice_path() {
    local slug="${1:-}"
    local cycle="${2:-}"
    local persona="${3:-}"
    if [[ -z "$persona" ]]; then
        echo "wm: wm_persona_slice_path requires <slug> <cycle> <persona>" >&2
        return 1
    fi
    if [[ ! "$persona" =~ $WM_PERSONA_NAME_REGEX ]]; then
        echo "wm: invalid persona name: '$persona' (expected [a-z0-9][a-z0-9-]{0,31})" >&2
        return 1
    fi
    local dir
    dir="$(wm_cycle_dir "$slug" "$cycle")" || return 1
    printf '%s/%s.md' "$dir" "$persona"
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
