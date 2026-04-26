#!/usr/bin/env bash
# tests/canonical-memory-write.test.sh
#
# Source-level invariants of the /yoke:preserve write protocol:
#   (a) lib/canonical-memory/propose-write.sh does not exist
#   (b) skills/canonize/ does not exist
#   (c) skills/preserve/SKILL.md declares the four impact classes
#       (low, medium, high, regulatory)
#   (d) high never auto-merges
#   (e) regulatory routes via CODEOWNERS
#   (f) canonization-criteria.sh is referenced
#   (g) the three git strategies (commit-push, commit-push-pr, commit-only)
#       are honored
#   (h) bidirectional linking is declared
#   (i) all five rippability fields (ratified_at, model_calibrated_against,
#       last_validated, traceability, impact_level) are present
#   (j) agents/orchestrator.md invokes /yoke:preserve
#   (k) no direct memory-path commit invocations exist outside skills/preserve/
#
# This is a doc-shape inspection. Real PR-opening flow is exercised in
# host projects, not here.

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

cd "$PLUGIN_ROOT"

# ---------------------------------------------------------------------
# (a) and (b) — single-write-point: prior write entries are gone
# ---------------------------------------------------------------------
if [ ! -f "lib/canonical-memory/propose-write.sh" ]; then
  pass "(a) propose-write.sh absent (single write point)"
else
  err "(a) propose-write.sh exists (must be absent — single write point invariant)"
fi

if [ ! -d "skills/canonize" ]; then
  pass "(b) skills/canonize/ absent (single write point)"
else
  err "(b) skills/canonize/ exists (must be absent)"
fi

PRE="skills/preserve/SKILL.md"
if [ ! -f "$PRE" ]; then
  err "skills/preserve/SKILL.md missing"
  harness::summary
fi

# ---------------------------------------------------------------------
# (c) Four impact classes
# ---------------------------------------------------------------------
for cls in low medium high regulatory; do
  if grep -qE "\`${cls}\`" "$PRE"; then
    pass "(c) preserve declares impact class \`${cls}\`"
  else
    err "(c) preserve missing impact class \`${cls}\`"
  fi
done

# ---------------------------------------------------------------------
# (d) high never auto-merges
# ---------------------------------------------------------------------
if grep -qE '`high` and `regulatory` writes \*\*never\*\* auto-merge|`high`.*never.*auto-merge|never.*auto-merge.*`high`' "$PRE"; then
  pass "(d) preserve blocks auto-merge for high"
else
  err "(d) preserve does not block auto-merge for high"
fi

# ---------------------------------------------------------------------
# (e) Regulatory routes via CODEOWNERS
# ---------------------------------------------------------------------
if grep -qE 'regulatory.*CODEOWNERS|CODEOWNERS.*regulatory|Compliance via CODEOWNERS' "$PRE"; then
  pass "(e) preserve routes regulatory via CODEOWNERS"
else
  err "(e) preserve missing regulatory CODEOWNERS routing"
fi

# ---------------------------------------------------------------------
# (f) canonization-criteria.sh referenced
# ---------------------------------------------------------------------
if grep -q 'canonization-criteria\.sh' "$PRE"; then
  pass "(f) preserve invokes canonization-criteria.sh as the Model C classifier"
else
  err "(f) preserve does not reference canonization-criteria.sh"
fi

# ---------------------------------------------------------------------
# (g) Three git strategies honored
# ---------------------------------------------------------------------
for strat in commit-push commit-push-pr commit-only; do
  if grep -qE "\`${strat}\`" "$PRE"; then
    pass "(g) preserve honors git strategy \`${strat}\`"
  else
    err "(g) preserve missing git strategy \`${strat}\`"
  fi
done

# ---------------------------------------------------------------------
# (h) Bidirectional linking
# ---------------------------------------------------------------------
if grep -qiE 'bidirectional links?|bidirectional linking' "$PRE"; then
  pass "(h) preserve declares bidirectional linking"
else
  err "(h) preserve missing bidirectional linking"
fi

# ---------------------------------------------------------------------
# (i) Five rippability fields enforced on create
# ---------------------------------------------------------------------
for field in ratified_at model_calibrated_against last_validated traceability impact_level; do
  if grep -q "$field" "$PRE"; then
    pass "(i) preserve references rippability field $field"
  else
    err "(i) preserve missing rippability field $field"
  fi
done

# ---------------------------------------------------------------------
# (j) Orchestrator invokes /yoke:preserve
# ---------------------------------------------------------------------
if grep -q '/yoke:preserve' agents/orchestrator.md; then
  pass "(j) orchestrator invokes /yoke:preserve via the Skill tool"
else
  err "(j) orchestrator does not invoke /yoke:preserve"
fi

# ---------------------------------------------------------------------
# (k) No direct memory-path commits outside skills/preserve/.
# The regex matches the canonical-memory commit invocation pattern
# (with optional surrounding double-quotes around the variable).
# ---------------------------------------------------------------------
LEAKS=$(grep -rEln 'git -C "?\$MEMORY_PATH"? commit' agents/ skills/ lib/ tests/ 2>/dev/null \
  | grep -v '^skills/preserve/' \
  | grep -v "^${BASH_SOURCE[0]#"$PLUGIN_ROOT/"}\$" || true)

if [ -z "$LEAKS" ]; then
  pass "(k) no direct memory commits outside skills/preserve/"
else
  err "(k) found direct memory commits outside skills/preserve/:"
  printf '%s\n' "$LEAKS" | sed 's/^/    /' >&2
fi

harness::summary
