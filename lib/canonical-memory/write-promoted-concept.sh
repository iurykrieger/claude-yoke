#!/usr/bin/env bash
# write-promoted-concept.sh — write a promoted concept entity (and its
# host-actor backlink) to the canonical-memory tree.
#
# Implementation of sprint-contract-promotion s01-t03 — the materialise
# step that turns a cascade-admitted candidate flagged with
# `kind: sprint-contract-promotion` into a concrete file pair:
#
#   <canonical-memory>/concepts/<llm-summarized-slug>.md   (new)
#   <canonical-memory>/actors/<host-actor>.md              (created or
#                                                           appended)
#
# The concept entity carries the mandatory rippability frontmatter per
# [[yoke-pattern-memory-model]] (`ratified`, `model_calibrated_against`,
# `last_validated`, `traceability`, `impact_level`) plus the binding
# Acceptance-Contract fields for Scenario 3 / FR-3 / FR-5:
#
#   type, name, aliases, description, status, ratified,
#   model_calibrated_against, last_validated, traceability, impact_level,
#   tags (MUST include both `kind/contract` and `yoke-framework`),
#   applies_to (MUST list exactly the resolved host-actor name),
#   depends_on, supersedes, contradicts_with, project
#
# The actor file gains a `## Recent Activity` section (created if absent)
# with a line `- <YYYY-MM-DD> — [[<concept-slug>]] — <summary>` — the
# bidirectional invariant that the FR-4 / Scenario 4 sensors enforce.
#
# Usage:
#   write-promoted-concept.sh \
#       --candidate <yaml-block-path> \
#       --host-actor <actor-name> \
#       --canonical-memory <dir> \
#       [--topic <string>] \
#       [--summary <string>] \
#       [--ratified <ISO-8601>] \
#       [--model <model-id>] \
#       [--project <project-slug>]
#
# --candidate <path>
#     Path to a YAML file containing a single cascade-candidate block
#     (the `- id: cN` … `content_excerpt: …` lines emitted by
#     canonization-criteria.sh, optionally rewritten by
#     semantic-overlap-rewrite.sh). Used to extract `impact:`,
#     `traceability:`, `reason:`, `content_excerpt:`, and the topic
#     (recovered from `reason: "Sprint contract on <topic>"` per the
#     existing convention).
#
# --host-actor <name>
#     The canonical actor name for the host project (resolved by the
#     caller via `lib/working-memory/host-actor.sh::wm_host_actor_name`).
#     Used as `applies_to:` and as the actor file basename.
#
# --canonical-memory <dir>
#     The output directory. The helper writes
#     <dir>/concepts/<slug>.md and <dir>/actors/<host-actor>.md.
#
# --topic <string>
#     Optional override for the topic prose. When omitted, the helper
#     extracts the topic from the candidate YAML's `reason: "Sprint
#     contract on <topic>"` line.
#
# --summary <string>
#     Optional one-line summary attached to the actor backlink line. When
#     omitted, the helper synthesises one from the candidate's
#     `content_excerpt:` line, truncated to 80 chars.
#
# --ratified <ISO-8601>
#     Optional override for the `ratified:` and `last_validated:` fields.
#     Default = today's date in `YYYY-MM-DD` form.
#
# --model <model-id>
#     Optional override for `model_calibrated_against:`. Default =
#     `claude-opus-4-7[1m]` (the model the cohesive judgment in t02 ran
#     against, per the AC's calibration metadata note).
#
# --project <project-slug>
#     Optional `project:` frontmatter value. Default = the host-actor
#     name (sufficient for self-referential framework promotions).
#
# Slug-summarisation hook:
#   The helper calls a slug-summarisation function to produce the
#   concept filename. By default it derives a deterministic kebab-case
#   slug from the topic (≤50 chars). Tests pin the function to a stub
#   via the `YOKE_PROMOTED_CONCEPT_SLUG_FN` environment variable: when
#   set, the helper invokes
#       "$YOKE_PROMOTED_CONCEPT_SLUG_FN" <topic> <attempt>
#   and reads stdout as the slug. <attempt> is 0 on first try, 1..4 on
#   retry. The attempt arg lets stubs simulate either retry-and-succeed
#   or retry-to-exhaustion behaviour.
#
# Slug collision rule (FR-6):
#   On `concepts/<slug>.md` already-present, the helper retries
#   summarisation up to 5 times (attempts 0..4). On exhaustion (every
#   attempt collides), the helper exits non-zero (4) with a diagnostic
#   citing the colliding slug.
#
# Actor-create rule (FR-7):
#   When `actors/<host-actor>.md` does not exist, the helper creates it
#   from `templates/canonical/actor/_template.md` with placeholders
#   filled (type=actor, name=<host-actor>, status=active, today's
#   updated_at, etc.) and seeds the body with the `## Recent Activity`
#   section containing the backlink line.
#
# Exit codes:
#   0 — concept and actor backlink written
#   2 — usage error
#   3 — input file missing / unreadable / candidate parse failure
#   4 — slug-collision retry exhausted (5 attempts, all collided)
#
# Source PRD/Spec:
#   .yoke/prds/2026-04-27-sprint-contract-promotion.md
#   .yoke/specs/2026-04-27-sprint-contract-promotion.md (s01-t03)
#   .yoke/acceptance-contracts/2026-04-27-sprint-contract-promotion.md
#       (Scenario 3 — promoted-concept write produces a complete entity
#        with bidirectional links and rippability frontmatter)

set -euo pipefail

# Resolve plugin root from this script: lib/canonical-memory/ → ../..
_WPC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_WPC_PLUGIN_ROOT="$(cd "${_WPC_DIR}/../.." && pwd)"

candidate=""
host_actor=""
canonical_memory=""
topic_override=""
summary_override=""
ratified_override=""
model_override=""
project_override=""

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --candidate)         candidate="${2:-}";          shift 2 ;;
    --host-actor)        host_actor="${2:-}";         shift 2 ;;
    --canonical-memory)  canonical_memory="${2:-}";   shift 2 ;;
    --topic)             topic_override="${2:-}";     shift 2 ;;
    --summary)           summary_override="${2:-}";   shift 2 ;;
    --ratified)          ratified_override="${2:-}";  shift 2 ;;
    --model)             model_override="${2:-}";     shift 2 ;;
    --project)           project_override="${2:-}";   shift 2 ;;
    -h|--help)           sed -n '1,90p' "$0"; exit 0 ;;
    *) echo "write-promoted-concept: unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$candidate" ] || [ ! -f "$candidate" ]; then
  echo "write-promoted-concept: --candidate is required and must exist (got: '$candidate')" >&2
  exit 3
fi
if [ -z "$host_actor" ]; then
  echo "write-promoted-concept: --host-actor is required" >&2
  exit 2
fi
if [ -z "$canonical_memory" ]; then
  echo "write-promoted-concept: --canonical-memory is required" >&2
  exit 2
fi

mkdir -p "${canonical_memory}/concepts" "${canonical_memory}/actors"

# ----------------------------------------------------------------------
# Parse the candidate YAML for the fields we need.
# ----------------------------------------------------------------------
_extract_field() {
  # _extract_field <key>
  #   Echoes the first occurrence of `<key>: <value>` in the candidate
  #   block, with surrounding quotes stripped.
  local key="$1"
  awk -v key="$key" '
    {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]+/, "", line)
      sub(/^[[:space:]]+/, "", line)
      if (index(line, key ":") == 1) {
        v = substr(line, length(key) + 2)
        sub(/^[[:space:]]+/, "", v)
        sub(/[[:space:]]+$/, "", v)
        if (v ~ /^".*"$/) v = substr(v, 2, length(v) - 2)
        print v
        exit
      }
    }
  ' "$candidate"
}

_extract_traceability() {
  # _extract_traceability — echoes one path per line for every entry under
  # the `traceability:` block. Captures the indented `- "<path>"` lines
  # until the next non-indented top-level key.
  awk '
    BEGIN { in_trace = 0 }
    /^[[:space:]]+traceability:[[:space:]]*$/ { in_trace = 1; next }
    in_trace == 1 {
      if ($0 ~ /^[[:space:]]+-[[:space:]]+/) {
        v = $0
        sub(/^[[:space:]]+-[[:space:]]+/, "", v)
        sub(/[[:space:]]+$/, "", v)
        if (v ~ /^".*"$/) v = substr(v, 2, length(v) - 2)
        print v
        next
      }
      # Indented but not a list item, or de-dent — leave the block.
      in_trace = 0
    }
  ' "$candidate"
}

reason="$(_extract_field "reason" || true)"
impact="$(_extract_field "impact" || true)"
content_excerpt="$(_extract_field "content_excerpt" || true)"

# Recover topic from `reason: "Sprint contract on <topic>"` convention.
topic=""
if [ -n "$topic_override" ]; then
  topic="$topic_override"
elif [ -n "$reason" ]; then
  case "$reason" in
    "Sprint contract on "*) topic="${reason#Sprint contract on }" ;;
    *) topic="$reason" ;;
  esac
fi

if [ -z "$topic" ]; then
  echo "write-promoted-concept: could not derive topic from --candidate (reason line missing)" >&2
  exit 3
fi

# Defaults.
today="$(date -u +%Y-%m-%d)"
ratified="${ratified_override:-$today}"
model="${model_override:-claude-opus-4-7[1m]}"
project="${project_override:-$host_actor}"
impact="${impact:-low}"

# Summary for the actor backlink line.
summary="${summary_override:-$content_excerpt}"
if [ -z "$summary" ]; then
  summary="$topic"
fi
# Trim summary to ≤80 chars for the activity line.
if [ ${#summary} -gt 80 ]; then
  summary="${summary:0:77}..."
fi

# ----------------------------------------------------------------------
# Slug-summarisation hook.
# ----------------------------------------------------------------------
# default_slug_fn <topic> <attempt>
#   Deterministic kebab transform of <topic>, ≤50 chars after the slug,
#   with attempt suffix when attempt > 0 to avoid trivial self-collision.
default_slug_fn() {
  local t="$1"
  local attempt="${2:-0}"
  local s
  s="$(printf '%s' "$t" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -e 's/[^a-z0-9]\{1,\}/-/g' \
              -e 's/^-//' \
              -e 's/-$//')"
  # Truncate to 50 chars before suffix.
  if [ ${#s} -gt 50 ]; then
    s="${s:0:50}"
    # Avoid trailing `-` after truncation.
    s="${s%-}"
  fi
  if [ "$attempt" -gt 0 ]; then
    s="${s}-${attempt}"
  fi
  printf '%s' "$s"
}

resolve_slug() {
  local t="$1"
  local attempt="$2"
  if [ -n "${YOKE_PROMOTED_CONCEPT_SLUG_FN:-}" ]; then
    "$YOKE_PROMOTED_CONCEPT_SLUG_FN" "$t" "$attempt"
  else
    default_slug_fn "$t" "$attempt"
  fi
}

# Retry up to 5 attempts (FR-6).
slug=""
attempt=0
final_slug_path=""
while [ "$attempt" -lt 5 ]; do
  candidate_slug="$(resolve_slug "$topic" "$attempt")"
  if [ -z "$candidate_slug" ]; then
    echo "write-promoted-concept: slug fn returned empty string on attempt $attempt" >&2
    exit 3
  fi
  candidate_path="${canonical_memory}/concepts/${candidate_slug}.md"
  if [ ! -e "$candidate_path" ]; then
    slug="$candidate_slug"
    final_slug_path="$candidate_path"
    break
  fi
  attempt=$((attempt + 1))
done

if [ -z "$slug" ]; then
  echo "write-promoted-concept: slug-collision retry exhausted (5 attempts) — last colliding slug: '$candidate_slug'" >&2
  exit 4
fi

# ----------------------------------------------------------------------
# Build the concept frontmatter + body.
# ----------------------------------------------------------------------
# Concept name = topic verbatim; description is one-liner; aliases carry
# the topic prose verbatim per the Tech Spec.
concept_name="$topic"
description="$reason"
if [ -z "$description" ]; then
  description="Promoted concept for: $topic"
fi

# Build traceability list (YAML array entries, one per line).
trace_yaml=""
trace_paths_file="$(mktemp)"
trap 'rm -f "$trace_paths_file"' EXIT
_extract_traceability > "$trace_paths_file"
if [ -s "$trace_paths_file" ]; then
  trace_yaml="$(awk '{ printf "  - \"%s\"\n", $0 }' "$trace_paths_file")"
else
  trace_yaml="  - \"<no-traceability-recovered>\""
fi

# Compose the concept file.
cat > "$final_slug_path" <<EOF
---
type: concept
name: "${concept_name}"
aliases:
  - "${topic}"
description: "${description}"
status: active
ratified: "${ratified}"
model_calibrated_against: "${model}"
last_validated: "${ratified}"
traceability:
${trace_yaml}
impact_level: "${impact}"
tags:
  - type/concept
  - kind/contract
  - yoke-framework
  - status/active
applies_to:
  - "${host_actor}"
depends_on: []
supersedes: []
contradicts_with: []
project: "${project}"
updated_at: ${ratified}
updated_by: "yoke-preserve@write-promoted-concept"
---

# ${concept_name}

> ${description}

## Description

${reason}

## Originating contracts

EOF

# Append originating contracts (the traceability list, formatted as a
# markdown bullet list with bare wikilink-style references).
if [ -s "$trace_paths_file" ]; then
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    printf -- '- %s\n' "$path" >> "$final_slug_path"
  done < "$trace_paths_file"
else
  printf -- '- <no-traceability-recovered>\n' >> "$final_slug_path"
fi

cat >> "$final_slug_path" <<EOF

## Where it applies

- [[${host_actor}]] — host project actor for this promoted concept.

## Related

EOF

# ----------------------------------------------------------------------
# Actor backlink (create-or-append).
# ----------------------------------------------------------------------
actor_path="${canonical_memory}/actors/${host_actor}.md"
activity_line="- ${ratified} — [[${slug}]] — ${summary}"

if [ ! -f "$actor_path" ]; then
  # FR-7 — create the actor entity from the canonical actor template.
  template="${_WPC_PLUGIN_ROOT}/templates/canonical/actor/_template.md"
  if [ ! -f "$template" ]; then
    echo "write-promoted-concept: actor template missing at $template" >&2
    exit 3
  fi
  # Render the template with `name` filled and a stub status. Strip the
  # template guidance comments + the demo "Actor Name" header so the
  # rendered file has a clean starting point. We keep the rippability +
  # graph-relationship blocks intact (they are required by the entity
  # schema) and tack on a `## Recent Activity` section containing the
  # backlink at the bottom.
  awk -v name="$host_actor" -v today="$ratified" '
    /^name: ""$/        { print "name: \"" name "\""; next }
    /^status: ""/       { print "status: \"active\""; next }
    /^updated_at: YYYY-MM-DD$/ { print "updated_at: " today; next }
    /^updated_by: ""$/  { print "updated_by: \"yoke-preserve@write-promoted-concept\""; next }
    { print }
  ' "$template" > "$actor_path"
  printf '\n## Recent Activity\n\n%s\n' "$activity_line" >> "$actor_path"
else
  # Append-only: ensure `## Recent Activity` exists, then append the line.
  if grep -q '^## Recent Activity[[:space:]]*$' "$actor_path"; then
    # Append after the existing section header (at EOF for simplicity —
    # body order doesn't matter for the bidirectional invariant).
    printf '%s\n' "$activity_line" >> "$actor_path"
  else
    printf '\n## Recent Activity\n\n%s\n' "$activity_line" >> "$actor_path"
  fi
fi

# ----------------------------------------------------------------------
# Report success.
# ----------------------------------------------------------------------
printf 'concept: %s\n' "$final_slug_path"
printf 'actor: %s\n'   "$actor_path"
printf 'slug: %s\n'    "$slug"
printf 'host_actor: %s\n' "$host_actor"

exit 0
