#!/bin/bash
# scaffold-tasks.sh
#
# Deterministic task-file scaffolder for the tech-spec-task-split flow.
# Parses task IDs out of an approved `.yoke/specs/<slug>.md`, computes
# their target paths via `wm_task_path`, and creates one empty task
# file per ID seeded from `templates/task.md` (single source of truth
# for the frontmatter shape).
#
# Stage 2 of the 3-stage `/yoke:tech-spec` blueprint: stage 1 (LLM)
# drafts the spec; this script materializes the empty task files;
# stage 3 (LLM, per-task) fills each file. Pure bash — zero LLM cost.
#
# Usage:
#   lib/working-memory/scaffold-tasks.sh <spec-path>
#
# Exit codes:
#   0 — all task files created (or none to create)
#   2 — invalid arguments / missing spec / template not found
#   3 — at least one target path already exists (no files written)
#   4 — could not extract any task IDs from the spec body

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=./paths.sh
source "${SCRIPT_DIR}/paths.sh"

usage() {
    cat >&2 <<'EOF'
usage: scaffold-tasks.sh <spec-path>

  <spec-path>   path to an approved .yoke/specs/<slug>.md spec.
                The script extracts task IDs from lines matching
                "#### Task <id>" and creates the corresponding empty
                task files under .yoke/tasks/.

Strict on conflicts: existing task files are never overwritten — the
script exits non-zero (3) with the conflicting paths listed.
EOF
}

if [[ $# -ne 1 ]]; then
    usage
    exit 2
fi

spec_path="$1"

if [[ ! -f "$spec_path" ]]; then
    echo "wm: spec file not found: $spec_path" >&2
    exit 2
fi

template_path="${PLUGIN_ROOT}/templates/task.md"
if [[ ! -f "$template_path" ]]; then
    echo "wm: task template not found: $template_path" >&2
    exit 2
fi

# Task heading regex — anchored on the templates/spec.md shape:
#   "#### Task <slug>-s<N>-t<M>" optionally followed by " — <story>".
# Capture groups: 1 = slug, 2 = sprint number, 3 = task number.
# The trailing `($|[^0-9])` boundary keeps M's digit run from leaking
# into adjacent characters and rejects 4+ digit task numbers.
readonly TASK_HEADING_RE='^#### Task ([0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]*)-s([0-9]{1,3})-t([0-9]{1,3})($|[^0-9])'

mapfile -t lines < <(grep -E "$TASK_HEADING_RE" "$spec_path" || true)

if [[ ${#lines[@]} -eq 0 ]]; then
    echo "wm: no task IDs found in $spec_path (expected lines matching '#### Task <slug>-sNN-tMM ...')" >&2
    exit 4
fi

declare -a task_slugs task_sprints task_tasks task_paths
declare -a conflicts=()

for line in "${lines[@]}"; do
    if [[ ! "$line" =~ $TASK_HEADING_RE ]]; then
        echo "wm: failed to re-parse task heading: $line" >&2
        exit 4
    fi
    slug="${BASH_REMATCH[1]}"
    sprint_str="${BASH_REMATCH[2]}"
    task_str="${BASH_REMATCH[3]}"
    # Decimal coercion (10#) defends against leading zeros being read as octal.
    sprint=$((10#$sprint_str))
    task=$((10#$task_str))

    target_path="$(wm_task_path "$slug" "$sprint" "$task")"

    task_slugs+=("$slug")
    task_sprints+=("$sprint")
    task_tasks+=("$task")
    task_paths+=("$target_path")

    if [[ -e "$target_path" ]]; then
        conflicts+=("$target_path")
    fi
done

if [[ ${#conflicts[@]} -gt 0 ]]; then
    echo "wm: refusing to overwrite ${#conflicts[@]} existing task file(s):" >&2
    for c in "${conflicts[@]}"; do
        echo "wm:   $c" >&2
    done
    exit 3
fi

mkdir -p "${WM_ROOT}/tasks"

iso_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
template_body="$(cat "$template_path")"

for i in "${!task_paths[@]}"; do
    slug="${task_slugs[$i]}"
    sprint="${task_sprints[$i]}"
    task="${task_tasks[$i]}"
    target="${task_paths[$i]}"
    task_id="$(printf '%s-s%02d-t%02d' "$slug" "$sprint" "$task")"

    # Substitute placeholders. Order: longest/most-specific first so
    # later substitutions don't clobber earlier ones.
    body="$template_body"
    body="${body//<slug>-s<NN>-t<MM>/$task_id}"
    body="${body//<slug>/$slug}"
    # Sprint number unpadded in YAML (`sprint: 1`, not `sprint: 01`)
    # to follow common YAML integer convention. Padding is purely a
    # filename concern and lives in the task_id field above.
    body="${body//<N>/$sprint}"
    body="${body//<iso8601>/$iso_date}"

    printf '%s' "$body" > "$target"
done

echo "wm: scaffolded ${#task_paths[@]} task file(s) under ${WM_ROOT}/tasks/" >&2
exit 0
