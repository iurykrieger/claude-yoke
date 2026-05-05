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

# wm_check_phase1_approved <path>
#   Phase-1-artifact-agnostic approval predicate. Used by every downstream
#   skill that consumes a Phase-1 artifact through the
#   wm_phase1_artifact_path resolver — the resolver does not branch on
#   PRD-vs-fix-spec identity, so the approval check stays artifact-agnostic
#   too.
#
#   Exits 0 when <path> exists AND its body carries a blockquote line
#   matching `> Status: approved` (or `ratified`, mirroring
#   wm_check_prd_approved's grammar). Exits 1 with a `wm:`-prefixed stderr
#   diagnostic ending with the literal remediation hint
#   `Run /yoke:discover or /yoke:fix first.` per the post-migration FR-9
#   contract.
#
# Anchors:
#   - PRD: .yoke/prds/2026-05-05-phase-1-fix-entrypoint.md (FR-9, FR-2 of
#     the migration tier — every downstream skill's pre-flight error
#     message updates from "Run /yoke:discover first." to "Run /yoke:discover
#     or /yoke:fix first.")
#   - Acceptance Criteria (binding):
#     .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md
#     (US-003 DoD bullet, AC-003-1, AC-003-2)
wm_check_phase1_approved() {
    local path="${1:-}"
    if [[ -z "$path" ]]; then
        echo "wm: wm_check_phase1_approved requires <path>" >&2
        return 2
    fi
    if [[ ! -f "$path" ]]; then
        echo "wm: Phase-1 artifact missing or unapproved at $path. Run /yoke:discover or /yoke:fix first." >&2
        return 1
    fi
    if ! grep -qE "^> Status:[[:space:]]*(approved|ratified)" "$path"; then
        echo "wm: Phase-1 artifact missing or unapproved at $path. Run /yoke:discover or /yoke:fix first." >&2
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
