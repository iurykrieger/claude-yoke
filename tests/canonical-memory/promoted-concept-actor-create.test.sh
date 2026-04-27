#!/usr/bin/env bash
# tests/canonical-memory/promoted-concept-actor-create.test.sh
#
# Self-test for the actor-create-on-first-use branch of
# `lib/canonical-memory/write-promoted-concept.sh`
# (sprint-contract-promotion s01-t03).
#
# Binding for FR-7 + Scenario 3 (actor-absent subcase):
#   - fixture starts WITHOUT an actor file
#   - helper creates actors/<host-actor>.md from the canonical actor
#     template (templates/canonical/actor/_template.md)
#   - the seeded body contains the `## Recent Activity` section with
#     the backlink to the new concept slug
#   - the rendered frontmatter is well-formed (matches the
#     entities/actor.md shape — at minimum, `type: actor`, `name`,
#     `status: active`, `updated_at` populated)

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

HELPER="$PLUGIN_ROOT/lib/canonical-memory/write-promoted-concept.sh"
TEMPLATE="$PLUGIN_ROOT/templates/canonical/actor/_template.md"

if [ ! -f "$HELPER" ]; then
  err "write-promoted-concept helper missing at $HELPER"
  harness::summary
fi
if [ ! -f "$TEMPLATE" ]; then
  err "actor template missing at $TEMPLATE"
  harness::summary
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CANDIDATE="$TMP/candidate.yaml"
cat > "$CANDIDATE" <<'EOF'
  - id: c1
    kind: sprint-contract-promotion
    score: 80
    impact: low
    reason: "Sprint contract on retry-budget cap"
    traceability:
      - "contracts/2026-04-26-foo.md#contract-c1"
      - "contracts/2026-04-27-bar.md#contract-c1"
    occurrences: 2
    content_path: "divergences/c1.md"
    content_excerpt: "Cap retries at 5 attempts per request"
EOF

CMEM="$TMP/canonical-memory"
mkdir -p "$CMEM"  # NOTE: do NOT pre-create actors/ — helper must mkdir

HOST_ACTOR="brand-new-actor"

# Stub slug fn — deterministic kebab.
SLUG_STUB="$TMP/slug-stub.sh"
cat > "$SLUG_STUB" <<'EOF'
#!/usr/bin/env bash
printf 'retry-budget-cap'
EOF
chmod +x "$SLUG_STUB"

ACTOR_FILE="$CMEM/actors/${HOST_ACTOR}.md"
[ -f "$ACTOR_FILE" ] && rm -f "$ACTOR_FILE"

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

# 1. Actor file was created.
if [ ! -f "$ACTOR_FILE" ]; then
  err "(FR-7) actor file NOT created at $ACTOR_FILE"
  harness::summary
fi
pass "(FR-7) actor file created at $ACTOR_FILE"

# 2. Frontmatter shape matches entities/actor.md — minimum binding fields:
#    type: actor, name: "<host-actor>", status: "active", updated_at filled.
FM="$(awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; next} n==1 {print}' "$ACTOR_FILE")"

assert_field() {
  local field="$1"
  local expected="$2"
  local v
  v="$(printf '%s\n' "$FM" \
       | awk -v field="$field" '
           {
             line = $0
             sub(/^[[:space:]]+/, "", line)
             if (index(line, field ":") == 1) {
               v = substr(line, length(field) + 2)
               sub(/^[[:space:]]+/, "", v)
               sub(/[[:space:]]+$/, "", v)
               if (v ~ /^".*"$/) v = substr(v, 2, length(v) - 2)
               print v
               exit
             }
           }
         ')"
  if [ "$v" = "$expected" ]; then
    pass "(FR-7) frontmatter '$field' = '$expected'"
  else
    err "(FR-7) frontmatter '$field' expected '$expected', got '$v'"
  fi
}

assert_field "type"   "actor"
assert_field "name"   "$HOST_ACTOR"
assert_field "status" "active"

updated_at="$(printf '%s\n' "$FM" \
              | awk '/^updated_at:/{sub(/^updated_at:[[:space:]]*/,""); print; exit}')"
if [ -n "$updated_at" ] && [ "$updated_at" != "YYYY-MM-DD" ]; then
  pass "(FR-7) frontmatter 'updated_at' is filled (value: '$updated_at')"
else
  err "(FR-7) frontmatter 'updated_at' is missing or unfilled (value: '$updated_at')"
fi

# 3. The seeded body contains `## Recent Activity` with the backlink.
if grep -q '^## Recent Activity[[:space:]]*$' "$ACTOR_FILE"; then
  pass "(FR-7) seeded body contains '## Recent Activity' section"
else
  err "(FR-7) seeded body missing '## Recent Activity' — body:\n$(cat "$ACTOR_FILE")"
fi

if grep -q '\[\[retry-budget-cap\]\]' "$ACTOR_FILE"; then
  pass "(FR-7) seeded body contains bidirectional backlink [[retry-budget-cap]]"
else
  err "(FR-7) seeded body missing backlink [[retry-budget-cap]] — body:\n$(cat "$ACTOR_FILE")"
fi

# 4. The activity line must be in the canonical shape per Scenario 3.
if grep -qE '^- 2026-04-27 — \[\[retry-budget-cap\]\] — ' "$ACTOR_FILE"; then
  pass "(Scenario 3) activity line matches canonical shape in seeded actor"
else
  err "(Scenario 3) activity line shape mismatch in seeded actor — body:\n$(cat "$ACTOR_FILE")"
fi

# 5. The companion concept file must also exist (the helper writes both).
CONCEPT_FILE="$CMEM/concepts/retry-budget-cap.md"
if [ -f "$CONCEPT_FILE" ]; then
  pass "(Scenario 3) companion concept file written at $CONCEPT_FILE"
else
  err "(Scenario 3) companion concept file missing at $CONCEPT_FILE"
fi

harness::summary
