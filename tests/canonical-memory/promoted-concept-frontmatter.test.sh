#!/usr/bin/env bash
# tests/canonical-memory/promoted-concept-frontmatter.test.sh
#
# Self-test for the rippability frontmatter produced by
# `lib/canonical-memory/write-promoted-concept.sh`
# (sprint-contract-promotion s01-t03).
#
# Binding for FR-3 + FR-5 + Scenario 3 of the Acceptance Contract:
#   - every mandatory rippability field is non-empty
#   - tags: list contains both `kind/contract` and `yoke-framework`
#   - applies_to: lists exactly the resolved host-actor name
#
# The slug-summarisation call is stubbed via the
# YOKE_PROMOTED_CONCEPT_SLUG_FN env var so the test pins a deterministic
# kebab output regardless of any future LLM behaviour.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

HELPER="$PLUGIN_ROOT/lib/canonical-memory/write-promoted-concept.sh"

if [ ! -f "$HELPER" ]; then
  err "write-promoted-concept helper missing at $HELPER"
  harness::summary
fi

# ---------------------------------------------------------------------
# Build a synthetic candidate YAML block (the cascade output the helper
# expects) plus a tmp canonical-memory tree.
# ---------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CANDIDATE="$TMP/candidate.yaml"
cat > "$CANDIDATE" <<'EOF'
  - id: c1
    kind: sprint-contract-promotion
    score: 80
    impact: medium
    reason: "Sprint contract on redirectUrl quoting style"
    traceability:
      - "contracts/2026-04-26-slug-a.md#contract-c1"
      - "progress.md#cycle-2"
      - "contracts/2026-04-27-slug-b.md#contract-c1"
    occurrences: 2
    content_path: "divergences/c1.md"
    content_excerpt: "Use single quotes around redirectUrl values"
EOF

CMEM="$TMP/canonical-memory"
mkdir -p "$CMEM"

HOST_ACTOR="claude-yoke"

# Stub the slug fn: deterministic kebab, ignores attempt arg (no
# collision in this test).
SLUG_STUB="$TMP/slug-stub.sh"
cat > "$SLUG_STUB" <<'EOF'
#!/usr/bin/env bash
# Always return the same canned slug.
printf 'redirect-url-quoting-style'
EOF
chmod +x "$SLUG_STUB"

# Run the helper.
if ! YOKE_PROMOTED_CONCEPT_SLUG_FN="$SLUG_STUB" \
     bash "$HELPER" \
       --candidate "$CANDIDATE" \
       --host-actor "$HOST_ACTOR" \
       --canonical-memory "$CMEM" \
       --ratified "2026-04-27" \
       --model "claude-opus-4-7[1m]" \
       --project "claude-yoke" \
       >"$TMP/run.stdout" 2>"$TMP/run.stderr"; then
  err "helper exited non-zero — stdout: $(cat "$TMP/run.stdout"), stderr: $(cat "$TMP/run.stderr")"
  harness::summary
fi

CONCEPT_FILE="$CMEM/concepts/redirect-url-quoting-style.md"
if [ ! -f "$CONCEPT_FILE" ]; then
  err "concept file not created at $CONCEPT_FILE"
  harness::summary
fi
pass "(0) helper writes concepts/<slug>.md to canonical-memory dir"

# ---------------------------------------------------------------------
# Frontmatter assertions — extract the YAML between the leading `---`
# delimiters and check each mandatory field individually.
# ---------------------------------------------------------------------
FM="$(awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; next} n==1 {print}' "$CONCEPT_FILE")"

# Helper: assert <field>: non-empty (top-level scalar). Allows quoted or
# bare values; rejects empty string `""`.
assert_field_nonempty() {
  local field="$1"
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
  if [ -n "$v" ]; then
    pass "(FR-3) frontmatter field '$field' is non-empty (value: '$v')"
  else
    err "(FR-3) frontmatter field '$field' is missing or empty"
  fi
}

# 1. Every mandatory rippability + identity field is non-empty (FR-3 +
#    Scenario 3 binding fields).
for f in type name description status ratified model_calibrated_against last_validated impact_level project; do
  assert_field_nonempty "$f"
done

# 2. type: concept, status: active (binding values per Scenario 3).
type_v="$(printf '%s\n' "$FM" | awk -F': ' '/^type:/{gsub(/"/, "", $2); print $2; exit}')"
status_v="$(printf '%s\n' "$FM" | awk -F': ' '/^status:/{gsub(/"/, "", $2); print $2; exit}')"
[ "$type_v" = "concept" ] && pass "(FR-3) type: concept" || err "(FR-3) type expected 'concept', got '$type_v'"
[ "$status_v" = "active" ] && pass "(FR-3) status: active" || err "(FR-3) status expected 'active', got '$status_v'"

# 3. tags: list MUST contain both `kind/contract` and `yoke-framework`
#    (FR-5 binding).
if printf '%s\n' "$FM" | grep -q '^[[:space:]]*-[[:space:]]\+kind/contract[[:space:]]*$'; then
  pass "(FR-5) tags contains 'kind/contract'"
else
  err "(FR-5) tags does NOT contain 'kind/contract' — frontmatter:\n$FM"
fi
if printf '%s\n' "$FM" | grep -q '^[[:space:]]*-[[:space:]]\+yoke-framework[[:space:]]*$'; then
  pass "(FR-5) tags contains 'yoke-framework'"
else
  err "(FR-5) tags does NOT contain 'yoke-framework' — frontmatter:\n$FM"
fi

# 4. applies_to: list contains exactly the resolved host-actor name
#    (Scenario 3 binding).
applies_block="$(printf '%s\n' "$FM" | awk '
  BEGIN{in_block=0; n=0}
  /^applies_to:[[:space:]]*$/ { in_block=1; next }
  in_block==1 {
    if ($0 ~ /^[[:space:]]+-[[:space:]]+/) {
      v = $0
      sub(/^[[:space:]]+-[[:space:]]+/, "", v)
      sub(/[[:space:]]+$/, "", v)
      if (v ~ /^".*"$/) v = substr(v, 2, length(v) - 2)
      print v
      n++
    } else {
      in_block=0
    }
  }
')"
applies_count=$(printf '%s' "$applies_block" | grep -c .)
if [ "$applies_count" = "1" ] && [ "$applies_block" = "$HOST_ACTOR" ]; then
  pass "(Scenario 3) applies_to lists exactly the host-actor: $HOST_ACTOR"
else
  err "(Scenario 3) applies_to expected exactly ['$HOST_ACTOR'], got: '$applies_block'"
fi

# 5. depends_on / supersedes / contradicts_with — present as empty arrays
#    (Scenario 3 binding).
for empty_field in depends_on supersedes contradicts_with; do
  if printf '%s\n' "$FM" | grep -qE "^${empty_field}:[[:space:]]*\[\][[:space:]]*$"; then
    pass "(Scenario 3) ${empty_field}: [] is present"
  else
    err "(Scenario 3) ${empty_field}: [] not present"
  fi
done

# 6. traceability: list contains both originating contract paths
#    (Scenario 3 binding).
trace_block="$(printf '%s\n' "$FM" | awk '
  BEGIN{in_block=0}
  /^traceability:[[:space:]]*$/ { in_block=1; next }
  in_block==1 {
    if ($0 ~ /^[[:space:]]+-[[:space:]]+/) print $0
    else in_block=0
  }
')"
if printf '%s\n' "$trace_block" | grep -q 'contracts/2026-04-26-slug-a.md#contract-c1' \
   && printf '%s\n' "$trace_block" | grep -q 'contracts/2026-04-27-slug-b.md#contract-c1'; then
  pass "(Scenario 3) traceability lists both originating contract paths"
else
  err "(Scenario 3) traceability missing originating contract paths — got:\n$trace_block"
fi

# 7. aliases: present and non-empty (Scenario 3 binding — original topic
#    prose verbatim).
if printf '%s\n' "$FM" | awk '
  BEGIN{in_block=0; ok=0}
  /^aliases:[[:space:]]*$/ { in_block=1; next }
  in_block==1 {
    if ($0 ~ /^[[:space:]]+-[[:space:]]+/) ok=1
    else in_block=0
  }
  END { exit (ok==1) ? 0 : 1 }
'; then
  pass "(Scenario 3) aliases is present and non-empty"
else
  err "(Scenario 3) aliases missing or empty"
fi

harness::summary
