#!/usr/bin/env bash
# tests/smoke/bedrock-canonize-roundtrip.test.sh
#
# NOTE: A true end-to-end round-trip test for Acceptance Contract
# Scenario 9 — "/yoke:canonize from a fixture Yoke project dispatches
# to /bedrock:canonize --working-memory <abs-path>, the fixture
# Bedrock vault grows by ≥1 entity, the chain exits 0, and stdout
# matches `^canonize: created=[0-9]+ updated=[0-9]+ skipped=[0-9]+$`"
# requires:
#
#   1. The claude-bedrock peer plugin installed alongside Yoke under a
#      live Claude Code session so the Skill-tool dispatcher can
#      resolve `/bedrock:canonize`.
#   2. A populated fixture Bedrock vault (markdown frontmatter graph)
#      that the migrated `lib/canonical-memory/canonization-criteria.sh`
#      and `write-promoted-concept.sh` can write into.
#   3. A converged-task `.yoke/` working-memory fixture (PRD + spec +
#      sprint files + runtime/progress.md with Generator+Validator
#      consensus to canonize).
#
# Neither (1) nor (2) is reproducible inside the framework's per-PR
# test surface. Sprint 02's cycle-2 input authorizes a structural-
# assertion form (mirroring Sprint 01's search-facade-equivalence and
# canonize-progress-log-line shape sensors) so the binding sensor
# exits 0 without exit_code=127. The deferred true E2E lives:
#
#   - In the framework's CI integration suite (Sprint 08 onward) once
#     a co-installation harness is wired up.
#   - As manual verification by the developer running Yoke + Bedrock
#     locally (the canonical-memory-setup.md doc explains the cohort).
#
# What this test asserts (structural — necessary, not sufficient — for
# the round-trip claim):
#
#   (1) ../claude-bedrock/skills/canonize/SKILL.md exists.
#   (2) Frontmatter declares `name: canonize` (Skill-tool dispatch
#       identity for /bedrock:canonize).
#   (3) Frontmatter declares the mandatory --working-memory argument
#       in argument-hint.
#   (4) Body sources the migrated `lib/canonical-memory/resolve-memory.sh`
#       (vault resolution).
#   (5) Body invokes the migrated five-criterion classifier
#       (`canonization-criteria.sh`) — never invents new criteria.
#   (6) Body delegates writes through `/bedrock:preserve` (Model C
#       single-write-point invariant).
#   (7) Body documents the soft exit-summary regex anchor
#       `^canonize: created=` so downstream readers (the Yoke facade)
#       can grep the line.
#   (8) Body declares the parse-error exit code 2 for missing
#       --working-memory (Acceptance Contract Scenario 9 negative case).
#   (9) Body forbids writes inside the working memory directory
#       (the Yoke contract reserves <wm>/runtime/progress.md to the
#       facade).
#
# Sensor: bedrock-canonize-roundtrip (computational, expensive-tier).

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$PLUGIN_ROOT/../claude-bedrock/skills/canonize/SKILL.md"

fail=0
pass() { echo "[PASS] $1"; }
err()  { echo "[FAIL] $1" >&2; fail=$((fail+1)); }

echo "--- bedrock-canonize-roundtrip structural-assertion test ---"
echo "(true E2E deferred — see NOTE comment at file head)"
echo

# ---------------------------------------------------------------------------
# (1) File presence.
# ---------------------------------------------------------------------------
if [ ! -f "$SKILL" ]; then
  err "(1) ../claude-bedrock/skills/canonize/SKILL.md missing"
  echo "--- done: $fail failure(s) ---"
  exit 1
fi
pass "(1) ../claude-bedrock/skills/canonize/SKILL.md exists"

# ---------------------------------------------------------------------------
# (2) Frontmatter declares the dispatch identity.
# ---------------------------------------------------------------------------
grep -q '^name: canonize$' "$SKILL" \
  && pass "(2) frontmatter: name == canonize" \
  || err "(2) frontmatter missing 'name: canonize'"

# ---------------------------------------------------------------------------
# (3) Mandatory argument declared in argument-hint.
# ---------------------------------------------------------------------------
grep -qE '^argument-hint:.*--working-memory' "$SKILL" \
  && pass "(3) argument-hint declares the mandatory --working-memory argument" \
  || err "(3) argument-hint missing --working-memory"

# ---------------------------------------------------------------------------
# (4) Body sources the vault resolver.
# ---------------------------------------------------------------------------
grep -q 'lib/canonical-memory/resolve-memory.sh' "$SKILL" \
  && pass "(4) body references lib/canonical-memory/resolve-memory.sh" \
  || err "(4) body does not source the vault resolver"

# ---------------------------------------------------------------------------
# (5) Body invokes the migrated five-criterion classifier.
# ---------------------------------------------------------------------------
grep -q 'canonization-criteria.sh' "$SKILL" \
  && pass "(5) body invokes canonization-criteria.sh (five-criterion cascade)" \
  || err "(5) body does not invoke canonization-criteria.sh"

# ---------------------------------------------------------------------------
# (6) Body delegates writes through /bedrock:preserve.
# ---------------------------------------------------------------------------
grep -q '/bedrock:preserve\|bedrock:preserve' "$SKILL" \
  && pass "(6) body delegates writes through /bedrock:preserve (Model C invariant)" \
  || err "(6) body does not delegate writes through /bedrock:preserve"

# ---------------------------------------------------------------------------
# (7) Body documents the soft exit-summary regex anchor.
# ---------------------------------------------------------------------------
grep -qE "\^canonize: created=" "$SKILL" \
  && pass "(7) body documents the '^canonize: created=' line-anchor regex" \
  || err "(7) body does not document the '^canonize: created=' line-anchor regex"

# ---------------------------------------------------------------------------
# (8) Body declares the parse-error exit code 2 for missing --working-memory.
# ---------------------------------------------------------------------------
grep -qE 'requires --working-memory|--working-memory must be an absolute path' "$SKILL" \
  && pass "(8) body declares missing-argument diagnostic for --working-memory" \
  || err "(8) body does not declare a missing-argument diagnostic for --working-memory"

# ---------------------------------------------------------------------------
# (9) Body forbids writes inside the working memory directory.
# ---------------------------------------------------------------------------
grep -qE '(NEVER|never)[[:space:]]+write[s]?[[:space:]]+inside' "$SKILL" \
  && pass "(9) body forbids writes inside the working memory directory" \
  || err "(9) body does not forbid writes inside the working memory directory"

echo
echo "--- done: $fail failure(s) ---"
[ "$fail" -eq 0 ]
