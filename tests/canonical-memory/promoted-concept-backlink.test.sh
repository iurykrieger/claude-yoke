#!/usr/bin/env bash
# tests/canonical-memory/promoted-concept-backlink.test.sh
#
# Self-test for the bidirectional backlink invariant produced by
# `lib/canonical-memory/write-promoted-concept.sh`
# (sprint-contract-promotion s01-t03).
#
# Binding for FR-4 (backlink subcase) + Scenario 3 — actor-existing
# branch:
#   - actors/<host-actor>.md exists (pre-seeded in this test)
#   - after the helper runs, the actor's `## Recent Activity` section
#     contains a line with a bare wikilink `[[<concept-slug>]]` whose
#     target slug matches the concept written
#
# (Scenario 4 sensors — contract-promotion-bidirectional-{self-test,
# integration} — also cover FR-4 from a different angle and land in
# s01-t04, not in this test.)

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

HELPER="$PLUGIN_ROOT/lib/canonical-memory/write-promoted-concept.sh"

if [ ! -f "$HELPER" ]; then
  err "write-promoted-concept helper missing at $HELPER"
  harness::summary
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CANDIDATE="$TMP/candidate.yaml"
cat > "$CANDIDATE" <<'EOF'
  - id: c1
    kind: sprint-contract-promotion
    score: 75
    impact: low
    reason: "Sprint contract on session timeout policy"
    traceability:
      - "contracts/2026-04-26-slug-a.md#contract-c1"
      - "progress.md#cycle-2"
      - "contracts/2026-04-27-slug-b.md#contract-c1"
    occurrences: 2
    content_path: "divergences/c1.md"
    content_excerpt: "Set session timeout to 30 minutes for all flows"
EOF

CMEM="$TMP/canonical-memory"
mkdir -p "$CMEM/actors" "$CMEM/concepts"

HOST_ACTOR="claude-yoke"

# Pre-seed an actor file so the helper takes the append-to-existing
# branch (Scenario 3 — actor-present subcase). The seeded body has no
# `## Recent Activity` section yet — the helper must add one.
cat > "$CMEM/actors/${HOST_ACTOR}.md" <<EOF
---
type: actor
name: "${HOST_ACTOR}"
status: "active"
updated_at: 2026-04-26
updated_by: "test-fixture"
---

# ${HOST_ACTOR}

> Pre-existing actor body for the backlink test fixture.
EOF

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

CONCEPT_FILE="$CMEM/concepts/session-timeout-policy.md"
ACTOR_FILE="$CMEM/actors/${HOST_ACTOR}.md"

if [ ! -f "$CONCEPT_FILE" ]; then
  err "concept file not created at $CONCEPT_FILE"
  harness::summary
fi
pass "(0) concept file written at $CONCEPT_FILE"

# 1. The actor file must still exist (helper must not have clobbered it).
if [ ! -f "$ACTOR_FILE" ]; then
  err "(FR-4) actor file disappeared at $ACTOR_FILE"
  harness::summary
fi
pass "(FR-4) actor file preserved at $ACTOR_FILE"

# 2. The actor body must contain a `## Recent Activity` section.
if grep -q '^## Recent Activity[[:space:]]*$' "$ACTOR_FILE"; then
  pass "(FR-4) actor body contains '## Recent Activity' section"
else
  err "(FR-4) actor body missing '## Recent Activity' section — body:\n$(cat "$ACTOR_FILE")"
fi

# 3. The actor body must contain a bare wikilink to the new concept slug.
#    Bare = `[[session-timeout-policy]]`, never `[[concepts/...]]`.
if grep -q '\[\[session-timeout-policy\]\]' "$ACTOR_FILE"; then
  pass "(FR-4) actor body contains bare wikilink [[session-timeout-policy]] (bidirectional invariant)"
else
  err "(FR-4) actor body missing bare wikilink [[session-timeout-policy]] — body:\n$(cat "$ACTOR_FILE")"
fi

# 4. Reject namespaced wikilinks like [[concepts/...]] — the canonical
#    convention is bare wikilinks per [[yoke-pattern-memory-model]].
if grep -q '\[\[concepts/' "$ACTOR_FILE"; then
  err "(FR-4) actor body contains namespaced wikilink [[concepts/...]] — bare-wikilink convention violated"
else
  pass "(FR-4) actor body uses bare wikilinks (no [[concepts/...]] form)"
fi

# 5. The activity line must be in the structured shape declared by the
#    Tech Spec: `- <YYYY-MM-DD> — [[<concept-slug>]] — <summary>`.
if grep -qE '^- 2026-04-27 — \[\[session-timeout-policy\]\] — ' "$ACTOR_FILE"; then
  pass "(Scenario 3) activity line matches '- <YYYY-MM-DD> — [[<concept-slug>]] — <summary>' shape"
else
  err "(Scenario 3) activity line shape mismatch — body:\n$(cat "$ACTOR_FILE")"
fi

harness::summary
