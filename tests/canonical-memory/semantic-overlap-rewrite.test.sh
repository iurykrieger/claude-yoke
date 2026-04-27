#!/usr/bin/env bash
# tests/canonical-memory/semantic-overlap-rewrite.test.sh
#
# Self-test for the semantic-overlap layer at
# `lib/canonical-memory/semantic-overlap-rewrite.sh` (sprint-contract
# -promotion s01-t02). The layer rewrites the YAML emitted by
# `lib/canonical-memory/canonization-criteria.sh` so contracts that
# resolve the same ambiguity with different surface prose are
# recognised as the same topic.
#
# The LLM judgment that decides cohesive/split/contradiction is the
# load-bearing semantic step at runtime, but the **acceptance signal**
# (binding under FR-2 / FR-8 / Scenario 2) is the YAML-rewriting
# logic's correctness given a canned verdict file. This test supplies
# canned verdicts (the "LLM-stub strategy" called out in the Tech Spec
# and the Acceptance Contract) so the rewriter is provable
# independent of live LLM behaviour. The live-LLM smoke is gated
# behind YOKE_RUN_LIVE_LLM_SMOKE=1 and is informational only.
#
# Subtests (each builds a fixture under tests/canonical-memory/
# fixtures/semantic-overlap-rewrite/<case>/, runs the deterministic
# floor in canonization-criteria.sh against that fixture, then runs
# the semantic-overlap rewriter with a canned verdicts file):
#
#   1. Cohesive case — two archives whose `topic:` strings differ in
#      surface prose but resolve the same ambiguity. The canned
#      verdict is `cohesive`. Expected post-rewrite: exactly one
#      candidate group with `occurrences: 2` whose `reason:` field
#      references both originating contracts. THIS IS THE BINDING
#      SUBTEST FOR FR-2 (cohesive subcase) / Scenario 2.
#
#   2. Split case — two archives whose `topic:` strings are similar
#      but resolve different ambiguities. The canned verdict is
#      `split`. Expected post-rewrite: two candidates each with
#      `occurrences: 1` and no cohesive group.
#
#   3. Contradiction case — two archives whose `topic:` strings are
#      similar but `decision:` fields directly contradict. The canned
#      verdict is `contradiction`. Expected post-rewrite: two
#      candidates each with `occurrences: 1` AND a top-level `notes:`
#      entry citing the contradiction. THIS SURFACES FR-8 (Trigger 5
#      synchronous human ratification).
#
#   4. No-invent invariant — a candidate whose deterministic-floor
#      `occurrences:` is 1 is never promoted to `occurrences: 2` by
#      the semantic layer, even when a canned verdict declares it
#      cohesive. Enforces FR-2's "no new candidates" invariant.
#
# Each subtest also performs structural assertions on the
# post-rewrite YAML (occurrences count, reason content,
# notes presence/absence) rather than byte-for-byte diffing, so
# small whitespace changes upstream do not break the test.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

CASCADE="$PLUGIN_ROOT/lib/canonical-memory/canonization-criteria.sh"
REWRITE="$PLUGIN_ROOT/lib/canonical-memory/semantic-overlap-rewrite.sh"
FIXTURE_ROOT="$PLUGIN_ROOT/tests/canonical-memory/fixtures/semantic-overlap-rewrite"

if [ ! -f "$CASCADE" ]; then
  err "cascade script missing at $CASCADE"
  harness::summary
fi
if [ ! -f "$REWRITE" ]; then
  err "semantic-overlap rewriter missing at $REWRITE"
  harness::summary
fi
if [ ! -d "$FIXTURE_ROOT" ]; then
  err "fixture root missing at $FIXTURE_ROOT"
  harness::summary
fi

# ---------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------

# build_wm <tmpdir> <case> — copy the fixture's archive files into a
# fresh tmpdir/.yoke/contracts/ directory so the cascade script can
# read them. Keeps fixtures out of the test runner's CWD.
build_wm() {
  local tmpdir="$1"
  local case_name="$2"
  local src_dir="$FIXTURE_ROOT/$case_name/contracts"
  mkdir -p "$tmpdir/.yoke/contracts"
  cp "$src_dir"/*.md "$tmpdir/.yoke/contracts/"
}

# count_occ_eq <yaml> <n> — count `occurrences: <n>` lines.
count_occ_eq() {
  local yaml="$1"
  local n="$2"
  printf '%s\n' "$yaml" | grep -c "^[[:space:]]*occurrences: ${n}\$" || true
}

# count_id_lines <yaml> — count `  - id: c<N>` lines (number of
# emitted candidates).
count_id_lines() {
  printf '%s\n' "$1" | grep -c '^[[:space:]]*-[[:space:]]*id:[[:space:]]*c[0-9]' || true
}

# has_notes_block <yaml> — non-empty if a top-level `notes:` line is
# present (i.e., contradiction was emitted).
has_notes_block() {
  printf '%s\n' "$1" | grep -E '^notes:' >/dev/null && echo "yes" || echo "no"
}

# ---------------------------------------------------------------------
# Subtest 1 — Cohesive case.
#
# The deterministic floor of canonization-criteria.sh requires
# byte-identical `topic:` strings to count two contracts as the same
# topic. To exercise the cohesive path we therefore build a fixture
# whose two archives carry byte-identical topic strings (so
# occurrences = 2 from t01). The semantic-overlap layer's job in this
# case is to confirm the cohesion via the canned verdict and merge
# the two members into one cohesive candidate.
#
# In production the LLM would also surface as cohesive the case where
# the topic prose is *similar* (different surface words but same
# ambiguity); that path is exercised by the live LLM smoke
# (YOKE_RUN_LIVE_LLM_SMOKE=1). The unit test caps at the YAML
# rewriting contract.
# ---------------------------------------------------------------------
T1=$(mktemp -d)
trap 'rm -rf "$T1"' EXIT

build_wm "$T1" "cohesive"
CASCADE_OUT_1="$T1/cascade.yaml"
bash "$CASCADE" --working-memory "$T1/.yoke" > "$CASCADE_OUT_1" 2>/dev/null

VERDICTS_1="$FIXTURE_ROOT/cohesive/verdicts.tsv"
POST_1="$(bash "$REWRITE" --cascade-yaml "$CASCADE_OUT_1" --verdicts "$VERDICTS_1" 2>/dev/null || true)"

# Structural assertions for the binding cohesive subcase.
n_cands=$(count_id_lines "$POST_1")
n_occ_2=$(count_occ_eq "$POST_1" 2)
n_occ_1=$(count_occ_eq "$POST_1" 1)
n_occ_2=${n_occ_2:-0}
n_occ_1=${n_occ_1:-0}
n_cands=${n_cands:-0}

if [ "$n_cands" = "1" ] && [ "$n_occ_2" = "1" ] && [ "$n_occ_1" = "0" ]; then
  pass "(1) cohesive case emits exactly one merged candidate with occurrences: 2"
else
  err "(1) cohesive case structural mismatch (cands=$n_cands, occ=2 lines=$n_occ_2, occ=1 lines=$n_occ_1)"
  printf -- '--- post-rewrite YAML ---\n%s\n' "$POST_1" >&2
fi

# Reason content assertion: must reference both originating contracts.
# The canned verdict reason cites both archive filenames; assert both
# substrings are present in the merged candidate's reason line.
reason_line="$(printf '%s\n' "$POST_1" | grep -E '^[[:space:]]+reason:[[:space:]]*' | head -1 || true)"
if printf '%s' "$reason_line" | grep -q 'cohesive-a.md' \
   && printf '%s' "$reason_line" | grep -q 'cohesive-b.md'; then
  pass "(1*) cohesive merged candidate's reason references both originating contracts (Scenario 2 binding)"
else
  err "(1*) cohesive reason does not reference both originating contracts"
  printf -- '--- reason line ---\n%s\n' "$reason_line" >&2
fi

# No top-level notes entry on a cohesive case.
if [ "$(has_notes_block "$POST_1")" = "no" ]; then
  pass "(1**) cohesive case emits no contradiction notes"
else
  err "(1**) cohesive case unexpectedly emitted a notes block"
fi

rm -rf "$T1"
trap - EXIT

# ---------------------------------------------------------------------
# Subtest 2 — Split case.
#
# Two archives with byte-identical topics but, per the canned verdict,
# the LLM judges them as resolving different underlying ambiguities.
# The deterministic floor will report occurrences: 2; the semantic
# layer must split the group back to two candidates each with
# occurrences: 1.
# ---------------------------------------------------------------------
T2=$(mktemp -d)
trap 'rm -rf "$T2"' EXIT

build_wm "$T2" "split"
CASCADE_OUT_2="$T2/cascade.yaml"
bash "$CASCADE" --working-memory "$T2/.yoke" > "$CASCADE_OUT_2" 2>/dev/null

VERDICTS_2="$FIXTURE_ROOT/split/verdicts.tsv"
POST_2="$(bash "$REWRITE" --cascade-yaml "$CASCADE_OUT_2" --verdicts "$VERDICTS_2" 2>/dev/null || true)"

n_cands=$(count_id_lines "$POST_2")
n_occ_2=$(count_occ_eq "$POST_2" 2)
n_occ_1=$(count_occ_eq "$POST_2" 1)
n_occ_2=${n_occ_2:-0}
n_occ_1=${n_occ_1:-0}
n_cands=${n_cands:-0}

if [ "$n_cands" = "2" ] && [ "$n_occ_1" = "2" ] && [ "$n_occ_2" = "0" ]; then
  pass "(2) split case emits two candidates each with occurrences: 1 and no cohesive group"
else
  err "(2) split case structural mismatch (cands=$n_cands, occ=1 lines=$n_occ_1, occ=2 lines=$n_occ_2)"
  printf -- '--- post-rewrite YAML ---\n%s\n' "$POST_2" >&2
fi

if [ "$(has_notes_block "$POST_2")" = "no" ]; then
  pass "(2*) split case emits no contradiction notes"
else
  err "(2*) split case unexpectedly emitted a notes block"
fi

rm -rf "$T2"
trap - EXIT

# ---------------------------------------------------------------------
# Subtest 3 — Contradiction case.
#
# Two archives with topics the LLM judges as the same ambiguity
# resolved with directly contradictory `decision:` fields. The
# semantic layer must split the group (no coalescing on
# contradiction) AND emit a top-level `notes:` entry citing the
# contradiction. This surfaces FR-8: the contradiction note is the
# signal that routes the impact class to require synchronous human
# ratification per Model C governance.
# ---------------------------------------------------------------------
T3=$(mktemp -d)
trap 'rm -rf "$T3"' EXIT

build_wm "$T3" "contradiction"
CASCADE_OUT_3="$T3/cascade.yaml"
bash "$CASCADE" --working-memory "$T3/.yoke" > "$CASCADE_OUT_3" 2>/dev/null

VERDICTS_3="$FIXTURE_ROOT/contradiction/verdicts.tsv"
POST_3="$(bash "$REWRITE" --cascade-yaml "$CASCADE_OUT_3" --verdicts "$VERDICTS_3" 2>/dev/null || true)"

n_cands=$(count_id_lines "$POST_3")
n_occ_2=$(count_occ_eq "$POST_3" 2)
n_occ_1=$(count_occ_eq "$POST_3" 1)
n_occ_2=${n_occ_2:-0}
n_occ_1=${n_occ_1:-0}
n_cands=${n_cands:-0}

if [ "$n_cands" = "2" ] && [ "$n_occ_1" = "2" ] && [ "$n_occ_2" = "0" ]; then
  pass "(3) contradiction case splits the group into two occurrences: 1 candidates"
else
  err "(3) contradiction case structural mismatch (cands=$n_cands, occ=1 lines=$n_occ_1, occ=2 lines=$n_occ_2)"
  printf -- '--- post-rewrite YAML ---\n%s\n' "$POST_3" >&2
fi

if [ "$(has_notes_block "$POST_3")" = "yes" ]; then
  pass "(3*) contradiction case emits a top-level notes block (FR-8 surface)"
else
  err "(3*) contradiction case did NOT emit a top-level notes block"
  printf -- '--- post-rewrite YAML ---\n%s\n' "$POST_3" >&2
fi

# Notes content must cite the contradiction ("contradict" or "contradiction"
# substring is sufficient — the verdict reason carries the citation).
notes_content="$(printf '%s\n' "$POST_3" | awk '/^notes:/{f=1; next} f && /^[[:space:]]+-/' || true)"
if printf '%s' "$notes_content" | grep -Eqi 'contradict'; then
  pass "(3**) contradiction notes entry cites the contradiction"
else
  err "(3**) contradiction notes entry does not cite the contradiction"
  printf -- '--- notes content ---\n%s\n' "$notes_content" >&2
fi

rm -rf "$T3"
trap - EXIT

# ---------------------------------------------------------------------
# Subtest 4 — No-invent invariant (FR-2).
#
# A candidate with deterministic-floor occurrences: 1 must remain at
# occurrences: 1 after the semantic layer, even when a malicious /
# overzealous verdict declares it cohesive. The semantic layer must
# never invent a recurring group the floor did not admit.
# ---------------------------------------------------------------------
T4=$(mktemp -d)
trap 'rm -rf "$T4"' EXIT

# Hand-crafted single-occurrence cascade YAML.
cat > "$T4/cascade.yaml" <<'EOF'
candidates:
  - id: c1
    kind: other
    score: 60
    impact: low
    reason: "Sprint contract on lonely topic"
    traceability:
      - "contracts/2026-04-27-foo.md#contract-c1"
      - "progress.md#cycle-2"
    occurrences: 1
    content_path: "divergences/c1.md"
    content_excerpt: "lonely decision"
EOF

# A verdict that (incorrectly) tries to promote the lonely candidate
# to a cohesive group. The rewriter must ignore this — occurrences: 1
# is the deterministic floor, not eligible for cohesion.
cat > "$T4/verdicts.tsv" <<'EOF'
lonely topic	cohesive	A verdict that should never fire because the floor reported occurrences: 1
EOF

POST_4="$(bash "$REWRITE" --cascade-yaml "$T4/cascade.yaml" --verdicts "$T4/verdicts.tsv" 2>/dev/null || true)"

n_cands=$(count_id_lines "$POST_4")
n_occ_2=$(count_occ_eq "$POST_4" 2)
n_occ_1=$(count_occ_eq "$POST_4" 1)
n_occ_2=${n_occ_2:-0}
n_occ_1=${n_occ_1:-0}
n_cands=${n_cands:-0}

if [ "$n_cands" = "1" ] && [ "$n_occ_1" = "1" ] && [ "$n_occ_2" = "0" ]; then
  pass "(4) no-invent invariant: single-occurrence candidate stays at occurrences: 1 even with cohesive verdict"
else
  err "(4) no-invent invariant violated (cands=$n_cands, occ=1 lines=$n_occ_1, occ=2 lines=$n_occ_2)"
  printf -- '--- post-rewrite YAML ---\n%s\n' "$POST_4" >&2
fi

rm -rf "$T4"
trap - EXIT

harness::summary
