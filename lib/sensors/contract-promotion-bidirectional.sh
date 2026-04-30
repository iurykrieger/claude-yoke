#!/usr/bin/env bash
# Sensor: bidirectional-link invariant between every promoted concept
# (`kind/contract` + `yoke-framework`) and every actor named in its
# `applies_to:` list.
#
# Implementation of sprint-contract-promotion s01-t04 — the standing-
# guard check that the helper-time invariant guaranteed by
# `lib/canonical-memory/write-promoted-concept.sh` continues to hold
# after a `/yoke:canonize`, `/bedrock:compress`, or hand edit.
#
# Invariants asserted (per [[yoke-pattern-memory-model]]):
#
#   1. Forward edge — every concept under `concepts/` whose frontmatter
#      `tags:` contains BOTH `yoke-framework` AND `kind/contract`,
#      parses its `applies_to:` YAML list. For every actor name in that
#      list, the file `actors/<actor-name>.md` MUST exist AND its body
#      MUST contain at least one bare wikilink `[[<concept-slug>]]`
#      where `<concept-slug>` is the concept's filename without the
#      `.md` extension.
#
#   2. Reverse edge — every file under `actors/` is scanned for bare
#      wikilinks. For every wikilink whose target resolves to a
#      `concepts/<target>.md` file whose frontmatter `tags:` contains
#      `kind/contract`, that concept's `applies_to:` MUST contain the
#      actor's name.
#
# Output (per [[yoke-pattern-sensors]]'s structured-output rule):
#   each violation is a YAML block with `id` (the concept or actor
#   filename), `location` (file path), `correction_instruction`
#   (concrete fix: which file to edit and what link to add), and
#   `reference` (a wikilink to [[yoke-pattern-memory-model]] for the
#   bidirectional rule). Success is silent (empty stdout, exit 0).
#   Any violation → exit non-zero (1).
#
# Canonical-memory resolution chain:
#   1. `--canonical-memory <dir>` flag (explicit; used by tests).
#   2. `YOKE_MEMORY_PATH` env var (set by callers that already invoked
#      lib/canonical-memory/resolve-memory.sh).
#   3. Fallback: source `lib/canonical-memory/resolve-memory.sh` from
#      the plugin root and call `yoke_resolve_memory`.
#
# Source: .yoke/acceptance-contracts/2026-04-27-sprint-contract-promotion.md
#   Scenario 4 / FR-4 / FR-9. Default tier `cheap` (computational
#   sensor, O(N) over concepts/ + actors/).

set -euo pipefail

cmem=""
while [ $# -gt 0 ]; do
  case "${1:-}" in
    --canonical-memory) cmem="${2:-}"; shift 2 ;;
    --canonical-memory=*) cmem="${1#--canonical-memory=}"; shift ;;
    -h|--help)
      sed -n '2,/^# Source/p' "$0" >&2
      exit 0
      ;;
    *) echo "contract-promotion-bidirectional: unknown option: $1" >&2; exit 2 ;;
  esac
done

# Resolve plugin root: lib/sensors/ → ../..
_CPB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CPB_PLUGIN_ROOT="$(cd "${_CPB_DIR}/../.." && pwd)"

if [ -z "$cmem" ]; then
  if [ -n "${YOKE_MEMORY_PATH:-}" ]; then
    cmem="$YOKE_MEMORY_PATH"
  else
    # shellcheck disable=SC1091
    if ! source "${_CPB_PLUGIN_ROOT}/lib/canonical-memory/resolve-memory.sh"; then
      echo "contract-promotion-bidirectional: failed to source resolve-memory.sh" >&2
      exit 2
    fi
    if ! yoke_resolve_memory; then
      echo "contract-promotion-bidirectional: could not resolve canonical-memory path" >&2
      exit 2
    fi
    cmem="$YOKE_MEMORY_PATH"
  fi
fi

if [ ! -d "$cmem" ]; then
  echo "contract-promotion-bidirectional: canonical-memory dir not found: $cmem" >&2
  exit 2
fi

concepts_dir="${cmem}/concepts"
actors_dir="${cmem}/actors"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Extract the YAML frontmatter (between the first two `---`) from a
# markdown file. Echoes the frontmatter content (no delimiters).
_cpb_extract_frontmatter() {
  awk '
    BEGIN { count = 0 }
    /^---[[:space:]]*$/ { count++; if (count == 2) exit; next }
    count == 1 { print }
  ' "$1"
}

# Echo "yes" if the frontmatter contains BOTH a `tags:` block listing
# `yoke-framework` AND `kind/contract`. Tolerates flow-list
# (`tags: [a, b]`) and block-list (`tags:` followed by `  - a`).
_cpb_concept_is_kind_contract() {
  local fm="$1"
  printf '%s\n' "$fm" | awk '
    BEGIN { in_tags=0; have_kind=0; have_yoke=0 }
    /^tags:[[:space:]]*\[/ {
      line = $0
      sub(/^tags:[[:space:]]*\[/, "", line)
      sub(/\][[:space:]]*$/, "", line)
      n = split(line, arr, ",")
      for (i = 1; i <= n; i++) {
        v = arr[i]
        sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v)
        gsub(/^"|"$/, "", v)
        if (v == "kind/contract") have_kind = 1
        if (v == "yoke-framework") have_yoke = 1
      }
      next
    }
    /^tags:[[:space:]]*$/ { in_tags = 1; next }
    in_tags == 1 && /^[[:space:]]+-[[:space:]]+/ {
      v = $0
      sub(/^[[:space:]]+-[[:space:]]+/, "", v)
      sub(/[[:space:]]+$/, "", v)
      gsub(/^"|"$/, "", v)
      if (v == "kind/contract") have_kind = 1
      if (v == "yoke-framework") have_yoke = 1
      next
    }
    in_tags == 1 && /^[A-Za-z_][A-Za-z0-9_]*:/ { in_tags = 0 }
    END {
      if (have_kind && have_yoke) print "yes"
    }
  '
}

# Echo each entry in the `applies_to:` YAML list, one per line.
# Tolerates flow-list and block-list shapes.
_cpb_extract_applies_to() {
  local fm="$1"
  printf '%s\n' "$fm" | awk '
    BEGIN { in_applies=0 }
    /^applies_to:[[:space:]]*\[/ {
      line = $0
      sub(/^applies_to:[[:space:]]*\[/, "", line)
      sub(/\][[:space:]]*$/, "", line)
      n = split(line, arr, ",")
      for (i = 1; i <= n; i++) {
        v = arr[i]
        sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v)
        gsub(/^"|"$/, "", v)
        if (v != "") print v
      }
      next
    }
    /^applies_to:[[:space:]]*$/ { in_applies = 1; next }
    in_applies == 1 && /^[[:space:]]+-[[:space:]]+/ {
      v = $0
      sub(/^[[:space:]]+-[[:space:]]+/, "", v)
      sub(/[[:space:]]+$/, "", v)
      gsub(/^"|"$/, "", v)
      if (v != "") print v
      next
    }
    in_applies == 1 && /^[A-Za-z_][A-Za-z0-9_]*:/ { in_applies = 0 }
  '
}

# Echo each bare wikilink target (the text between `[[` and `]]`) in
# the body (everything after the second `---`). Strips a leading
# `concepts/` prefix if present so callers can compare against the
# slug name directly.
_cpb_extract_body_wikilinks() {
  awk '
    BEGIN { count = 0 }
    /^---[[:space:]]*$/ { count++; next }
    count >= 2 {
      s = $0
      while (match(s, /\[\[[^]]+\]\]/)) {
        target = substr(s, RSTART + 2, RLENGTH - 4)
        sub(/\|.*$/, "", target)
        sub(/#.*$/, "", target)
        if (target != "") print target
        s = substr(s, RSTART + RLENGTH)
      }
    }
  ' "$1"
}

# Emit a structured-output YAML violation block.
# Args: <id> <location> <correction_instruction>
_cpb_emit_violation() {
  printf -- '- id: "%s"\n' "$1"
  printf -- '  location: "%s"\n' "$2"
  printf -- '  correction_instruction: "%s"\n' "$3"
  printf -- '  reference: "[[yoke-pattern-memory-model]]"\n'
}

# ---------------------------------------------------------------------------
# Forward-edge pass — concept -> actor backlink.
# ---------------------------------------------------------------------------
violations=0
violation_buf=""

if [ -d "$concepts_dir" ]; then
  while IFS= read -r -d '' concept_file; do
    [ -f "$concept_file" ] || continue
    fm="$(_cpb_extract_frontmatter "$concept_file" || true)"
    [ -n "$fm" ] || continue
    is_contract="$(_cpb_concept_is_kind_contract "$fm" || true)"
    [ "$is_contract" = "yes" ] || continue

    concept_slug="$(basename "$concept_file" .md)"
    while IFS= read -r actor_name; do
      [ -n "$actor_name" ] || continue
      actor_file="${actors_dir}/${actor_name}.md"
      if [ ! -f "$actor_file" ]; then
        violations=$((violations + 1))
        violation_buf+="$(_cpb_emit_violation \
          "${actor_name}" \
          "${actor_file}" \
          "create actors/${actor_name}.md and add a bare wikilink [[${concept_slug}]] in its body so the bidirectional invariant holds (concepts/${concept_slug}.md lists '${actor_name}' under applies_to)" \
        )"$'\n'
        continue
      fi
      # Body must contain a bare `[[<concept-slug>]]` wikilink.
      if ! grep -qF "[[${concept_slug}]]" "$actor_file"; then
        violations=$((violations + 1))
        violation_buf+="$(_cpb_emit_violation \
          "${actor_name}" \
          "${actor_file}" \
          "add a bare wikilink [[${concept_slug}]] to actors/${actor_name}.md (e.g. under '## Recent Activity') so it back-references concepts/${concept_slug}.md whose applies_to lists '${actor_name}'" \
        )"$'\n'
      fi
    done < <(_cpb_extract_applies_to "$fm")
  done < <(find "$concepts_dir" -maxdepth 1 -type f -name '*.md' -print0 2>/dev/null)
fi

# ---------------------------------------------------------------------------
# Reverse-edge pass — actor wikilink -> concept applies_to.
# ---------------------------------------------------------------------------
if [ -d "$actors_dir" ]; then
  while IFS= read -r -d '' actor_file; do
    [ -f "$actor_file" ] || continue
    actor_name="$(basename "$actor_file" .md)"
    while IFS= read -r target; do
      [ -n "$target" ] || continue
      # Strip leading `concepts/` if author used a namespaced wikilink.
      stripped="${target#concepts/}"
      target_concept="${concepts_dir}/${stripped}.md"
      [ -f "$target_concept" ] || continue
      target_fm="$(_cpb_extract_frontmatter "$target_concept" || true)"
      [ -n "$target_fm" ] || continue
      is_contract="$(_cpb_concept_is_kind_contract "$target_fm" || true)"
      [ "$is_contract" = "yes" ] || continue

      # Concept exists and is kind/contract — its applies_to MUST list
      # this actor.
      found=0
      while IFS= read -r listed_actor; do
        [ -n "$listed_actor" ] || continue
        if [ "$listed_actor" = "$actor_name" ]; then
          found=1
          break
        fi
      done < <(_cpb_extract_applies_to "$target_fm")

      if [ "$found" -ne 1 ]; then
        violations=$((violations + 1))
        violation_buf+="$(_cpb_emit_violation \
          "${stripped}" \
          "${target_concept}" \
          "add '${actor_name}' to the applies_to: list of concepts/${stripped}.md so it back-references actors/${actor_name}.md whose body wikilinks [[${stripped}]]" \
        )"$'\n'
      fi
    done < <(_cpb_extract_body_wikilinks "$actor_file")
  done < <(find "$actors_dir" -maxdepth 1 -type f -name '*.md' -print0 2>/dev/null)
fi

# ---------------------------------------------------------------------------
# Report.
# ---------------------------------------------------------------------------
if [ "$violations" -eq 0 ]; then
  exit 0
fi

printf '%s' "$violation_buf"
echo "sensor: contract-promotion-bidirectional found ${violations} violation(s)" >&2
exit 1
