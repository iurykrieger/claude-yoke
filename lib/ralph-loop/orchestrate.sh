#!/bin/bash
# orchestrate.sh — deterministic helpers for /yoke:implement (Phase 4 ralph loop).
#
# Subcommands:
#   preflight                        verify Phase-4 pre-conditions
#   append-contract <yaml-file>      append a sprint contract YAML fragment
#                                     to .yoke/contracts.md
#   check-contradiction              detect textual contradictions between
#                                     .yoke/contracts.md and
#                                     .yoke/acceptance-contract.md
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

usage() {
  cat <<'EOF'
Usage: orchestrate.sh <subcommand> [args]

Subcommands:
  preflight                        verify Phase-4 pre-conditions
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
    for f in .yoke/prd.md .yoke/tech-spec.md .yoke/acceptance-contract.md; do
      if [ ! -f "$f" ]; then
        echo "Error: $f not found. Run the upstream phase first." >&2
        exit 4
      fi
    done
    if ! grep -qE "^> Status:[[:space:]]*(approved|ratified)" .yoke/prd.md; then
      echo "Error: .yoke/prd.md is not approved. Run /yoke:discover and approve." >&2
      exit 4
    fi
    if ! grep -qE "^> Status:[[:space:]]*(approved|ratified)" .yoke/tech-spec.md; then
      echo "Error: .yoke/tech-spec.md is not approved. Run /yoke:tech-spec and approve." >&2
      exit 4
    fi
    if ! grep -qE "^> Status:[[:space:]]*ratified" .yoke/acceptance-contract.md; then
      echo "Error: .yoke/acceptance-contract.md is not ratified. Run /yoke:acceptance-contract and ratify." >&2
      exit 4
    fi
    echo "ok"
    exit 0
    ;;

  append-contract)
    yaml_file="${1:-}"
    if [ -z "$yaml_file" ] || [ ! -f "$yaml_file" ]; then
      echo "Error: append-contract requires a path to a YAML fragment file." >&2
      usage
      exit 2
    fi
    if [ ! -f ".yoke/contracts.md" ]; then
      # Initialize from template if available; otherwise minimal header.
      if [ -f "templates/contracts.md" ]; then
        cp templates/contracts.md .yoke/contracts.md
      else
        printf '# Sprint contracts\n' > .yoke/contracts.md
      fi
    fi
    {
      echo ""
      echo "## Contract"
      cat "$yaml_file"
    } >> .yoke/contracts.md
    echo "appended"
    exit 0
    ;;

  check-contradiction)
    contract=".yoke/acceptance-contract.md"
    sprint_contracts=".yoke/contracts.md"
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
