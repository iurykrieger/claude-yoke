#!/usr/bin/env bash
# check-approved.sh — shared status-line predicates for working-memory
# artifacts (PRD, Tech Spec, Acceptance Criteria).
#
# Yoke's working-memory artifacts encode their human-gate status as a
# blockquote line in the document body, NOT in YAML frontmatter:
#
#     > Status: approved      (PRD, Tech Spec — Triggers 1 & 2)
#     > Status: ratified      (Acceptance Criteria — Trigger 3)
#
# This file centralises the grep predicates so every Yoke skill that
# needs to gate on approval / ratification status uses the same regex
# (no drift in the future when the status grammar evolves).
#
# Error contract: failures emit `wm:`-prefixed messages to stderr and
# return non-zero. Diagnostics are exact strings — they're asserted
# character-for-character in smoke tests (e.g.,
# `tests/smoke/generate-sprints-preflight.test.sh`).
#
# Usage:
#   source lib/working-memory/check-approved.sh
#   wm_check_prd_approved "$prd_path"   || exit 1
#   wm_check_spec_approved "$spec_path" || exit 1
#   wm_check_ac_ratified "$ac_path"     || exit 1

# Idempotent re-source guard.
if [[ -n "${_WM_CHECK_APPROVED_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly _WM_CHECK_APPROVED_LOADED=1

# wm_check_prd_approved <path>
#   Exits 0 when <path> exists AND its body carries a blockquote line
#   matching `> Status: approved` (or `ratified`, since the PRD can be
#   re-ratified post-merge). Exits 1 with `wm:`-prefixed stderr otherwise.
wm_check_prd_approved() {
    local path="${1:-}"
    if [[ -z "$path" ]]; then
        echo "wm: wm_check_prd_approved requires <path>" >&2
        return 2
    fi
    if [[ ! -f "$path" ]]; then
        echo "wm: PRD missing or unapproved at $path. Run /yoke:discover first." >&2
        return 1
    fi
    if ! grep -qE "^> Status:[[:space:]]*(approved|ratified)" "$path"; then
        echo "wm: PRD missing or unapproved at $path. Run /yoke:discover first." >&2
        return 1
    fi
    return 0
}

# wm_check_spec_approved <path>
#   Exits 0 when <path> exists AND its body carries a blockquote line
#   matching `> Status: approved`. Exits 1 with `wm:`-prefixed stderr
#   otherwise.
wm_check_spec_approved() {
    local path="${1:-}"
    if [[ -z "$path" ]]; then
        echo "wm: wm_check_spec_approved requires <path>" >&2
        return 2
    fi
    if [[ ! -f "$path" ]]; then
        echo "wm: spec missing or unapproved at $path. Run /yoke:tech-spec first." >&2
        return 1
    fi
    if ! grep -qE "^> Status:[[:space:]]*approved" "$path"; then
        echo "wm: spec missing or unapproved at $path. Run /yoke:tech-spec first." >&2
        return 1
    fi
    return 0
}

# wm_check_ac_ratified <path>
#   Exits 0 when <path> exists AND its body carries a blockquote line
#   matching `> Status: ratified` (the canonical AC status — Trigger 3
#   ratifies, it does not approve). Exits 1 with `wm:`-prefixed stderr
#   otherwise.
wm_check_ac_ratified() {
    local path="${1:-}"
    if [[ -z "$path" ]]; then
        echo "wm: wm_check_ac_ratified requires <path>" >&2
        return 2
    fi
    if [[ ! -f "$path" ]]; then
        echo "wm: acceptance-criteria missing or un-ratified at $path. Run /yoke:acceptance-criteria first." >&2
        return 1
    fi
    if ! grep -qE "^> Status:[[:space:]]*ratified" "$path"; then
        echo "wm: acceptance-criteria missing or un-ratified at $path. Run /yoke:acceptance-criteria first." >&2
        return 1
    fi
    return 0
}
