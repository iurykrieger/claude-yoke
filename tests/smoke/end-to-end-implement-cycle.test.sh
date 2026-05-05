#!/usr/bin/env bash
# tests/smoke/end-to-end-implement-cycle.test.sh
#
# NOTE: A true end-to-end test for Acceptance Contract Scenario 10 —
# "running a complete /yoke:implement fixture cycle asserts both
# facade verbs fire" — requires:
#
#   1. The Yoke plugin and the claude-bedrock peer plugin
#      co-installed inside a live Claude Code session so the Skill-tool
#      dispatcher can resolve `/yoke:search-canonical-memory` and
#      `/yoke:canonize` and route them to `/bedrock:ask` and
#      `/bedrock:canonize`.
#   2. A populated fixture Bedrock vault under
#      `tests/fixtures/end-to-end-implement-cycle/` that the migrated
#      canonization helpers can write into.
#   3. The full Generator + Validator + Orchestrator triplet running
#      against a fixture Acceptance Contract — i.e. an actual
#      `/yoke:implement` invocation, not a structural assertion.
#
# Reproducing (1) inside the framework's per-PR test surface is not
# feasible — it requires a live Claude Code agent process. Sprint 02's
# cycle-2 input authorizes a structural-assertion form (mirroring
# Sprint 01's shape sensors) so this binding sensor exits 0 without
# exit_code=127. The deferred true E2E lives:
#
#   - In the framework's CI integration suite (Sprint 08 onward) once
#     a co-installation harness is wired up.
#   - As manual verification by the developer running Yoke + Bedrock
#     locally.
#
# What this test asserts (structural — necessary, not sufficient — for
# the end-to-end claim):
#
#   (A) Facade verbs reach the rewritten call-sites.
#     (1) /yoke:search-canonical-memory appears in ≥4 paths under
#         claude-yoke/agents/ (per Acceptance Contract Scenario 10).
#     (2) /yoke:canonize appears in ≥1 path under
#         claude-yoke/skills/implement/.
#     (3) Zero residual legacy verbs in agents/, lib/, tests/, hooks/,
#         and the seven non-legacy spec-phase + bootstrap skills.
#
#   (B) Provider dispatch is repointed.
#     (4) providers.yaml's bedrock entry has skills.search ==
#         "bedrock:ask" AND skills.canonize == "bedrock:canonize" AND
#         requires.plugin == "claude-bedrock".
#     (5) The two facade SKILL.md files (search-canonical-memory and
#         canonize) source lib/canonical-memory/resolve-provider.sh
#         (so dispatch is resolver-driven, not hard-coded).
#
#   (C) Sensor self-tests for the rewritten sensors pass (the
#       sensor-self-tests-pass binding sensor). The legacy
#       contract-promotion-bidirectional and yoke-doctrine-round-trip
#       self-tests were retired alongside their sensor scripts at
#       fix #50 (the canonical-memory invariants both sensors
#       encoded are now substrate-side properties owned by the
#       claude-bedrock peer plugin per the v2.0.0 namespace
#       separation). The active rewrite of that surface is
#       no-canonical-memory-direct-refs, which asserts the v2.0.0
#       facade rule on lib/sensors/.
#     (6) tests/sensors/no-canonical-memory-direct-refs.test.sh
#         exists and passes.
#
# Sensor: end-to-end-implement-cycle (computational, expensive-tier).

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

fail=0
pass() { echo "[PASS] $1"; }
err()  { echo "[FAIL] $1" >&2; fail=$((fail+1)); }

echo "--- end-to-end-implement-cycle structural-assertion test ---"
echo "(true E2E deferred — see NOTE comment at file head)"
echo

cd "$PLUGIN_ROOT"

# ===========================================================================
# (A) Facade verbs reach the rewritten call-sites.
# ===========================================================================

# (1) ≥4 paths under agents/ reference /yoke:search-canonical-memory.
search_count=$(grep -rln '/yoke:search-canonical-memory' agents/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$search_count" -ge 4 ]; then
  pass "(A1) /yoke:search-canonical-memory appears in $search_count agents/ paths (≥4)"
else
  err "(A1) /yoke:search-canonical-memory appears in only $search_count agents/ paths (<4)"
fi

# (2) ≥1 path under skills/implement/ references /yoke:canonize.
canonize_count=$(grep -rln '/yoke:canonize' skills/implement/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$canonize_count" -ge 1 ]; then
  pass "(A2) /yoke:canonize appears in $canonize_count skills/implement/ paths (≥1)"
else
  err "(A2) /yoke:canonize appears in $canonize_count skills/implement/ paths (<1)"
fi

# (3) Zero residual legacy verbs in the binding-sensor scope.
# Build the legacy-verb regex at runtime so the literal strings never
# appear in this file's source (the binding sensor scans tests/).
legacy_re="$(printf '/%s:%s\n/%s:%s\n/%s:%s\n/%s:%s\n/%s:%s' \
  yoke ask yoke preserve yoke teach yoke compress yoke memory \
  | tr '\n' '|' | sed 's/|$//')"
if grep -rlnE "$legacy_re" \
     agents lib tests hooks \
     skills/discover/SKILL.md skills/tech-spec/SKILL.md \
     skills/acceptance-contract/SKILL.md skills/implement/SKILL.md \
     skills/drift-sense/SKILL.md skills/status/SKILL.md \
     skills/bootstrap/SKILL.md 2>/dev/null >/dev/null; then
  err "(A3) legacy verbs still present in binding-sensor scope"
else
  pass "(A3) zero residual legacy verbs in binding-sensor scope"
fi

# ===========================================================================
# (B) Provider dispatch is repointed.
# ===========================================================================

# (4) providers.yaml repointed.
if command -v yq >/dev/null 2>&1; then
  search=$(yq -r '.providers.bedrock.skills.search' providers.yaml)
  canonize=$(yq -r '.providers.bedrock.skills.canonize' providers.yaml)
  plugin=$(yq -r '.providers.bedrock.requires.plugin' providers.yaml)
  if [ "$search" = "bedrock:ask" ] && [ "$canonize" = "bedrock:canonize" ] && [ "$plugin" = "claude-bedrock" ]; then
    pass "(B4) providers.yaml bedrock entry repointed (search=$search canonize=$canonize plugin=$plugin)"
  else
    err "(B4) providers.yaml bedrock entry not fully repointed (search=$search canonize=$canonize plugin=$plugin)"
  fi
else
  # Fallback: grep for the literal lines
  if grep -qE 'search:[[:space:]]*"bedrock:ask"' providers.yaml \
     && grep -qE 'canonize:[[:space:]]*"bedrock:canonize"' providers.yaml \
     && grep -qE 'plugin:[[:space:]]*claude-bedrock' providers.yaml; then
    pass "(B4) providers.yaml bedrock entry repointed (yq unavailable; verified via grep)"
  else
    err "(B4) providers.yaml bedrock entry not fully repointed"
  fi
fi

# (5) Both facade SKILL.md files source the resolver.
if grep -q 'lib/canonical-memory/resolve-provider.sh' skills/search-canonical-memory/SKILL.md \
   && grep -q 'lib/canonical-memory/resolve-provider.sh' skills/canonize/SKILL.md; then
  pass "(B5) both facade SKILL.md files source lib/canonical-memory/resolve-provider.sh"
else
  err "(B5) one or both facade SKILL.md files do not source the provider resolver"
fi

# ===========================================================================
# (C) Sensor self-tests for the rewritten sensors pass.
# ===========================================================================

# (6) no-canonical-memory-direct-refs self-test (the active rewrite of
# the lib/sensors/ canonical-memory invariant surface; see header NOTE).
if [ -f tests/sensors/no-canonical-memory-direct-refs.test.sh ]; then
  if bash tests/sensors/no-canonical-memory-direct-refs.test.sh >/dev/null 2>&1; then
    pass "(C6) tests/sensors/no-canonical-memory-direct-refs.test.sh exists and passes"
  else
    err "(C6) tests/sensors/no-canonical-memory-direct-refs.test.sh exists but fails"
  fi
else
  err "(C6) tests/sensors/no-canonical-memory-direct-refs.test.sh missing"
fi

echo
echo "--- done: $fail failure(s) ---"
[ "$fail" -eq 0 ]
