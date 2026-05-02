#!/usr/bin/env bash
# shellcheck shell=bash
#
# trigger-4.sh — Sprint 02 / Task t04 / Acceptance Contract Scenario 9 + FR-3.
#
# Renders the user-facing Trigger 4 escalation message when the council
# protocol exhausts its round cap with unresolved disagreements.
# Generalizes the v2.x 2-party Implementation↔Validation arbitration
# message to N-party persona pairs.
#
# Subcommand:
#
#   render <merged-view-path> <last-arbiter-verdict-path> [<output-path>]
#
#       Reads the merged council view + the arbiter's last JSON verdict
#       (schema: round, consensus, contradictions[], tone_only_pairs[])
#       and emits a markdown escalation message to <output-path>
#       (default: .yoke/runtime/.trigger4-council-message.md). Echoes
#       the message to stdout for piping into lib/ralph-loop/escalate.sh.
#
#       Message shape:
#
#           # Trigger 4 — council cap exhausted
#
#           Round: <N> | Cap: <N> | Status: cap-exhausted
#
#           ## Unresolved persona pairs
#           - sr-eng × sr-qa — <summary> [direct-contradiction]
#           - sr-qa × sr-staff — <summary> [importance-disagreement]
#
#           ## Arbiter verdict summary
#           consensus=false contradictions=2 tone_only_pairs=1
#
#           ## Directive
#           Pick one persona to ratify (e.g. `ratify sr-staff`),
#           or supply a third resolution (e.g. `rework needed: <text>`).
#
# The message is what the existing escalate.sh attaches to the
# Trigger-4 packet. v2.x's `lib/ralph-loop/escalate.sh` takes a
# `--council-message <path>` flag added in Sprint 02 (see the script
# itself).
#
# Cites concepts/yoke-pattern-human-triggers — Trigger 4 is the
# human-arbitration trigger that fires on persona divergence the
# council loop cannot resolve. The full pattern documentation is
# rewritten in Sprint 4; v3.0 ships an inline reference comment in the
# rendered file pointing at the canonical-memory entity.
#
# Cites concepts/yoke-conventions for the structured-output contract
# (every error path emits `wm:`-prefixed stderr).

set -euo pipefail

if [[ -z "${_YOKE_TRIGGER_4_LOADED:-}" ]]; then
  readonly _YOKE_TRIGGER_4_LOADED=1

  _yoke_trigger_4_violation() {
    printf 'wm: %s\n' "$1" >&2
  }

  # _yoke_trigger_4_round <verdict-path>
  #   Echoes the integer in `"round": <N>` (default 0 on parse failure).
  _yoke_trigger_4_round() {
    local verdict="$1"
    awk '
      match($0, /"round"[[:space:]]*:[[:space:]]*[0-9]+/) {
        m = substr($0, RSTART, RLENGTH)
        sub(/.*:[[:space:]]*/, "", m)
        print m
        exit
      }
    ' "$verdict" 2>/dev/null || true
  }

  # _yoke_trigger_4_consensus <verdict-path>
  #   Echoes `true`/`false` for the consensus boolean.
  _yoke_trigger_4_consensus() {
    local verdict="$1"
    if grep -Eq '"consensus"[[:space:]]*:[[:space:]]*true' "$verdict"; then
      printf 'true'
    else
      printf 'false'
    fi
  }

  # _yoke_trigger_4_extract_pairs <verdict-path>
  #   Walks the JSON verdict's `contradictions` array and emits one
  #   pipe-delimited line per entry: `<persona-a>|<persona-b>|<summary>|<category>`.
  #   Uses python3-free awk by reading the whole file as one string
  #   first (records are split on the closing `]` of contradictions,
  #   then per-object extraction).
  _yoke_trigger_4_extract_pairs() {
    local verdict="$1"
    awk '
      function extract_field(s, key,    re, m) {
        re = "\"" key "\"[[:space:]]*:[[:space:]]*\"[^\"]*\""
        if (match(s, re)) {
          m = substr(s, RSTART, RLENGTH)
          sub(/.*:[[:space:]]*"/, "", m)
          sub(/"$/, "", m)
          return m
        }
        return ""
      }
      function extract_personas(s,    p1, p2, m, body, rest, q, qq, idx) {
        if (match(s, /"personas"[[:space:]]*:[[:space:]]*\[[^]]*\]/)) {
          body = substr(s, RSTART, RLENGTH)
          rest = body
          idx = 0
          while (match(rest, /"[^"]*"/)) {
            q = substr(rest, RSTART, RLENGTH)
            qq = substr(q, 2, length(q) - 2)
            rest = substr(rest, RSTART + RLENGTH)
            if (qq != "personas") {
              idx++
              if (idx == 1) p1 = qq
              else if (idx == 2) { p2 = qq; break }
            }
          }
          return p1 "\t" p2
        }
        return "\t"
      }
      {
        all = all $0 "\n"
      }
      END {
        # Find contradictions array bounds.
        if (!match(all, /"contradictions"[[:space:]]*:[[:space:]]*\[/)) exit
        start = RSTART + RLENGTH
        # Find matching closing bracket at depth 0.
        depth = 1
        end = 0
        for (i = start; i <= length(all); i++) {
          c = substr(all, i, 1)
          if (c == "[") depth++
          else if (c == "]") { depth--; if (depth == 0) { end = i; break } }
        }
        if (end == 0) exit
        body = substr(all, start, end - start)
        # Walk top-level objects within body.
        depth = 0
        objstart = 0
        for (i = 1; i <= length(body); i++) {
          c = substr(body, i, 1)
          if (c == "{") {
            if (depth == 0) objstart = i
            depth++
          } else if (c == "}") {
            depth--
            if (depth == 0 && objstart > 0) {
              obj = substr(body, objstart, i - objstart + 1)
              objstart = 0
              ps = extract_personas(obj)
              n = split(ps, parts, "\t")
              p1 = parts[1]; p2 = parts[2]
              sum = extract_field(obj, "summary")
              cat = extract_field(obj, "category")
              printf "%s|%s|%s|%s\n", p1, p2, sum, cat
            }
          }
        }
      }
    ' "$verdict" 2>/dev/null || true
  }

  # _yoke_trigger_4_arbiter_summary <verdict-path>
  #   One-line summary mirroring council.sh's _yoke_council_arbiter_summary
  #   shape so the Trigger 4 message and the council YAML summary stay
  #   consistent.
  _yoke_trigger_4_arbiter_summary() {
    local verdict="$1"
    local consensus
    consensus="$(_yoke_trigger_4_consensus "$verdict")"
    local contradictions tone_only total_summaries
    contradictions="$(grep -oE '"category"[[:space:]]*:' "$verdict" | wc -l | tr -d ' ')"
    [[ -n "$contradictions" ]] || contradictions=0
    total_summaries="$(grep -oE '"summary"[[:space:]]*:' "$verdict" | wc -l | tr -d ' ')"
    [[ -n "$total_summaries" ]] || total_summaries=0
    tone_only=$((total_summaries - contradictions))
    [[ "$tone_only" -ge 0 ]] || tone_only=0
    printf 'consensus=%s contradictions=%s tone_only_pairs=%s' \
      "$consensus" "$contradictions" "$tone_only"
  }

  # _yoke_trigger_4_render <merged-view> <last-arbiter-verdict> [<output-path>]
  _yoke_trigger_4_render() {
    if [[ $# -lt 2 ]]; then
      _yoke_trigger_4_violation "trigger-4: render requires <merged-view> <last-arbiter-verdict> [<output-path>]"
      return 2
    fi
    local merged="$1"
    local verdict="$2"
    local out="${3:-.yoke/runtime/.trigger4-council-message.md}"
    if [[ ! -f "$merged" ]]; then
      _yoke_trigger_4_violation "trigger-4: merged view not found: '$merged'"
      return 1
    fi
    if [[ ! -f "$verdict" ]]; then
      _yoke_trigger_4_violation "trigger-4: arbiter verdict not found: '$verdict'"
      return 1
    fi

    mkdir -p "$(dirname "$out")"

    local round
    round="$(_yoke_trigger_4_round "$verdict")"
    [[ -n "$round" ]] || round="?"
    local cap="${YOKE_COUNCIL_ROUND_CAP:-?}"
    local summary
    summary="$(_yoke_trigger_4_arbiter_summary "$verdict")"

    {
      printf '<!-- Trigger 4 — council protocol cap exhausted. See concepts/yoke-pattern-human-triggers (canonical memory) for the full pattern documentation; v3.0 inline reference. -->\n\n'
      printf '# Trigger 4 — council cap exhausted\n\n'
      printf 'Round: %s | Cap: %s | Status: cap-exhausted\n\n' "$round" "$cap"

      printf '## Unresolved persona pairs\n'
      local found=0
      local line p1 p2 sum cat
      while IFS='|' read -r p1 p2 sum cat; do
        [[ -n "$p1" && -n "$p2" ]] || continue
        found=$((found + 1))
        # Sort persona names alphabetically for the `× ` rendering, so
        # `sr-eng × sr-qa` and `sr-qa × sr-eng` collapse to a stable
        # canonical form.
        local a b
        if [[ "$p1" < "$p2" ]]; then
          a="$p1"; b="$p2"
        else
          a="$p2"; b="$p1"
        fi
        printf -- '- %s × %s — %s [%s]\n' "$a" "$b" "$sum" "$cat"
      done < <(_yoke_trigger_4_extract_pairs "$verdict")
      if [[ "$found" == "0" ]]; then
        printf -- '- (no contradictions extracted from the arbiter verdict; this is a sensor-bug-grade signal)\n'
      fi
      printf '\n'

      printf '## Arbiter verdict summary\n'
      printf '%s\n\n' "$summary"

      printf '## Merged council view\n'
      printf '<!-- Inlined verbatim for human review. -->\n\n'
      cat "$merged"
      printf '\n'

      printf '## Directive\n'
      printf 'Pick one persona to ratify (e.g. `ratify sr-staff`), or supply a\n'
      printf 'third resolution (e.g. `rework needed: <text>`). The council\n'
      printf 'loop persists your reply as the cycle resolution and resumes\n'
      printf 'on the next /yoke:implement invocation.\n'
    } > "$out"

    cat "$out"
    return 0
  }
fi

# --- CLI dispatch -----------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    render)
      shift
      _yoke_trigger_4_render "$@"
      exit "$?"
      ;;
    ""|-h|--help|help)
      cat <<'EOF'
trigger-4.sh — render the council Trigger 4 escalation message.

Usage:
  trigger-4.sh render <merged-view> <last-arbiter-verdict> [<output-path>]

Environment:
  YOKE_COUNCIL_ROUND_CAP   passed through into the rendered "Cap: <N>" line.

Exit codes:
  0  message rendered to <output-path> and echoed to stdout.
  1  unrecoverable error; a `wm:`-prefixed stderr line names the failure.
  2  CLI usage error.
EOF
      exit 0
      ;;
    *)
      _yoke_trigger_4_violation "trigger-4: unknown subcommand: '${1}'"
      exit 2
      ;;
  esac
fi
