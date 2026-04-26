#!/usr/bin/env bash
# tests/example-project.test.sh
#
# Example project completeness:
#   (a) examples/greenfield-payment-service/ has README.md, CLAUDE.md,
#       .yoke/config.yaml, .yoke/prd.md, .yoke/tech-spec.md,
#       .yoke/acceptance-contract.md
#   (b) prd.md and tech-spec.md carry "Status: approved";
#       acceptance-contract.md carries "Status: ratified"
#   (c) example CLAUDE.md has ## Testing, ## Linting, ## Build sections
#   (d) the contract has ≥3 BDD scenarios (^### Scenario [0-9]+) and
#       ≥4 functional requirements (^- \[ \] \*\*FR-)
#   (e) discover-from-claude-md.sh emits ≥2 testing sensors against the
#       example CLAUDE.md (intentional duplication with the
#       acceptance-and-sensors test: this file owns "the example is
#       whole", that file owns "the sensor lib emits structured output")

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

cd "$PLUGIN_ROOT"

EX="examples/greenfield-payment-service"

# ---------------------------------------------------------------------
# (a) Required artifacts
# ---------------------------------------------------------------------
for f in README.md CLAUDE.md .yoke/config.yaml .yoke/prd.md .yoke/tech-spec.md .yoke/acceptance-contract.md; do
  if [ -f "$EX/$f" ]; then
    pass "(a) $EX/$f exists"
  else
    err "(a) missing $EX/$f"
  fi
done

# ---------------------------------------------------------------------
# (b) Statuses
# ---------------------------------------------------------------------
for spec in prd tech-spec; do
  f="$EX/.yoke/${spec}.md"
  if grep -qE '^> Status: approved' "$f" 2>/dev/null; then
    pass "(b) $spec is Status: approved"
  else
    err "(b) $spec not approved"
  fi
done

if grep -qE '^> Status: ratified' "$EX/.yoke/acceptance-contract.md" 2>/dev/null; then
  pass "(b) acceptance-contract is Status: ratified"
else
  err "(b) acceptance-contract not ratified"
fi

# ---------------------------------------------------------------------
# (c) Example CLAUDE.md sections
# ---------------------------------------------------------------------
for section in Testing Linting Build; do
  if grep -qE "^## ${section}\$" "$EX/CLAUDE.md" 2>/dev/null; then
    pass "(c) example CLAUDE.md has '## ${section}' section"
  else
    err "(c) example CLAUDE.md missing '## ${section}' section"
  fi
done

# ---------------------------------------------------------------------
# (d) BDD scenarios + functional requirements
# ---------------------------------------------------------------------
contract="$EX/.yoke/acceptance-contract.md"
bdd_count=$(grep -cE '^### Scenario [0-9]+' "$contract" 2>/dev/null || echo 0)
fr_count=$(grep -cE '^- \[ \] \*\*FR-' "$contract" 2>/dev/null || echo 0)

if [ "$bdd_count" -ge 3 ]; then
  pass "(d) contract has $bdd_count BDD scenarios (≥3)"
else
  err "(d) contract has $bdd_count BDD scenarios (expected ≥3)"
fi

if [ "$fr_count" -ge 4 ]; then
  pass "(d) contract has $fr_count functional requirements (≥4)"
else
  err "(d) contract has $fr_count functional requirements (expected ≥4)"
fi

# ---------------------------------------------------------------------
# (e) ≥2 testing sensors discoverable from the example CLAUDE.md
# ---------------------------------------------------------------------
discover_out=""
discover_exit=0
discover_out=$(bash lib/sensors/discover-from-claude-md.sh "$EX/CLAUDE.md" 2>&1) \
  || discover_exit=$?

if [ "$discover_exit" -eq 0 ]; then
  testing_count=$(echo "$discover_out" | grep -c 'category: testing' || true)
  if [ "$testing_count" -ge 2 ]; then
    pass "(e) example CLAUDE.md exposes $testing_count testing sensors (≥2)"
  else
    err "(e) example CLAUDE.md exposes $testing_count testing sensors (expected ≥2)"
  fi
else
  err "(e) discover-from-claude-md.sh exit_code=$discover_exit against example"
fi

harness::summary
