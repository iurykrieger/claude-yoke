#!/usr/bin/env bash
# registry.sh — manage the Yoke memory registry at <plugin_dir>/memories.json.
#
# Schema:
#   { "memories": [
#       { "name": "kebab", "path": "/abs/path", "url": "git-url", "default": true|false }
#   ] }
#
# Operations:
#   init                                  — create empty registry (idempotent)
#   list                                  — print registered memories as YAML-ish lines
#   add <name> <path> [<url>]             — add an entry; first add becomes default
#   remove <name>                         — remove an entry; if removing default, no default until set-default runs
#   set-default <name>                    — mark a single entry as default; clears others
#   path-of <name>                        — print the path of <name> (used by resolve-memory.sh)
#   default-name                          — print the default entry's name (or empty)
#   has-url <url>                         — print "yes" or "no"; exit 0 either way
#
# Exit codes:
#   0 — success
#   2 — usage error
#   3 — registry file missing for an op that requires it
#   4 — duplicate name or URL on add
#   5 — entry not found on remove/set-default/path-of
#
# Plugin-dir resolution:
#   1. If $YOKE_PLUGIN_DIR is set, use it.
#   2. Otherwise, resolve as the parent of the directory holding this script's `lib/` ancestor.
#
# Dependency: python3 (for safe JSON rewrites). Documented in docs/installation.md.

set -euo pipefail

usage() {
  sed -n '2,30p' "$0" >&2
  exit 2
}

resolve_plugin_dir() {
  if [ -n "${YOKE_PLUGIN_DIR:-}" ]; then
    printf '%s' "$YOKE_PLUGIN_DIR"
    return 0
  fi
  # this script lives at <plugin_dir>/lib/canonical-memory/registry.sh
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # plugin_dir = script_dir/../..
  (cd "${script_dir}/../.." && pwd)
}

registry_path() {
  printf '%s/memories.json' "$(resolve_plugin_dir)"
}

require_registry() {
  local path
  path="$(registry_path)"
  if [ ! -f "$path" ]; then
    echo "Error: registry not found at $path. Run 'registry.sh init' or '/yoke:memory add' first." >&2
    exit 3
  fi
}

cmd_init() {
  local path
  path="$(registry_path)"
  if [ -f "$path" ]; then
    return 0
  fi
  printf '{\n  "memories": []\n}\n' > "$path"
}

cmd_list() {
  require_registry
  python3 - "$(registry_path)" <<'PY'
import json, sys
p = sys.argv[1]
with open(p) as f:
    data = json.load(f)
mems = data.get("memories", [])
if not mems:
    print("(no memories registered)")
    sys.exit(0)
for m in mems:
    star = " *" if m.get("default") else ""
    url = m.get("url") or "-"
    print(f"- {m['name']}{star}: {m['path']} (url: {url})")
PY
}

cmd_add() {
  if [ "$#" -lt 2 ]; then
    echo "Usage: registry.sh add <name> <path> [<url>]" >&2
    exit 2
  fi
  local name="$1" path="$2" url="${3:-}"
  cmd_init
  python3 - "$(registry_path)" "$name" "$path" "$url" <<'PY'
import json, sys
reg, name, path, url = sys.argv[1:5]
with open(reg) as f:
    data = json.load(f)
mems = data.setdefault("memories", [])
for m in mems:
    if m["name"] == name:
        sys.stderr.write(f"Error: name '{name}' already registered (path: {m['path']}).\n")
        sys.exit(4)
    if url and m.get("url") and m["url"] == url:
        sys.stderr.write(f"Error: url '{url}' already registered as '{m['name']}'.\n")
        sys.exit(4)
is_default = (len(mems) == 0)
entry = {"name": name, "path": path, "default": is_default}
if url:
    entry["url"] = url
mems.append(entry)
with open(reg, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

cmd_remove() {
  if [ "$#" -lt 1 ]; then
    echo "Usage: registry.sh remove <name>" >&2
    exit 2
  fi
  require_registry
  local name="$1"
  python3 - "$(registry_path)" "$name" <<'PY'
import json, sys
reg, name = sys.argv[1:3]
with open(reg) as f:
    data = json.load(f)
mems = data.get("memories", [])
new = [m for m in mems if m["name"] != name]
if len(new) == len(mems):
    sys.stderr.write(f"Error: '{name}' not found in registry.\n")
    sys.exit(5)
data["memories"] = new
with open(reg, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

cmd_set_default() {
  if [ "$#" -lt 1 ]; then
    echo "Usage: registry.sh set-default <name>" >&2
    exit 2
  fi
  require_registry
  local name="$1"
  python3 - "$(registry_path)" "$name" <<'PY'
import json, sys
reg, name = sys.argv[1:3]
with open(reg) as f:
    data = json.load(f)
mems = data.get("memories", [])
hit = False
for m in mems:
    if m["name"] == name:
        m["default"] = True
        hit = True
    else:
        m["default"] = False
if not hit:
    sys.stderr.write(f"Error: '{name}' not found in registry.\n")
    sys.exit(5)
with open(reg, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

cmd_path_of() {
  if [ "$#" -lt 1 ]; then
    echo "Usage: registry.sh path-of <name>" >&2
    exit 2
  fi
  require_registry
  local name="$1"
  python3 - "$(registry_path)" "$name" <<'PY'
import json, sys
reg, name = sys.argv[1:3]
with open(reg) as f:
    data = json.load(f)
for m in data.get("memories", []):
    if m["name"] == name:
        print(m["path"])
        sys.exit(0)
sys.stderr.write(f"Error: '{name}' not found in registry.\n")
sys.exit(5)
PY
}

cmd_default_name() {
  require_registry
  python3 - "$(registry_path)" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for m in data.get("memories", []):
    if m.get("default"):
        print(m["name"])
        sys.exit(0)
# Empty stdout if no default.
PY
}

cmd_has_url() {
  if [ "$#" -lt 1 ]; then
    echo "Usage: registry.sh has-url <url>" >&2
    exit 2
  fi
  local url="$1"
  if [ ! -f "$(registry_path)" ]; then
    echo "no"
    return 0
  fi
  python3 - "$(registry_path)" "$url" <<'PY'
import json, sys
reg, url = sys.argv[1:3]
with open(reg) as f:
    data = json.load(f)
for m in data.get("memories", []):
    if m.get("url") == url:
        print("yes")
        sys.exit(0)
print("no")
PY
}

if [ "$#" -lt 1 ]; then
  usage
fi

cmd="$1"; shift
case "$cmd" in
  init)          cmd_init "$@" ;;
  list)          cmd_list "$@" ;;
  add)           cmd_add "$@" ;;
  remove)        cmd_remove "$@" ;;
  set-default)   cmd_set_default "$@" ;;
  path-of)       cmd_path_of "$@" ;;
  default-name)  cmd_default_name "$@" ;;
  has-url)       cmd_has_url "$@" ;;
  -h|--help)     usage ;;
  *)             echo "Unknown command: $cmd" >&2; usage ;;
esac
