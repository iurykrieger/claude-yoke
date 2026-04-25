#!/bin/bash
# graph.sh — operations over canonical-memory frontmatter relationships.
#
# Frontmatter edges Yoke understands:
#   depends_on:       []
#   supersedes:       []
#   applies_to:       []
#   contradicts_with: []
#
# Subcommands:
#   subgraph <repo-path> <seed-file> [--depth N]
#       Emit (one path per line) the set of files reachable from <seed-file>
#       via the four edges, up to <depth> hops (default 2). Includes <seed-file>.
#   list-edges <repo-path> <file>
#       Emit lines of the form "<edge-name>:<target-path>" for every edge
#       found in <file>'s frontmatter.
#
# Sprint 6 ships subgraph traversal for progressive disclosure (depth ≤ 2
# in v0.6.0 to keep <2s on 1000-entry memory).
#
# Exit codes:
#   0   success
#   2   usage error
#   3   repo path not a directory
#   4   seed file missing

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  graph.sh subgraph <repo-path> <seed-file> [--depth N]
  graph.sh list-edges <repo-path> <file>
  graph.sh help
EOF
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  help|-h|--help) usage; exit 0 ;;

  list-edges)
    repo_path="${1:-}"
    file_path="${2:-}"
    if [ -z "$repo_path" ] || [ -z "$file_path" ]; then
      usage; exit 2
    fi
    [ -d "$repo_path" ] || { echo "Error: repo path '$repo_path' is not a directory." >&2; exit 3; }
    full_path="$file_path"
    if [ ! -f "$full_path" ]; then
      full_path="$repo_path/$file_path"
    fi
    [ -f "$full_path" ] || { echo "Error: file '$file_path' not found." >&2; exit 4; }

    # Extract frontmatter (between first two `---` lines)
    awk '
      /^---$/ { c++; next }
      c==1 { print }
    ' "$full_path" | awk '
      function emit_edge(edge, val,    p) {
        # Split val on commas if it is inline list, like [a, b, c]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
        gsub(/^\[|\]$/, "", val)
        if (val == "") return
        n = split(val, parts, /[[:space:]]*,[[:space:]]*/)
        for (i = 1; i <= n; i++) {
          p = parts[i]
          gsub(/^"|"$/, "", p)
          if (p != "") print edge ":" p
        }
      }

      /^(depends_on|supersedes|applies_to|contradicts_with):/ {
        edge = $0
        sub(/:.*/, "", edge)
        val = $0
        sub(/^[a-z_]+:[[:space:]]*/, "", val)
        if (val ~ /^\[.*\]$/) {
          emit_edge(edge, val)
          in_block = ""
          next
        }
        in_block = edge
        next
      }
      in_block != "" && /^[[:space:]]+-[[:space:]]+/ {
        item = $0
        sub(/^[[:space:]]+-[[:space:]]+/, "", item)
        gsub(/^"|"$/, "", item)
        if (item != "") print in_block ":" item
        next
      }
      in_block != "" && /^[a-z]/ { in_block = "" }
    '
    exit 0
    ;;

  subgraph)
    repo_path="${1:-}"
    seed="${2:-}"
    shift 2 || true
    depth=2
    while [ $# -gt 0 ]; do
      case "${1:-}" in
        --depth) depth="${2:-2}"; shift 2 ;;
        *) shift ;;
      esac
    done

    if [ -z "$repo_path" ] || [ -z "$seed" ]; then
      usage; exit 2
    fi
    [ -d "$repo_path" ] || { echo "Error: repo path '$repo_path' is not a directory." >&2; exit 3; }

    seed_full="$seed"
    if [ ! -f "$seed_full" ]; then
      seed_full="$repo_path/$seed"
    fi
    [ -f "$seed_full" ] || { echo "Error: seed '$seed' not found." >&2; exit 4; }

    # BFS over edges up to <depth> hops
    visited_file=$(mktemp)
    frontier_file=$(mktemp)
    next_file=$(mktemp)
    trap 'rm -f "$visited_file" "$frontier_file" "$next_file"' EXIT

    seed_rel=${seed_full#$repo_path/}
    echo "$seed_rel" > "$frontier_file"
    echo "$seed_rel" > "$visited_file"

    hop=0
    while [ "$hop" -lt "$depth" ] && [ -s "$frontier_file" ]; do
      : > "$next_file"
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        full="$repo_path/$f"
        [ -f "$full" ] || continue
        bash "$0" list-edges "$repo_path" "$f" 2>/dev/null | while IFS=: read -r edge target; do
          [ -z "$target" ] && continue
          # Only follow edges whose target exists in the repo
          if [ -f "$repo_path/$target" ] && ! grep -qxF "$target" "$visited_file"; then
            echo "$target" >> "$next_file"
            echo "$target" >> "$visited_file"
          fi
        done
      done < "$frontier_file"
      mv "$next_file" "$frontier_file"
      hop=$((hop + 1))
    done

    sort -u "$visited_file"
    exit 0
    ;;

  *)
    echo "Unknown subcommand: $cmd" >&2
    usage
    exit 2
    ;;
esac
