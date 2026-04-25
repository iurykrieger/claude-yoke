#!/bin/bash
# query.sh — read canonical memory.
#
# Sprint 2: basic text grep. Sprint 5: mediated through the Orchestrator
# skill, emits to .yoke/query-trace.md. Sprint 6: subgraph traversal for
# progressive disclosure.
#
# Usage:
#   query.sh [--trace <path>] [--invoker <name>] <term> [<canonical-repo-path>]
#
# Behavior:
#   - If <canonical-repo-path> is omitted, the script reads
#     canonical_memory.url from ./.yoke/config.yaml and clones (or pulls)
#     the repo into ~/.cache/yoke/canonical/<slug>/.
#   - Performs a recursive case-insensitive grep over *.md files.
#   - Caps output at 20 matches; appends a truncation note if more exist.
#   - Empty-state UX: returns a clear message when canonical memory is
#     empty, when it has entries but no matches, or when it is not yet
#     configured. All of these are exit 0.
#   - When --trace <path> is provided, writes a YAML trace entry to that
#     path. Initializes the file with a `# Query trace` header if absent.
#
# Trace entry shape (Sprint 5):
#   - timestamp: "<iso8601>"
#     mode: mediator
#     query: "<term>"
#     subgraph_depth: 1
#     matches: <count>
#     capped: <true|false>
#     invoker: "<name>"   # only when --invoker provided
#
# Exit codes:
#   0 — query ran (matches printed, empty-state message, or no matches)
#   2 — usage error
#   3 — .yoke/config.yaml missing (only when no <canonical-repo-path> given)
#   4 — clone failed
#   5 — invalid canonical-repo-path

set -euo pipefail

trace_path=""
invoker=""
subgraph_depth=0

# Argument parsing — long options first, then positionals
while [ $# -gt 0 ]; do
  case "${1:-}" in
    --trace)            trace_path="${2:-}";            shift 2 ;;
    --invoker)          invoker="${2:-}";               shift 2 ;;
    --subgraph-depth)   subgraph_depth="${2:-0}";       shift 2 ;;
    -h|--help)
      sed -n '1,50p' "$0"
      exit 0
      ;;
    --)         shift; break ;;
    -*)
      echo "Usage: query.sh [--trace <path>] [--invoker <name>] [--subgraph-depth N] <term> [<canonical-repo-path>]" >&2
      exit 2
      ;;
    *)          break ;;
  esac
done

if [ "$#" -lt 1 ]; then
  echo "Usage: query.sh [--trace <path>] [--invoker <name>] <term> [<canonical-repo-path>]" >&2
  exit 2
fi

term="$1"
repo_path="${2:-}"

# Helper: write a trace entry, initializing the file if needed.
write_trace() {
  local matches_count="$1"
  local capped="$2"
  local note="${3:-}"

  if [ -z "$trace_path" ]; then
    return 0
  fi

  # Initialize header if absent
  if [ ! -f "$trace_path" ]; then
    mkdir -p "$(dirname "$trace_path")" 2>/dev/null || true
    printf '# Query trace\n' > "$trace_path"
  fi

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Escape double quotes in fields
  local q_term="${term//\"/\\\"}"
  local q_invoker="${invoker//\"/\\\"}"

  {
    printf -- '- timestamp: "%s"\n' "$ts"
    printf -- '  mode: mediator\n'
    printf -- '  query: "%s"\n' "$q_term"
    printf -- '  subgraph_depth: 1\n'
    printf -- '  matches: %s\n' "$matches_count"
    printf -- '  capped: %s\n' "$capped"
    if [ -n "$invoker" ]; then
      printf -- '  invoker: "%s"\n' "$q_invoker"
    fi
    if [ -n "$note" ]; then
      printf -- '  notes: "%s"\n' "$note"
    fi
  } >> "$trace_path"
}

# Locate the canonical repo path if not provided
if [ -z "$repo_path" ]; then
  config_file=".yoke/config.yaml"
  if [ ! -f "$config_file" ]; then
    echo "Error: .yoke/config.yaml not found. Run /yoke:bootstrap first." >&2
    exit 3
  fi

  # Extract canonical_memory.url with awk (avoid yq dependency).
  url=$(awk '
    /^canonical_memory:/ { flag=1; next }
    flag && /^[a-z]/ { flag=0 }
    flag && /^[[:space:]]+url:/ {
      sub(/^[[:space:]]+url:[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ' "$config_file")

  if [ -z "$url" ] || [ "$url" = "{{ canonical_memory_url }}" ]; then
    write_trace 0 false "not-configured"
    echo "Canonical memory not configured. Re-run /yoke:bootstrap to link or create one."
    exit 0
  fi

  slug=$(echo "$url" | sed -E 's|.*/([^/]+)$|\1|; s|\.git$||')
  cache_root="${HOME}/.cache/yoke/canonical"
  repo_path="${cache_root}/${slug}"

  if [ ! -d "$repo_path" ]; then
    mkdir -p "$cache_root"
    if ! git clone --quiet --depth 1 "$url" "$repo_path" 2>/dev/null; then
      echo "Error: failed to clone canonical-memory repo at $url" >&2
      exit 4
    fi
  else
    git -C "$repo_path" pull --quiet --ff-only 2>/dev/null || true
  fi
fi

if [ ! -d "$repo_path" ]; then
  echo "Error: canonical-memory path '$repo_path' is not a directory." >&2
  exit 5
fi

# Count total markdown entries for empty-state UX
total_md=$(find "$repo_path" -type f -name '*.md' -not -path '*/.git/*' | wc -l | tr -d ' ')

if [ "$total_md" -eq 0 ]; then
  write_trace 0 false "empty-memory"
  echo "Canonical memory has no entries yet. /yoke:canonize will populate it as tasks complete (Sprint 5+)."
  exit 0
fi

# Capture matches once; tolerate grep's exit 1 when there are no matches.
matches=$(grep -rni --include='*.md' --exclude-dir='.git' -- "$term" "$repo_path" 2>/dev/null || true)

if [ -z "$matches" ]; then
  write_trace 0 false ""
  echo "No matches for '$term' across $total_md entries."
  exit 0
fi

total_matches=$(echo "$matches" | wc -l | tr -d ' ')
capped="false"

# Subgraph expansion (Sprint 6 — progressive disclosure).
# When --subgraph-depth N (N >= 1) is given AND there are matches,
# take the first match's file as seed and emit the subgraph reachable
# from it via depends_on / supersedes / applies_to / contradicts_with
# edges. Caps at 10 entries to bound context.
if [ "$subgraph_depth" -gt 0 ]; then
  graph_sh="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/graph.sh"
  if [ ! -x "$graph_sh" ] && [ ! -f "$graph_sh" ]; then
    # Fall through to flat output if graph helper is missing
    subgraph_depth=0
  fi
fi

if [ "$subgraph_depth" -gt 0 ]; then
  # First match's file (relative to repo)
  seed_path=$(echo "$matches" | head -1 | sed -E "s|^${repo_path}/||" | cut -d: -f1)

  # Run subgraph traversal
  subgraph_paths=$(bash "$graph_sh" subgraph "$repo_path" "$seed_path" --depth "$subgraph_depth" 2>/dev/null || echo "$seed_path")
  # Cap at 10 entries
  capped_paths=$(echo "$subgraph_paths" | head -10)
  total_subgraph=$(echo "$subgraph_paths" | wc -l | tr -d ' ')
  capped_count=$(echo "$capped_paths" | wc -l | tr -d ' ')
  [ "$total_subgraph" -gt 10 ] && capped="true"

  write_trace "$capped_count" "$capped" "subgraph-depth=$subgraph_depth"

  # Emit subgraph entries with a brief summary line per file
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    echo "- $p"
  done <<< "$capped_paths"

  if [ "$total_subgraph" -gt 10 ]; then
    echo "... (showing 10 of $total_subgraph subgraph entries; refine seed or reduce depth)"
  fi

  exit 0
fi

# Flat-grep mode (Sprint 5 behavior)
[ "$total_matches" -gt 20 ] && capped="true"

write_trace "$total_matches" "$capped" ""

echo "$matches" | head -20 | sed -E "s|^${repo_path}/||"

if [ "$total_matches" -gt 20 ]; then
  echo "... (showing 20 of $total_matches matches; refine your query)"
fi

exit 0
