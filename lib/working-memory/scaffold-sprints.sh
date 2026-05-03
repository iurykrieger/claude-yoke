#!/usr/bin/env bash
# scaffold-sprints.sh
#
# Deterministic sprint-file scaffolder for the sprint-as-cycle flow.
# Parses sprint headings out of an approved `.yoke/specs/<slug>.md`,
# computes their target paths via `wm_sprint_path`, and creates one
# empty sprint file per sprint number, seeded from `templates/sprint.md`
# (single source of truth for the frontmatter shape).
#
# Mirrors lib/working-memory/scaffold-tasks.sh in shape and style. Both
# scripts coexist during the sprint-as-cycle PRD's migration window;
# scaffold-tasks.sh retires in sprint 3 of that PRD.
#
# Stage 2 of the 3-stage `/yoke:tech-spec` blueprint (post sprint 3
# rewrite): stage 1 (LLM) drafts the spec; this script materializes
# the empty sprint files; stage 3 (LLM, per-sprint) fills each file.
# Pure bash — zero LLM cost.
#
# Cites concepts/yoke-pattern-plugin-structure for the lib/ layout
# convention.
#
# Usage:
#   lib/working-memory/scaffold-sprints.sh <spec-path>
#
# Exit codes:
#   0 — all sprint files created (or none to create — but see exit 4)
#   2 — invalid arguments / missing spec / template not found
#   3 — at least one target path already exists (no files written)
#   4 — could not extract any sprint headings from the spec body, or a
#       sprint number is outside the 1..99 range

set -euo pipefail

# Bash-4+ guard. The script uses `mapfile` (line 87) which Apple's
# stock /bin/bash 3.2 does not implement; without `#!/usr/bin/env bash`
# (above) plus this guard, macOS hosts trip `mapfile: command not
# found` (exit 127) the first time `/yoke:tech-spec` reaches stage 2.
# CLAUDE.md :: ## Linting already states "Bash scripts target bash 4+";
# this surfaces the mismatch with an actionable diagnostic instead of
# the cryptic mapfile error. Source: issue #33.
if (( BASH_VERSINFO[0] < 4 )); then
    echo "wm: scaffold-sprints.sh requires bash 4+ (running $BASH_VERSION from ${BASH:-unknown})." >&2
    echo "wm: on macOS, install Homebrew bash and ensure it precedes /bin/bash on PATH:" >&2
    echo "wm:   brew install bash" >&2
    echo "wm:   export PATH=\"/opt/homebrew/bin:\$PATH\"   # Apple Silicon" >&2
    echo "wm:   export PATH=\"/usr/local/bin:\$PATH\"      # Intel Macs" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=./paths.sh
source "${SCRIPT_DIR}/paths.sh"

usage() {
    cat >&2 <<'EOF'
usage: scaffold-sprints.sh <spec-path>

  <spec-path>   path to an approved .yoke/specs/<slug>.md spec.
                The script extracts sprint numbers from lines matching
                "### Sprint <N> — <name>" and creates one empty sprint
                file per number under .yoke/sprints/<slug>-s<NN>.md.

Strict on conflicts: existing sprint files are never overwritten — the
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

template_path="${PLUGIN_ROOT}/templates/sprint.md"
if [[ ! -f "$template_path" ]]; then
    echo "wm: sprint template not found: $template_path" >&2
    exit 2
fi

# Extract slug from the spec basename (strip leading dirs and trailing .md).
spec_basename="$(basename "$spec_path" .md)"
slug="$spec_basename"

if ! wm_validate_slug "$slug"; then
    # wm_validate_slug already wrote the diagnostic.
    exit 2
fi

# Sprint heading regex — anchored on the sprint-as-cycle spec shape:
#   "### Sprint <N> — <name>". The em-dash separator matches the existing
#   templates/spec.md and .yoke/specs/2026-04-27-sprint-as-cycle.md style.
# Capture group: 1 = sprint number (1..3 digits before 1..99 validation).
readonly SPRINT_HEADING_RE='^### Sprint ([0-9]{1,3}) — '

mapfile -t lines < <(grep -E "$SPRINT_HEADING_RE" "$spec_path" || true)

if [[ ${#lines[@]} -eq 0 ]]; then
    echo "wm: no sprint headings found in $spec_path (expected lines matching '### Sprint <N> — ...')" >&2
    exit 4
fi

declare -a sprint_nums sprint_paths
declare -a conflicts=()
declare -A seen_sprints=()

for line in "${lines[@]}"; do
    if [[ ! "$line" =~ $SPRINT_HEADING_RE ]]; then
        echo "wm: failed to re-parse sprint heading: $line" >&2
        exit 4
    fi
    sprint_str="${BASH_REMATCH[1]}"
    # Decimal coercion (10#) defends against leading zeros being read as octal.
    sprint=$((10#$sprint_str))

    # Sprint range guard — must be 1..99 to satisfy the zero-pad-to-2-digits
    # filename invariant (and to match WM_SPRINT_NUM_REGEX in paths.sh).
    if [[ "$sprint" -lt 1 || "$sprint" -gt 99 ]]; then
        echo "wm: invalid sprint number $sprint in $spec_path (expected positive integer 1..99)" >&2
        exit 4
    fi

    # De-duplicate: a spec listing "### Sprint 1 — Foo" twice should not
    # cause two scaffolding attempts (and is almost certainly a bug
    # upstream worth surfacing in stderr without aborting the whole run).
    if [[ -n "${seen_sprints[$sprint]:-}" ]]; then
        echo "wm: duplicate sprint heading for sprint $sprint in $spec_path; using first occurrence" >&2
        continue
    fi
    seen_sprints[$sprint]=1

    target_path="$(wm_sprint_path "$slug" "$sprint")"

    sprint_nums+=("$sprint")
    sprint_paths+=("$target_path")

    if [[ -e "$target_path" ]]; then
        conflicts+=("$target_path")
    fi
done

if [[ ${#conflicts[@]} -gt 0 ]]; then
    echo "wm: would overwrite existing sprint file(s):" >&2
    for c in "${conflicts[@]}"; do
        echo "wm:   $c" >&2
    done
    exit 3
fi

mkdir -p "${WM_ROOT}/sprints"

iso_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
template_body="$(cat "$template_path")"

for i in "${!sprint_paths[@]}"; do
    sprint="${sprint_nums[$i]}"
    target="${sprint_paths[$i]}"
    sprint_padded="$(printf '%02d' "$sprint")"
    sprint_id="${slug}-s${sprint_padded}"

    # Substitute placeholders. Order: longest/most-specific first so
    # later substitutions don't clobber earlier ones.
    body="$template_body"
    body="${body//<slug>-s<NN>/$sprint_id}"
    body="${body//<slug>/$slug}"
    # Padded NN (filename concern) and unpadded N (YAML integer) carried
    # in distinct placeholders to match templates/sprint.md.
    body="${body//<NN>/$sprint_padded}"
    body="${body//<N>/$sprint}"
    body="${body//<iso8601>/$iso_date}"

    printf '%s' "$body" > "$target"
done

echo "wm: scaffolded ${#sprint_paths[@]} sprint file(s) under ${WM_ROOT}/sprints/" >&2
exit 0
