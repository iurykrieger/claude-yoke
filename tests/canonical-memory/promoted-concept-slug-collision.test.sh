#!/usr/bin/env bash
# tests/canonical-memory/promoted-concept-slug-collision.test.sh
#
# Self-test for the slug-collision retry contract in
# `lib/canonical-memory/write-promoted-concept.sh`
# (sprint-contract-promotion s01-t03).
#
# Binding for FR-6 + Scenario 3 (slug-collision subcase):
#   - fixture pre-seeds concepts/<colliding-slug>.md
#   - the slug-summarisation stub returns the SAME colliding slug on
#     every attempt (regardless of the <attempt> arg)
#   - the helper retries up to 5 times, each retry colliding
#   - on exhaustion (every attempt collided) the helper exits non-zero
#     with a diagnostic naming the colliding slug
#
# The "exits non-zero on exhaustion" path IS the binding outcome for
# this subtest — there is no path where the helper succeeds against
# a perpetually-colliding stub.

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
    score: 70
    impact: low
    reason: "Sprint contract on logger-format choice"
    traceability:
      - "contracts/2026-04-26-foo.md#contract-c1"
      - "contracts/2026-04-27-bar.md#contract-c1"
    occurrences: 2
    content_path: "divergences/c1.md"
    content_excerpt: "Use structured JSON logging across services"
EOF

CMEM="$TMP/canonical-memory"
mkdir -p "$CMEM/concepts" "$CMEM/actors"

HOST_ACTOR="claude-yoke"
COLLIDING_SLUG="logger-format-choice"

# Pre-seed the colliding slug so every retry attempts to write the same path.
cat > "$CMEM/concepts/${COLLIDING_SLUG}.md" <<EOF
---
type: concept
name: "pre-existing concept that takes the slug"
---

# pre-existing concept

> Fixture file. Pre-seeded so the slug-collision retry path engages.
EOF

# Stub slug fn — ALWAYS return the colliding slug, ignoring attempt.
# This pins the exhaustion path: the helper has no way out, must fail.
SLUG_STUB="$TMP/slug-stub.sh"
cat > "$SLUG_STUB" <<EOF
#!/usr/bin/env bash
# Always return the colliding slug, regardless of attempt number.
# The retry counter increments on the helper side; the stub stays still.
printf '%s' "${COLLIDING_SLUG}"
EOF
chmod +x "$SLUG_STUB"

# Counter file: the stub also bumps a counter so we can verify the
# helper actually retried up to 5 times rather than bailing on the first
# collision.
COUNTER="$TMP/attempts.count"
echo 0 > "$COUNTER"

# Wrap the slug stub with attempt counting.
SLUG_STUB_COUNTING="$TMP/slug-stub-counting.sh"
cat > "$SLUG_STUB_COUNTING" <<EOF
#!/usr/bin/env bash
# Increment counter and return colliding slug.
n=\$(cat "${COUNTER}")
echo \$((n + 1)) > "${COUNTER}"
printf '%s' "${COLLIDING_SLUG}"
EOF
chmod +x "$SLUG_STUB_COUNTING"

# Run the helper. It MUST exit non-zero.
set +e
YOKE_PROMOTED_CONCEPT_SLUG_FN="$SLUG_STUB_COUNTING" \
  bash "$HELPER" \
    --candidate "$CANDIDATE" \
    --host-actor "$HOST_ACTOR" \
    --canonical-memory "$CMEM" \
    --ratified "2026-04-27" \
    >"$TMP/run.stdout" 2>"$TMP/run.stderr"
exit_code=$?
set -e

# 1. Helper exited non-zero (binding outcome for FR-6 exhaustion subcase).
if [ "$exit_code" -ne 0 ]; then
  pass "(FR-6) helper exited non-zero on slug-collision exhaustion (exit: $exit_code)"
else
  err "(FR-6) helper exited 0 on slug-collision exhaustion — expected non-zero"
fi

# 2. The stub was called the contract-mandated number of times. The
#    Tech Spec + AC pin the cap at 5 attempts (attempts 0..4 inclusive).
attempts="$(cat "$COUNTER")"
if [ "$attempts" -eq 5 ]; then
  pass "(FR-6) slug fn was invoked exactly 5 times (the documented retry cap)"
else
  err "(FR-6) slug fn was invoked $attempts times — expected exactly 5"
fi

# 3. Diagnostic on stderr names the colliding slug (the AC + Tech Spec
#    require a non-zero exit "with a diagnostic naming the colliding
#    slug").
if grep -q "$COLLIDING_SLUG" "$TMP/run.stderr"; then
  pass "(FR-6) stderr diagnostic names the colliding slug ('$COLLIDING_SLUG')"
else
  err "(FR-6) stderr diagnostic does NOT name the colliding slug — stderr:\n$(cat "$TMP/run.stderr")"
fi

# 4. The pre-seeded concept file must NOT have been clobbered. The
#    helper failed before writing, so the original content stays.
if grep -q '^name: "pre-existing concept that takes the slug"$' "$CMEM/concepts/${COLLIDING_SLUG}.md"; then
  pass "(FR-6) pre-existing concept file was not clobbered by failed retry"
else
  err "(FR-6) pre-existing concept file was clobbered or rewritten — content:\n$(cat "$CMEM/concepts/${COLLIDING_SLUG}.md")"
fi

# 5. No actor file was written for this run (helper failed before reaching
#    the actor-write step).
if [ ! -f "$CMEM/actors/${HOST_ACTOR}.md" ]; then
  pass "(FR-6) no actor file was written on the failed retry path"
else
  err "(FR-6) actor file was written despite slug-collision failure — file:\n$(cat "$CMEM/actors/${HOST_ACTOR}.md")"
fi

harness::summary
