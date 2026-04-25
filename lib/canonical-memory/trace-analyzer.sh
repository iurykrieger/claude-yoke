#!/bin/bash
# trace-analyzer.sh — drift-sense detector for working-memory traces.
#
# Reads .yoke/contracts.md and .yoke/query-trace.md from the host project
# (or one or more provided directories) and detects recurring patterns
# that never reached canonization.
#
# v0.7.0 logic: count `topic:` occurrences in contracts.md across all
# provided trace dirs (typically merged tasks). Emit findings for topics
# that recur ≥ N times (default 3) but have no corresponding entry in
# the canonical-memory repo (matched by topic substring against `# <id>`
# headings).
#
# Usage:
#   trace-analyzer.sh [--canonical <repo-path>] [--config <path>]
#                     [--min-recurrence N]
#                     [--trace-dir <dir>]...
#
# Defaults:
#   --canonical        (resolved from .yoke/config.yaml canonical_memory.url)
#   --config           .yoke/config.yaml
#   --min-recurrence   3  (or .yoke/config.yaml overrides.drift_sense.recurrence_min)
#   --trace-dir        .yoke (single dir; pass multiple for cross-task analysis)
#
# Output (YAML):
#   findings:
#     - target: traces
#       kind: uncanonized-recurrence
#       severity: low | medium
#       location: "<topic>"
#       excerpt: "<topic> recurred N times across M tasks; no canonical entry"
#       suggestion: "Lower canonization criterion (repeatability_min) or canonize manually"
#
# Exit codes:
#   0   findings emitted (zero or more)
#   2   usage error

set -euo pipefail

canonical=""
config=".yoke/config.yaml"
min_recurrence=""
trace_dirs=()

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --canonical)        canonical="${2:-}";        shift 2 ;;
    --config)           config="${2:-}";           shift 2 ;;
    --min-recurrence)   min_recurrence="${2:-}";   shift 2 ;;
    --trace-dir)        trace_dirs+=("${2:-}");    shift 2 ;;
    -h|--help)          sed -n '1,30p' "$0"; exit 0 ;;
    "")                 break ;;
    *)                  echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# Default trace dir
if [ "${#trace_dirs[@]}" -eq 0 ]; then
  trace_dirs=(".yoke")
fi

# Resolve canonical repo path
if [ -z "$canonical" ] && [ -f "$config" ]; then
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
    canonical="${HOME}/.cache/yoke/canonical/${slug}"
  fi
fi

# Resolve min_recurrence override
if [ -z "$min_recurrence" ] && [ -f "$config" ]; then
  v=$(awk '
    /^overrides:/ { in_o=1; next }
    in_o && /^[a-z]/ { in_o=0 }
    in_o && /^[[:space:]]+drift_sense:/ { in_d=1; next }
    in_o && in_d && /^[[:space:]]+recurrence_min:/ {
      sub(/.*recurrence_min:[[:space:]]*/, "")
      gsub(/[[:space:]]+#.*/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
    in_o && in_d && /^[[:space:]]+[a-z]+:/ && !/^[[:space:]]+recurrence_min:/ { in_d=0 }
  ' "$config" 2>/dev/null)
  min_recurrence="${v:-3}"
fi
min_recurrence="${min_recurrence:-3}"

# Collect topics from all contracts.md files across all trace dirs
topics_file=$(mktemp)
trap 'rm -f "$topics_file"' EXIT

for d in "${trace_dirs[@]}"; do
  contracts="${d}/contracts.md"
  if [ -f "$contracts" ]; then
    awk '
      /^[[:space:]]*-?[[:space:]]*topic:[[:space:]]*/ {
        line = $0
        sub(/^[[:space:]]*-?[[:space:]]*topic:[[:space:]]*/, "", line)
        gsub(/^"|"$/, "", line)
        gsub(/[[:space:]]+#.*/, "", line)
        if (line != "") print line
      }
    ' "$contracts" >> "$topics_file"
  fi
done

# Count topic occurrences
counts_file=$(mktemp)
trap 'rm -f "$topics_file" "$counts_file"' EXIT
if [ -s "$topics_file" ]; then
  sort "$topics_file" | uniq -c | sort -rn > "$counts_file"
fi

# Emit findings header
echo "findings:"
emitted=0

if [ -s "$counts_file" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    count=$(echo "$line" | awk '{print $1}')
    topic=$(echo "$line" | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//')

    if [ "$count" -lt "$min_recurrence" ]; then
      continue
    fi

    # Check whether canonical memory has any entry mentioning this topic
    canonized="false"
    if [ -n "$canonical" ] && [ -d "$canonical" ]; then
      if grep -rliq -- "$topic" "$canonical" --include='*.md' 2>/dev/null; then
        canonized="true"
      fi
    fi

    if [ "$canonized" = "false" ]; then
      severity="low"
      [ "$count" -ge $((min_recurrence * 2)) ] && severity="medium"

      escaped=${topic//\"/\\\"}
      printf -- '  - target: traces\n'
      printf -- '    kind: uncanonized-recurrence\n'
      printf -- '    severity: %s\n' "$severity"
      printf -- '    location: "%s"\n' "$escaped"
      printf -- '    excerpt: "topic recurred %s times across trace; no canonical entry mentions it"\n' "$count"
      printf -- '    suggestion: "Lower repeatability_min, expand traces, or canonize manually."\n'
      emitted=$((emitted + 1))
    fi
  done < "$counts_file"
fi

if [ "$emitted" -eq 0 ]; then
  echo "  []"
fi

exit 0
