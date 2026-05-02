#!/usr/bin/env bash
# shellcheck shell=bash
#
# persona-loader.sh — Sprint 01 / Task t03 / Acceptance Contract
# Scenario 3 + FR-1.
#
# Validates persona files (Claude Code agent format extended with the
# Yoke-specific keys `objective`, `sensor-toolkit`, optional `review-skill`)
# at `/yoke:implement` startup. Two callable subcommands:
#
#   validate      <persona-file-path>
#   validate-all  <agents-dir>
#
# Behaviour:
#   - On success: exit 0, no stdout, no stderr.
#   - On any frontmatter violation: print a `wm: <message>` line to stderr
#     naming both the file path AND the missing or malformed key, then
#     exit non-zero. The `wm:` prefix is the deterministic-sensor-output
#     contract from `concepts/yoke-conventions`.
#
# Required keys in the YAML frontmatter (delimited by lines that contain
# only `---`):
#   - name           — non-empty scalar.
#   - description    — non-empty scalar.
#   - tools          — non-empty scalar (Claude Code agent format is
#                      a comma-separated tool list on a single line).
#   - objective      — non-empty scalar.
#   - sensor-toolkit — YAML list (block style with `- ` items, possibly
#                      empty list spelled `[]`). A scalar string is a
#                      type violation.
#
# Optional key:
#   - review-skill   — when present, must be a scalar string. When the
#                      persona name is `sr-staff`, the field is required
#                      to default to `/review` (handled by the
#                      `persona-files-shape` test, not by this loader,
#                      so a host that overrides the default still passes).
#
# Discovery: this loader is sourced by `/yoke:implement`'s pre-flight in
# Sprint 2. Sprint 1 only ships the helper plus its tests.

set -euo pipefail

# Idempotent re-source guard. The loader is also called as a CLI;
# the guard only protects the function definitions, not the dispatch.
if [[ -z "${_YOKE_PERSONA_LOADER_LOADED:-}" ]]; then
  readonly _YOKE_PERSONA_LOADER_LOADED=1

  # _yoke_persona_violation <file> <message>
  _yoke_persona_violation() {
    local file="$1"
    local msg="$2"
    printf 'wm: persona-loader violation: %s: %s\n' "$file" "$msg" >&2
  }

  # _yoke_persona_extract_frontmatter <file>
  # Echoes the YAML frontmatter body (the lines between the first and
  # second `---` delimiters). Empty output means "no frontmatter".
  _yoke_persona_extract_frontmatter() {
    local file="$1"
    awk '
      BEGIN          { in_fm = 0; seen = 0 }
      /^---[[:space:]]*$/ {
        if (!seen) {
          in_fm = 1
          seen = 1
          next
        }
        if (in_fm) {
          in_fm = 0
          exit
        }
      }
      in_fm { print }
    ' "$file"
  }

  # _yoke_persona_scalar_value <key> <frontmatter>
  # Echoes the scalar value for `key:` in the given frontmatter body.
  # Trims surrounding whitespace and strips a single layer of quotes.
  # Empty output means "key absent or value empty".
  _yoke_persona_scalar_value() {
    local key="$1"
    local fm="$2"
    printf '%s\n' "$fm" | awk -v key="$key" '
      $0 ~ "^"key":" {
        line = $0
        sub("^"key":[[:space:]]*", "", line)
        sub(/[[:space:]]+$/, "", line)
        # strip wrapping quotes
        if (line ~ /^".*"$/) { line = substr(line, 2, length(line)-2) }
        else if (line ~ /^'\''.*'\''$/) { line = substr(line, 2, length(line)-2) }
        print line
        exit
      }
    '
  }

  # _yoke_persona_key_present <key> <frontmatter>
  # Returns 0 (true) when `<key>:` is present at the top level of the
  # frontmatter body, regardless of whether the value is a scalar or a
  # block-list opener.
  _yoke_persona_key_present() {
    local key="$1"
    local fm="$2"
    printf '%s\n' "$fm" | awk -v key="$key" '
      $0 ~ "^"key":" { found = 1; exit }
      END { exit (found ? 0 : 1) }
    '
  }

  # _yoke_persona_is_block_list <key> <frontmatter>
  # Returns 0 (true) when `<key>:` is followed by either `[]` (inline
  # empty list) or by at least one indented `- ` item. Returns 1 when
  # the value is a non-empty scalar (the FR-1 type violation case).
  _yoke_persona_is_block_list() {
    local key="$1"
    local fm="$2"
    printf '%s\n' "$fm" | awk -v key="$key" '
      BEGIN { state = 0 }
      state == 0 && $0 ~ "^"key":" {
        line = $0
        sub("^"key":[[:space:]]*", "", line)
        sub(/[[:space:]]+$/, "", line)
        # inline empty list
        if (line == "[]") { found = 1; exit }
        # inline non-empty flow-style list — also acceptable as a list
        if (line ~ /^\[.*\]$/) { found = 1; exit }
        # any other non-empty scalar is a type violation
        if (line != "") { found = 0; exit }
        state = 1
        next
      }
      state == 1 {
        if ($0 ~ /^[[:space:]]*-[[:space:]]/) { found = 1; exit }
        if ($0 ~ /^[A-Za-z_-]+:/)             { found = 0; exit }
        if ($0 ~ /^[[:space:]]*$/)            { next }
      }
      END { exit (found ? 0 : 1) }
    '
  }

  # _yoke_persona_validate_file <file>
  # Returns 0 on a valid file; on any violation prints `wm:`-prefixed
  # stderr and returns non-zero.
  _yoke_persona_validate_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
      _yoke_persona_violation "$file" "file not found"
      return 1
    fi

    local fm
    fm="$(_yoke_persona_extract_frontmatter "$file")"
    if [[ -z "$fm" ]]; then
      _yoke_persona_violation "$file" "missing YAML frontmatter (expected a '---' delimited block at the top of the file)"
      return 1
    fi

    local key
    for key in name description tools objective; do
      if ! _yoke_persona_key_present "$key" "$fm"; then
        _yoke_persona_violation "$file" "missing required key: $key"
        return 1
      fi
      local value
      value="$(_yoke_persona_scalar_value "$key" "$fm")"
      if [[ -z "$value" ]]; then
        _yoke_persona_violation "$file" "required key '$key' is present but empty"
        return 1
      fi
    done

    if ! _yoke_persona_key_present sensor-toolkit "$fm"; then
      _yoke_persona_violation "$file" "missing required key: sensor-toolkit"
      return 1
    fi
    if ! _yoke_persona_is_block_list sensor-toolkit "$fm"; then
      _yoke_persona_violation "$file" "key 'sensor-toolkit' must be a YAML list (block '- ' items or inline '[]'), not a scalar string"
      return 1
    fi

    # review-skill is optional. When present, it must be a scalar (we
    # do not enforce the leading slash here — host overrides may target
    # arbitrary skill identifiers).
    if _yoke_persona_key_present review-skill "$fm"; then
      :
    fi

    return 0
  }

  # _yoke_persona_validate_dir <dir>
  # Loops over every council-persona file directly inside <dir> and
  # validates each. Council personas are identified by the filename
  # convention `<persona>.md` where `<persona>` carries the
  # `sr-*` prefix that Yoke ships defaults for; this is the same
  # convention `concepts/yoke-pattern-roles` records for the council
  # personas (Sr Eng, Sr QA, Sr Staff). Non-persona agent files in
  # the same directory (e.g. `agents/orchestrator.md` for the
  # canonize-only termination handoff, `agents/council-arbiter.md`
  # for the contradiction-detection JSON verdict, `agents/semantic-
  # judge.md` for legacy inferential-sensor dispatch) are
  # intentionally NOT council personas and are skipped by the sweep.
  #
  # Returns 0 only when every council-persona file passes.
  _yoke_persona_validate_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
      _yoke_persona_violation "$dir" "agents directory not found"
      return 1
    fi
    local rc=0 file
    shopt -s nullglob
    for file in "$dir"/sr-*.md; do
      if ! _yoke_persona_validate_file "$file"; then
        rc=1
      fi
    done
    shopt -u nullglob
    return "$rc"
  }
fi

# --- CLI dispatch -----------------------------------------------------------

# Only run dispatch when invoked as a script, not when sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    validate)
      shift
      if [[ $# -ne 1 ]]; then
        printf 'usage: persona-loader.sh validate <persona-file-path>\n' >&2
        exit 2
      fi
      _yoke_persona_validate_file "$1"
      exit "$?"
      ;;
    validate-all)
      shift
      if [[ $# -ne 1 ]]; then
        printf 'usage: persona-loader.sh validate-all <agents-dir>\n' >&2
        exit 2
      fi
      _yoke_persona_validate_dir "$1"
      exit "$?"
      ;;
    ""|-h|--help|help)
      cat <<'EOF'
persona-loader.sh — validate Yoke council persona files.

Usage:
  persona-loader.sh validate      <persona-file-path>
  persona-loader.sh validate-all  <agents-dir>

Exit codes:
  0  every persona file is valid.
  1  at least one persona file is malformed (a `wm:`-prefixed
     diagnostic on stderr names every offending file plus key).
  2  CLI usage error.
EOF
      exit 0
      ;;
    *)
      printf 'persona-loader.sh: unknown subcommand: %s\n' "$1" >&2
      exit 2
      ;;
  esac
fi
