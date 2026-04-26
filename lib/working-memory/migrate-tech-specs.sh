#!/bin/bash
# migrate-tech-specs.sh
#
# One-shot, non-destructive migration helper for converting a legacy
# `.yoke/tech-specs/<slug>.md` archive into the sprint-index +
# per-task layout introduced by `tech-spec-task-split`.
#
# The migration follows Part 2's 3-stage pipeline:
#   Stage 1 — LLM:    Generator drafts the new sprint index at
#                     `.yoke/specs/<slug>.md` from the legacy monolith.
#   Stage 2 — bash:   `scaffold-tasks.sh` materializes empty task files.
#   Stage 3 — LLM:    Generator fills each empty task file.
#
# Stages 1 and 3 require an LLM (Claude session driving the
# Generator persona). Stage 2 is the deterministic bridge this
# script invokes. The legacy file at `.yoke/tech-specs/<slug>.md`
# is **never** modified or deleted — recovery is a `git diff` away.
#
# Usage:
#   migrate-tech-specs.sh <legacy-spec-path>           # plan + Stage-1 instruction
#   migrate-tech-specs.sh --scaffold <legacy-spec-path>   # Stage-2 (after Stage-1 wrote the new spec)
#
# Exit codes:
#   0 — plan printed, or scaffold completed
#   2 — invalid arguments / legacy file missing / not under .yoke/tech-specs/
#   3 — refused: new spec or task files already exist for this slug
#   4 — --scaffold called before .yoke/specs/<slug>.md exists
#   5 — Stage-2 (scaffold-tasks.sh) failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=./paths.sh
source "${SCRIPT_DIR}/paths.sh"

usage() {
    cat >&2 <<'EOF'
usage:
  migrate-tech-specs.sh <legacy-spec-path>
      Validates the legacy file, derives the slug, ensures no new-layout
      artifacts exist for this slug, and prints the 3-stage migration
      plan (Stage 1 to be performed by Claude; Stage 2 invoked by
      re-running with --scaffold; Stage 3 to be performed by Claude).

  migrate-tech-specs.sh --scaffold <legacy-spec-path>
      Stage 2: invokes lib/working-memory/scaffold-tasks.sh against the
      already-drafted .yoke/specs/<slug>.md. Run this only AFTER Stage 1
      (Claude wrote the new spec).

The legacy file is never modified. The migration is non-destructive.
EOF
}

mode="plan"
legacy=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scaffold)
            mode="scaffold"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --*)
            echo "wm: unknown flag: $1" >&2
            usage
            exit 2
            ;;
        *)
            if [[ -n "$legacy" ]]; then
                echo "wm: extra positional argument: $1" >&2
                usage
                exit 2
            fi
            legacy="$1"
            shift
            ;;
    esac
done

if [[ -z "$legacy" ]]; then
    usage
    exit 2
fi

if [[ ! -f "$legacy" ]]; then
    echo "wm: legacy spec not found: $legacy" >&2
    exit 2
fi

# Constrain to .yoke/tech-specs/ to avoid migrating arbitrary files.
case "$legacy" in
    .yoke/tech-specs/*.md|*/.yoke/tech-specs/*.md)
        : ;;
    *)
        echo "wm: legacy spec must live under .yoke/tech-specs/ (got: $legacy)" >&2
        exit 2 ;;
esac

base="$(basename "$legacy" .md)"
if ! wm_validate_slug "$base"; then
    echo "wm: filename does not yield a valid slug: $base" >&2
    exit 2
fi
slug="$base"

new_spec_path="$(wm_spec_path "$slug")"
existing_tasks="$(wm_list_task_paths "$slug")"

if [[ "$mode" == "scaffold" ]]; then
    if [[ ! -f "$new_spec_path" ]]; then
        echo "wm: --scaffold requires Stage 1 to have written $new_spec_path first" >&2
        echo "wm: re-run without --scaffold to print the migration plan" >&2
        exit 4
    fi
    if [[ -n "$existing_tasks" ]]; then
        echo "wm: refusing to overwrite existing task file(s):" >&2
        echo "$existing_tasks" | sed 's/^/wm:   /' >&2
        exit 3
    fi
    if ! bash "${SCRIPT_DIR}/scaffold-tasks.sh" "$new_spec_path"; then
        echo "wm: stage-2 scaffold failed" >&2
        exit 5
    fi
    cat <<EOF
wm: migration stage 2 complete.

Stage 3 (manual / LLM): for each empty task file under .yoke/tasks/
that begins with the slug "$slug", fill the four required body
sections (Story / Technical implementation / Validation / Acceptance
criterion) from the legacy content at:
  $legacy
following templates/task.md. The legacy file is left in place as
the audit trail.
EOF
    exit 0
fi

# Plan mode (default): refuse if any new-layout artifact already exists,
# then print the migration plan.
if [[ -f "$new_spec_path" ]]; then
    echo "wm: refusing to plan migration — $new_spec_path already exists" >&2
    exit 3
fi
if [[ -n "$existing_tasks" ]]; then
    echo "wm: refusing to plan migration — task files already exist for slug '$slug':" >&2
    echo "$existing_tasks" | sed 's/^/wm:   /' >&2
    exit 3
fi

cat <<EOF
wm: migration plan for slug "$slug"

Legacy:    $legacy
New spec:  $new_spec_path
New tasks: .yoke/tasks/${slug}-s<NN>-t<MM>.md (created in Stage 2)

The 3-stage pipeline (the legacy file is never modified):

  Stage 1 (LLM / Claude — Generator persona)
    Read $legacy.
    Draft a new sprint index at $new_spec_path following
    templates/spec.md, preserving every described task as a
    distinct task ID of shape <slug>-s<NN>-t<MM>. No inline task
    body — only the one-line story per task.

  Stage 2 (bash — this script)
    Re-run: $0 --scaffold $legacy
    This invokes lib/working-memory/scaffold-tasks.sh, which
    materializes one empty .yoke/tasks/<slug>-s<NN>-t<MM>.md per
    task ID parsed from the spec.

  Stage 3 (LLM / Claude — Generator persona)
    For each empty task file, fill the four required body
    sections from the legacy content, following templates/task.md.

Tip: review the proposed task list at the end of Stage 1 before
running Stage 2. If the split looks wrong, edit the spec or restart
Stage 1.
EOF
exit 0
