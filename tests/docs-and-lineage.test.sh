#!/usr/bin/env bash
# tests/docs-and-lineage.test.sh
#
# Honesty + completeness of the published documentation:
#   (a) docs/lineage.md cites Vibeflow + Bedrock URLs and the
#       "ex nihilo" honesty statement
#   (b) docs/troubleshooting.md has Installation + Phase 1 + Phase 4 +
#       Phase 5 + Phase 6 sections
#   (c) docs/architecture.md mentions Model C
#   (d) README.md credits Vibeflow and Bedrock and links to
#       docs/installation.md (or `/plugin marketplace add ...`),
#       docs/quickstart.md, docs/architecture.md
#   (e) CHANGELOG.md has at least one ## [<semver>] heading matching the
#       manifest version (cross-referenced via plugin.json)

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

cd "$PLUGIN_ROOT"

# ---------------------------------------------------------------------
# (a) Lineage doc
# ---------------------------------------------------------------------
LIN="docs/lineage.md"
if [ ! -f "$LIN" ]; then
  err "(a) $LIN missing"
else
  if grep -qF "github.com/pe-menezes/vibeflow" "$LIN"; then
    pass "(a) lineage cites Vibeflow URL"
  else
    err "(a) lineage missing Vibeflow URL"
  fi

  if grep -qF "github.com/iurykrieger/claude-bedrock" "$LIN"; then
    pass "(a) lineage cites Bedrock URL"
  else
    err "(a) lineage missing Bedrock URL"
  fi

  if grep -qF "ex nihilo" "$LIN"; then
    pass "(a) lineage carries the 'ex nihilo' honesty statement"
  else
    err "(a) lineage missing 'ex nihilo' honesty statement"
  fi
fi

# ---------------------------------------------------------------------
# (b) Troubleshooting sections
# ---------------------------------------------------------------------
TS="docs/troubleshooting.md"
if [ ! -f "$TS" ]; then
  err "(b) $TS missing"
else
  for section in "Installation" "Phase 1" "Phase 4" "Phase 5" "Phase 6"; do
    if grep -qF -- "$section" "$TS"; then
      pass "(b) troubleshooting has '$section' section"
    else
      err "(b) troubleshooting missing '$section'"
    fi
  done
fi

# ---------------------------------------------------------------------
# (c) Architecture mentions Model C
# ---------------------------------------------------------------------
ARCH="docs/architecture.md"
if [ ! -f "$ARCH" ]; then
  err "(c) $ARCH missing"
elif grep -qF "Model C" "$ARCH"; then
  pass "(c) architecture mentions Model C"
else
  err "(c) architecture missing Model C reference"
fi

# ---------------------------------------------------------------------
# (d) README credits + links
# ---------------------------------------------------------------------
RM="README.md"
if [ ! -f "$RM" ]; then
  err "(d) $RM missing"
else
  if grep -qF "Vibeflow" "$RM"; then
    pass "(d) README credits Vibeflow"
  else
    err "(d) README missing Vibeflow credit"
  fi

  if grep -qF "Bedrock" "$RM"; then
    pass "(d) README credits Bedrock"
  else
    err "(d) README missing Bedrock credit"
  fi

  if grep -qF "docs/installation.md" "$RM" || grep -qE '/plugin marketplace add' "$RM"; then
    pass "(d) README links to installation (docs or /plugin marketplace add)"
  else
    err "(d) README missing installation link"
  fi

  if grep -qF "docs/quickstart.md" "$RM"; then
    pass "(d) README links to quickstart"
  else
    err "(d) README missing docs/quickstart.md link"
  fi

  if grep -qF "docs/architecture.md" "$RM"; then
    pass "(d) README links to architecture"
  else
    err "(d) README missing docs/architecture.md link"
  fi
fi

# ---------------------------------------------------------------------
# (e) CHANGELOG has a semver heading matching the manifest version
# ---------------------------------------------------------------------
plugin_ver=$(python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json')).get('version',''))" 2>/dev/null || echo "")

if [ -z "$plugin_ver" ]; then
  err "(e) plugin.json version not readable"
elif grep -qE "^## \[${plugin_ver//./\\.}\][[:space:]]" CHANGELOG.md; then
  pass "(e) CHANGELOG has ## [$plugin_ver] heading matching manifest"
else
  err "(e) CHANGELOG missing ## [$plugin_ver] heading"
fi

harness::summary
