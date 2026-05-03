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
# Environment variables (production code paths — NOT test-only branches):
#   YOKE_IMPLEMENT_DRY_RUN   When set to '1', the `preflight` subcommand
#                             still runs every gate check (config
#                             presence, upstream-artifact approval,
#                             AC ratification, gate-state ladder,
#                             sprint-file presence) but emits the
#                             extra stdout marker `dry-run: ok` and
#                             exits 0 BEFORE Phase A council spawn.
#                             The downstream cycle loop (sourcing
#                             this preflight from /yoke:implement)
#                             reads `dry-run: ok` and short-circuits.
#                             Useful for inspecting gate state on
#                             a real working tree without paying
#                             the council-spawn cost.
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
# shellcheck source=../working-memory/gate-state.sh
source "${script_dir}/../working-memory/gate-state.sh"

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
    legacy_ac=".yoke/acceptance-contracts/${slug}.md"

    # Legacy-flow detection — the new-flow `acceptance-criteria/<slug>.md`
    # archive is the canonical input for the post-rename ratified gate.
    # Tasks emitted by the legacy `/yoke:tech-spec` stage 3 carry their
    # ratified envelope at `acceptance-contracts/<slug>.md` instead.
    # Per the parent PRD `.yoke/prds/2026-05-03-generate-sprints-skill.md`
    # FR-15 / Decision 6A, the legacy envelope keeps walking under
    # `/yoke:implement` unmodified. The gate-state refusal added below
    # only fires on the new-flow path.
    is_legacy=0
    if [ ! -f "$ac" ] && [ -f "$legacy_ac" ]; then
      is_legacy=1
    fi

    # Always-required upstream artifacts: PRD + Spec.
    for f in "$prd" "$tech"; do
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

    # Ratified AC envelope — new flow checks `acceptance-criteria/`,
    # legacy flow checks `acceptance-contracts/`. Both grammars accept
    # `> Status: ratified`.
    if [ "$is_legacy" -eq 0 ]; then
      if [ ! -f "$ac" ]; then
        echo "Error: $ac not found. Run /yoke:acceptance-criteria first." >&2
        exit 4
      fi
      if ! grep -qE "^> Status:[[:space:]]*ratified" "$ac"; then
        echo "Error: $ac is not ratified. Run /yoke:acceptance-criteria and ratify." >&2
        exit 4
      fi
    else
      if ! grep -qE "^> Status:[[:space:]]*ratified" "$legacy_ac"; then
        echo "Error: $legacy_ac is not ratified. Run /yoke:acceptance-contract and ratify." >&2
        exit 4
      fi
    fi

    # Gate-state refusal — fires only on the new-flow path. Per the
    # parent PRD FR-14 (and Spec :: Flow-detection contract) the
    # post-rename ladder includes `awaiting:generate-sprints` between
    # `awaiting:acceptance-criteria` and `running:implement`. When the
    # active task sits at that state (spec + AC ratified, zero sprint
    # files), `/yoke:implement` MUST refuse with the literal stderr
    # below. Legacy tasks (no AC under `acceptance-criteria/`) never
    # cross this branch — `is_legacy` short-circuits ahead.
    if [ "$is_legacy" -eq 0 ]; then
      gate="$(detect_gate_state 2>/dev/null || true)"
      if [ "$gate" = "awaiting:generate-sprints" ]; then
        echo "wm: run /yoke:generate-sprints to advance to Phase 4" >&2
        exit 4
      fi
    fi

    # Sprint-walk pre-check: at least one sprint file MUST exist for the
    # cycle loop to have a working set to load. The /yoke:implement
    # cycle reads `current_sprint:` from progress.md and loads the
    # active sprint's runtime bundle — without sprint files there is
    # nothing to converge.
    sprint_count=0
    while IFS= read -r _; do
      sprint_count=$((sprint_count + 1))
    done < <(wm_list_sprint_paths "$slug" 2>/dev/null || true)
    if [ "$sprint_count" -eq 0 ]; then
      echo "Error: no sprint files for slug '$slug'. Run /yoke:tech-spec and approve." >&2
      exit 4
    fi

    # Dry-run short-circuit — production code path (not a test-only
    # branch). When YOKE_IMPLEMENT_DRY_RUN=1 every preflight gate has
    # already passed at this point; emit the dedicated stdout marker
    # `dry-run: ok` and exit 0. The /yoke:implement cycle loop reads
    # the marker and short-circuits BEFORE Phase A council spawn,
    # letting a user verify gate state without paying council cost.
    # This is documented in skills/implement/SKILL.md (§1 Pre-flight)
    # and exercised by tests/runtime/full-flow.test.sh.
    if [ "${YOKE_IMPLEMENT_DRY_RUN:-}" = "1" ]; then
      echo "dry-run: ok"
      exit 0
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
