#!/usr/bin/env bash
# resolve-provider.sh — resolve the active canonical-memory provider for the
# current host project by intersecting two curated sources of truth:
#
#   1. The host project's `.yoke/config.yaml` :: `canonical_memory.provider`
#      (the user's selection, written by /yoke:bootstrap or hand-edited).
#   2. The plugin's `providers.yaml` (the curated registry of supported
#      providers and their pinned skill verbs).
#
# Sourced by the two facade skills `/yoke:search-canonical-memory` and
# `/yoke:canonize`, both of which need a deterministic, exported answer
# to "which skill should I dispatch against?". Mirrors the shape of
# `lib/canonical-memory/resolve-memory.sh` (sourced, exports vars,
# stable exit codes).
#
# Usage (sourced):
#   source <plugin_dir>/lib/canonical-memory/resolve-provider.sh
#   yoke_resolve_provider          # populates the four exported vars below
#
# Usage (exec):
#   resolve-provider.sh            # prints "<name>\t<search>\t<canonize>" on
#                                  # stdout; exit 0 on success.
#
# Exit codes (sourced or exec):
#   0 — resolved
#   3 — config missing  (the host project has no `.yoke/config.yaml`)
#   4 — `canonical_memory.provider` key missing from `.yoke/config.yaml`
#       (the unmigrated v1.x case; mirrored by s03-t02's hard-break helper)
#   5 — provider name not present in `providers.yaml`, OR plugin root
#       unresolvable (neither `YOKE_PLUGIN_DIR` nor `BASH_SOURCE[0]` set)
#
# Exported variables on success:
#   YOKE_PROVIDER_NAME              — "<provider-name>"
#   YOKE_PROVIDER_SEARCH_SKILL      — "<plugin>:<skill>" used by /yoke:search-canonical-memory
#   YOKE_PROVIDER_CANONIZE_SKILL    — "<plugin>:<skill>" used by /yoke:canonize
#   YOKE_PROVIDER_CONFIG_PASSTHROUGH — newline-separated list of keys forwarded
#                                      opaquely from
#                                      `.yoke/config.yaml :: canonical_memory.*`
#                                      to the provider.
#
# References:
# - PRD:  .yoke/prds/2026-04-30-pluggable-canonical-memory.md
# - Spec: .yoke/specs/2026-04-30-pluggable-canonical-memory.md
# - Acceptance Contract Scenario 2 / FR-2.
# - Sprint 1 task 2026-04-30-pluggable-canonical-memory-s01-t02.

set -uo pipefail

# Resolve the plugin dir the same way as resolve-memory.sh.
_yoke_provider_plugin_dir() {
  if [ -n "${YOKE_PLUGIN_DIR:-}" ]; then
    printf '%s' "$YOKE_PLUGIN_DIR"
    return 0
  fi
  local source_path="${BASH_SOURCE[0]:-}"
  if [ -z "$source_path" ]; then
    echo "wm: cannot resolve plugin root — neither YOKE_PLUGIN_DIR nor BASH_SOURCE[0] is set. Export YOKE_PLUGIN_DIR=<plugin path> before sourcing." >&2
    return 5
  fi
  local script_dir
  script_dir="$(cd "$(dirname "$source_path")" && pwd)"
  (cd "${script_dir}/../.." && pwd)
}

_yoke_providers_yaml_path() {
  local plugin_dir
  plugin_dir="$(_yoke_provider_plugin_dir)" || return $?
  printf '%s/providers.yaml' "$plugin_dir"
}

_yoke_project_config_path() {
  # The host project's .yoke/config.yaml, resolved relative to $PWD.
  printf '%s/.yoke/config.yaml' "$(pwd -P)"
}

# Sourceable function. Sets and exports YOKE_PROVIDER_*.
# Returns non-zero with a stderr diagnostic on failure.
yoke_resolve_provider() {
  local cfg
  cfg="$(_yoke_project_config_path)"
  if [ ! -f "$cfg" ]; then
    echo "wm: .yoke/config.yaml not found in \$PWD. Run /yoke:bootstrap." >&2
    return 3
  fi

  local providers_yaml
  providers_yaml="$(_yoke_providers_yaml_path)" || return $?
  if [ ! -f "$providers_yaml" ]; then
    echo "wm: providers.yaml missing from plugin root ($providers_yaml)." >&2
    return 5
  fi

  # Try python3 + yaml first (deterministic structural parse), fall back to
  # yq if available, fall back to a grep/awk parser as last resort.
  local tmp
  tmp="$(mktemp 2>/dev/null || printf '/tmp/yoke-resolve-provider-%s' "$$")"
  local rc=0
  python3 - "$cfg" "$providers_yaml" >"$tmp" 2>"${tmp}.err" <<'PY' || rc=$?
import sys

cfg_path, providers_path = sys.argv[1:3]

try:
    import yaml  # type: ignore[import]
except ImportError:
    sys.stderr.write("python3 yaml module unavailable; fallback to yq/awk\n")
    sys.exit(127)

with open(cfg_path) as f:
    cfg = yaml.safe_load(f) or {}
with open(providers_path) as f:
    providers_doc = yaml.safe_load(f) or {}

cm = (cfg.get("canonical_memory") or {})
if not isinstance(cm, dict):
    sys.stderr.write("wm: .yoke/config.yaml has no canonical_memory: block.\n")
    sys.exit(4)

provider_name = cm.get("provider")
if not provider_name or not isinstance(provider_name, str) or not provider_name.strip():
    sys.stderr.write(
        "wm: canonical_memory.provider not configured. "
        "Run /yoke:bootstrap to migrate.\n"
    )
    sys.exit(4)

provider_name = provider_name.strip()
providers = (providers_doc.get("providers") or {})
if provider_name not in providers:
    sys.stderr.write(
        f"wm: provider '{provider_name}' is not registered in providers.yaml.\n"
    )
    available = sorted(providers.keys())
    if available:
        sys.stderr.write("Available providers:\n")
        for p in available:
            sys.stderr.write(f"  - {p}\n")
    sys.exit(5)

entry = providers[provider_name] or {}
skills = (entry.get("skills") or {})
search = skills.get("search")
canonize = skills.get("canonize")
if not search or not canonize:
    sys.stderr.write(
        f"wm: provider '{provider_name}' is missing skills.search "
        "or skills.canonize in providers.yaml.\n"
    )
    sys.exit(5)

passthrough = entry.get("config_passthrough") or []
if not isinstance(passthrough, list):
    passthrough = []

# stdout: 4 lines — name, search, canonize, then passthrough keys (one per line)
print(provider_name)
print(search)
print(canonize)
for key in passthrough:
    if isinstance(key, str) and key:
        print(key)
PY

  if [ "$rc" -eq 127 ]; then
    # Python yaml not available — try yq fallback.
    if command -v yq >/dev/null 2>&1; then
      _yoke_resolve_provider_yq "$cfg" "$providers_yaml" >"$tmp" 2>"${tmp}.err"
      rc=$?
    else
      _yoke_resolve_provider_awk "$cfg" "$providers_yaml" >"$tmp" 2>"${tmp}.err"
      rc=$?
    fi
  fi

  if [ "$rc" -ne 0 ]; then
    if [ -s "${tmp}.err" ]; then
      cat "${tmp}.err" >&2
    fi
    rm -f "$tmp" "${tmp}.err"
    return "$rc"
  fi

  # Stream output: line 1 = name, line 2 = search, line 3 = canonize,
  # remaining lines = passthrough keys.
  local name search canonize passthrough_block
  IFS= read -r name <"$tmp" || name=""
  {
    IFS= read -r _name_dup
    IFS= read -r search
    IFS= read -r canonize
    passthrough_block="$(cat)"
  } <"$tmp"
  rm -f "$tmp" "${tmp}.err"

  if [ -z "$name" ] || [ -z "$search" ] || [ -z "$canonize" ]; then
    echo "wm: resolve-provider produced an empty result; check providers.yaml shape." >&2
    return 5
  fi

  YOKE_PROVIDER_NAME="$name"
  YOKE_PROVIDER_SEARCH_SKILL="$search"
  YOKE_PROVIDER_CANONIZE_SKILL="$canonize"
  YOKE_PROVIDER_CONFIG_PASSTHROUGH="$passthrough_block"
  export YOKE_PROVIDER_NAME YOKE_PROVIDER_SEARCH_SKILL YOKE_PROVIDER_CANONIZE_SKILL YOKE_PROVIDER_CONFIG_PASSTHROUGH
  return 0
}

# yq fallback — used when python3 yaml is unavailable but yq is on PATH.
_yoke_resolve_provider_yq() {
  local cfg="$1"
  local providers_yaml="$2"
  local provider
  provider="$(yq -r '.canonical_memory.provider // ""' "$cfg" 2>/dev/null || true)"
  provider="${provider#null}"
  if [ -z "$provider" ] || [ "$provider" = "null" ]; then
    echo "wm: canonical_memory.provider not configured. Run /yoke:bootstrap to migrate." >&2
    return 4
  fi
  local search canonize
  search="$(yq -r ".providers.\"$provider\".skills.search // \"\"" "$providers_yaml" 2>/dev/null || true)"
  canonize="$(yq -r ".providers.\"$provider\".skills.canonize // \"\"" "$providers_yaml" 2>/dev/null || true)"
  if [ -z "$search" ] || [ "$search" = "null" ] || [ -z "$canonize" ] || [ "$canonize" = "null" ]; then
    echo "wm: provider '$provider' is not registered in providers.yaml or is missing skills.search/canonize." >&2
    return 5
  fi
  printf '%s\n%s\n%s\n' "$provider" "$search" "$canonize"
  yq -r ".providers.\"$provider\".config_passthrough[]? // empty" "$providers_yaml" 2>/dev/null || true
}

# Last-resort grep/awk fallback. Handles the canonical providers.yaml shape
# emitted by /yoke:bootstrap (2-space indent, flow-free). Provider blocks
# nested under `providers:`, fields nested 4 spaces deep.
_yoke_resolve_provider_awk() {
  local cfg="$1"
  local providers_yaml="$2"
  local provider
  provider="$(awk '
    /^canonical_memory:[[:space:]]*$/ { in_cm = 1; next }
    in_cm && /^[^[:space:]#]/ { in_cm = 0 }
    in_cm && /^[[:space:]]+provider:[[:space:]]*/ {
      sub(/^[[:space:]]+provider:[[:space:]]*/, "", $0)
      gsub(/[[:space:]]*#.*$/, "", $0)
      gsub(/^[\"'\'']|[\"'\'']$/, "", $0)
      print $0
      exit
    }
  ' "$cfg")"
  if [ -z "$provider" ]; then
    echo "wm: canonical_memory.provider not configured. Run /yoke:bootstrap to migrate." >&2
    return 4
  fi

  awk -v p="$provider" '
    BEGIN { in_provider = 0; in_skills = 0; in_pass = 0 }
    /^providers:[[:space:]]*$/ { in_providers = 1; next }
    in_providers && /^[^[:space:]#]/ { in_providers = 0 }
    in_providers && match($0, /^  ([A-Za-z0-9_.-]+):[[:space:]]*$/, m) {
      in_provider = (m[1] == p) ? 1 : 0
      in_skills = 0; in_pass = 0
      next
    }
    in_provider && /^    skills:[[:space:]]*$/ { in_skills = 1; in_pass = 0; next }
    in_provider && /^    config_passthrough:[[:space:]]*$/ { in_skills = 0; in_pass = 1; next }
    in_provider && /^    [A-Za-z0-9_]+:/ { in_skills = 0; in_pass = 0 }
    in_provider && in_skills && match($0, /^      search:[[:space:]]*\"?([^\"#]+)\"?[[:space:]]*$/, sm) {
      gsub(/[[:space:]]+$/, "", sm[1])
      search = sm[1]
    }
    in_provider && in_skills && match($0, /^      canonize:[[:space:]]*\"?([^\"#]+)\"?[[:space:]]*$/, cm) {
      gsub(/[[:space:]]+$/, "", cm[1])
      canonize = cm[1]
    }
    in_provider && in_pass && match($0, /^      -[[:space:]]*\"?([^\"#]+)\"?[[:space:]]*$/, pm) {
      gsub(/[[:space:]]+$/, "", pm[1])
      pass[++np] = pm[1]
    }
    END {
      if (search == "" || canonize == "") {
        exit 5
      }
      print p
      print search
      print canonize
      for (i = 1; i <= np; i++) print pass[i]
    }
  ' "$providers_yaml" || {
    echo "wm: provider '$provider' is not registered in providers.yaml or is missing skills.search/canonize." >&2
    return 5
  }
}

# When exec'd directly, print "<name>\t<search>\t<canonize>" on stdout.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  if yoke_resolve_provider "$@"; then
    printf '%s\t%s\t%s\n' "$YOKE_PROVIDER_NAME" "$YOKE_PROVIDER_SEARCH_SKILL" "$YOKE_PROVIDER_CANONIZE_SKILL"
  else
    exit "$?"
  fi
fi
