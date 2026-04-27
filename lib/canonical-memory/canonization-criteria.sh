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
#   <working-memory>/contracts.md       — legacy single-file sprint contracts
#                                         (one Contract block per consensus
#                                          reached during Phase 4)
#   <working-memory>/contracts/*.md     — per-task sprint-contract archives
#                                         (added by sprint-contract-promotion
#                                          s01-t01 — additive cross-archive
#                                          enumeration; the deterministic
#                                          floor that admits a recurring
#                                          contract into cascade scoring)
#   <working-memory>/progress.md        — implementation cycles (read for
#                                         cycle context)
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
#       occurrences: <int>           # cross-archive count of byte-identical
#                                    # `topic:` strings (1 = single-occurrence;
#                                    # ≥ 2 = recurring across archives, the
#                                    # deterministic floor for promotion)
#       content_path: "<path inside the canonical repo>"
#       content_excerpt: "<markdown body excerpt>"
#
# Or, when no candidates pass:
#   candidates: []
#   notes: "<reason>"
#
# Performance contract: complete in <5s on a working memory of up to 1000
# Contract blocks across 50 archives. v0.5.0 ships heuristic implementations;
# Sprint 6 refines stability and contradiction detection.
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
    -h|--help)        sed -n '1,50p' "$0"; exit 0 ;;
    "")               break ;;
    *)                echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------
# Enumerate contract sources, in deterministic order:
#   1. The legacy single-file path (`<working-memory>/contracts.md`),
#      preserved byte-for-byte for backward compatibility — emitted
#      first when present.
#   2. Per-task archives under `<working-memory>/contracts/*.md`, in
#      lexical order. Lexical sort over slug-prefixed filenames gives
#      chronological ordering by construction (slugs are
#      `<YYYY-MM-DD>-<kebab>`).
#
# Both shapes coexist: the legacy single-file path remains the v0
# input; the per-task glob is additive. The cross-archive
# `occurrences:` count is computed across the union of both.
# ---------------------------------------------------------------------
contracts_file="${working_memory}/contracts.md"
contracts_dir="${working_memory}/contracts"

inputs=()
if [ -f "$contracts_file" ]; then
  inputs+=("$contracts_file")
fi
if [ -d "$contracts_dir" ]; then
  # Use a portable sorted glob expansion (no GNU `find -print0`).
  while IFS= read -r f; do
    [ -n "$f" ] && inputs+=("$f")
  done < <(ls -1 "$contracts_dir"/*.md 2>/dev/null | sort)
fi

if [ "${#inputs[@]}" -eq 0 ]; then
  printf 'candidates: []\nnotes: "No %s and no %s/ archives — task did not produce sprint contracts."\n' \
    "$contracts_file" "$contracts_dir"
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
#
# Cross-archive `occurrences:` counter (s01-t01): a single awk pass over the
# union of inputs collects every block into parallel arrays keyed by a
# monotonic block index, plus an `occurs[topic]` count and a per-topic
# `refs[topic]` list of `<source-file>#contract-<id>` references. At END we
# emit candidates in encounter order; each candidate carries
# `occurrences: <count>` and (when occurrences ≥ 2) the cross-archive refs
# appended to its `traceability:` list.

tmp_out="$(mktemp)"
trap 'rm -f "$tmp_out"' EXIT

awk -v working_memory="$working_memory" '
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

# rel_source(path) — collapse <working_memory>/<x> to either
#   "contracts.md"                  (legacy single-file path)
#   "contracts/<basename>"          (per-task archive)
# so the emitted traceability strings stay stable across fixtures and
# match the legacy golden output byte-for-byte.
function rel_source(path,    p, base) {
  p = path
  # Strip a leading "<working_memory>/" if present.
  if (index(p, working_memory "/") == 1) {
    p = substr(p, length(working_memory) + 2)
  }
  return p
}

function stash_block(    src) {
  if (block_id == "") return
  if (contradicts(decision)) {
    block_id = ""; topic = ""; decision = ""; rationale = ""; cycle = ""
    block_source = ""
    return
  }

  blocks_total++
  b_id[blocks_total]        = block_id
  b_topic[blocks_total]     = topic
  b_decision[blocks_total]  = decision
  b_rationale[blocks_total] = rationale
  b_cycle[blocks_total]     = cycle
  b_source[blocks_total]    = block_source

  # Cross-archive topic counter. The key is the verbatim `topic:` string.
  occurs[topic]++
  src = rel_source(block_source) "#contract-" block_id
  if (refs[topic] == "") {
    refs[topic] = src
  } else {
    refs[topic] = refs[topic] SUBSEP src
  }

  block_id = ""; topic = ""; decision = ""; rationale = ""; cycle = ""
  block_source = ""
}

BEGIN {
  block_id = ""; topic = ""; decision = ""; rationale = ""; cycle = ""
  block_source = ""
  blocks_total = 0
  current_file = ""
}

# Track the source file each block came from. FILENAME changes between
# inputs; flush the in-progress block at file boundaries so a contract
# block never spans two archives (it cannot, by construction; this is a
# defensive guard).
FNR == 1 {
  if (current_file != "" && current_file != FILENAME) {
    stash_block()
  }
  current_file = FILENAME
}

/^## Contract / {
  stash_block()
  block_id = $0
  sub(/^## Contract /, "", block_id)
  block_source = FILENAME
  next
}

/^## / && !/^## Contract / {
  stash_block()
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
  stash_block()

  # Emit candidates in encounter order.
  count = 0
  for (i = 1; i <= blocks_total; i++) {
    count++

    t  = b_topic[i]
    d  = b_decision[i]
    r  = b_rationale[i]
    cy = b_cycle[i]
    bid = b_id[i]
    src = b_source[i]

    combined = tolower(t " " d)
    imp = impact_for(combined)
    knd = kind_for(combined)

    score = 50
    if (cy != "") score += 10
    if (r  != "") score += 10

    occ = occurs[t] + 0

    printf "  - id: c%d\n", count
    printf "    kind: %s\n", knd
    printf "    score: %d\n", score
    printf "    impact: %s\n", imp
    printf "    reason: \"Sprint contract on %s\"\n", escape(t)
    printf "    traceability:\n"

    # Legacy traceability line: the originating block keyed by
    # block-id only, preserved byte-for-byte for the legacy fixture.
    # When the contract came from the legacy single-file path we keep
    # the original `contracts.md#contract-<id>` shape (no path
    # prefix). When it came from a per-task archive we use the
    # archive-relative path.
    rel = rel_source(src)
    if (rel == "contracts.md") {
      printf "      - \"contracts.md#contract-%s\"\n", escape(bid)
    } else {
      printf "      - \"%s#contract-%s\"\n", escape(rel), escape(bid)
    }
    if (cy != "") {
      printf "      - \"progress.md#cycle-%s\"\n", cy
    }

    # Cross-archive references — only listed when the topic recurred,
    # to keep the legacy single-file fixture byte-for-byte stable
    # except for the additive `occurrences: 1` line.
    if (occ >= 2) {
      n = split(refs[t], parts, SUBSEP)
      for (j = 1; j <= n; j++) {
        # Skip the originating reference (already emitted above) to
        # avoid duplication when the originating archive happens to
        # match its own back-reference.
        own_rel = rel
        if (own_rel == "contracts.md") {
          own_ref = "contracts.md#contract-" bid
        } else {
          own_ref = own_rel "#contract-" bid
        }
        if (parts[j] != own_ref) {
          printf "      - \"%s\"\n", escape(parts[j])
        }
      }
    }

    printf "    occurrences: %d\n", occ
    printf "    content_path: \"divergences/%s.md\"\n", escape(bid)
    printf "    content_excerpt: \"%s\"\n", escape(d)
  }

  print "__COUNT__" count
}
' "${inputs[@]}" > "$tmp_out"

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
