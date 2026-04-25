#!/usr/bin/env bash
# resolve-memory.sh — resolve the active canonical-memory path through the
# 3-step chain:
#
#   1. --memory <name> flag (explicit)
#   2. CWD detection (longest-prefix match against registered paths)
#   3. Default-marked registry entry
#
# Usage (sourced):
#   source lib/canonical-memory/resolve-memory.sh
#   yoke_resolve_memory --memory main          # populates $YOKE_MEMORY_PATH and $YOKE_MEMORY_NAME
#   yoke_resolve_memory                        # uses CWD then default
#
# Usage (exec):
#   resolve-memory.sh [--memory <name>]        # prints "<name>\t<path>"; exit 0 on success
#
# Exit codes (when exec'd):
#   0 — resolved
#   3 — registry missing
#   5 — not resolvable (no flag, CWD outside any memory, no default)

set -euo pipefail

# Resolve plugin dir the same way as registry.sh.
_yoke_plugin_dir() {
  if [ -n "${YOKE_PLUGIN_DIR:-}" ]; then
    printf '%s' "$YOKE_PLUGIN_DIR"
    return 0
  fi
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  (cd "${script_dir}/../.." && pwd)
}

_yoke_registry_path() {
  printf '%s/memories.json' "$(_yoke_plugin_dir)"
}

# Sourceable function. Sets:
#   YOKE_MEMORY_NAME  — the resolved memory's name
#   YOKE_MEMORY_PATH  — the resolved memory's local path
# Returns non-zero on failure (and prints a diagnostic to stderr).
yoke_resolve_memory() {
  local explicit_name=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --memory) explicit_name="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done

  local reg
  reg="$(_yoke_registry_path)"
  if [ ! -f "$reg" ]; then
    echo "No memory registered. Run /yoke:memory add <path> or re-run /yoke:bootstrap." >&2
    return 3
  fi

  local cwd
  cwd="$(pwd -P)"

  python3 - "$reg" "$explicit_name" "$cwd" >/tmp/yoke-resolve-$$.tsv <<'PY' || rc=$?
import json, sys, os
reg, explicit, cwd = sys.argv[1:4]
with open(reg) as f:
    data = json.load(f)
mems = data.get("memories", [])

def emit(m):
    print(f"{m['name']}\t{m['path']}")
    sys.exit(0)

# 1. Explicit
if explicit:
    for m in mems:
        if m["name"] == explicit:
            emit(m)
    sys.stderr.write(f"Error: '{explicit}' is not a registered memory.\n")
    sys.exit(5)

# 2. CWD detection — longest-prefix match
matches = []
for m in mems:
    p = os.path.realpath(m["path"])
    if cwd == p or cwd.startswith(p + "/"):
        matches.append((len(p), m))
if matches:
    matches.sort(key=lambda x: x[0], reverse=True)
    emit(matches[0][1])

# 3. Default
for m in mems:
    if m.get("default"):
        emit(m)

# 4. No resolution
sys.stderr.write("No memory resolved. Available memories:\n")
if not mems:
    sys.stderr.write("  (none registered)\n")
else:
    for m in mems:
        star = " *" if m.get("default") else ""
        sys.stderr.write(f"  - {m['name']}{star}: {m['path']}\n")
sys.stderr.write("Use --memory <name> to specify, or run /yoke:memory set-default <name>.\n")
sys.exit(5)
PY
  local rc="${rc:-$?}"
  if [ "$rc" -ne 0 ]; then
    rm -f "/tmp/yoke-resolve-$$.tsv"
    return "$rc"
  fi

  local line
  line="$(cat "/tmp/yoke-resolve-$$.tsv")"
  rm -f "/tmp/yoke-resolve-$$.tsv"
  YOKE_MEMORY_NAME="${line%%$'\t'*}"
  YOKE_MEMORY_PATH="${line#*$'\t'}"
  export YOKE_MEMORY_NAME YOKE_MEMORY_PATH
  return 0
}

# When exec'd directly, print "<name>\t<path>" to stdout.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  if yoke_resolve_memory "$@"; then
    printf '%s\t%s\n' "$YOKE_MEMORY_NAME" "$YOKE_MEMORY_PATH"
  else
    exit "$?"
  fi
fi
