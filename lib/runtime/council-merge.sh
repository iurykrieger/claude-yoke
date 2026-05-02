#!/usr/bin/env bash
# shellcheck shell=bash
#
# council-merge.sh — Sprint 01 / Task t04 / Acceptance Contract
# Scenario 4 + FR-2.
#
# Deterministic merge helper for the per-cycle persona slice protocol.
# Each council cycle owns a directory at `.yoke/runtime/cycles/<N>/`
# containing one `<persona>.md` slice file per active persona. This helper
# reads each slice file in alphabetical order and emits a structured
# markdown view to stdout: one `## <persona>` H2 per persona with the
# slice body inlined as H3s under that H2.
#
# Subcommands:
#
#   merge                         <cycle-dir>
#   check-slice-isolation         <cycle-dir>
#
# `merge` is pure: it performs no writes, issues no canonical-memory
# queries, makes no LLM calls, and reads no files outside the named
# cycle directory. Two consecutive invocations against the same cycle
# directory MUST produce byte-identical stdout (verified by `diff -q`
# in `tests/runtime/council-merge.test.sh`). Merge order is alphabetical
# regardless of file mtime.
#
# `check-slice-isolation` inspects each slice's `## Phase A — own progress`
# section and asserts that no body line cites another persona's name as
# the author of the progress entry. A `## Phase A — own progress` block
# whose body lines start with `# author: <other-persona>` (or any
# `^author: <other>` line whose value is a known persona other than the
# slice's own filename) is flagged as a slice-isolation violation. On
# violation, the sensor emits a `wm: slice-isolation violation:` line to
# stderr naming the slice file plus the offending author and exits
# non-zero. On success, exits 0 silently.
#
# Cites concepts/yoke-pattern-memory-model for the working-memory archive
# layout invariants (slice files are runtime-tier ephemeral working
# memory under .yoke/runtime/cycles/<N>/, not versioned archive).
#
# Discovery: this helper is sourced by `/yoke:implement`'s Phase B
# opener in Sprint 2. Sprint 1 ships the helper plus its tests only.

set -euo pipefail

# Idempotent re-source guard. The helper is also called as a CLI;
# the guard only protects the function definitions, not the dispatch.
if [[ -z "${_YOKE_COUNCIL_MERGE_LOADED:-}" ]]; then
  readonly _YOKE_COUNCIL_MERGE_LOADED=1

  # _yoke_council_merge_violation <message>
  _yoke_council_merge_violation() {
    printf 'wm: %s\n' "$1" >&2
  }

  # _yoke_council_merge_list_slices <cycle-dir>
  #   prints one slice basename per line, alphabetically sorted, no path,
  #   no extension. Empty output (and exit 0) when the directory is
  #   empty. Exits non-zero only when the directory does not exist.
  _yoke_council_merge_list_slices() {
    local cycle_dir="$1"
    if [[ ! -d "$cycle_dir" ]]; then
      _yoke_council_merge_violation "council-merge: cycle directory not found: '$cycle_dir'"
      return 1
    fi
    (
      shopt -s nullglob
      local f
      for f in "$cycle_dir"/*.md; do
        basename "$f" .md
      done
    ) | LC_ALL=C sort
  }

  # _yoke_council_merge_emit_slice <slice-file> <persona>
  #   emits a `## <persona>` H2 plus the slice body, with every existing
  #   H2 in the body demoted to H3 (so the merged document has exactly
  #   one H2 per persona). Slice frontmatter (top-of-file `---` block)
  #   is dropped; everything after the closing `---` is body. Slices
  #   without frontmatter are inlined as-is.
  _yoke_council_merge_emit_slice() {
    local slice_file="$1"
    local persona="$2"
    printf '## %s\n\n' "$persona"
    awk '
      BEGIN { in_fm = 0; saw_fm = 0; emitted_body = 0 }
      NR == 1 && $0 == "---" { in_fm = 1; saw_fm = 1; next }
      in_fm == 1 && $0 == "---" { in_fm = 0; next }
      in_fm == 1 { next }
      {
        # Demote every existing H2 in the slice to H3 so the merged view
        # carries exactly one H2 per persona; deeper headings are kept.
        if ($0 ~ /^## /) { sub(/^## /, "### ", $0) }
        print
        emitted_body = 1
      }
      END {
        # Ensure the slice contributes a trailing newline regardless of
        # how the source file ends — determinism requires a stable
        # boundary between personas.
        if (emitted_body == 0) { print "" }
      }
    ' "$slice_file"
    printf '\n'
  }

  # _yoke_council_merge_run <cycle-dir>
  #   the deterministic merge body. Pure: reads only the named cycle
  #   directory and the slice files inside it; writes only to stdout.
  _yoke_council_merge_run() {
    local cycle_dir="$1"
    local slices
    if ! slices="$(_yoke_council_merge_list_slices "$cycle_dir")"; then
      return 1
    fi
    if [[ -z "$slices" ]]; then
      # Empty cycle directory is a valid input; emit a zero-byte view
      # rather than an error so the caller can detect the empty case
      # via output length rather than exit code.
      return 0
    fi
    local persona
    while IFS= read -r persona; do
      [[ -n "$persona" ]] || continue
      _yoke_council_merge_emit_slice "$cycle_dir/${persona}.md" "$persona"
    done <<< "$slices"
  }

  # _yoke_council_merge_check_isolation <cycle-dir>
  #   walks every slice file, extracts the section under
  #   `## Phase A — own progress`, and flags any `^author: <other>` line
  #   whose value is a known persona name (the basename of any other
  #   slice in the cycle directory) other than the slice's own
  #   filename. Returns 0 when every slice's progress block is
  #   self-authored; non-zero (with a `wm:`-prefixed stderr line) on
  #   any violation.
  _yoke_council_merge_check_isolation() {
    local cycle_dir="$1"
    local slices
    if ! slices="$(_yoke_council_merge_list_slices "$cycle_dir")"; then
      return 1
    fi
    if [[ -z "$slices" ]]; then
      return 0
    fi
    # Build the set of known persona names for the cycle (one per
    # slice file). The check considers any author cite that names a
    # persona in this set, but skips cites to the slice's own name.
    local known_personas=()
    local persona
    while IFS= read -r persona; do
      [[ -n "$persona" ]] || continue
      known_personas+=("$persona")
    done <<< "$slices"
    local rc=0
    local owner
    for owner in "${known_personas[@]}"; do
      local slice_file="$cycle_dir/${owner}.md"
      [[ -f "$slice_file" ]] || continue
      # Extract the body of the `## Phase A — own progress` section
      # (everything between that H2 and the next `^## ` heading or EOF).
      local section
      section="$(awk '
        /^## Phase A — own progress[[:space:]]*$/ { in_section = 1; next }
        in_section == 1 && /^## / { in_section = 0 }
        in_section == 1 { print }
      ' "$slice_file")"
      [[ -n "$section" ]] || continue
      # Look for `author: <name>` lines (case-insensitive on the key,
      # exact match on the value against the known-personas set).
      local author_line author_name
      while IFS= read -r author_line; do
        [[ -n "$author_line" ]] || continue
        author_name="$(printf '%s' "$author_line" \
          | sed -E 's/^[[:space:]]*[Aa]uthor:[[:space:]]*//; s/[[:space:]]+$//')"
        [[ -n "$author_name" ]] || continue
        if [[ "$author_name" == "$owner" ]]; then
          continue
        fi
        local other
        for other in "${known_personas[@]}"; do
          if [[ "$author_name" == "$other" ]]; then
            _yoke_council_merge_violation \
              "slice-isolation violation: ${slice_file} declares author '${author_name}' under '## Phase A — own progress' but the slice owner is '${owner}'"
            rc=1
            break
          fi
        done
      done < <(printf '%s\n' "$section" | grep -E '^[[:space:]]*[Aa]uthor:' || true)
    done
    return "$rc"
  }
fi

# CLI dispatch. The script is both sourceable (function definitions are
# protected by the re-source guard above) and executable (this dispatch
# block runs when invoked as `bash lib/runtime/council-merge.sh ...`).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -lt 1 ]]; then
    _yoke_council_merge_violation "council-merge: missing subcommand; expected 'merge <cycle-dir>' or 'check-slice-isolation <cycle-dir>'"
    exit 1
  fi
  subcommand="$1"
  shift
  case "$subcommand" in
    merge)
      if [[ $# -ne 1 ]]; then
        _yoke_council_merge_violation "council-merge: 'merge' requires exactly one argument <cycle-dir>"
        exit 1
      fi
      _yoke_council_merge_run "$1"
      ;;
    check-slice-isolation)
      if [[ $# -ne 1 ]]; then
        _yoke_council_merge_violation "council-merge: 'check-slice-isolation' requires exactly one argument <cycle-dir>"
        exit 1
      fi
      _yoke_council_merge_check_isolation "$1"
      ;;
    *)
      _yoke_council_merge_violation "council-merge: unknown subcommand '$subcommand'; expected 'merge' or 'check-slice-isolation'"
      exit 1
      ;;
  esac
fi
