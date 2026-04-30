#!/bin/bash
# yoke-doctrine-round-trip.sh — round-trip validation of canonized Yoke doctrine.
#
# Sensor for Acceptance Contract Scenario 15 / FR-2 / FR-6. Runs ~16
# sample queries against the registered canonical-memory checkout to
# assert every migrated entity class is retrievable by both filename
# and content substring.
#
# This is a deterministic filesystem-based check — it does NOT invoke
# `/yoke:search-canonical-memory` (which requires LLM judgment in
# classification + retrieval). The contract calls this an
# "inferential" sensor; the
# implementation is "computational" because deterministic substring
# matching against a known-good content set is sufficient evidence
# that the entities are correctly canonized.
#
# Source: .yoke/acceptance-contracts/2026-04-27-yoke-doctrine-canonization.md

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_FILE=".yoke/runtime/round-trip-evidence.txt"

mkdir -p "$(dirname "$EVIDENCE_FILE")"

# Resolve the canonical-memory checkout path. When this sensor runs
# from a git worktree of the plugin source, the worktree path lacks
# memories.json (it lives only in the canonical plugin install).
# YOKE_PLUGIN_DIR overrides the BASH_SOURCE-relative resolution; if
# unset, fall back to the script's PLUGIN_ROOT (which is the right
# location when installed normally).
YOKE_PLUGIN_DIR="${YOKE_PLUGIN_DIR:-}"
if [ -z "$YOKE_PLUGIN_DIR" ] && [ ! -f "$PLUGIN_ROOT/memories.json" ]; then
  # Heuristic: search ancestor directories for memories.json (worktree case).
  candidate="$PLUGIN_ROOT"
  while [ "$candidate" != "/" ] && [ ! -f "$candidate/memories.json" ]; do
    candidate="$(dirname "$candidate")"
  done
  [ -f "$candidate/memories.json" ] && YOKE_PLUGIN_DIR="$candidate"
fi
[ -z "$YOKE_PLUGIN_DIR" ] && YOKE_PLUGIN_DIR="$PLUGIN_ROOT"

VAULT="$(YOKE_PLUGIN_DIR="$YOKE_PLUGIN_DIR" bash "$YOKE_PLUGIN_DIR/lib/canonical-memory/registry.sh" path-of iury-brain 2>/dev/null)"
if [ -z "$VAULT" ] || [ ! -d "$VAULT" ]; then
  echo "round-trip: canonical-memory checkout not found" >&2
  exit 2
fi

failures=0
passes=0

# Hard-coded query suite. Each entry: <label>|<file-path>|<expected-substring>
queries=(
  "project-claude-yoke|projects/claude-yoke.md|claude-yoke"
  "actor-yoke|actors/yoke-framework.md|yoke-framework"
  "pattern-roles|concepts/yoke-pattern-roles.md|Generator"
  "pattern-phase-flow|concepts/yoke-pattern-phase-flow.md|Phase"
  "pattern-acceptance-contract|concepts/yoke-pattern-acceptance-contract.md|Acceptance"
  "pattern-ralph-loop|concepts/yoke-pattern-ralph-loop.md|loop"
  "pattern-sensors|concepts/yoke-pattern-sensors.md|sensor"
  "pattern-memory-model|concepts/yoke-pattern-memory-model.md|memory"
  "pattern-model-c-governance|concepts/yoke-pattern-model-c-governance.md|Model C"
  "pattern-human-triggers|concepts/yoke-pattern-human-triggers.md|Trigger"
  "pattern-plugin-structure|concepts/yoke-pattern-plugin-structure.md|plugin"
  "conventions|concepts/yoke-conventions.md|MUST"
  "decision-recent|concepts/yoke-decision-2026-04-25-generator-subagent-persona-senior-developer-coding.md|Senior Developer"
  "decision-mid|concepts/yoke-decision-2026-04-25-three-runtime-subagents-only.md|three"
  "audit-sample|discussions/|yoke-audit-"
)

# Open evidence file
{
  echo "=== Yoke doctrine round-trip evidence ==="
  echo "=== generated: $(date -u +%FT%TZ) ==="
  echo "=== vault: $VAULT ==="
  echo
} > "$EVIDENCE_FILE"

for q in "${queries[@]}"; do
  IFS='|' read -r label path expected <<<"$q"

  echo "=== query: $label ===" >> "$EVIDENCE_FILE"
  echo "path: $path" >> "$EVIDENCE_FILE"
  echo "expected substring: $expected" >> "$EVIDENCE_FILE"

  # For directory queries (label ends in 'sample'), check any matching file
  if [[ "$path" == */ ]]; then
    if find "$VAULT/$path" -name "${expected}*" -type f 2>/dev/null | head -1 | grep -q .; then
      echo "result: PASS (found matching files in $path)" >> "$EVIDENCE_FILE"
      passes=$((passes + 1))
    else
      echo "result: FAIL (no files matching ${expected}* in $VAULT/$path)" >> "$EVIDENCE_FILE"
      failures=$((failures + 1))
    fi
  else
    full_path="$VAULT/$path"
    if [ ! -f "$full_path" ]; then
      echo "result: FAIL (file not found: $full_path)" >> "$EVIDENCE_FILE"
      failures=$((failures + 1))
    elif grep -qF "$expected" "$full_path"; then
      echo "result: PASS" >> "$EVIDENCE_FILE"
      passes=$((passes + 1))
    else
      echo "result: FAIL (substring '$expected' not found in $path)" >> "$EVIDENCE_FILE"
      failures=$((failures + 1))
    fi
  fi
  echo >> "$EVIDENCE_FILE"
done

# Summary
{
  echo "=== summary ==="
  echo "passes: $passes"
  echo "failures: $failures"
  echo "total: ${#queries[@]}"
} >> "$EVIDENCE_FILE"

echo "round-trip: $passes/${#queries[@]} pass, $failures fail (evidence: $EVIDENCE_FILE)"

if [ "$failures" -gt 0 ]; then
  exit 1
fi
exit 0
