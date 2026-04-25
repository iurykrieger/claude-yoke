#!/bin/bash
# escalate.sh — emits the Trigger-4 arbitration packet on divergence,
# contract conflict, or hard-bound hit.
#
# The packet is structured YAML written to .yoke/.trigger4-packet.yaml AND
# echoed on stdout. It contains:
#   - reason: divergence | contract-conflict | hard-bound | infeasibility
#   - category: <subcategory of reason>
#   - state:
#       progress_md_path
#       contracts_md_path
#       latest_snapshot_path
#       cycles, cycles_max, elapsed, timeout, tokens, token_budget (when hard-bound)
#   - unresolved_sprint_contract: <id or "none">
#   - divergence_category: <category from patterns/ralph-loop.md §15.6>
#   - escalation_to: spec-author | tech-lead | compliance | user
#   - decision_required: reformulate-acceptance-contract |
#                        reformulate-tech-spec | accept-trade-off | abort
#
# Trigger-4 schema is non-coalescable with Triggers 1, 2, 3, 5 — see
# .vibeflow/patterns/human-triggers.md.
#
# Usage:
#   escalate.sh --reason <reason> [--category <cat>]
#               [--cycles N --cycles-max N --elapsed S --timeout S
#                --tokens N --token-budget N]
#               [--unresolved-contract <id>]
#               [--escalation-to spec-author|tech-lead|compliance|user]
#
# Exit codes:
#   0   packet emitted
#   2   usage error
#   3   .yoke/ missing

set -euo pipefail

reason=""
category=""
cycles=""
cycles_max=""
elapsed=""
timeout=""
tokens=""
token_budget=""
unresolved_contract="none"
escalation_to="user"

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --reason)              reason="${2:-}";              shift 2 ;;
    --category)            category="${2:-}";            shift 2 ;;
    --cycles)              cycles="${2:-}";              shift 2 ;;
    --cycles-max)          cycles_max="${2:-}";          shift 2 ;;
    --elapsed)             elapsed="${2:-}";             shift 2 ;;
    --timeout)             timeout="${2:-}";             shift 2 ;;
    --tokens)              tokens="${2:-}";              shift 2 ;;
    --token-budget)        token_budget="${2:-}";        shift 2 ;;
    --unresolved-contract) unresolved_contract="${2:-none}"; shift 2 ;;
    --escalation-to)       escalation_to="${2:-user}";   shift 2 ;;
    -h|--help)             sed -n '1,30p' "$0"; exit 0 ;;
    "")                    break ;;
    *)                     echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$reason" ]; then
  echo "Error: --reason is required (divergence|contract-conflict|hard-bound|infeasibility)" >&2
  exit 2
fi

if [ ! -d ".yoke" ]; then
  echo "Error: .yoke/ not found." >&2
  exit 3
fi

# Determine divergence_category from reason + category
divergence_category=""
case "$reason" in
  divergence)
    # Per ralph-loop.md §15.6 — four categories
    divergence_category="${category:-quality-policies-broken}"
    ;;
  contract-conflict)
    divergence_category="acceptance-contract-violation"
    ;;
  hard-bound)
    divergence_category="hard-bound-${category:-cycles}"
    ;;
  infeasibility)
    divergence_category="fundamental-infeasibility"
    ;;
  *)
    divergence_category="$reason"
    ;;
esac

# Determine decision_required from reason
decision_required=""
case "$reason" in
  divergence|contract-conflict)
    decision_required="reformulate-acceptance-contract|reformulate-tech-spec|accept-trade-off|abort"
    ;;
  hard-bound)
    decision_required="raise-bounds|reformulate-tech-spec|abort"
    ;;
  infeasibility)
    decision_required="reformulate-acceptance-contract|abort"
    ;;
  *)
    decision_required="user-arbitration"
    ;;
esac

# Locate latest snapshot
latest_snapshot=""
if [ -d ".yoke/.snapshots" ]; then
  latest_snapshot=$(ls -1 .yoke/.snapshots/cycle-*.yaml 2>/dev/null | sort -V | tail -1 || true)
fi

packet=".yoke/.trigger4-packet.yaml"
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build YAML packet
{
  printf 'trigger: 4\n'
  printf 'schema: arbitration-packet\n'
  printf 'timestamp: "%s"\n' "$ts"
  printf 'reason: %s\n' "$reason"
  printf 'divergence_category: %s\n' "$divergence_category"
  printf 'state:\n'
  printf '  progress_md_path: ".yoke/progress.md"\n'
  printf '  contracts_md_path: ".yoke/contracts.md"\n'
  if [ -n "$latest_snapshot" ]; then
    printf '  latest_snapshot_path: "%s"\n' "$latest_snapshot"
  else
    printf '  latest_snapshot_path: null\n'
  fi
  if [ "$reason" = "hard-bound" ]; then
    printf '  cycles: %s\n'        "${cycles:-0}"
    printf '  cycles_max: %s\n'    "${cycles_max:-0}"
    printf '  elapsed: %s\n'       "${elapsed:-0}"
    printf '  timeout: %s\n'       "${timeout:-0}"
    printf '  tokens: %s\n'        "${tokens:-0}"
    printf '  token_budget: %s\n'  "${token_budget:-0}"
  fi
  printf 'unresolved_sprint_contract: "%s"\n' "$unresolved_contract"
  printf 'escalation_to: %s\n' "$escalation_to"
  printf 'decision_required: "%s"\n' "$decision_required"
} > "$packet"

cat "$packet"
exit 0
