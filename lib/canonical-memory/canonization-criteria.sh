#!/bin/bash
# canonization-criteria.sh — apply the five canonization criteria to working
# memory and emit a structured YAML candidate list.
#
# Usage: canonization-criteria.sh [--working-memory <dir>] [--config <path>]
#
# Defaults:
#   --working-memory  .yoke
#   --config          .yoke/config.yaml
#
# Reads:
#   <working-memory>/contracts.md  — sprint contracts (one Contract block per
#                                    consensus reached during Phase 4)
#   <working-memory>/progress.md   — implementation cycles (read for cycle context)
#   <config>: canonization.repeatability_min, generality_min, stability_min_days
#
# Output (YAML to stdout):
#   candidates:
#     - id: c<n>
#       kind: divergence-pattern | template-refinement | sensor-calibration | other
#       score: <0–100>
#       impact: low | medium | high | regulatory
#       reason: "<why this passes 1–4>"
#       traceability:
#         - "<source: contracts.md#contract-X | progress.md#cycle-N | …>"
#       content_path: "<path inside the canonical repo>"
#       content_excerpt: "<markdown body excerpt>"
#
# Or, when no candidates pass:
#   candidates: []
#   notes: "<reason>"
#
# Performance contract: complete in <5s on a working memory of up to 1000
# Contract blocks. v0.5.0 ships heuristic implementations; Sprint 6 refines
# stability and contradiction detection.
#
# Exit codes:
#   0 — successful run (with or without candidates)
#   2 — usage error

set -euo pipefail

working_memory=".yoke"
config=".yoke/config.yaml"

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --working-memory) working_memory="${2:-.yoke}";        shift 2 ;;
    --config)         config="${2:-.yoke/config.yaml}";    shift 2 ;;
    -h|--help)        sed -n '1,40p' "$0"; exit 0 ;;
    "")               break ;;
    *)                echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

contracts_file="${working_memory}/contracts.md"

if [ ! -f "$contracts_file" ]; then
  printf 'candidates: []\nnotes: "No %s — task did not produce sprint contracts."\n' "$contracts_file"
  exit 0
fi

# All heuristic logic in awk for speed and bash-3 compatibility.
# Heuristic for impact classification (keywords inside topic OR decision):
#   regulatory ← regulatory|gdpr|lgpd|pci|hipaa|soc2|compliance
#   high       ← policy|must|require
#   medium     ← template|convention|naming
#   low        ← default
#
# Non-contradiction (criterion 5): skip the candidate if the decision contains
# relax|remove|skip|disable|bypass|ignore (mirrors orchestrate.sh check-contradiction).

tmp_out="$(mktemp)"
trap 'rm -f "$tmp_out"' EXIT

awk '
function escape(s,    r) {
  r = s
  gsub(/\\/, "\\\\", r)
  gsub(/"/,  "\\\"",  r)
  return r
}

function impact_for(combined) {
  if (combined ~ /regulatory|gdpr|lgpd|pci|hipaa|soc2|compliance/) return "regulatory"
  if (combined ~ /policy|[[:space:]]must[[:space:]]|require/)      return "high"
  if (combined ~ /template|convention|naming/)                     return "medium"
  return "low"
}

function kind_for(combined) {
  if (combined ~ /divergence|conflict/) return "divergence-pattern"
  if (combined ~ /template/)            return "template-refinement"
  if (combined ~ /sensor|calibrat/)     return "sensor-calibration"
  return "other"
}

function contradicts(decision) {
  return (tolower(decision) ~ /relax|remove|skip|disable|bypass|ignore/)
}

function emit_candidate() {
  if (block_id == "") return
  if (contradicts(decision)) {
    block_id = ""; topic=""; decision=""; rationale=""; cycle=""
    return
  }
  count++

  combined = tolower(topic " " decision)
  imp = impact_for(combined)
  knd = kind_for(combined)

  # Score heuristic
  score = 50
  if (cycle != "")     score += 10
  if (rationale != "") score += 10

  printf "  - id: c%d\n", count
  printf "    kind: %s\n", knd
  printf "    score: %d\n", score
  printf "    impact: %s\n", imp
  printf "    reason: \"Sprint contract on %s\"\n", escape(topic)
  printf "    traceability:\n"
  printf "      - \"contracts.md#contract-%s\"\n", escape(block_id)
  if (cycle != "") {
    printf "      - \"progress.md#cycle-%s\"\n", cycle
  }
  printf "    content_path: \"divergences/%s.md\"\n", escape(block_id)
  printf "    content_excerpt: \"%s\"\n", escape(decision)

  block_id = ""; topic=""; decision=""; rationale=""; cycle=""
}

BEGIN {
  block_id = ""; topic = ""; decision = ""; rationale = ""; cycle = ""
  count = 0
}

/^## Contract / {
  emit_candidate()
  block_id = $0
  sub(/^## Contract /, "", block_id)
  next
}

/^## / && !/^## Contract / {
  emit_candidate()
  next
}

/^[[:space:]]*-?[[:space:]]*topic:/ {
  v = $0
  sub(/^[[:space:]]*-?[[:space:]]*topic:[[:space:]]*/, "", v)
  gsub(/^"|"$/, "", v)
  topic = v
  next
}

/^[[:space:]]*-?[[:space:]]*decision:/ {
  v = $0
  sub(/^[[:space:]]*-?[[:space:]]*decision:[[:space:]]*/, "", v)
  gsub(/^"|"$/, "", v)
  decision = v
  next
}

/^[[:space:]]*-?[[:space:]]*rationale:/ {
  v = $0
  sub(/^[[:space:]]*-?[[:space:]]*rationale:[[:space:]]*/, "", v)
  gsub(/^"|"$/, "", v)
  rationale = v
  next
}

/^[[:space:]]*-?[[:space:]]*cycle:/ {
  v = $0
  sub(/^[[:space:]]*-?[[:space:]]*cycle:[[:space:]]*/, "", v)
  gsub(/[^0-9]/, "", v)
  cycle = v
  next
}

END {
  emit_candidate()
  print "__COUNT__" count
}
' "$contracts_file" > "$tmp_out"

# Extract count line and strip it from the output
count=$(grep -m1 '^__COUNT__' "$tmp_out" | sed 's/^__COUNT__//')
sed -i.bak '/^__COUNT__/d' "$tmp_out" 2>/dev/null || sed -i '' '/^__COUNT__/d' "$tmp_out" 2>/dev/null || {
  # GNU sed without -i.bak fallback
  grep -v '^__COUNT__' "$tmp_out" > "${tmp_out}.tmp" && mv "${tmp_out}.tmp" "$tmp_out"
}
rm -f "${tmp_out}.bak" 2>/dev/null || true

if [ "${count:-0}" -eq 0 ]; then
  printf 'candidates: []\nnotes: "No candidates passed criteria 1-5 (most likely all contradicted the Acceptance Contract)."\n'
else
  echo "candidates:"
  cat "$tmp_out"
fi

exit 0
