#!/usr/bin/env bash
# tests/canonical-memory/contract-promotion-bidirectional-integration.test.sh
#
# Integration test for the bidirectional-link sensor against a
# canonical-memory state produced by the s01-t03 helper
# (`lib/canonical-memory/write-promoted-concept.sh`).
#
# Two subcases:
#
#   (1) Positive — run write-promoted-concept.sh against a synthetic
#       cascade candidate, then run
#       lib/sensors/contract-promotion-bidirectional.sh against the
#       resulting canonical-memory tree → exit 0 (silent).
#
#   (2) Negative — start from the same positive state, hand-delete the
#       backlink line from actors/<host-actor>.md, then re-run the
#       sensor → exit non-zero with at least one structured violation
#       block whose `location` cites the actor file.
#
# Source: .yoke/acceptance-contracts/2026-04-27-sprint-contract-promotion.md
# Scenario 4 / FR-4 binding subcases. The integration check proves the
# helper-time invariant (s01-t03) and the standing-guard sensor
# (s01-t04) agree on the bidirectional rule — discrepancy between the
# two surfaces is a known failure mode for invariant sensors and the
# Tech Spec calls this test out as the load-bearing integration.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

HELPER="$PLUGIN_ROOT/lib/canonical-memory/write-promoted-concept.sh"
SENSOR="$PLUGIN_ROOT/lib/sensors/contract-promotion-bidirectional.sh"

[ -f "$HELPER" ] || { err "helper missing at $HELPER"; harness::summary; }
[ -f "$SENSOR" ] || { err "sensor missing at $SENSOR"; harness::summary; }
[ -x "$SENSOR" ] && pass "(0) sensor is executable" || err "(0) sensor not executable"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ----------------------------------------------------------------------
# Build a candidate fixture matching the Scenario 3 helper input shape.
# ----------------------------------------------------------------------
CANDIDATE="$TMP/candidate.yaml"
cat > "$CANDIDATE" <<'EOF'
  - id: c1
    kind: sprint-contract-promotion
    score: 75
    impact: low
    reason: "Sprint contract on session timeout policy"
    traceability:
      - "contracts/2026-04-26-slug-a.md#contract-c1"
      - "contracts/2026-04-27-slug-b.md#contract-c1"
    occurrences: 2
    content_path: "divergences/c1.md"
    content_excerpt: "Set session timeout to 30 minutes for all flows"
EOF

CMEM="$TMP/canonical-memory"
mkdir -p "$CMEM/actors" "$CMEM/concepts"

HOST_ACTOR="claude-yoke"

SLUG_STUB="$TMP/slug-stub.sh"
cat > "$SLUG_STUB" <<'EOF'
#!/usr/bin/env bash
printf 'session-timeout-policy'
EOF
chmod +x "$SLUG_STUB"

if ! YOKE_PROMOTED_CONCEPT_SLUG_FN="$SLUG_STUB" \
     bash "$HELPER" \
       --candidate "$CANDIDATE" \
       --host-actor "$HOST_ACTOR" \
       --canonical-memory "$CMEM" \
       --ratified "2026-04-27" \
       >"$TMP/run.stdout" 2>"$TMP/run.stderr"; then
  err "helper exited non-zero — stdout: $(cat "$TMP/run.stdout"), stderr: $(cat "$TMP/run.stderr")"
  harness::summary
fi
pass "(0) helper wrote concept + actor backlink to $CMEM"

CONCEPT_FILE="$CMEM/concepts/session-timeout-policy.md"
ACTOR_FILE="$CMEM/actors/${HOST_ACTOR}.md"

[ -f "$CONCEPT_FILE" ] || { err "concept file not created at $CONCEPT_FILE"; harness::summary; }
[ -f "$ACTOR_FILE"   ] || { err "actor file not created at $ACTOR_FILE"; harness::summary; }

# ----------------------------------------------------------------------
# Subcase 1 — positive: sensor against helper-produced state → exit 0.
# ----------------------------------------------------------------------
POS_STDOUT="$TMP/pos.stdout"
POS_STDERR="$TMP/pos.stderr"
if bash "$SENSOR" --canonical-memory "$CMEM" >"$POS_STDOUT" 2>"$POS_STDERR"; then
  pass "(1) sensor against helper-produced canonical memory: exit 0"
else
  err "(1) sensor should exit 0 against helper-produced state — stdout: $(cat "$POS_STDOUT") | stderr: $(cat "$POS_STDERR")"
fi

if [ ! -s "$POS_STDOUT" ]; then
  pass "(1) sensor stdout is silent on positive fixture"
else
  err "(1) sensor stdout not silent — body: $(cat "$POS_STDOUT")"
fi

# ----------------------------------------------------------------------
# Subcase 2 — hand-delete the backlink line from the actor body, then
# re-run the sensor → non-zero with violation citing the actor file.
# ----------------------------------------------------------------------
# Remove every line containing the bare `[[session-timeout-policy]]`
# wikilink from the actor body. This mirrors a hand edit / regression
# in `/yoke:compress` or `/yoke:preserve`.
DAMAGED_ACTOR="$ACTOR_FILE"
grep -v '\[\[session-timeout-policy\]\]' "$DAMAGED_ACTOR" > "$DAMAGED_ACTOR.tmp"
mv "$DAMAGED_ACTOR.tmp" "$DAMAGED_ACTOR"

if grep -qF '[[session-timeout-policy]]' "$DAMAGED_ACTOR"; then
  err "(2) hand-deletion did not remove the wikilink — body: $(cat "$DAMAGED_ACTOR")"
  harness::summary
fi
pass "(2) hand-deleted backlink from actor body"

NEG_STDOUT="$TMP/neg.stdout"
NEG_STDERR="$TMP/neg.stderr"
if bash "$SENSOR" --canonical-memory "$CMEM" >"$NEG_STDOUT" 2>"$NEG_STDERR"; then
  err "(2) sensor should exit non-zero after hand-deletion — stdout: $(cat "$NEG_STDOUT")"
else
  pass "(2) sensor exits non-zero after hand-deletion"
fi

if grep -qE '^- id: "claude-yoke"' "$NEG_STDOUT"; then
  pass "(2) violation block id names the offending actor (claude-yoke)"
else
  err "(2) violation block missing actor id — body: $(cat "$NEG_STDOUT")"
fi

if grep -qF "actors/${HOST_ACTOR}.md" "$NEG_STDOUT"; then
  pass "(2) violation location cites actors/${HOST_ACTOR}.md"
else
  err "(2) violation missing actor file location — body: $(cat "$NEG_STDOUT")"
fi

if grep -qF "[[session-timeout-policy]]" "$NEG_STDOUT"; then
  pass "(2) correction_instruction names the missing wikilink"
else
  err "(2) correction missing wikilink — body: $(cat "$NEG_STDOUT")"
fi

if grep -qF "[[yoke-pattern-memory-model]]" "$NEG_STDOUT"; then
  pass "(2) violation reference cites [[yoke-pattern-memory-model]]"
else
  err "(2) violation missing pattern reference — body: $(cat "$NEG_STDOUT")"
fi

harness::summary
