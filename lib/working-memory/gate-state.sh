#!/bin/bash
# gate-state.sh — gate-state detection ladder for the active task.
#
# Single source of truth for resolving where the active task sits in
# the phase flow (which gate is open, which next-step skill the user
# should run). Sourced by /yoke:status (renders the state with an
# action hint) and by /yoke:implement's preflight (refuses to run
# when the gate is `awaiting:generate-sprints`).
#
# Two ladders coexist — selected by a single `test -f` check on
# `.yoke/acceptance-criteria/<slug>.md`:
#
#   New flow (presence of acceptance-criteria/<slug>.md):
#     awaiting:tech-spec          (no spec or unapproved spec)
#     awaiting:acceptance-criteria (spec approved, AC missing/unratified)
#     awaiting:generate-sprints   (spec + AC approved/ratified, zero sprint files)
#     running:implement            (sprint files exist + status approved)
#     done                         (all sprints completed)
#
#   Legacy flow (no acceptance-criteria/<slug>.md):
#     awaiting:tech-spec          (no spec or unapproved spec)
#     awaiting:acceptance-contract (legacy AC archive missing/unratified)
#     running:implement            (sprint files exist + status approved)
#     done                         (all sprints completed)
#
# Per FR-14 / FR-17 of the parent PRD `.yoke/prds/2026-05-03-generate-sprints-skill.md`
# and the Spec's "Flow-detection contract" section, the detection rule
# is a single `test -f` check on the acceptance-criteria archive
# entry; it does not parse file contents.
#
# Output contract: `detect_gate_state` echoes a single token to stdout
# (one of the seven labels above) and exits 0 on success. On
# missing-active-slug the helper exits non-zero with a `wm:`-prefixed
# stderr line; callers should run with `set -euo pipefail` to honor
# failures.
#
# Usage:
#   source lib/working-memory/gate-state.sh
#   state="$(detect_gate_state)"
#   case "$state" in
#       awaiting:generate-sprints) … ;;
#       running:implement)         … ;;
#   esac

# Idempotent re-source guard.
if [[ -n "${_WM_GATE_STATE_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly _WM_GATE_STATE_LOADED=1

# Source the paths helper so wm_*_path resolvers are available.
_gate_state_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "${_gate_state_script_dir}/paths.sh"

# _gate_status_line <path>
#   Echoes the trimmed value of the leading `> Status: <value>` line
#   of an artifact, or the leading `status: <value>` frontmatter line.
#   Returns empty string when neither is present.
_gate_status_line() {
    local path="${1:-}"
    [[ -f "$path" ]] || return 0
    # Try blockquote prefix first (PRD/Spec/AC convention).
    local val
    val="$(awk '
        /^> Status:[[:space:]]*/ {
            sub(/^> Status:[[:space:]]*/, "", $0)
            sub(/[[:space:]]*$/, "", $0)
            print
            exit
        }
    ' "$path" 2>/dev/null || true)"
    if [[ -n "$val" ]]; then
        printf '%s' "$val"
        return 0
    fi
    # Fallback: YAML frontmatter `status:` line (sprint files).
    awk '
        /^status:[[:space:]]*/ {
            sub(/^status:[[:space:]]*/, "", $0)
            sub(/[[:space:]]*$/, "", $0)
            print
            exit
        }
    ' "$path" 2>/dev/null || true
}

# _gate_count_sprint_files <slug>
#   Echoes the number of sprint files for the given slug. Returns 0
#   on slug-validation failure (treated as "no sprint files" by the
#   caller, which forces the gate to `awaiting:tech-spec`).
_gate_count_sprint_files() {
    local slug="${1:-}"
    local count=0
    while IFS= read -r _; do
        count=$((count + 1))
    done < <(wm_list_sprint_paths "$slug" 2>/dev/null || true)
    printf '%s' "$count"
}

# _gate_count_completed_sprints
#   Reads `completed_sprints:` from .yoke/runtime/progress.md and
#   echoes the comma-separated entry count. Returns 0 on missing
#   progress.md or empty array (the caller interprets 0 as "no sprint
#   has converged yet").
_gate_count_completed_sprints() {
    local progress
    progress="$(wm_progress_path)" || return 0
    [[ -f "$progress" ]] || { printf '0'; return 0; }
    awk '
        /^completed_sprints:[[:space:]]*\[/ {
            line = $0
            sub(/^completed_sprints:[[:space:]]*\[/, "", line)
            sub(/\].*/, "", line)
            gsub(/[[:space:]]/, "", line)
            if (line == "") { print 0; exit }
            n = split(line, parts, ",")
            print n
            exit
        }
    ' "$progress" 2>/dev/null || printf '0'
}

# detect_gate_state
#   Resolves the gate state for the active task. Echoes one of the
#   seven canonical labels; exits non-zero on missing active slug.
detect_gate_state() {
    local slug
    slug="$(wm_active_slug)" || return 1

    local spec_path
    spec_path="$(wm_spec_path "$slug")" || return 1
    local spec_status
    spec_status="$(_gate_status_line "$spec_path")"

    # Step 1 — spec must exist and be approved before any later gate.
    if [[ ! -f "$spec_path" || "$spec_status" != "approved" ]]; then
        printf 'awaiting:tech-spec'
        return 0
    fi

    # Step 2 — flow detection. The presence of acceptance-criteria/<slug>.md
    # selects the new ladder; absence selects the legacy ladder.
    local ac_path
    ac_path="$(wm_acceptance_criteria_path "$slug")" || return 1

    if [[ -f "$ac_path" ]]; then
        # New flow.
        local ac_status
        ac_status="$(_gate_status_line "$ac_path")"
        if [[ "$ac_status" != "ratified" && "$ac_status" != "approved" ]]; then
            printf 'awaiting:acceptance-criteria'
            return 0
        fi
        # Spec approved, AC ratified — check sprint files.
        local sprint_count
        sprint_count="$(_gate_count_sprint_files "$slug")"
        if [[ "$sprint_count" -eq 0 ]]; then
            printf 'awaiting:generate-sprints'
            return 0
        fi
    else
        # Legacy flow — check the legacy acceptance-contracts archive.
        local legacy_ac="${WM_ROOT}/acceptance-contracts/${slug}.md"
        if [[ ! -f "$legacy_ac" ]]; then
            printf 'awaiting:acceptance-contract'
            return 0
        fi
        local legacy_status
        legacy_status="$(_gate_status_line "$legacy_ac")"
        if [[ "$legacy_status" != "ratified" && "$legacy_status" != "approved" ]]; then
            printf 'awaiting:acceptance-contract'
            return 0
        fi
        # Legacy fixtures must already carry sprint files (legacy
        # /yoke:tech-spec stage 3 emitted them); fall through to
        # running/done detection.
    fi

    # Both flows converge here once the upstream gates pass.
    local completed
    completed="$(_gate_count_completed_sprints)"
    local total
    total="$(_gate_count_sprint_files "$slug")"
    if [[ "$total" -gt 0 && "$completed" -ge "$total" ]]; then
        printf 'done'
        return 0
    fi
    printf 'running:implement'
    return 0
}

# detect_gate_action_hint <state>
#   Echoes a one-line action hint for the given state. The hint is
#   the user-facing remediation step rendered alongside the state
#   label by /yoke:status.
detect_gate_action_hint() {
    local state="${1:-}"
    case "$state" in
        awaiting:tech-spec)
            printf 'awaiting:tech-spec — run /yoke:tech-spec to draft and approve the architecture spec'
            ;;
        awaiting:acceptance-criteria)
            printf 'awaiting:acceptance-criteria — run /yoke:acceptance-criteria to draft and ratify the binding criteria'
            ;;
        awaiting:generate-sprints)
            printf 'awaiting:generate-sprints — run /yoke:generate-sprints to advance'
            ;;
        awaiting:acceptance-contract)
            printf 'awaiting:acceptance-contract — legacy task; run /yoke:acceptance-contract to ratify'
            ;;
        running:implement)
            printf 'running:implement — run /yoke:implement to advance the council loop'
            ;;
        done)
            printf 'done — all sprints completed'
            ;;
        *)
            printf 'unknown gate state: %s' "$state"
            ;;
    esac
}
