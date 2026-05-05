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
readonly WM_ARCHIVE_CATEGORIES=(prds fixes specs sprints acceptance-criteria acceptance-contracts contracts)

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
    # FR-9a invariant on write — refuse to record .current when both
    # Phase-1 archives exist for the slug. This is belt-and-suspenders
    # against scenarios I (cross-branch merge collision) and V (manual
    # merge resolution accepting both sides) which bypass FR-4's
    # collision check. Prints the FR-9 ambiguous-Phase-1-state
    # diagnostic verbatim and leaves .current unmodified on refusal.
    #
    # Anchors: PRD FR-9a + AC-004-3 of
    # .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md
    local prd_path="${WM_ROOT}/prds/${slug}.md"
    local fix_path="${WM_ROOT}/fixes/${slug}.md"
    if [[ -f "$prd_path" && -f "$fix_path" ]]; then
        _wm_emit_ambiguous_phase1_diagnostic "$slug" "$prd_path" "$fix_path" >&2
        return 1
    fi
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
# wm_fix_path "<slug>"
#   Echoes ".yoke/fixes/<slug>.md" deterministically — pure path computer
#   with no I/O. Mirrors wm_prd_path / wm_spec_path / wm_acceptance_criteria_path
#   shape: validates the slug via wm_validate_slug at the boundary and aborts
#   non-zero with a "wm:"-prefixed diagnostic on regex violation. When called
#   without an argument, falls back to the active slug via wm_active_slug.
#
#   Anchored to PRD FR-3 (.yoke/prds/2026-05-05-phase-1-fix-entrypoint.md).
#   The materialized .yoke/fixes/ directory is created lazily on first write
#   by the /yoke:fix skill; this helper does NOT stat or mkdir.
wm_fix_path()                  { _wm_archive_path "fixes" "${1:-}"; }

# --- Phase-1 artifact resolver (existence-aware exception) -------------------
#
# wm_phase1_artifact_path "<slug>"
#
# THIS FUNCTION IS THE CANONICAL I/O-AWARE EXCEPTION IN paths.sh.
# Its existence-aware contract does NOT propagate to future helpers;
# every other helper in this file is a pure path computer by default and
# new helpers added to this file MUST remain pure path computers unless a
# fresh PRD ratifies a new I/O-aware exception. The resolver lives in
# paths.sh (not in a sibling lib/) so that working-memory path resolution
# stays centralized — but its docstring is the load-bearing reminder that
# this is the sole exception.
#
# Contract:
#   - Validates the slug via wm_validate_slug; falls back to wm_active_slug
#     when called without an argument (matches every sibling helper's
#     argument shape).
#   - Stats both .yoke/prds/<slug>.md and .yoke/fixes/<slug>.md.
#   - Exactly one exists  → echoes that path to stdout, exits 0.
#   - Both exist          → emits the verbatim "wm: ambiguous Phase-1
#                            state for slug '<slug>'" structured-recovery
#                            diagnostic to stderr (paths + first-100-bytes
#                            excerpts + last-commit sha + author + ISO-8601
#                            timestamp + git rm recipe), exits non-zero.
#                            stdout is empty on this branch.
#   - Neither exists      → emits a "wm:"-prefixed neither-case diagnostic
#                            ending with the literal remediation
#                            "Run /yoke:discover or /yoke:fix first.", exits
#                            non-zero. stdout is empty on this branch.
#
# No read-vs-write split — every caller (read-only or write) inherits the
# same abort path. PRD OQ-3 / option (δ) ratifies this uniform contract.
#
# Anchors:
#   - PRD: .yoke/prds/2026-05-05-phase-1-fix-entrypoint.md (FR-9)
#   - Spec: .yoke/specs/2026-05-05-phase-1-fix-entrypoint.md (APIs and
#     Data Model :: wm_phase1_artifact_path)
#   - Acceptance Criteria (binding):
#     .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md
#     (US-003 DoD bullet, US-004 DoD bullets, AC-004-1, AC-004-2)
wm_phase1_artifact_path() {
    local slug="${1:-}"
    if [[ -z "$slug" ]]; then
        slug="$(wm_active_slug)" || return 1
    else
        wm_validate_slug "$slug" || return 1
    fi
    local prd_path="${WM_ROOT}/prds/${slug}.md"
    local fix_path="${WM_ROOT}/fixes/${slug}.md"
    local prd_exists=0 fix_exists=0
    [[ -f "$prd_path" ]] && prd_exists=1
    [[ -f "$fix_path" ]] && fix_exists=1

    if (( prd_exists == 1 && fix_exists == 1 )); then
        _wm_emit_ambiguous_phase1_diagnostic "$slug" "$prd_path" "$fix_path" >&2
        return 1
    fi
    if (( prd_exists == 0 && fix_exists == 0 )); then
        {
            echo "wm: no Phase-1 artifact for slug '$slug'"
            echo
            echo "  expected one of:"
            echo "    $prd_path"
            echo "    $fix_path"
            echo
            echo "Run /yoke:discover or /yoke:fix first."
        } >&2
        return 1
    fi
    if (( prd_exists == 1 )); then
        printf '%s' "$prd_path"
    else
        printf '%s' "$fix_path"
    fi
}

# _wm_emit_ambiguous_phase1_diagnostic <slug> <prd-path> <fix-path>
#   Internal helper — emits the verbatim FR-9 "ambiguous Phase-1 state"
#   diagnostic to stdout (callers redirect to stderr). Body carries:
#     1. The "wm: ambiguous Phase-1 state for slug '<slug>'" header — the
#        stable substring that AC-004-1 ratifies and the no-ambiguous-phase1
#        sensor scans CI logs for.
#     2. Both paths with first-100-bytes excerpts, last-commit sha, author,
#        and ISO-8601 commit timestamp (when the file is git-tracked).
#     3. A "git rm" example recipe and the literal "Exactly one Phase-1
#        artifact must exist per slug" closing reminder.
#
#   Files outside git (untracked or no .git directory) print
#   "<unversioned>" in the commit-metadata slot — the diagnostic remains
#   well-formed and stable.
_wm_emit_ambiguous_phase1_diagnostic() {
    local slug="$1"
    local prd_path="$2"
    local fix_path="$3"
    echo "wm: ambiguous Phase-1 state for slug '$slug'"
    echo
    _wm_emit_phase1_artifact_block "$prd_path"
    _wm_emit_phase1_artifact_block "$fix_path"
    echo
    echo "Exactly one Phase-1 artifact must exist per slug. Resolve via:"
    echo "  git rm $prd_path && git commit"
    echo "or"
    echo "  git rm $fix_path && git commit"
    echo "or rename one slug. The canonical Phase-1 lifecycle expects"
    echo "one of (PRD, fix-spec) per slug, never both."
}

# _wm_emit_phase1_artifact_block <path>
#   Internal helper — emits one indented artifact block:
#     <path>
#       first 100 bytes: <excerpt>
#       last commit:     <sha> by <author> on <iso8601>
#   Falls back to "<unversioned>" when git is unavailable or the path is
#   not tracked. The first-100-bytes excerpt has its newlines collapsed
#   to a single space and trailing whitespace trimmed, so the diagnostic
#   stays single-line per byte regardless of file content.
_wm_emit_phase1_artifact_block() {
    local path="$1"
    local excerpt commit_line
    if [[ -f "$path" ]]; then
        excerpt="$(head -c 100 "$path" 2>/dev/null | tr '\n\r' '  ' | sed -E 's/[[:space:]]+$//')"
    else
        excerpt="<missing>"
    fi
    commit_line="$(_wm_last_commit_for "$path")"
    echo "  $path"
    echo "    first 100 bytes: $excerpt"
    echo "    last commit:     $commit_line"
}

# _wm_last_commit_for <path>
#   Echoes "<sha> by <author> on <iso8601>" for the path's last git
#   commit. Echoes "<unversioned>" when git is unavailable, when the path
#   is outside a git working tree, or when the path is untracked.
_wm_last_commit_for() {
    local path="$1"
    if ! command -v git >/dev/null 2>&1; then
        echo "<unversioned>"
        return 0
    fi
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "<unversioned>"
        return 0
    fi
    local info
    info="$(git log -n 1 --pretty=format:'%h by %an on %aI' -- "$path" 2>/dev/null)"
    if [[ -z "$info" ]]; then
        echo "<unversioned>"
    else
        echo "$info"
    fi
}

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

# wm_reset_cycle_counter
#   Deterministic primitive that zeros the per-sprint cycle counter file at
#   wm_cycle_counter_path() — i.e. ".yoke/runtime/.cycle-counter". Invoked by
#   the council coordinator on per-sprint convergence, AFTER appending the
#   just-converged sprint id to `completed_sprints:` and incrementing
#   `current_sprint:` in `progress.md` frontmatter (placing it earlier would
#   zero the counter mid-sprint and let `hooks/check-hard-bounds.sh` accept
#   additional cycles in the just-completed sprint). Idempotent: writes the
#   single byte `0` (no trailing newline, mirroring `wm_set_active`'s
#   convention) regardless of the file's prior state, creating it (and the
#   parent runtime directory, post-`wm_wipe_runtime`) when absent. Surfaces
#   filesystem errors via `wm:`-prefixed stderr and exits non-zero. Does not
#   write to `progress.md`, does not invoke any canonical-memory verb, and
#   does not modify any file outside `wm_cycle_counter_path()`.
#
#   Anchors:
#   - Fix-spec: .yoke/fixes/2026-05-05-cycle-counter-reset-on-sprint-advance.md
#     (FR-1)
#   - Tech Spec: .yoke/specs/2026-05-05-cycle-counter-reset-on-sprint-advance.md
#     (Architecture :: deterministic working-memory primitive)
#   - Acceptance Criteria:
#     .yoke/acceptance-criteria/2026-05-05-cycle-counter-reset-on-sprint-advance.md
#     (US-001 DoD + AC-001-1..AC-001-4)
#   - concepts/yoke-pattern-sprint-runtime-bundle (canonical memory) — sprint
#     advance resets the counter; hard-bound exhaustion fires Trigger 4 keyed
#     on the active sprint.
wm_reset_cycle_counter() {
    local target
    target="$(wm_cycle_counter_path)"
    local parent
    parent="$(dirname "$target")"
    if ! mkdir -p "$parent" 2>/dev/null; then
        echo "wm: wm_reset_cycle_counter: failed to create runtime dir '$parent'" >&2
        return 1
    fi
    if ! printf '0' > "$target" 2>/dev/null; then
        echo "wm: wm_reset_cycle_counter: failed to write '$target'" >&2
        return 1
    fi
}

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
