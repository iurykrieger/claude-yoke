#!/usr/bin/env bash
# tests/sensors/contract-promotion-bidirectional.test.sh
#
# Self-test for lib/sensors/contract-promotion-bidirectional.sh. Three
# subcases:
#
#   (1) Positive — concept's applies_to lists actor + actor body
#       wikilinks the concept slug → silent exit 0.
#   (2) Negative (forward edge) — concept's applies_to references
#       actor whose body is missing the bare `[[<concept-slug>]]`
#       wikilink → exit non-zero with structured-output YAML violation
#       block whose `location` cites the actor file.
#   (3) Reverse — actor body wikilinks a `kind/contract` concept whose
#       `applies_to:` does NOT list the actor → exit non-zero with
#       structured violation citing the concept file.
#
# Source: .yoke/acceptance-contracts/2026-04-27-sprint-contract-promotion.md
# Scenario 4 / FR-4. Acceptance criterion s01-t04: this script exits 0
# with all three subcases exercised.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SENSOR="$PLUGIN_ROOT/lib/sensors/contract-promotion-bidirectional.sh"

fail=0
pass() { echo "[PASS] $1"; }
err()  { echo "[FAIL] $1" >&2; fail=$((fail+1)); }

echo "--- contract-promotion-bidirectional sensor self-test ---"

# 0. Sensor file exists and is executable.
[ -f "$SENSOR" ] || { err "sensor missing at $SENSOR"; exit 1; }
[ -x "$SENSOR" ] && pass "sensor is executable" || err "sensor not executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Common concept frontmatter generator.
make_concept() {
  local cmem="$1"
  local slug="$2"
  local actor="$3"
  cat > "${cmem}/concepts/${slug}.md" <<EOF
---
type: concept
name: "${slug}"
description: "Test concept"
status: active
ratified: "2026-04-27"
model_calibrated_against: "test"
last_validated: "2026-04-27"
traceability:
  - "test"
impact_level: "low"
tags:
  - type/concept
  - kind/contract
  - yoke-framework
applies_to:
  - "${actor}"
depends_on: []
supersedes: []
contradicts_with: []
project: "test"
---

# ${slug}

> Test concept body.
EOF
}

# Common actor frontmatter generator. body=with-link includes the
# wikilink, body=without-link omits it.
make_actor() {
  local cmem="$1"
  local actor="$2"
  local body_mode="$3"
  local concept_slug="$4"
  local activity_line=""
  if [ "$body_mode" = "with-link" ]; then
    activity_line="- 2026-04-27 — [[${concept_slug}]] — test backlink"
  else
    activity_line="- 2026-04-27 — (no link) — placeholder"
  fi
  cat > "${cmem}/actors/${actor}.md" <<EOF
---
type: actor
name: "${actor}"
status: "active"
updated_at: 2026-04-27
updated_by: "test-fixture"
---

# ${actor}

> Test actor body.

## Recent Activity

${activity_line}
EOF
}

# ---------------------------------------------------------------------------
# Subcase 1 — positive fixture: silent exit 0.
# ---------------------------------------------------------------------------
pos="$tmp/positive"
mkdir -p "$pos/concepts" "$pos/actors"
make_concept "$pos" "session-timeout-policy" "host-actor"
make_actor   "$pos" "host-actor" "with-link" "session-timeout-policy"

pos_stdout="$tmp/.pos.stdout"
pos_stderr="$tmp/.pos.stderr"
if bash "$SENSOR" --canonical-memory "$pos" >"$pos_stdout" 2>"$pos_stderr"; then
  pass "(1) positive fixture: exit 0"
else
  err "(1) positive fixture should exit 0 — stdout: $(cat "$pos_stdout") | stderr: $(cat "$pos_stderr")"
fi

if [ ! -s "$pos_stdout" ]; then
  pass "(1) positive fixture: stdout is silent"
else
  err "(1) positive fixture stdout not silent: $(cat "$pos_stdout")"
fi

# ---------------------------------------------------------------------------
# Subcase 2 — negative (forward edge): concept lists actor; actor body
# lacks the bare `[[<slug>]]` backlink. Exit non-zero + structured
# violation citing the actor file.
# ---------------------------------------------------------------------------
neg="$tmp/negative"
mkdir -p "$neg/concepts" "$neg/actors"
make_concept "$neg" "session-timeout-policy" "host-actor"
make_actor   "$neg" "host-actor" "without-link" "session-timeout-policy"

neg_stdout="$tmp/.neg.stdout"
neg_stderr="$tmp/.neg.stderr"
if bash "$SENSOR" --canonical-memory "$neg" >"$neg_stdout" 2>"$neg_stderr"; then
  err "(2) negative fixture should exit non-zero but exited 0 — stdout: $(cat "$neg_stdout")"
else
  pass "(2) negative fixture: non-zero exit"
fi

if grep -qE '^- id: "host-actor"' "$neg_stdout"; then
  pass "(2) negative fixture stdout: violation block id names the offending actor"
else
  err "(2) negative fixture stdout missing violation id — body: $(cat "$neg_stdout")"
fi

if grep -qF "actors/host-actor.md" "$neg_stdout"; then
  pass "(2) negative fixture stdout: location cites actors/host-actor.md"
else
  err "(2) negative fixture stdout missing actor file location — body: $(cat "$neg_stdout")"
fi

if grep -qF "[[session-timeout-policy]]" "$neg_stdout"; then
  pass "(2) negative fixture stdout: correction_instruction names the missing wikilink"
else
  err "(2) negative fixture stdout missing wikilink in correction — body: $(cat "$neg_stdout")"
fi

if grep -qF "[[yoke-pattern-memory-model]]" "$neg_stdout"; then
  pass "(2) negative fixture stdout: reference cites [[yoke-pattern-memory-model]]"
else
  err "(2) negative fixture stdout missing pattern reference — body: $(cat "$neg_stdout")"
fi

# ---------------------------------------------------------------------------
# Subcase 3 — reverse fixture: actor body wikilinks a kind/contract
# concept whose applies_to does NOT list the actor. Exit non-zero +
# violation citing the concept file.
# ---------------------------------------------------------------------------
rev="$tmp/reverse"
mkdir -p "$rev/concepts" "$rev/actors"
# Concept's applies_to lists `other-actor` but the actor body that
# wikilinks it is `host-actor`. Forward edge would fault on the
# missing other-actor.md file too — so we also ensure other-actor
# exists with a satisfying backlink to keep the forward pass clean
# and isolate the reverse-edge violation.
make_concept "$rev" "logger-format-choice" "other-actor"
make_actor   "$rev" "other-actor" "with-link" "logger-format-choice"

# Plant `host-actor` whose body wikilinks `[[logger-format-choice]]`
# but the concept's applies_to does NOT list `host-actor` — reverse
# edge fault.
cat > "$rev/actors/host-actor.md" <<'EOF'
---
type: actor
name: "host-actor"
status: "active"
updated_at: 2026-04-27
updated_by: "test-fixture"
---

# host-actor

## Recent Activity

- 2026-04-27 — [[logger-format-choice]] — orphan reverse wikilink
EOF

rev_stdout="$tmp/.rev.stdout"
rev_stderr="$tmp/.rev.stderr"
if bash "$SENSOR" --canonical-memory "$rev" >"$rev_stdout" 2>"$rev_stderr"; then
  err "(3) reverse fixture should exit non-zero but exited 0 — stdout: $(cat "$rev_stdout")"
else
  pass "(3) reverse fixture: non-zero exit"
fi

if grep -qE '^- id: "logger-format-choice"' "$rev_stdout"; then
  pass "(3) reverse fixture stdout: violation block id names the orphan-target concept"
else
  err "(3) reverse fixture stdout missing concept id — body: $(cat "$rev_stdout")"
fi

if grep -qF "concepts/logger-format-choice.md" "$rev_stdout"; then
  pass "(3) reverse fixture stdout: location cites concepts/logger-format-choice.md"
else
  err "(3) reverse fixture stdout missing concept file location — body: $(cat "$rev_stdout")"
fi

if grep -qF "host-actor" "$rev_stdout"; then
  pass "(3) reverse fixture stdout: correction_instruction names the missing actor"
else
  err "(3) reverse fixture stdout missing actor name in correction — body: $(cat "$rev_stdout")"
fi

# ---------------------------------------------------------------------------
# Diagnostic-summary line on stderr for any failure run.
# ---------------------------------------------------------------------------
if grep -qE 'sensor: contract-promotion-bidirectional found[[:space:]]+[0-9]+[[:space:]]+violation' "$neg_stderr"; then
  pass "(2) negative fixture stderr: diagnostic summary present"
else
  err "(2) negative fixture stderr missing diagnostic summary — stderr: $(cat "$neg_stderr")"
fi

echo "--- done: $fail failure(s) ---"
[ "$fail" -eq 0 ]
