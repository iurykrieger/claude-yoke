#!/usr/bin/env bash
# tests/plugin-distribution.test.sh
#
# Verifies the plugin's distribution surface:
#   - .claude-plugin/plugin.json and .claude-plugin/marketplace.json
#     parse as JSON
#   - the version field in plugin.json equals
#     marketplace.json.metadata.version and marketplace.json.plugins[0].version
#   - the most recent ## [<version>] heading in CHANGELOG.md matches
#     the manifest version
#   - every structural directory listed in patterns/plugin-structure.md
#     exists at the repo root
#   - the canonical top-level files (README.md, LICENSE, CHANGELOG.md,
#     CLAUDE.md) exist
#
# This test asserts present-tense invariants only. Adding a directory
# to the framework's canonical layout requires an explicit edit to
# expected_dirs below — that is a deliberate signal, not a chore.

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

cd "$PLUGIN_ROOT"

# ---------------------------------------------------------------------
# (a) Manifests parse as JSON
# ---------------------------------------------------------------------
if python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))" >/dev/null 2>&1; then
  pass ".claude-plugin/plugin.json parses as JSON"
else
  err ".claude-plugin/plugin.json does not parse as JSON"
fi

if python3 -c "import json; json.load(open('.claude-plugin/marketplace.json'))" >/dev/null 2>&1; then
  pass ".claude-plugin/marketplace.json parses as JSON"
else
  err ".claude-plugin/marketplace.json does not parse as JSON"
fi

# ---------------------------------------------------------------------
# (b) Version cross-consistency between the two manifests
# ---------------------------------------------------------------------
plugin_ver=$(python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json')).get('version',''))" 2>/dev/null || echo "")
mp_meta_ver=$(python3 -c "import json; print(json.load(open('.claude-plugin/marketplace.json')).get('metadata',{}).get('version',''))" 2>/dev/null || echo "")
mp_plugin_ver=$(python3 -c "import json; print(json.load(open('.claude-plugin/marketplace.json')).get('plugins',[{}])[0].get('version',''))" 2>/dev/null || echo "")

if [ -z "$plugin_ver" ]; then
  err "plugin.json missing 'version' field"
elif [ "$plugin_ver" = "$mp_meta_ver" ] && [ "$plugin_ver" = "$mp_plugin_ver" ]; then
  pass "manifest versions cross-match (plugin=$plugin_ver, marketplace.metadata=$mp_meta_ver, marketplace.plugins[0]=$mp_plugin_ver)"
else
  err "manifest versions differ: plugin=$plugin_ver marketplace.metadata=$mp_meta_ver marketplace.plugins[0]=$mp_plugin_ver"
fi

# ---------------------------------------------------------------------
# (c) CHANGELOG most-recent ## [<semver>] heading matches the manifest.
# Keep-a-Changelog's [Unreleased] section is skipped; only released
# version headings (X.Y.Z) participate in the cross-check.
# ---------------------------------------------------------------------
changelog_ver=$(awk '
  /^## \[[0-9]+\.[0-9]+\.[0-9]+/ {
    match($0, /\[[0-9]+\.[0-9]+\.[0-9]+[^]]*\]/)
    print substr($0, RSTART+1, RLENGTH-2)
    exit
  }
' CHANGELOG.md 2>/dev/null || echo "")

if [ -z "$changelog_ver" ]; then
  err "CHANGELOG.md has no released '## [<semver>]' heading"
elif [ "$changelog_ver" = "$plugin_ver" ]; then
  pass "CHANGELOG.md most-recent released heading matches manifest ($changelog_ver)"
else
  err "CHANGELOG.md most-recent released heading is [$changelog_ver] but manifest is $plugin_ver"
fi

# ---------------------------------------------------------------------
# (d) Structural directories listed in patterns/plugin-structure.md
# ---------------------------------------------------------------------
expected_dirs=(
  .claude-plugin
  skills
  agents
  hooks
  templates
  lib
  lib/canonical-memory
  lib/ralph-loop
  lib/sensors
  docs
  tests
)

for d in "${expected_dirs[@]}"; do
  if [ -d "$d" ]; then
    pass "directory $d/ exists"
  else
    err "directory $d/ missing"
  fi
done

# ---------------------------------------------------------------------
# (e) Canonical top-level files
# ---------------------------------------------------------------------
for f in README.md LICENSE CHANGELOG.md CLAUDE.md; do
  if [ -f "$f" ]; then
    pass "top-level $f exists"
  else
    err "top-level $f missing"
  fi
done

harness::summary
