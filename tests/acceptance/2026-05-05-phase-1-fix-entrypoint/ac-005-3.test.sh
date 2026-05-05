#!/usr/bin/env bash
# criterion: AC-005-3
#
# AC-005-3 (binding text from
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md):
#
#   "The canonize-handoff package produced at Phase 5 termination
#    contains a proposed amendment to `concepts/yoke-conventions`
#    introducing the Mode-tag convention, classified as
#    `model_c_impact: medium` in the proposal frontmatter and
#    pointing at PRD OQ-2 / Spec Alt(b) for traceability."
#
# Sprint scope (s05-t01): Sr Eng authors the canonize-handoff packet
# under `.yoke/runtime/` for the Mode-tag amendment. The packet is
# staged working memory only — the Orchestrator (canonize-only mode)
# is the entity that ultimately writes to canonical memory; this
# packet is the proposal it consumes.
#
# Path resolution (Phase B round 1, cycle 5):
#   The sprint task initially proposed `.yoke/canonize/<slug>-...md`
#   as the staging surface, but `lib/working-memory/canonize-stage.sh`
#   does NOT mirror a `.yoke/canonize/` directory. Its mkdir block
#   creates: `prds/`, `fixes/`, `specs/`, `sprints/`,
#   `acceptance-criteria/`, `acceptance-contracts/`, `contracts/`,
#   and copies the entire `.yoke/runtime/.` subtree wholesale into
#   `<stage>/runtime/`. The proven prior convention used by every
#   prior Yoke canonize handoff is `.yoke/runtime/.preserve-packet.md`
#   (anchored in `.yoke/specs/2026-04-27-sprint-as-cycle.md`,
#   `.yoke/sprints/2026-04-27-sprint-as-cycle-s04.md`,
#   `.yoke/sprints/2026-05-03-generate-sprints-skill-s04.md`).
#   Sr Staff's Phase A Q4 verdict on cycle 5 explicitly flagged
#   `.yoke/canonize/<slug>-...` as REWORK NEEDED for this same
#   reason. This test follows the actual canonize-stage convention.
#
# PRD OQ-2 / Spec Alt(b) provide the traceability anchors:
#   - PRD OQ-2 — Senior Engineer persona name uniformity (resolved
#     with option (c): two-tier literal name + Mode tag).
#   - Spec Alt(b) — Manufactured persona name "Diagnostic Engineer"
#     for /yoke:fix (the rejected option (b) of OQ-2; cited as
#     traceability for the alternative considered and rejected in
#     favour of the two-tier convention).
#
# Observable conditions tested:
#   (1) The canonize-handoff packet exists under `.yoke/runtime/`.
#       Primary expected path: `.yoke/runtime/.preserve-packet.md`
#       (the proven convention). Fallback discovery: any markdown
#       file under `.yoke/runtime/` (any depth) whose frontmatter
#       declares `type: canonize-handoff-packet`. The packet body
#       must reference the Mode-tag amendment.
#   (2) The packet's frontmatter declares `model_c_impact: medium`
#       (verbatim per AC-005-3).
#   (3) The packet body cites PRD OQ-2 (substring `OQ-2`) AND Spec
#       Alt(b) (one of: substring `Alt(b)`, substring `Alt: Manufactured`,
#       or substring `Manufactured persona name`).
#   (4) The amendment text introduces the Mode-tag convention with
#       `diagnose-first` and `design-first` as the initial vocabulary
#       values (per PRD OQ-2 resolution: open vocabulary, two seed
#       values). The packet must mention "Mode tag" or `**Mode:**`
#       AND both seed values.

set -euo pipefail

# Internal watchdog (per repo testing convention).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

# Resolve repo root from the location of this file:
#   tests/acceptance/<slug>/ac-005-3.test.sh -> ../../..
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=/dev/null
source "$REPO_ROOT/tests/lib/harness.sh"

RUNTIME_DIR="$REPO_ROOT/.yoke/runtime"
PRIMARY_PACKET="$RUNTIME_DIR/.preserve-packet.md"

# ---------------------------------------------------------------------------
# Case (1) — canonize-handoff packet present.
#
# Resolution order:
#   1. Primary path `.yoke/runtime/.preserve-packet.md` (the proven
#      convention used by every prior Yoke canonize handoff).
#   2. Fallback: discover any markdown file under `.yoke/runtime/`
#      whose frontmatter declares `type: canonize-handoff-packet`.
#      If multiple such files exist, prefer one whose body cites the
#      Mode-tag convention; otherwise pick the first match so the
#      remaining cases produce a precise diagnosis instead of a
#      silent skip.
# ---------------------------------------------------------------------------
if [[ ! -d "$RUNTIME_DIR" ]]; then
  err "(1) .yoke/runtime/ directory missing — no working-memory tree to host the canonize-handoff packet"
  harness::summary
fi

PACKET=""
if [[ -f "$PRIMARY_PACKET" ]]; then
  PACKET="$PRIMARY_PACKET"
else
  # Fallback discovery — any md file under .yoke/runtime/ with the
  # canonize-handoff-packet frontmatter type. We include hidden files
  # (-print0 + -name '*.md' covers both visible and dotfiles).
  CANDIDATES=()
  while IFS= read -r -d '' f; do
    if grep -qE '^type:[[:space:]]*"?canonize-handoff-packet"?[[:space:]]*$' "$f" 2>/dev/null; then
      CANDIDATES+=("$f")
    fi
  done < <(find "$RUNTIME_DIR" -type f -name '*.md' -print0 2>/dev/null)

  if [[ "${#CANDIDATES[@]}" -gt 0 ]]; then
    # Prefer Mode-tag-citing candidate.
    for c in "${CANDIDATES[@]}"; do
      if grep -qE 'Mode[ -]?tag|\*\*Mode:\*\*' "$c" 2>/dev/null; then
        PACKET="$c"
        break
      fi
    done
    # Fallback: first candidate.
    if [[ -z "$PACKET" ]]; then
      PACKET="${CANDIDATES[0]}"
    fi
  fi
fi

if [[ -z "$PACKET" || ! -f "$PACKET" ]]; then
  err "(1) canonize-handoff packet not found — expected .yoke/runtime/.preserve-packet.md or any *.md under .yoke/runtime/ with frontmatter type=canonize-handoff-packet"
  harness::summary
fi

# Render packet location relative to repo root for the pass message.
PACKET_REL="${PACKET#$REPO_ROOT/}"
pass "(1) canonize-handoff packet present at $PACKET_REL"

# ---------------------------------------------------------------------------
# Extract frontmatter for case (2).
# Frontmatter is the YAML block bounded by `---` lines at the very top of
# the file (per Yoke working-memory convention). We extract everything
# between the first two `---` lines.
# ---------------------------------------------------------------------------
FRONTMATTER=$(awk '
  BEGIN { in_fm=0; fm_count=0 }
  /^---[[:space:]]*$/ {
    fm_count++
    if (fm_count == 1) { in_fm=1; next }
    if (fm_count == 2) { in_fm=0; exit }
  }
  in_fm { print }
' "$PACKET")

PACKET_BODY=$(awk '
  BEGIN { in_fm=0; fm_count=0 }
  /^---[[:space:]]*$/ {
    fm_count++
    if (fm_count == 1) { in_fm=1; next }
    if (fm_count == 2) { in_fm=0; next }
    print; next
  }
  !in_fm { print }
' "$PACKET")

# ---------------------------------------------------------------------------
# Case (2) — frontmatter declares `model_c_impact: medium`.
#
# The AC-005-3 text fixes the literal: "classified as `model_c_impact:
# medium` in the proposal frontmatter". We accept whitespace tolerance
# around the colon and around the value but pin the verbatim key name
# and the verbatim value `medium` (Model-C governance vocabulary).
# ---------------------------------------------------------------------------
if grep -qE '^[[:space:]]*model_c_impact:[[:space:]]*"?medium"?[[:space:]]*$' <<<"$FRONTMATTER"; then
  pass "(2) packet frontmatter declares model_c_impact: medium"
else
  FM_HEAD=$(printf '%s\n' "$FRONTMATTER" | head -10 | tr '\n' '|')
  err "(2) packet frontmatter missing 'model_c_impact: medium' key/value; frontmatter-head='$FM_HEAD'"
fi

# ---------------------------------------------------------------------------
# Case (3) — packet body cites PRD OQ-2 AND Spec Alt(b) for traceability.
#
# AC-005-3 text fixes "pointing at PRD OQ-2 / Spec Alt(b) for
# traceability". The OQ-2 anchor is verbatim. The Alt(b) anchor is
# tolerant: the spec section is titled `### Alt: Manufactured persona
# name "Diagnostic Engineer" for /yoke:fix (option b of PRD OQ-2)`,
# so we accept any of the documented citation forms.
# ---------------------------------------------------------------------------
if grep -q 'OQ-2' <<<"$PACKET_BODY"; then
  pass "(3a) packet body cites PRD OQ-2"
else
  err "(3a) packet body does not cite 'OQ-2' — PRD traceability anchor missing"
fi

if grep -qE 'Alt\(b\)|Alt:[[:space:]]+Manufactured|Manufactured persona name' <<<"$PACKET_BODY"; then
  pass "(3b) packet body cites Spec Alt(b) (Manufactured persona name 'Diagnostic Engineer' rejected option)"
else
  err "(3b) packet body does not cite Spec Alt(b) / 'Manufactured persona name' — Spec traceability anchor missing"
fi

# ---------------------------------------------------------------------------
# Case (4) — packet introduces the Mode-tag convention with the two seed
# vocabulary values.
#
# Per PRD OQ-2 resolution + Spec § Mode-tag schema: vocabulary is open;
# initial values are `diagnose-first` and `design-first`. The packet
# must (a) name the convention and (b) enumerate both seed values so a
# downstream canonize ratification can land the correct entity content.
# ---------------------------------------------------------------------------
if grep -qE 'Mode[ -]?tag|\*\*Mode:\*\*' <<<"$PACKET_BODY"; then
  pass "(4a) packet body names the Mode-tag convention ('Mode tag' or '**Mode:**' substring)"
else
  err "(4a) packet body does not name the Mode-tag convention ('Mode tag' / '**Mode:**' substring missing)"
fi

if grep -q 'diagnose-first' <<<"$PACKET_BODY" && grep -q 'design-first' <<<"$PACKET_BODY"; then
  pass "(4b) packet body enumerates both seed vocabulary values (diagnose-first, design-first)"
else
  err "(4b) packet body missing one or both seed vocabulary values; expected both 'diagnose-first' and 'design-first'"
fi

harness::summary
