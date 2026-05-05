#!/usr/bin/env bash
# canonize-stage.sh
#
# Materializes the active task's working-memory diff into a fresh
# tmp directory shaped exactly like `.yoke/`, then echoes the
# absolute path of that staging dir on stdout. Designed for
# /yoke:canonize: instead of handing the provider the full `.yoke/`
# (which contains historical PRDs, specs, sprint bundles, and
# acceptance documents from every prior task), the facade stages
# only the active slug's artifacts.
#
# The slug is read from `.yoke/runtime/.current` via wm_active_slug
# unless `--slug <slug>` is passed (escape hatch for tests and for
# manual catch-up canonizations of a slug that is not currently
# active).
#
# Files staged (all keyed off the resolved slug):
#   - config.yaml                       — provider needs canonical_memory.* passthrough
#   - .gitignore                        — preserved for shape parity
#   - prds/<slug>.md                    — when present
#   - specs/<slug>.md                   — when present
#   - sprints/<slug>-s*.md              — every match (zero or more)
#   - acceptance-criteria/<slug>.md     — when present (post v4.0.0)
#   - acceptance-contracts/<slug>.md    — when present (legacy, pre v4.0.0)
#   - contracts/<slug>.md               — when present (sprint contracts)
#   - runtime/                          — full subtree, per-task transient state
#
# Files explicitly NOT staged:
#   - prds/<other-slug>.md and the same pattern for every historical
#     archive category — those are previous tasks, already canonized
#     in their own runs.
#   - sensors/<sensor-id>.md — project-scoped, not per-task. Re-feeding
#     them on every canonize re-runs the provider's entity-matching
#     pipeline against artifacts that already canonized.
#
# Source issue: https://github.com/iurykrieger/claude-yoke/issues/40.
# Contract reference: docs/canonical-memory-provider-contract.md.
#
# Usage:
#   stage_dir="$(lib/working-memory/canonize-stage.sh)"
#   # ... dispatch provider with --working-memory "$stage_dir" ...
#   rm -rf "$stage_dir"   # caller cleans up
#
# Exit codes:
#   0 — staged successfully; absolute stage path on stdout
#   2 — invalid args, missing host .yoke/, or unsupported bash version
#   3 — could not resolve active slug (no .yoke/runtime/.current)

set -euo pipefail

# Bash-4+ guard. Mirrors scaffold-sprints.sh per issue #33.
if (( BASH_VERSINFO[0] < 4 )); then
    echo "wm: canonize-stage.sh requires bash 4+ (running $BASH_VERSION from ${BASH:-unknown})." >&2
    echo "wm: on macOS, install Homebrew bash and ensure it precedes /bin/bash on PATH:" >&2
    echo "wm:   brew install bash" >&2
    echo "wm:   export PATH=\"/opt/homebrew/bin:\$PATH\"   # Apple Silicon" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./paths.sh
source "${SCRIPT_DIR}/paths.sh"

usage() {
    cat >&2 <<'EOF'
usage: canonize-stage.sh [--slug <slug>]

  --slug <slug>  Stage this slug instead of reading
                 .yoke/runtime/.current. Useful for tests and for
                 catching up a slug that is not currently active.

Echoes the absolute path of a fresh staging directory on stdout.
Caller is responsible for `rm -rf` after the provider returns.
EOF
}

slug=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --slug)
            slug="${2:-}"
            shift 2 || { usage; exit 2; }
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "wm: canonize-stage.sh: unknown argument: $1" >&2
            usage
            exit 2
            ;;
    esac
done

if [[ ! -d "$PWD/.yoke" ]]; then
    echo "wm: .yoke/ not found in \$PWD ($PWD)" >&2
    exit 2
fi

if [[ -z "$slug" ]]; then
    slug="$(wm_active_slug)" || exit 3
else
    wm_validate_slug "$slug" || exit 2
fi

stage="$(mktemp -d "${TMPDIR:-/tmp}/yoke-canonize-stage.XXXXXX")"

mkdir -p \
    "$stage/prds" \
    "$stage/fixes" \
    "$stage/specs" \
    "$stage/sprints" \
    "$stage/acceptance-criteria" \
    "$stage/acceptance-contracts" \
    "$stage/contracts"

# config.yaml + .gitignore — required for shape parity. The provider
# reads canonical_memory.* passthrough keys from config.yaml.
[[ -f .yoke/config.yaml ]] && cp -p .yoke/config.yaml "$stage/config.yaml"
[[ -f .yoke/.gitignore ]] && cp -p .yoke/.gitignore "$stage/.gitignore"

# Per-slug archive files (each is conditional — partial archives are
# valid; e.g. spec-phase only has prds/specs/sprints, no contracts).
[[ -f ".yoke/prds/${slug}.md" ]] \
    && cp -p ".yoke/prds/${slug}.md" "$stage/prds/${slug}.md"
# fixes/<slug>.md — Phase-1 fix-spec archive, sibling of prds/. The
# FR-9a write-time invariant in wm_set_active makes PRD+fix-spec
# coexistence unreachable, so at most one of prds/<slug>.md and
# fixes/<slug>.md is staged for any given slug. Anchor: PRD
# `.yoke/prds/2026-05-05-phase-1-fix-entrypoint.md`.
[[ -f ".yoke/fixes/${slug}.md" ]] \
    && cp -p ".yoke/fixes/${slug}.md" "$stage/fixes/${slug}.md"
[[ -f ".yoke/specs/${slug}.md" ]] \
    && cp -p ".yoke/specs/${slug}.md" "$stage/specs/${slug}.md"
[[ -f ".yoke/acceptance-criteria/${slug}.md" ]] \
    && cp -p ".yoke/acceptance-criteria/${slug}.md" "$stage/acceptance-criteria/${slug}.md"
[[ -f ".yoke/acceptance-contracts/${slug}.md" ]] \
    && cp -p ".yoke/acceptance-contracts/${slug}.md" "$stage/acceptance-contracts/${slug}.md"
[[ -f ".yoke/contracts/${slug}.md" ]] \
    && cp -p ".yoke/contracts/${slug}.md" "$stage/contracts/${slug}.md"

# Every sprint file for the active slug.
shopt -s nullglob
for f in ".yoke/sprints/${slug}"-s*.md; do
    cp -p "$f" "$stage/sprints/$(basename "$f")"
done
shopt -u nullglob

# runtime/ is per-task, transient, gitignored. Copy the full subtree
# so the provider sees the same context the framework saw at canonize
# time (progress.md is especially useful for canonize-line lineage).
if [[ -d .yoke/runtime ]]; then
    mkdir -p "$stage/runtime"
    cp -Rp .yoke/runtime/. "$stage/runtime/"
fi

# Drop empty archive directories so the staged tree mirrors what the
# provider would see in a fresh `.yoke/`. Empty `acceptance-contracts/`
# (post v4.0.0) and empty `contracts/` (pre-runtime) are common.
for d in "$stage/prds" "$stage/fixes" "$stage/specs" "$stage/sprints" \
         "$stage/acceptance-criteria" "$stage/acceptance-contracts" \
         "$stage/contracts"; do
    if [[ -d "$d" ]] && [[ -z "$(ls -A "$d" 2>/dev/null)" ]]; then
        rmdir "$d"
    fi
done

printf '%s' "$stage"
