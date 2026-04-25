#!/usr/bin/env bash
# tests/smoke/preserve-model-c.test.sh
#
# Part 4 smoke test — verifies that /yoke:preserve:
#   1. is the single canonical-memory write entry (no propose-write.sh,
#      no skills/canonize/, no direct git commit outside skills/preserve/)
#   2. declares Model C impact-class routing for low / medium / high /
#      regulatory writes
#   3. blocks high-impact writes from auto-merge (synchronous human
#      ratification required)
#   4. routes regulatory writes via CODEOWNERS
#
# This test runs against the SKILL document and the surrounding codebase.
# Full end-to-end PR opening is exercised in the host project, not here.

set -euo pipefail

if [ -z "${SMOKE_TIMEOUT_WRAPPED:-}" ] && command -v timeout >/dev/null 2>&1; then
  exec env SMOKE_TIMEOUT_WRAPPED=1 timeout 600 bash "$0" "$@"
fi

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PLUGIN_DIR"

pass() { echo "  PASS — $*"; }
fail() { echo "  FAIL — $*" >&2; exit 1; }

PRE="skills/preserve/SKILL.md"

# 1. Single write point — propose-write.sh and skills/canonize/ are gone.
[ ! -f "lib/canonical-memory/propose-write.sh" ] \
  || fail "propose-write.sh still present (Part 4 DoD-4)"
pass "propose-write.sh deleted"

[ ! -d "skills/canonize" ] \
  || fail "skills/canonize/ still present (Part 4 DoD-4)"
pass "skills/canonize/ deleted"

# 2. /yoke:preserve declares the single-write-point invariant
[ -f "$PRE" ] || fail "preserve SKILL missing"
grep -qiE "single write (point|entry)|sole write" "$PRE" \
  || fail "preserve SKILL missing single-write-point declaration"
pass "preserve SKILL declares single-write-point invariant"

# 3. Model C routing — all four impact classes documented
for cls in low medium high regulatory; do
  grep -qE "\`${cls}\`" "$PRE" \
    || fail "preserve SKILL missing impact class '${cls}'"
done
pass "preserve SKILL documents all 4 impact classes"

# 4. High-impact blocks auto-merge
grep -qE 'high.*never auto-merge|never auto-merge.*high|--no-auto-merge.*high|`high`.*never|`high`.*synchronous' "$PRE" \
  || grep -qE '`high` and `regulatory` writes \*\*never\*\* auto-merge' "$PRE" \
  || fail "preserve SKILL does not block auto-merge for high-impact writes"
pass "preserve SKILL blocks auto-merge for high-impact writes"

# 5. Regulatory routes via CODEOWNERS
grep -qE 'regulatory.*CODEOWNERS|CODEOWNERS.*regulatory|Compliance via CODEOWNERS' "$PRE" \
  || fail "preserve SKILL does not route regulatory via CODEOWNERS"
pass "preserve SKILL routes regulatory via CODEOWNERS"

# 6. Phase 3 invokes canonization-criteria.sh
grep -qE 'canonization-criteria\.sh' "$PRE" \
  || fail "preserve SKILL Phase 3 does not invoke canonization-criteria.sh"
pass "preserve SKILL invokes canonization-criteria.sh as the Model C classifier"

# 7. Three git strategies honored
for strat in commit-push commit-push-pr commit-only; do
  grep -qE "\`${strat}\`" "$PRE" \
    || fail "preserve SKILL missing git strategy '${strat}'"
done
pass "preserve SKILL honors three git strategies"

# 8. Bidirectional linking is in scope
grep -qE 'Bidirectional linking|bidirectional links?|Phase 5' "$PRE" \
  || fail "preserve SKILL missing bidirectional linking section"
pass "preserve SKILL declares bidirectional linking"

# 9. Five Yoke rippability fields enforced on create
for field in ratified_at model_calibrated_against last_validated traceability impact_level; do
  grep -q "$field" "$PRE" \
    || fail "preserve SKILL does not reference rippability field '$field'"
done
pass "preserve SKILL enforces five rippability fields on create"

# 10. Orchestrator subagent invokes /yoke:preserve via the Skill tool
ORCH="agents/orchestrator.md"
grep -qE '/yoke:preserve' "$ORCH" \
  || fail "orchestrator does not invoke /yoke:preserve"
pass "orchestrator invokes /yoke:preserve via the Skill tool"

# 11. No direct `git commit` against $MEMORY_PATH outside skills/preserve/
# (search code, not docs/CHANGELOG)
LEAKS=$(grep -rEln 'git -C "?\$MEMORY_PATH"? commit' agents/ skills/ lib/ tests/ 2>/dev/null | grep -v '^skills/preserve/' || true)
[ -z "$LEAKS" ] \
  || fail "found direct git -C \$MEMORY_PATH commit outside skills/preserve/: $LEAKS"
pass "no direct memory commits outside skills/preserve/"

echo
echo "All Part 4 Model C scenarios PASS"
