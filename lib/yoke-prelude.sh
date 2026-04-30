#!/usr/bin/env bash
# yoke-prelude.sh — shared pre-flight helper sourced by every Yoke skill
# except `bootstrap` (the migration entry point) and the seven legacy
# skills scheduled for deletion in Sprint 03 t03 (`ask`, `preserve`,
# `teach`, `compress`, `memory`, `confluence-to-markdown`, `gdoc-to-markdown`).
#
# Implements the v2.0.0 hard-break contract from the
# pluggable-canonical-memory PRD: a Yoke skill MUST refuse to run on a
# host project whose `.yoke/config.yaml` lacks the
# `canonical_memory.provider` key. Backward compatibility for in-flight
# tasks is not promised — the user must re-run `/yoke:bootstrap` to
# migrate a v1.x project to the v2.0.0 schema before any other Yoke
# skill works again.
#
# Usage (top of every eligible skill's pre-flight, AFTER the
# `<plugin_dir>/lib/working-memory/paths.sh` source line):
#
#   source <plugin_dir>/lib/yoke-prelude.sh && yoke_require_provider \
#     || exit 1
#
# Exported function:
#   yoke_require_provider — reads `.yoke/config.yaml` relative to $PWD,
#     parses `canonical_memory.provider` via either python3+yaml
#     (preferred), yq (fallback), or grep/awk (last resort), and:
#       - exit 0      → key present and non-empty (caller continues)
#       - exit 2      → `.yoke/config.yaml` is missing in $PWD
#                       (stderr: `wm: <abs_path> not found. Run
#                       /yoke:bootstrap to initialize this project.`)
#       - exit 1      → file present but `canonical_memory.provider`
#                       is missing or empty (stderr: `wm:
#                       canonical_memory.provider not configured. Run
#                       /yoke:bootstrap to migrate.`)
#
# Idempotent. The function only reads from disk and writes to stderr +
# return code. It does NOT export any variable, does NOT cd, does NOT
# call out to other helpers. The provider-name resolution belongs to
# `lib/canonical-memory/resolve-provider.sh::yoke_resolve_provider`,
# which the dispatch facades source separately. This helper exists to
# fail fast — before a skill even attempts to dispatch — when the
# project is unmigrated.
#
# References:
# - PRD:  .yoke/prds/2026-04-30-pluggable-canonical-memory.md
# - Spec: .yoke/specs/2026-04-30-pluggable-canonical-memory.md
# - Acceptance Contract Scenario 12 / FR-6.
# - Sprint 3 task 2026-04-30-pluggable-canonical-memory-s03-t02.

# Do not `set -e` at file scope: this file is sourced by skills that
# may already have their own errexit posture. The function returns
# explicit exit codes; callers branch on those.

_yoke_prelude_config_path() {
  printf '%s/.yoke/config.yaml' "$(pwd -P)"
}

# Read `canonical_memory.provider` from the host project's config.
# Echoes the trimmed value (possibly empty) on stdout. Never aborts.
_yoke_prelude_read_provider() {
  local cfg="$1"
  # Try python3 + yaml first (deterministic).
  local out rc=0
  out="$(python3 - "$cfg" 2>/dev/null <<'PY' || true
import sys
try:
    import yaml  # type: ignore[import]
except ImportError:
    sys.exit(127)
try:
    with open(sys.argv[1]) as f:
        cfg = yaml.safe_load(f) or {}
except Exception:
    sys.exit(0)
cm = cfg.get("canonical_memory") or {}
if not isinstance(cm, dict):
    sys.exit(0)
provider = cm.get("provider")
if isinstance(provider, str):
    print(provider.strip())
PY
)"
  rc=$?
  if [ "$rc" -eq 0 ] && [ -n "$out" ]; then
    printf '%s' "$out"
    return 0
  fi
  if [ "$rc" -eq 0 ]; then
    # python3 ran but no provider key (or empty). Don't fall back —
    # python3 yaml is authoritative when available.
    printf ''
    return 0
  fi

  # python3+yaml unavailable; try yq.
  if command -v yq >/dev/null 2>&1; then
    out="$(yq -r '.canonical_memory.provider // ""' "$cfg" 2>/dev/null || true)"
    out="${out#null}"
    [ "$out" = "null" ] && out=""
    printf '%s' "$out"
    return 0
  fi

  # Last-resort grep/awk fallback. Handles the canonical 2-space-indent
  # config.yaml shape that /yoke:bootstrap emits. Recognises an
  # unquoted, single-quoted, or double-quoted scalar; strips trailing
  # comments.
  awk '
    /^canonical_memory:[[:space:]]*$/ { in_cm = 1; next }
    in_cm && /^[^[:space:]#]/ { in_cm = 0 }
    in_cm && /^[[:space:]]+provider:[[:space:]]*/ {
      sub(/^[[:space:]]+provider:[[:space:]]*/, "", $0)
      gsub(/[[:space:]]*#.*$/, "", $0)
      gsub(/^[\"'\'']|[\"'\'']$/, "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      print $0
      exit
    }
  ' "$cfg" 2>/dev/null || true
}

# Public function — sourced and called by every eligible skill's
# pre-flight. Returns 0 / 1 / 2 per the documented contract above.
yoke_require_provider() {
  local cfg
  cfg="$(_yoke_prelude_config_path)"

  if [ ! -f "$cfg" ]; then
    printf 'wm: %s not found. Run /yoke:bootstrap to initialize this project.\n' "$cfg" >&2
    return 2
  fi

  local provider
  provider="$(_yoke_prelude_read_provider "$cfg")"

  # Treat literal "null", "~", and empty string as unset.
  case "$provider" in
    ""|null|"~")
      printf 'wm: canonical_memory.provider not configured. Run /yoke:bootstrap to migrate.\n' >&2
      return 1
      ;;
  esac

  return 0
}

# When exec'd directly, run the check and exit.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  yoke_require_provider
  exit $?
fi
