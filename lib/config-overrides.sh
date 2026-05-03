#!/usr/bin/env bash
# config-overrides.sh — read dotted keys from `.yoke/config.yaml :: overrides.*`
#                       with a caller-supplied default fallback.
#
# Sourced by skills that need to read tunable parameters from the host
# project's `.yoke/config.yaml` `overrides:` block. Mirrors the parsing
# style used by `lib/yoke-prelude.sh` (python3+yaml preferred, yq
# fallback, awk last resort) so behaviour matches whichever toolset the
# host environment carries.
#
# Source PRD: .yoke/prds/2026-05-03-tech-spec-as-design-doc.md (FR-3,
#             US-002 acceptance criterion: threshold overridable via
#             `.yoke/config.yaml :: overrides.tech_spec.canonical_pattern_threshold`).
# Source Spec: .yoke/specs/2026-05-03-tech-spec-as-design-doc.md
# Acceptance Contract: .yoke/acceptance-contracts/2026-05-03-tech-spec-as-design-doc.md
#                     Scenario 1 + Sensor `config-override-reader-callable`.
# Sprint 01 / Task t01.
#
# Cites concepts/yoke-pattern-plugin-structure for the lib/ placement
# rule: tunables live in lib/, sensors live in lib/sensors/, working-
# memory helpers live in lib/working-memory/. This file pins the
# overrides-reader as a top-level lib helper (used by skills, not by
# sensors).
#
# Usage (top of a skill body, after the prelude is sourced):
#
#   source <plugin_dir>/lib/config-overrides.sh
#   threshold="$(yoke_get_override overrides.tech_spec.canonical_pattern_threshold 3)"
#
# Public function:
#   yoke_get_override <dotted.key> <default>
#     - Reads `.yoke/config.yaml` relative to $PWD.
#     - Resolves the dotted key against the YAML tree.
#     - Echoes the resolved string value when the key exists.
#     - Echoes <default> when the key is absent, the value is null/~,
#       the value is an empty string, the file does not exist, or the
#       parse fails for any reason.
#     - Returns 0 in every documented case (this helper is read-only;
#       the hard break for unmigrated projects belongs to
#       `yoke_require_provider`, not to this helper).
#
# Idempotent. The function only reads from disk and writes to stdout;
# never modifies state, never calls out to other helpers, never cd's.

# Do not `set -e` at file scope: this file is sourced by skills that
# may already have their own errexit posture. The function returns 0
# unconditionally and writes to stdout only.

# Idempotent re-source guard.
if [[ -n "${_YOKE_CONFIG_OVERRIDES_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly _YOKE_CONFIG_OVERRIDES_LOADED=1

_yoke_config_overrides_config_path() {
    printf '%s/.yoke/config.yaml' "$(pwd -P)"
}

# Resolve a dotted key against `.yoke/config.yaml` via python3+yaml.
# Echoes the resolved string on stdout (possibly empty) when the file
# exists and python3+yaml is available; echoes nothing and returns
# non-zero otherwise so the caller can fall back.
_yoke_config_overrides_read_python() {
    local cfg="$1"
    local key="$2"
    local out rc=0
    out="$(python3 - "$cfg" "$key" 2>/dev/null <<'PY' || true
import sys
try:
    import yaml  # type: ignore[import]
except ImportError:
    sys.exit(127)
try:
    with open(sys.argv[1]) as f:
        cfg = yaml.safe_load(f) or {}
except Exception:
    sys.exit(126)

key = sys.argv[2]
node = cfg
for segment in key.split("."):
    if not isinstance(node, dict):
        sys.exit(0)
    if segment not in node:
        sys.exit(0)
    node = node[segment]

if node is None:
    sys.exit(0)
# Booleans serialize as Python "True"/"False"; preserve a YAML-shaped
# lower-case literal so callers comparing against "true"/"false" don't
# trip.
if isinstance(node, bool):
    print("true" if node else "false")
    sys.exit(0)
# Lists / dicts collapse to their YAML-ish repr — but the documented
# use case is scalar tunables (numbers, strings, booleans). Surface
# the str() form so the caller sees something rather than nothing;
# the falsy-default branch only fires on missing/empty keys.
print(str(node))
PY
)"
    rc=$?
    if [ "$rc" -eq 0 ]; then
        printf '%s' "$out"
        return 0
    fi
    return "$rc"
}

# Resolve a dotted key against `.yoke/config.yaml` via yq.
# Echoes the resolved value (possibly the literal "null" or empty)
# on stdout; never aborts.
_yoke_config_overrides_read_yq() {
    local cfg="$1"
    local key="$2"
    local out
    # `yq -r '.<key>'` returns the literal string "null" for absent
    # keys; normalise that to empty.
    out="$(yq -r ".${key} // \"\"" "$cfg" 2>/dev/null || true)"
    if [ "$out" = "null" ]; then
        out=""
    fi
    printf '%s' "$out"
}

# Resolve a dotted key against `.yoke/config.yaml` via awk.
# Last-resort fallback. Handles the canonical 2-space-indent
# config.yaml shape that /yoke:bootstrap emits. Recognises an
# unquoted, single-quoted, or double-quoted scalar; strips trailing
# comments. Walks segment-by-segment; depth is tracked by counting
# leading two-space units.
_yoke_config_overrides_read_awk() {
    local cfg="$1"
    local key="$2"
    awk -v key="$key" '
        BEGIN {
            n = split(key, segs, ".")
            depth = 0
            matched_to = 0
        }
        # Skip blank lines and pure-comment lines.
        /^[[:space:]]*(#.*)?$/ { next }
        {
            # Compute indent depth (each 2 leading spaces = one level).
            line = $0
            indent = 0
            while (substr(line, 1, 2) == "  ") {
                indent++
                line = substr(line, 3)
            }
            # The remaining `line` should look like `key:` or `key: value`.
            if (match(line, /^[A-Za-z_][A-Za-z0-9_-]*:/) == 0) { next }
            keypart = substr(line, 1, RLENGTH - 1)
            rest = substr(line, RLENGTH + 1)
            # Trim leading whitespace from the value remainder.
            sub(/^[[:space:]]+/, "", rest)
            # Strip trailing comment.
            sub(/[[:space:]]+#.*$/, "", rest)
            # Strip surrounding quotes.
            sub(/^["'\'']/, "", rest)
            sub(/["'\'']$/, "", rest)
            # Trim trailing whitespace.
            sub(/[[:space:]]+$/, "", rest)

            # If we are at the depth where the next-needed segment
            # lives, advance the match cursor on a hit.
            if (indent == matched_to) {
                wanted = segs[matched_to + 1]
                if (keypart == wanted) {
                    matched_to++
                    if (matched_to == n) {
                        if (rest == "" || rest == "null" || rest == "~") {
                            exit 0
                        }
                        print rest
                        exit 0
                    }
                }
            } else if (indent < matched_to) {
                # Dropped out of the matched subtree without seeing
                # the deeper segments. Reset cursor and reconsider
                # this line at top level.
                matched_to = 0
                if (indent == 0) {
                    wanted = segs[1]
                    if (keypart == wanted) {
                        matched_to = 1
                        if (n == 1) {
                            if (rest == "" || rest == "null" || rest == "~") {
                                exit 0
                            }
                            print rest
                            exit 0
                        }
                    }
                }
            }
            # indent > matched_to: a deeper key under an unmatched
            # parent. Skip.
        }
    ' "$cfg" 2>/dev/null || true
}

# Public function — read a dotted key from `.yoke/config.yaml` with
# a caller-supplied default fallback. Always echoes a value; always
# returns 0.
yoke_get_override() {
    local key="${1:-}"
    local default="${2:-}"

    if [ -z "$key" ]; then
        # Mis-call — print the default, no diagnostic. Mis-calls are a
        # caller bug; we surface the default so the skill stays alive.
        printf '%s' "$default"
        return 0
    fi

    local cfg
    cfg="$(_yoke_config_overrides_config_path)"

    if [ ! -f "$cfg" ]; then
        printf '%s' "$default"
        return 0
    fi

    # Try python3+yaml first.
    local resolved rc
    resolved="$(_yoke_config_overrides_read_python "$cfg" "$key")"
    rc=$?
    if [ "$rc" -eq 0 ]; then
        if [ -n "$resolved" ]; then
            printf '%s' "$resolved"
            return 0
        fi
        # python3+yaml ran cleanly but the key was absent / null.
        # Authoritative — do not fall back.
        printf '%s' "$default"
        return 0
    fi

    # python3+yaml unavailable (rc 127) or parse error (rc 126); try yq.
    if command -v yq >/dev/null 2>&1; then
        resolved="$(_yoke_config_overrides_read_yq "$cfg" "$key")"
        if [ -n "$resolved" ]; then
            printf '%s' "$resolved"
            return 0
        fi
        printf '%s' "$default"
        return 0
    fi

    # Last-resort awk fallback.
    resolved="$(_yoke_config_overrides_read_awk "$cfg" "$key")"
    if [ -n "$resolved" ]; then
        printf '%s' "$resolved"
        return 0
    fi
    printf '%s' "$default"
    return 0
}

# When exec'd directly, read the documented arguments and print.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    yoke_get_override "$@"
    exit $?
fi
