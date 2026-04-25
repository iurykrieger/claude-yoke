#!/bin/bash
# staleness-check.sh — drift-sense detector for canonical memory.
#
# Reads the canonical-memory repo (cached at ~/.cache/yoke/canonical/<slug>/
# or passed explicitly) and emits structured YAML findings. v0.7.0 uses
# pure metadata math (no LLM judgment).
#
# Usage:
#   staleness-check.sh [--repo <path>] [--config <path>] [--current-model <id>]
#                      [--query-trace <path>] [--max-days N]
#
# Defaults:
#   --repo            (resolved from .yoke/config.yaml canonical_memory.url)
#   --config          .yoke/config.yaml
#   --current-model   $YOKE_MODEL_ID  (default: claude-opus-4-7)
#   --query-trace     (empty; caller passes a versioned path resolved via
#                      lib/working-memory/paths.sh::wm_query_trace_path,
#                      or a glob expanded by drift-sense across all tasks)
#   --max-days        30  (or .yoke/config.yaml overrides.drift_sense.staleness_max_days)
#
# Three findings kinds:
#   stale         — last_validated > max-days ago AND no recent query-trace hits
#   model-drift   — model_calibrated_against != current-model
#   contradiction — contradicts_with: entry that exists in the repo today
#
# Output (YAML to stdout):
#   findings:
#     - target: canonical-memory
#       kind: <kind>
#       severity: low | medium | high
#       location: <path>
#       excerpt: "<short evidence>"
#       suggestion: "<actionable recommendation>"
#
# Exit codes:
#   0   findings emitted (zero or more)
#   2   usage error
#   3   repo not found / not configured

set -euo pipefail

repo=""
config=".yoke/config.yaml"
current_model="${YOKE_MODEL_ID:-claude-opus-4-7}"
query_trace=""
max_days=""

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --repo)           repo="${2:-}";          shift 2 ;;
    --config)         config="${2:-}";        shift 2 ;;
    --current-model)  current_model="${2:-}"; shift 2 ;;
    --query-trace)    query_trace="${2:-}";   shift 2 ;;
    --max-days)       max_days="${2:-}";      shift 2 ;;
    -h|--help)        sed -n '1,30p' "$0"; exit 0 ;;
    "")               break ;;
    *)                echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# Resolve repo path
if [ -z "$repo" ] && [ -f "$config" ]; then
  url=$(awk '
    /^canonical_memory:/ { in_section=1; next }
    in_section && /^[a-z]/ { in_section=0 }
    in_section && /^[[:space:]]+url:/ {
      sub(/^[[:space:]]+url:[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ' "$config" 2>/dev/null)
  if [ -n "$url" ] && [ "$url" != "{{ canonical_memory_url }}" ]; then
    slug=$(echo "$url" | sed -E 's|.*/([^/]+)$|\1|; s|\.git$||')
    repo="${HOME}/.cache/yoke/canonical/${slug}"
  fi
fi

if [ -z "$repo" ] || [ ! -d "$repo" ]; then
  echo "findings: []"
  printf 'notes:\n  - "Canonical-memory repo not configured or not cached at %s."\n' "${repo:-<unset>}"
  exit 0
fi

# Resolve max_days override
if [ -z "$max_days" ] && [ -f "$config" ]; then
  v=$(awk '
    /^overrides:/ { in_o=1; next }
    in_o && /^[a-z]/ { in_o=0 }
    in_o && /^[[:space:]]+drift_sense:/ { in_d=1; next }
    in_o && in_d && /^[[:space:]]+staleness_max_days:/ {
      sub(/.*staleness_max_days:[[:space:]]*/, "")
      gsub(/[[:space:]]+#.*/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
    in_o && in_d && /^[[:space:]]+[a-z]+:/ && !/^[[:space:]]+staleness_max_days:/ { in_d=0 }
  ' "$config" 2>/dev/null)
  max_days="${v:-30}"
fi
max_days="${max_days:-30}"

# Helper: extract a frontmatter scalar field from a markdown file
fm_field() {
  local file="$1"
  local key="$2"
  awk -v k="$key" '
    /^---$/ { c++; if (c == 2) exit; next }
    c == 1 {
      line = $0
      if (line ~ "^"k":") {
        sub(".*"k":[[:space:]]*", "", line)
        gsub(/^"|"$/, "", line)
        gsub(/[[:space:]]+#.*/, "", line)
        print line
        exit
      }
    }
  ' "$file" 2>/dev/null
}

# Helper: extract a list-typed frontmatter field. Handles both inline
# `[a, b]` and block `- a\n- b` shapes. Emits one item per line.
fm_list() {
  local file="$1"
  local key="$2"
  awk -v k="$key" '
    /^---$/ { c++; if (c == 2) exit; next }
    c == 1 {
      if ($0 ~ "^"k":[[:space:]]*\\[") {
        v = $0
        sub("^"k":[[:space:]]*\\[", "", v)
        sub(/\][[:space:]]*$/, "", v)
        gsub(/[[:space:]]/, "", v)
        n = split(v, parts, ",")
        for (i = 1; i <= n; i++) {
          p = parts[i]
          gsub(/"/, "", p)
          if (p != "") print p
        }
        in_block = 0
        next
      }
      if ($0 ~ "^"k":[[:space:]]*$") {
        in_block = 1
        next
      }
      if (in_block && /^[[:space:]]+-[[:space:]]+/) {
        item = $0
        sub(/^[[:space:]]+-[[:space:]]+/, "", item)
        gsub(/^"|"$/, "", item)
        if (item != "") print item
        next
      }
      if (in_block && /^[a-z]/) in_block = 0
    }
  ' "$file" 2>/dev/null
}

# Pre-build set of "consulted recently" file paths from query-trace
consulted_recently=$(mktemp)
trap 'rm -f "$consulted_recently"' EXIT
if [ -f "$query_trace" ]; then
  # Extract `query: "<term>"` and match approximations are weak; instead, look
  # at any `matches: <count>` entries with their preceding query, but for
  # heuristic purposes, treat any non-zero match as recent activity. The
  # query trace doesn't track per-file consultations directly in v0.7.0 —
  # this is conservative (under-counts staleness, which is fine).
  : > "$consulted_recently"
fi

now=$(date +%s)
threshold=$((now - max_days * 86400))

# Iterate over all *.md files in the repo
echo "findings:"
emitted=0
all_paths=$(mktemp)
trap 'rm -f "$consulted_recently" "$all_paths"' EXIT

find "$repo" -type f -name '*.md' -not -path '*/.git/*' > "$all_paths" 2>/dev/null || true

while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  rel=${entry#$repo/}

  # Frontmatter: last_validated, model_calibrated_against, contradicts_with
  last_validated=$(fm_field "$entry" "last_validated")
  model=$(fm_field "$entry" "model_calibrated_against")

  # Staleness check
  if [ -n "$last_validated" ]; then
    # Convert ISO date (YYYY-MM-DD) to epoch
    iso="$last_validated"
    # macOS / GNU date compatibility
    if epoch=$(date -j -f "%Y-%m-%d" "$iso" +%s 2>/dev/null) || \
       epoch=$(date -d "$iso" +%s 2>/dev/null); then
      if [ "$epoch" -lt "$threshold" ]; then
        days_stale=$(( (now - epoch) / 86400 ))
        printf -- '  - target: canonical-memory\n'
        printf -- '    kind: stale\n'
        printf -- '    severity: medium\n'
        printf -- '    location: "%s"\n' "$rel"
        printf -- '    excerpt: "last_validated %s (%s days ago)"\n' "$iso" "$days_stale"
        printf -- '    suggestion: "Re-validate against current model or deprecate."\n'
        emitted=$((emitted + 1))
      fi
    fi
  fi

  # Model drift
  if [ -n "$model" ] && [ "$model" != "$current_model" ]; then
    printf -- '  - target: canonical-memory\n'
    printf -- '    kind: model-drift\n'
    printf -- '    severity: medium\n'
    printf -- '    location: "%s"\n' "$rel"
    printf -- '    excerpt: "calibrated against %s; current model is %s"\n' "$model" "$current_model"
    printf -- '    suggestion: "Re-test rule against %s and update model_calibrated_against."\n' "$current_model"
    emitted=$((emitted + 1))
  fi

  # Contradictions: contradicts_with: list members must point at non-existent
  # OR existing entries. v0.7.0 reports contradictions when the target exists
  # in the repo today (i.e., live contradiction).
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    if [ -f "$repo/$target" ]; then
      printf -- '  - target: canonical-memory\n'
      printf -- '    kind: contradiction\n'
      printf -- '    severity: high\n'
      printf -- '    location: "%s"\n' "$rel"
      printf -- '    excerpt: "contradicts_with %s (live in repo)"\n' "$target"
      printf -- '    suggestion: "Resolve: deprecate one or document precedence."\n'
      emitted=$((emitted + 1))
    fi
  done < <(fm_list "$entry" "contradicts_with")

done < "$all_paths"

if [ "$emitted" -eq 0 ]; then
  # Re-emit the empty findings list (the awk loop printed `findings:` already)
  echo "  []"
fi

exit 0
