#!/usr/bin/env bash
# tests/canonical-memory/search-facade-equivalence.test.sh
#
# NOTE: A true end-to-end byte-equivalence test (Acceptance Contract
# Scenario 3) requires invoking `/yoke:search-canonical-memory "<query>"`
# and `/yoke:search-canonical-memory "<query>"` through Claude Code's Skill-tool dispatcher
# against a live Bedrock vault, then diffing stdout. That harness does
# not exist outside an interactive Claude Code session, and Sprint 01's
# coverage discipline (per the sprint file's "shape sensor" pattern —
# see search-canonical-memory-skill-shape, canonize-skill-shape,
# provider-contract-doc-shape) explicitly accepts a structural assertion
# in the test surface. The full E2E coverage lives downstream:
#
#   - Sprint 02 sensor `bedrock-canonize-roundtrip` exercises the full
#     dispatch path through the extracted claude-bedrock peer plugin
#     (Scenario 9 / FR-4).
#   - Sprint 02 sensor `end-to-end-implement-cycle` exercises the full
#     ralph-loop with both facade verbs live (Scenario 10 / FR-5).
#
# What this test asserts (structural equivalence — necessary, not
# sufficient — for the byte-equivalence claim):
#
#   (1) skills/search-canonical-memory/SKILL.md exists.
#   (2) Frontmatter declares `name: search-canonical-memory` (the
#       Skill-tool dispatch identity that callers will replace
#       /yoke:search-canonical-memory with).
#   (3) The skill body sources `lib/canonical-memory/resolve-provider.sh`
#       (so dispatch is wired through the resolver, not hard-coded).
#   (4) The skill body dispatches via `$YOKE_PROVIDER_SEARCH_SKILL`
#       (the variable the resolver exports), proving the facade is
#       provider-agnostic at the dispatch site.
#   (5) The skill body invokes the user query verbatim — at minimum
#       it references the query via `<query>` placeholder or
#       `$ARGUMENTS`/`$1` so the invariant "no parsing, no reformatting"
#       is structurally observable.
#   (6) Empty-query rejection is documented with the literal
#       "wm: query is required" string from the negative criterion in
#       Scenario 3's Then clause.
#   (7) The Critical-rules section forbids writes — proving the
#       byte-equivalence guarantee is not undermined by side effects.
#
# Sensor: search-facade-equivalence (computational, cheap).

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

SKILL="$PLUGIN_ROOT/skills/search-canonical-memory/SKILL.md"

# ----------------------------------------------------------------------
# (1) File presence.
# ----------------------------------------------------------------------
[ -f "$SKILL" ] && pass "(1) skills/search-canonical-memory/SKILL.md exists" || {
  err "(1) skills/search-canonical-memory/SKILL.md missing"
  harness::summary
}

# ----------------------------------------------------------------------
# (2) Frontmatter declares the dispatch identity.
# ----------------------------------------------------------------------
grep -q '^name: search-canonical-memory$' "$SKILL" \
  && pass "(2) frontmatter: name == search-canonical-memory" \
  || err "(2) frontmatter missing 'name: search-canonical-memory'"

# ----------------------------------------------------------------------
# (3) Skill body sources the provider resolver.
# ----------------------------------------------------------------------
grep -q 'lib/canonical-memory/resolve-provider.sh' "$SKILL" \
  && pass "(3) body references lib/canonical-memory/resolve-provider.sh" \
  || err "(3) body does not source the provider resolver"

# ----------------------------------------------------------------------
# (4) Skill body dispatches via $YOKE_PROVIDER_SEARCH_SKILL.
# ----------------------------------------------------------------------
grep -q 'YOKE_PROVIDER_SEARCH_SKILL' "$SKILL" \
  && pass "(4) body dispatches via YOKE_PROVIDER_SEARCH_SKILL (provider-agnostic)" \
  || err "(4) body does not reference YOKE_PROVIDER_SEARCH_SKILL — dispatch may be hard-coded"

# ----------------------------------------------------------------------
# (5) Skill body documents that the user query is forwarded verbatim.
# Accept any of the canonical placeholder forms ($ARGUMENTS, "<query>",
# or $1) — what we're asserting is "the body says forward the query
# unchanged".
# ----------------------------------------------------------------------
if grep -qE '(\$ARGUMENTS|<query>|args:[[:space:]]*"<query>")' "$SKILL"; then
  pass "(5) body forwards the user query verbatim (placeholder or \$ARGUMENTS reference present)"
else
  err "(5) body does not document that the user query is forwarded verbatim"
fi

# ----------------------------------------------------------------------
# (6) Empty-query rejection — Scenario 3's Then clause requires the
# literal "wm: query is required" string.
# ----------------------------------------------------------------------
grep -q 'wm: query is required' "$SKILL" \
  && pass "(6) empty-query rejection documented with literal 'wm: query is required'" \
  || err "(6) literal 'wm: query is required' missing — empty-query negative path is undocumented"

# ----------------------------------------------------------------------
# (7) Critical rules forbid writes / side effects (the read-only
# discipline that justifies byte-equivalence with /yoke:search-canonical-memory).
# Two acceptable phrasings: "NEVER write" or "Pure read".
# ----------------------------------------------------------------------
if grep -qE '(NEVER write|never writes?|[Pp]ure read)' "$SKILL"; then
  pass "(7) critical rules / description forbid writes (byte-equivalence invariant intact)"
else
  err "(7) no read-only discipline rule found — byte-equivalence invariant is undocumented"
fi

harness::summary
