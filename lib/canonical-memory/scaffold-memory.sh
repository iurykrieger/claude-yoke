#!/usr/bin/env bash
# scaffold-memory.sh — initialize a fresh canonical-memory repo.
#
# Creates:
#   <path>/.git                           — `git init`
#   <path>/{actors,people,teams,concepts,topics,discussions,projects,fleeting}/_template.md
#   <path>/.yoke-memory/config.json       — per-memory config (defaults from templates/yoke-memory-config.json)
#   <path>/README.md                      — short pointer to the Yoke plugin docs
#
# Usage:
#   scaffold-memory.sh <path>
#
# Exit codes:
#   0 — success (new memory scaffolded)
#   2 — usage error
#   6 — path already contains a non-empty memory (refuse to overwrite)

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: scaffold-memory.sh <path>" >&2
  exit 2
fi

target="$1"

# Resolve plugin dir for template lookup.
_yoke_plugin_dir() {
  if [ -n "${YOKE_PLUGIN_DIR:-}" ]; then
    printf '%s' "$YOKE_PLUGIN_DIR"
    return 0
  fi
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  (cd "${script_dir}/../.." && pwd)
}

plugin_dir="$(_yoke_plugin_dir)"
templates_root="${plugin_dir}/templates/canonical"
config_template="${plugin_dir}/templates/yoke-memory-config.json"

if [ ! -d "$templates_root" ]; then
  echo "Error: templates dir not found at $templates_root" >&2
  exit 6
fi

mkdir -p "$target"

# Refuse to overwrite an existing populated memory.
if [ -d "$target/.git" ] || [ -d "$target/.yoke-memory" ]; then
  echo "Error: $target already contains a memory (.git or .yoke-memory present). Refusing to overwrite." >&2
  exit 6
fi

# Initialize git.
git -C "$target" init --quiet --initial-branch=main 2>/dev/null || git -C "$target" init --quiet

# Create entity directories and copy templates.
for type in actor person team concept topic discussion project fleeting; do
  case "$type" in
    actor)      dir="actors" ;;
    person)     dir="people" ;;
    team)       dir="teams" ;;
    concept)    dir="concepts" ;;
    topic)      dir="topics" ;;
    discussion) dir="discussions" ;;
    project)    dir="projects" ;;
    fleeting)   dir="fleeting" ;;
  esac
  mkdir -p "$target/$dir"
  cp "$templates_root/$type/_template.md" "$target/$dir/_template.md"
done

# Per-memory config.
mkdir -p "$target/.yoke-memory"
if [ -f "$config_template" ]; then
  cp "$config_template" "$target/.yoke-memory/config.json"
else
  cat > "$target/.yoke-memory/config.json" <<'JSON'
{
  "language": "en-US",
  "git": { "strategy": "commit-push-pr" },
  "query": { "max_subgraph_calls": 3 }
}
JSON
fi

# README.
cat > "$target/README.md" <<'MD'
# Canonical memory (scaffolded by Yoke)

This repository is a Yoke canonical-memory substrate. It holds the
organization's ratified doctrine — policies, ADRs, patterns,
divergence resolutions, sensor calibrations — organized into the
8-entity Zettelkasten model (Actor / Person / Team / Concept / Topic /
Discussion / Project / Fleeting).

Operations:

- `/yoke:ask <query>` — read-only adaptive search.
- `/yoke:preserve` — single write point (governed by Model C).
- `/yoke:teach <source>` — ingest external sources.
- `/yoke:compress` — alignment maintenance.
- `/yoke:status --canonical` — healthcheck.

See the Yoke plugin docs for the full lifecycle.
MD

# Initial commit.
git -C "$target" add -A
git -C "$target" -c user.email="yoke@local" -c user.name="yoke" commit --quiet -m "scaffold: initialize Yoke canonical memory" || true

echo "Scaffolded canonical memory at: $target"
