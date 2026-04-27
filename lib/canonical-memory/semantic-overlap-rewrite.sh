#!/usr/bin/env bash
# semantic-overlap-rewrite.sh — semantic-overlap layer that rewrites the
# cascade-scoring YAML emitted by `canonization-criteria.sh` so contracts
# that resolve the same ambiguity with different surface prose are
# recognised as the same topic. This is the implementation of
# `/yoke:preserve` Phase 3.2's semantic-overlap sub-step (sprint-contract
# -promotion s01-t02). The deterministic floor is preserved verbatim;
# only the values of `occurrences:` and `reason:` may differ between the
# pre-rewrite and post-rewrite YAML.
#
# Usage:
#   semantic-overlap-rewrite.sh --cascade-yaml <path> --verdicts <path>
#
# --cascade-yaml <path>
#     Path to the YAML emitted by canonization-criteria.sh. The shape is
#     documented in canonization-criteria.sh and is consumed verbatim
#     here (the post-rewrite YAML is the same shape — only `occurrences:`
#     and `reason:` may change, plus an additive top-level `notes:`
#     entry on contradictions).
#
# --verdicts <path>
#     Path to a verdict file with one line per topic group. Format:
#         <topic>\t<verdict>\t<reason>
#     where <verdict> ∈ {cohesive, split, contradiction}. The <reason>
#     column is free-form prose; for cohesive groups it MUST reference
#     both originating contracts (FR-2 / Scenario 2 requires this),
#     and for contradictions it cites the contradiction. Topics not
#     listed in the verdict file are treated as deterministic-floor
#     pass-throughs (occurrences: 1 candidates need no verdict; this
#     is FR-2's "no new candidates" invariant).
#
#     This file is the load-bearing decoupling point: at runtime
#     `/yoke:preserve` Phase 3.2 produces it from a live LLM judge,
#     but the unit test (semantic-overlap-rewrite.test.sh) supplies
#     a canned file so the YAML-rewriting logic is provable
#     independent of LLM behaviour.
#
# Output (stdout, YAML):
#   candidates:
#     - id: c<n>
#       …                        # same shape as input, modulo:
#       occurrences: <int>       # rewritten per the rules below
#       reason: "<string>"       # rewritten on cohesive groups
#   notes:                       # only emitted when ≥ 1 contradiction
#     - "<verdict reason>"
#
# Rules:
#   1. Candidates with `occurrences == 1` pass through unchanged
#      (deterministic-floor invariant — no new candidates, FR-2).
#   2. Candidates with `occurrences ≥ 2` are grouped by their verbatim
#      `topic:` string and the verdict for that topic is consulted:
#        cohesive      → one merged candidate with occurrences: <count>
#                        and reason: <verdict reason>; member candidates
#                        are dissolved.
#        split         → each member is re-emitted with occurrences
#                        decremented to 1; the group is dissolved.
#        contradiction → each member is re-emitted with occurrences
#                        decremented to 1 (split semantics) AND a
#                        top-level `notes:` entry is added citing the
#                        contradiction (FR-8 surface — Trigger 5
#                        synchronous ratification).
#   3. A topic with occurrences ≥ 2 but no verdict in the verdicts file
#      is treated as `split` by default (conservative pass-through —
#      the LLM did not certify cohesion).
#   4. The legacy single-`contracts.md` path produces no occurrences ≥ 2
#      groups by construction (single source = single occurrence) so
#      this layer is a no-op for the legacy fixture; FR-10 (legacy
#      byte-for-byte regression) is preserved by structural isolation.
#
# Exit codes:
#   0 — successful rewrite
#   2 — usage error
#   3 — input file missing or unreadable

set -euo pipefail

cascade_yaml=""
verdicts=""

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --cascade-yaml) cascade_yaml="${2:-}";  shift 2 ;;
    --verdicts)     verdicts="${2:-}";      shift 2 ;;
    -h|--help)      sed -n '1,70p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$cascade_yaml" ] || [ ! -f "$cascade_yaml" ]; then
  echo "semantic-overlap-rewrite: --cascade-yaml is required and must exist" >&2
  exit 3
fi
if [ -z "$verdicts" ] || [ ! -f "$verdicts" ]; then
  echo "semantic-overlap-rewrite: --verdicts is required and must exist" >&2
  exit 3
fi

# Single awk pass over the cascade YAML: collects each candidate as a
# logical block (the leading `  - id:` line plus its indented children
# until the next `  - id:` or EOF), keyed by an extracted topic (read
# off the `reason: "Sprint contract on <topic>"` line that
# canonization-criteria.sh emits) and `occurrences:` value. After
# parse, walks the verdicts file to label each occurrences ≥ 2 group,
# then re-emits candidates per the rules documented above.
#
# Note on grouping key: canonization-criteria.sh does not emit a
# standalone `topic:` line; the topic is encoded inside the `reason:
# "Sprint contract on <topic>"` line. The rewriter strips that prefix
# so the verdicts file keys verbatim on the topic string the cascade
# saw in the source contracts.

awk -v verdicts_file="$verdicts" '
function rstrip(s) { sub(/[[:space:]]+$/, "", s); return s }

function load_verdicts(    line, n, parts) {
  while ((getline line < verdicts_file) > 0) {
    if (line ~ /^[[:space:]]*$/) continue
    if (line ~ /^[[:space:]]*#/) continue
    n = split(line, parts, "\t")
    if (n < 2) continue
    t = parts[1]
    v = parts[2]
    r = (n >= 3) ? parts[3] : ""
    verdict[t] = v
    verdict_reason[t] = r
  }
  close(verdicts_file)
}

function flush_block(    t, occ) {
  if (cur_id == "") return
  blocks_total++
  b_id[blocks_total]    = cur_id
  b_topic[blocks_total] = cur_topic
  b_occ[blocks_total]   = (cur_occ == "") ? 1 : cur_occ + 0
  b_body[blocks_total]  = cur_body
  cur_id = ""; cur_topic = ""; cur_occ = ""; cur_body = ""
}

BEGIN {
  load_verdicts()
  in_candidates = 0
  cur_id = ""; cur_topic = ""; cur_occ = ""; cur_body = ""
  blocks_total = 0
}

# Top-level marker. Anything before `candidates:` is preamble we drop
# (the canonization-criteria.sh output never has any). When the input
# contains `candidates: []` we still want the rewriter to be a no-op.
/^candidates:[[:space:]]*\[\][[:space:]]*$/ {
  empty_candidates = 1
  in_candidates = 1
  next
}
/^candidates:[[:space:]]*$/ {
  in_candidates = 1
  next
}

in_candidates == 0 { next }

# Start of a new candidate block.
/^[[:space:]]*-[[:space:]]+id:[[:space:]]*/ {
  flush_block()
  cur_id = $0
  sub(/^[[:space:]]*-[[:space:]]+id:[[:space:]]*/, "", cur_id)
  cur_body = $0 "\n"
  next
}

# Reason line — extract the topic from the canonization-criteria.sh
# convention `reason: "Sprint contract on <topic>"`. The topic is the
# post-prefix substring; that is the grouping key the verdicts file
# keys on. The line itself is preserved verbatim in the body.
/^[[:space:]]+reason:[[:space:]]*/ {
  v = $0
  sub(/^[[:space:]]+reason:[[:space:]]*/, "", v)
  gsub(/^"|"$/, "", v)
  # Strip the cascade-script prefix to recover the underlying topic.
  if (index(v, "Sprint contract on ") == 1) {
    cur_topic = substr(v, length("Sprint contract on ") + 1)
  } else {
    cur_topic = v
  }
  cur_body = cur_body $0 "\n"
  next
}

# Occurrences line — capture integer.
/^[[:space:]]+occurrences:[[:space:]]*/ {
  v = $0
  sub(/^[[:space:]]+occurrences:[[:space:]]*/, "", v)
  gsub(/[^0-9]/, "", v)
  cur_occ = v
  cur_body = cur_body $0 "\n"
  next
}

# Any other line that belongs to the current block — accumulate into
# the body. Stop at top-level keys (they would be `candidates:` / `notes:`
# at column 0, but in the input there should not be any after the
# `candidates:` opener).
in_candidates == 1 {
  if ($0 ~ /^[^[:space:]]/) {
    flush_block()
    in_candidates = 0
    next
  }
  cur_body = cur_body $0 "\n"
  next
}

END {
  flush_block()

  # Build per-topic group membership for occurrences ≥ 2.
  for (i = 1; i <= blocks_total; i++) {
    if (b_occ[i] >= 2) {
      t = b_topic[i]
      if (group_first[t] == "") {
        group_first[t] = i
        group_count[t] = 1
        group_members[t] = i
      } else {
        group_count[t]++
        group_members[t] = group_members[t] SUBSEP i
      }
    }
  }

  # Re-emit candidates. Preserve encounter order so the output is
  # deterministic (FR-1 traceability discipline).
  print "candidates:"
  emitted_idx = 0
  notes_count = 0

  for (i = 1; i <= blocks_total; i++) {
    if (b_occ[i] < 2) {
      # Pass-through. Re-emit body verbatim.
      emitted_idx++
      printf "%s", rewrite_id(b_body[i], emitted_idx)
      continue
    }

    # occurrences ≥ 2 — consult verdict.
    t = b_topic[i]
    v = (verdict[t] == "") ? "split" : verdict[t]

    if (v == "cohesive") {
      # Merge: emit once for the first member; skip later members.
      if (group_first[t] != i) continue
      emitted_idx++
      body = b_body[i]
      # Rewrite the reason line if a verdict reason is provided.
      if (verdict_reason[t] != "") {
        body = rewrite_reason(body, verdict_reason[t])
      }
      # Occurrences stays at the cohesive group count.
      printf "%s", rewrite_id(body, emitted_idx)
    } else if (v == "split") {
      # Decrement to 1 and re-emit each member separately.
      emitted_idx++
      body = b_body[i]
      body = rewrite_occurrences(body, 1)
      printf "%s", rewrite_id(body, emitted_idx)
    } else if (v == "contradiction") {
      # Same emission rule as split (decrement to 1) but accumulate a
      # top-level note. Only attach the note once per topic group.
      emitted_idx++
      body = b_body[i]
      body = rewrite_occurrences(body, 1)
      printf "%s", rewrite_id(body, emitted_idx)
      if (notes_done[t] == 0) {
        notes_count++
        notes[notes_count] = (verdict_reason[t] != "") \
          ? verdict_reason[t] \
          : ("Hard contradiction detected in topic group: " t)
        notes_done[t] = 1
      }
    } else {
      # Unknown verdict — conservative pass-through (split semantics).
      emitted_idx++
      body = b_body[i]
      body = rewrite_occurrences(body, 1)
      printf "%s", rewrite_id(body, emitted_idx)
    }
  }

  if (notes_count > 0) {
    print "notes:"
    for (k = 1; k <= notes_count; k++) {
      printf "  - \"%s\"\n", escape_yaml(notes[k])
    }
  }
}

function escape_yaml(s,    r) {
  r = s
  gsub(/\\/, "\\\\", r)
  gsub(/"/,  "\\\"",  r)
  return r
}

# rewrite_occurrences(body, n) — replace the `    occurrences: <int>`
# line in the body with `    occurrences: <n>`. The surrounding
# indentation matches canonization-criteria.shs emission (4 spaces).
function rewrite_occurrences(body, n,    out, lines, count, k) {
  count = split(body, lines, "\n")
  out = ""
  for (k = 1; k <= count; k++) {
    if (lines[k] ~ /^[[:space:]]+occurrences:[[:space:]]*/) {
      out = out "    occurrences: " n
    } else {
      out = out lines[k]
    }
    if (k < count) out = out "\n"
  }
  return out
}

# rewrite_reason(body, reason) — replace the `    reason: "..."` line.
function rewrite_reason(body, reason,    out, lines, count, k) {
  count = split(body, lines, "\n")
  out = ""
  for (k = 1; k <= count; k++) {
    if (lines[k] ~ /^[[:space:]]+reason:[[:space:]]*/) {
      out = out "    reason: \"" escape_yaml(reason) "\""
    } else {
      out = out lines[k]
    }
    if (k < count) out = out "\n"
  }
  return out
}

# rewrite_id(body, idx) — rewrite the leading `  - id: c<n>` so the
# emitted YAML keeps a contiguous c1..cN id sequence after merges.
function rewrite_id(body, idx,    out, lines, count, k) {
  count = split(body, lines, "\n")
  out = ""
  for (k = 1; k <= count; k++) {
    if (lines[k] ~ /^[[:space:]]*-[[:space:]]+id:[[:space:]]*/) {
      out = out "  - id: c" idx
    } else {
      out = out lines[k]
    }
    if (k < count) out = out "\n"
  }
  return out
}
' "$cascade_yaml"

exit 0
