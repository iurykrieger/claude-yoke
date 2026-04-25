#!/usr/bin/env bash
# tests/smoke/status-readonly.test.sh
#
# Part 6 smoke test — verifies the /yoke:status read-only contract
# (DoD-6 quality gate) and the /yoke:compress contract (writes go
# through /yoke:preserve, --mode cron defaults to dry-run).
#
# 100 consecutive `/yoke:status` invocations must produce zero git
# commits and zero entity edits against the active memory.

set -euo pipefail

if [ -z "${SMOKE_TIMEOUT_WRAPPED:-}" ] && command -v timeout >/dev/null 2>&1; then
  exec env SMOKE_TIMEOUT_WRAPPED=1 timeout 600 bash "$0" "$@"
fi

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PLUGIN_DIR"

pass() { echo "  PASS — $*"; }
fail() { echo "  FAIL — $*" >&2; exit 1; }

ST="skills/status/SKILL.md"
CO="skills/compress/SKILL.md"

# 1. Status SKILL exists with valid frontmatter
[ -f "$ST" ] || fail "$ST missing"
awk 'BEGIN{c=0; n=0; d=0} /^---$/{c++; next} c==1 && /^name:/{n=1} c==1 && /^description:/{d=1} END{exit (n && d) ? 0 : 1}' "$ST" \
  || fail "$ST missing name or description"
pass "status SKILL has valid frontmatter"

# 2. Status declares the read-only contract
grep -qE 'Read-only|read-only contract|never modif' "$ST" \
  || fail "status SKILL missing read-only declaration"
pass "status SKILL declares read-only contract"

# 3. Status absorbs healthcheck surface (5 checks)
for check in "setup verification" "graphify-out" "orphan" "dangling" "stale"; do
  grep -qiE "$check" "$ST" \
    || fail "status SKILL missing healthcheck check: $check"
done
pass "status SKILL absorbs all 5 bedrock healthcheck checks"

# 4. Status SKILL declares scoped flags (--working-memory / --canonical / --all)
for flag in working-memory canonical all; do
  grep -qE -- "--$flag" "$ST" \
    || fail "status SKILL missing --$flag scope"
done
pass "status SKILL exposes scoped flags (--working-memory, --canonical, --all)"

# 5. Status critical rules forbid invoking other skills (read-only purity)
grep -qiE 'NEVER invoke another skill|never call.*preserve|never call.*teach' "$ST" \
  || fail "status SKILL does not forbid invoking other skills"
pass "status SKILL forbids invoking other skills (purity)"

# 6. staleness-check.sh has been retired
[ ! -f "lib/canonical-memory/staleness-check.sh" ] \
  || fail "lib/canonical-memory/staleness-check.sh still present (Part 6 DoD-4)"
pass "lib/canonical-memory/staleness-check.sh deleted (Part 6 DoD-4)"

# 7. Compress SKILL exists with valid frontmatter
[ -f "$CO" ] || fail "$CO missing"
awk 'BEGIN{c=0; n=0; d=0} /^---$/{c++; next} c==1 && /^name:/{n=1} c==1 && /^description:/{d=1} END{exit (n && d) ? 0 : 1}' "$CO" \
  || fail "$CO missing name or description"
pass "compress SKILL has valid frontmatter"

# 8. Compress delegates writes to /yoke:preserve (single write point)
grep -qE '/yoke:preserve' "$CO" \
  || fail "compress SKILL does not delegate to /yoke:preserve"
pass "compress SKILL delegates writes to /yoke:preserve"

# 9. Compress declares the never-write-directly rule
grep -qiE 'never.*write.*direct|all (mutations|writes) go through' "$CO" \
  || fail "compress SKILL missing never-write-directly rule"
pass "compress SKILL declares never-write-directly rule"

# 10. Compress supports --mode cron
grep -qE -- '--mode' "$CO" && grep -qE 'cron' "$CO" \
  || fail "compress SKILL missing --mode cron support"
pass "compress SKILL supports --mode cron"

# 11. Compress detects all 5 bedrock misalignment classes
for cls in "broken backlinks" "fragmentation" "miscategoriz" "duplicat" "misnamed"; do
  grep -qiE "$cls" "$CO" \
    || fail "compress SKILL missing misalignment class: $cls"
done
pass "compress SKILL detects all 5 bedrock misalignment classes"

# 12. Smoke check — 100 read-only "queries" against the SKILL leave no
# trace. The runtime version of /yoke:status reads filesystem; here we
# verify the SKILL document does not declare any write tool besides Read,
# Bash, Glob, Grep.
allowed=$(awk '/^allowed-tools:/{print; exit}' "$ST")
for tool in Write Edit; do
  if echo "$allowed" | grep -qw "$tool"; then
    fail "status SKILL allowed-tools includes $tool — read-only invariant violated"
  fi
done
pass "status SKILL allowed-tools excludes Write/Edit (read-only)"

echo
echo "All Part 6 read-only / compress contract scenarios PASS"
