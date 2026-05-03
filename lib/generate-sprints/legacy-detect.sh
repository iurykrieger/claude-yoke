#!/bin/bash
# legacy-detect.sh — legacy-task detection helper for /yoke:generate-sprints.
#
# Per Decision 6A of the parent PRD
# (.yoke/prds/2026-05-03-generate-sprints-skill.md) and FR-16 of the
# binding criteria, legacy tasks emitted by the legacy
# `/yoke:tech-spec` stage 3 MUST be rejected by /yoke:generate-sprints
# without modification of any file under `.yoke/sprints/`. This helper
# encapsulates the two-pronged detection rule so the SKILL body, the
# coordinator's preflight, and the smoke test can share one source of
# truth.
#
# Detection rule:
#   1. `.yoke/acceptance-contracts/<slug>.md` exists → legacy (the
#      legacy ratified envelope lives there).
#   2. Any pre-existing `.yoke/sprints/<slug>-s*.md` file has
#      frontmatter `traceability` lacking the new-flow marker (the
#      substring `acceptance-criteria/<slug>.md`) → legacy (legacy
#      stage 3 cites only the spec in `traceability`).
#
# Output contract:
#   - `legacy_detect <slug>` echoes nothing on success (non-legacy);
#     exits 0.
#   - On legacy detection it prints the literal stderr line `wm:
#     legacy task — generate-sprints does not migrate` and exits 1.
#   - On slug-validation failure it prints a `wm:`-prefixed stderr
#     line and exits non-zero.
#
# The helper does NOT touch any file under `.yoke/sprints/`. Callers
# can wire the helper inline; cite concepts/yoke-pattern-memory-model
# inline in the SKILL body.

# Idempotent re-source guard.
if [[ -n "${_GENERATE_SPRINTS_LEGACY_DETECT_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly _GENERATE_SPRINTS_LEGACY_DETECT_LOADED=1

_legacy_detect_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../working-memory/paths.sh
source "${_legacy_detect_script_dir}/../working-memory/paths.sh"

# legacy_detect <slug>
#   Returns 0 (silent) when the slug points at a new-flow task.
#   Returns 1 (with the documented stderr) when the slug points at a
#   legacy task. Returns 2 on slug-validation failure.
legacy_detect() {
    local slug="${1:-}"
    if [[ -z "$slug" ]]; then
        slug="$(wm_active_slug)" || return 2
    else
        wm_validate_slug "$slug" || return 2
    fi

    local legacy_ac=".yoke/acceptance-contracts/${slug}.md"
    if [[ -f "$legacy_ac" ]]; then
        echo "wm: legacy task — generate-sprints does not migrate" >&2
        return 1
    fi

    local marker="acceptance-criteria/${slug}.md"
    local sprint_path
    while IFS= read -r sprint_path; do
        [[ -z "$sprint_path" ]] && continue
        if ! grep -qE "^traceability:.*${marker}" "$sprint_path" 2>/dev/null; then
            echo "wm: legacy task — generate-sprints does not migrate" >&2
            return 1
        fi
    done < <(wm_list_sprint_paths "$slug" 2>/dev/null || true)

    return 0
}
