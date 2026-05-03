#!/bin/bash
# orchestrate.sh — deterministic helpers for /yoke:implement (Phase 4 ralph loop).
#
# Subcommands:
#   preflight                        verify Phase-4 pre-conditions
#   active-sprint                    print the value of `current_sprint:` from
#                                     .yoke/runtime/progress.md (zero-padded);
#                                     defaults to `01` when absent. Used by
#                                     /yoke:implement to load the cycle's
#                                     working set (one sprint = one cycle).
#   total-sprints                    print the number of sprint files for the
#                                     active slug (i.e. the count returned by
#                                     wm_list_sprint_paths). Used by the
#                                     coordinator to decide when the outer
#                                     walk has finished.
#   append-contract <yaml-file>      append a sprint contract YAML fragment
#                                     to the active task's
#                                     .yoke/contracts/<slug>.md
#   check-contradiction              detect textual contradictions between
#                                     the active task's contracts and
#                                     acceptance contract (resolved via
#                                     lib/working-memory/paths.sh)
#   help | -h | --help               print this help
#
# v0.4.0: basic implementation. Sprint 6 adds hard-bound enforcement
# (see hooks/check-hard-bounds.sh) and the formal Trigger-4 escalation
# packet (lib/ralph-loop/escalate.sh).
#
# Exit codes:
#   0   success / clean
#   2   usage error
#   3   .yoke/ missing
#   4   upstream artifact missing or unapproved
#   10  contradiction detected (check-contradiction only)

set -euo pipefail

# Locate paths helper relative to this script (so cwd doesn't matter).
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../working-memory/paths.sh
source "${script_dir}/../working-memory/paths.sh"

usage() {
  cat <<'EOF'
Usage: orchestrate.sh <subcommand> [args]

Subcommands:
  preflight                        verify Phase-4 pre-conditions
  active-sprint                    print current_sprint: from progress.md
  total-sprints                    print count of sprint files for active slug
  append-contract <yaml-file>      append a sprint contract from a YAML file
  check-contradiction              detect textual contradictions
  help                             print this help

Exit codes:
  0   success
  2   usage error
  3   .yoke/ missing
  4   upstream artifact missing or unapproved
  10  contradiction detected (check-contradiction only)
EOF
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  help|-h|--help)
    usage
    exit 0
    ;;

  preflight)
    if [ ! -f ".yoke/config.yaml" ]; then
      echo "Error: .yoke/config.yaml not found. Run /yoke:bootstrap first." >&2
      exit 3
    fi
    slug="$(wm_active_slug)" || exit 3
    prd="$(wm_prd_path "$slug")"
    tech="$(wm_spec_path "$slug")"
    ac="$(wm_acceptance_criteria_path "$slug")"
    for f in "$prd" "$tech" "$ac"; do
      if [ ! -f "$f" ]; then
        echo "Error: $f not found. Run the upstream phase first." >&2
        exit 4
      fi
    done
    if ! grep -qE "^> Status:[[:space:]]*(approved|ratified)" "$prd"; then
      echo "Error: $prd is not approved. Run /yoke:discover and approve." >&2
      exit 4
    fi
    if ! grep -qE "^> Status:[[:space:]]*(approved|ratified)" "$tech"; then
      echo "Error: $tech is not approved. Run /yoke:tech-spec and approve." >&2
      exit 4
    fi
    if ! grep -qE "^> Status:[[:space:]]*ratified" "$ac"; then
      echo "Error: $ac is not ratified. Run /yoke:acceptance-criteria and ratify." >&2
      exit 4
    fi
    # Sprint-walk pre-check: at least one sprint file MUST exist for the
    # cycle loop to have a working set to load. The /yoke:implement
    # cycle reads `current_sprint:` from progress.md and loads
    # `.yoke/sprints/<slug>-s<current_sprint>.md` — without sprint
    # files there is nothing to converge.
    sprint_count=0
    while IFS= read -r _; do
      sprint_count=$((sprint_count + 1))
    done < <(wm_list_sprint_paths "$slug" 2>/dev/null || true)
    if [ "$sprint_count" -eq 0 ]; then
      echo "Error: no sprint files for slug '$slug'. Run /yoke:tech-spec and approve." >&2
      exit 4
    fi
    echo "ok"
    exit 0
    ;;

  active-sprint)
    # Read `current_sprint:` from .yoke/runtime/progress.md frontmatter.
    # Returns "01" (the conventional first sprint id) when progress.md
    # is absent or the field is unset — /yoke:implement initializes the
    # walk at sprint 01 on first invocation. Output is zero-padded to
    # 2 digits to match the sprint-id filename convention enforced by
    # WM_SPRINT_ID_REGEX in lib/working-memory/paths.sh.
    progress_file="$(wm_progress_path)" || exit 3
    if [ ! -f "$progress_file" ]; then
      echo "01"
      exit 0
    fi
    raw="$(awk '/^current_sprint:/ { gsub(/^current_sprint:[[:space:]]*"?|"?[[:space:]]*$/, "", $0); print; exit }' "$progress_file" 2>/dev/null || true)"
    if [ -z "$raw" ]; then
      echo "01"
      exit 0
    fi
    # Normalize to zero-padded 2 digits.
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
      printf '%02d\n' "$raw"
      exit 0
    fi
    echo "Error: malformed current_sprint: '$raw' in $progress_file" >&2
    exit 4
    ;;

  total-sprints)
    slug="$(wm_active_slug)" || exit 3
    sprint_count=0
    while IFS= read -r _; do
      sprint_count=$((sprint_count + 1))
    done < <(wm_list_sprint_paths "$slug" 2>/dev/null || true)
    echo "$sprint_count"
    exit 0
    ;;

  append-contract)
    yaml_file="${1:-}"
    if [ -z "$yaml_file" ] || [ ! -f "$yaml_file" ]; then
      echo "Error: append-contract requires a path to a YAML fragment file." >&2
      usage
      exit 2
    fi
    contracts_file="$(wm_contracts_path)" || exit 3
    mkdir -p "$(dirname "$contracts_file")"
    if [ ! -f "$contracts_file" ]; then
      # Initialize from template if available; otherwise minimal header.
      if [ -f "templates/contracts.md" ]; then
        cp templates/contracts.md "$contracts_file"
      else
        printf '# Sprint contracts\n' > "$contracts_file"
      fi
    fi
    {
      echo ""
      echo "## Contract"
      cat "$yaml_file"
    } >> "$contracts_file"
    echo "appended"
    exit 0
    ;;

  check-contradiction)
    contract="$(wm_acceptance_criteria_path)" || exit 3
    sprint_contracts="$(wm_contracts_path)" || exit 3
    if [ ! -f "$contract" ] || [ ! -f "$sprint_contracts" ]; then
      echo "ok"
      exit 0
    fi

    # Heuristic: extract Acceptance Contract criteria (FR-N tokens and
    # "Scenario N" tokens) and flag a sprint-contract `decision:` line
    # when a relax-class verb is grammatically *applied to* one of those
    # criteria. Prior versions tripped on any co-occurrence in the same
    # decision text — that produced false positives whenever the verb
    # referred to an unrelated subject (e.g. "the boundary file is
    # removed; FR-6 still satisfied"). The patterns below require one
    # of three syntactic shapes:
    #   A. verb [article] criterion           (e.g., "relax FR-1",
    #                                          "skip the FR-2 check")
    #   B. criterion <aux> verb-ed             (e.g., "FR-1 was relaxed")
    #   C. criterion verb-ed (direct adjacency) (e.g., "FR-1 dropped")
    criteria=$(grep -oE 'FR-[A-Za-z0-9]+|Scenario [0-9]+' "$contract" 2>/dev/null | sort -u || true)

    if [ -z "$criteria" ]; then
      echo "ok"
      exit 0
    fi

    decisions=$(grep -E '^[[:space:]]*-?[[:space:]]*decision:' "$sprint_contracts" 2>/dev/null || true)

    if [ -z "$decisions" ]; then
      echo "ok"
      exit 0
    fi

    verbs_inf='relax|remove|skip|disable|bypass|ignore|weaken|loosen|abandon|drop|delete'
    verbs_ed='relaxed|removed|skipped|disabled|bypassed|ignored|weakened|loosened|abandoned|dropped|deleted'
    article='(the[[:space:]]+|that[[:space:]]+|its[[:space:]]+|a[[:space:]]+|criterion[[:space:]]+)?'
    aux='(is|are|was|were|gets|got)([[:space:]]+been)?'

    while IFS= read -r criterion; do
      [ -z "$criterion" ] && continue
      # Allow flexible whitespace inside multi-word criteria like
      # "Scenario 4" so the pattern still matches when it's written
      # with a non-breaking space or extra spacing.
      crit_pat=$(printf '%s' "$criterion" | sed -E 's/[[:space:]]+/[[:space:]]+/g')
      pat_a="(${verbs_inf})(s|es|ed|ing)?[[:space:]]+${article}${crit_pat}\\b"
      pat_b="${crit_pat}[[:space:]]+${aux}[[:space:]]+(${verbs_ed})\\b"
      pat_c="${crit_pat}[[:space:]]+(${verbs_ed})\\b"
      while IFS= read -r decline; do
        [ -z "$decline" ] && continue
        match=""
        if   echo "$decline" | grep -qiE "$pat_a"; then match="A (verb→criterion)"
        elif echo "$decline" | grep -qiE "$pat_b"; then match="B (criterion is verbed)"
        elif echo "$decline" | grep -qiE "$pat_c"; then match="C (criterion verbed)"
        fi
        if [ -n "$match" ]; then
          echo "Contradiction: sprint contract decision applies a relax/remove verb to criterion '$criterion' [pattern $match]." >&2
          echo "  decision: $decline" >&2
          echo "Pausing for human arbitration. (Sprint 6 will ship the formal Trigger-4 packet.)" >&2
          exit 10
        fi
      done <<< "$decisions"
    done <<< "$criteria"

    echo "ok"
    exit 0
    ;;

  *)
    echo "Unknown subcommand: $cmd" >&2
    usage
    exit 2
    ;;
esac
