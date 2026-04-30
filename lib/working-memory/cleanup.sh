#!/bin/bash
# cleanup.sh — working-memory hygiene helpers for /yoke:implement.
#
# Three deterministic functions, all idempotent and silent-on-success:
#   wm_gitignore_self_heal     — write/repair .yoke/.gitignore
#   wm_check_runtime_tracked   — emit a one-line remediation hint when
#                                .yoke/runtime/ has tracked files
#   wm_runtime_cleanup         — delete contents of .yoke/runtime/ iff
#                                termination was MERGE-READY *and* the
#                                canonize handoff returned exit 0
#
# Convention: "Back-pressure: success is silent, failures are verbose."
# Correct state produces no output; repaired/violation states produce
# exactly one line on stdout. Errors go to stderr with the "wm:" prefix.
#
# Usage from /yoke:implement:
#   source lib/working-memory/paths.sh
#   source lib/working-memory/cleanup.sh
#   # preflight
#   wm_gitignore_self_heal
#   wm_check_runtime_tracked
#   # ...loop...
#   # termination (after canonize handoff)
#   wm_runtime_cleanup "$termination_reason" "$canonize_exit_code"

if [[ -n "${_WM_CLEANUP_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly _WM_CLEANUP_LOADED=1

# Hard dependency on paths.sh: wm_runtime_dir + wm_wipe_runtime.
# Intentionally not auto-sourced — callers source paths.sh first.
if [[ -z "${_WM_PATHS_LOADED:-}" ]]; then
    echo "wm: cleanup.sh requires lib/working-memory/paths.sh — source it first" >&2
    return 1 2>/dev/null || exit 1
fi

readonly _WM_GITIGNORE_PATH="${WM_ROOT}/.gitignore"
readonly _WM_GITIGNORE_CONTENT='runtime/'

# wm_gitignore_self_heal
#   Idempotently writes .yoke/.gitignore with the canonical two-line
#   content (".current" + "runtime/"). When the file is already correct,
#   produces no output. When missing or incomplete, writes/overwrites
#   it and prints exactly one line of notice.
#
#   Returns 0 always (creating .yoke/ if absent so the write succeeds).
wm_gitignore_self_heal() {
    mkdir -p "$WM_ROOT"
    if [[ -f "$_WM_GITIGNORE_PATH" ]]; then
        local current
        current="$(cat "$_WM_GITIGNORE_PATH")"
        if [[ "$current" == "$_WM_GITIGNORE_CONTENT" ]]; then
            return 0
        fi
    fi
    printf '%s\n' "$_WM_GITIGNORE_CONTENT" > "$_WM_GITIGNORE_PATH"
    echo "[yoke] repaired .yoke/.gitignore (wrote: runtime/)"
}

# wm_check_runtime_tracked
#   When run inside a git work tree, checks whether any path under
#   .yoke/runtime/ is tracked. If so, prints exactly one line with
#   the remediation command. Read-only — never modifies git state.
#   Silently returns 0 outside a git work tree.
wm_check_runtime_tracked() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    if git ls-files --error-unmatch -- "$WM_RUNTIME_DIR" >/dev/null 2>&1; then
        echo "[yoke] .yoke/runtime/ has tracked files. Run: git rm -r --cached .yoke/runtime/"
    fi
    return 0
}

# wm_runtime_cleanup <termination_reason> <canonize_exit_code>
#   Deletes the contents of .yoke/runtime/ iff:
#     reason == "merge-ready" AND canonize_exit == 0
#   Otherwise no-op. The directory itself is preserved.
#
#   Reasons that intentionally skip cleanup:
#     divergence, contract-conflict, hard-bound, infeasibility
#   These are arbitration pauses; the user must be able to resume the
#   loop with full cycle history.
#
#   A non-zero canonize exit also skips cleanup so the user can
#   re-invoke /yoke:canonize manually against intact runtime state.
wm_runtime_cleanup() {
    local reason="${1:-}"
    local canonize_exit="${2:-}"
    if [[ -z "$reason" || -z "$canonize_exit" ]]; then
        echo "wm: wm_runtime_cleanup requires <termination_reason> <canonize_exit_code>; got reason='$reason' canonize_exit='$canonize_exit'" >&2
        return 1
    fi
    if [[ "$reason" != "merge-ready" ]]; then
        return 0
    fi
    if [[ "$canonize_exit" != "0" ]]; then
        return 0
    fi
    wm_wipe_runtime
}
