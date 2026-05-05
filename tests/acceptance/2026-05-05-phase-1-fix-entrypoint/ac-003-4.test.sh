#!/usr/bin/env bash
# criterion: AC-003-4
#
# AC-003-4 (binding text from
# .yoke/acceptance-criteria/2026-05-05-phase-1-fix-entrypoint.md):
#
#   "The plugin manifest at .claude-plugin/plugin.json declares the
#    new skill and its version is bumped per Yoke's 'each sprint
#    produces an installable plugin version' decision; the manifest
#    passes schema validation in CI."
#
# Cross-cutting FR-4 (binding):
#
#   "The plugin manifest version bump is at least **major** (the
#    wm_phase1_artifact_path migration changes the helper layer's
#    contract for every downstream skill)."
#
# Architectural interpretation (per Sr Staff HQ2 cycle 4):
#
#   Claude Code plugins do NOT carry per-skill-verb listings inside
#   plugin.json. Skill registration happens via the filesystem layout
#   `skills/<skill-name>/SKILL.md` per `concepts/yoke-pattern-plugin-
#   structure`. "declares the new skill" is therefore observable as:
#
#     (a) `skills/fix/SKILL.md` exists on disk (the canonical
#         registration surface for /yoke:fix in Claude Code's plugin
#         runtime).
#     (b) plugin.json carries a discoverable mention of /yoke:fix in
#         its description so that marketplace consumers / catalog
#         walkers see the new surface (this is the user-facing
#         registration signal — the description is the only manifest
#         field that conveys per-skill-verb intent in Yoke's schema).
#     (c) plugin.json's version is at least 5.x (FR-4 mandates the
#         bump be at least major; Sprint 03 boundary held 4.0.0, so
#         a major bump lands at 5.0.0 minimum).
#     (d) marketplace.json mirrors the version + description per the
#         existing manifest cross-consistency invariant from
#         tests/plugin-distribution.test.sh.
#     (e) CHANGELOG.md's most-recent released `## [<semver>]` heading
#         matches plugin.json's version (Keep-a-Changelog discipline
#         per the existing tests/plugin-distribution.test.sh).
#     (f) Both manifests parse as valid JSON (the "passes schema
#         validation in CI" half — CI's prep job today only enforces
#         json.load parseability, not a JSON Schema).
#
# Observable conditions tested (one case per binding bullet above):
#
#   (1) skills/fix/SKILL.md exists (filesystem registration surface).
#   (2) plugin.json's description mentions /yoke:fix.
#   (3) plugin.json's version satisfies the major-bump invariant
#       (>= 5.0.0; integer-major comparison).
#   (4) marketplace.json's version mirrors plugin.json's (fail-closed
#       cross-consistency).
#   (5) marketplace.json's plugin description mentions /yoke:fix.
#   (6) CHANGELOG.md's most-recent released heading matches the
#       manifest version.
#   (7) Both .claude-plugin/*.json files parse as valid JSON.

set -euo pipefail

# Internal watchdog (per repo testing convention).
( sleep 600 && kill -TERM $$ ) &
_WATCHDOG_PID=$!
trap 'kill "$_WATCHDOG_PID" 2>/dev/null || true' EXIT

# Resolve repo root from the location of this file:
#   tests/acceptance/<slug>/ac-003-4.test.sh -> ../../..
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=/dev/null
source "$REPO_ROOT/tests/lib/harness.sh"

PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"
MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"
FIX_SKILL="$REPO_ROOT/skills/fix/SKILL.md"

# ---------------------------------------------------------------------------
# Case (1) — skills/fix/SKILL.md exists on disk.
#
# Claude Code's plugin runtime auto-discovers skills via
# `skills/*/SKILL.md` filesystem layout. The presence of this file IS
# the canonical "declared" signal — there is no per-skill-verb listing
# inside plugin.json.
# ---------------------------------------------------------------------------
if [[ -f "$FIX_SKILL" ]]; then
  pass "(1) skills/fix/SKILL.md exists (filesystem registration surface for /yoke:fix)"
else
  err "(1) skills/fix/SKILL.md does NOT exist — /yoke:fix is not registered with the plugin runtime"
  harness::summary
fi

# ---------------------------------------------------------------------------
# Case (2) — plugin.json's description mentions /yoke:fix.
#
# Yoke's plugin.json schema (verified by Sr Staff cycle 4 architectural
# read) carries no per-skill-verb listing. The description string is the
# only manifest field that conveys per-skill-verb intent to marketplace
# consumers. AC-003-4's "declares the new skill" gate is satisfied at
# the manifest layer when description mentions /yoke:fix.
# ---------------------------------------------------------------------------
if [[ ! -f "$PLUGIN_JSON" ]]; then
  err "(2) .claude-plugin/plugin.json missing"
  harness::summary
fi

PLUGIN_DESC="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('description',''))" "$PLUGIN_JSON" 2>/dev/null || echo "")"

if [[ "$PLUGIN_DESC" == *"/yoke:fix"* ]]; then
  pass "(2) plugin.json description mentions /yoke:fix (declares the new skill at the manifest layer)"
else
  err "(2) plugin.json description does NOT mention /yoke:fix — manifest does not declare the new skill"
fi

# ---------------------------------------------------------------------------
# Case (3) — plugin.json version satisfies the major-bump invariant.
#
# FR-4 binds the bump to "at least major". Sprint 03's boundary held
# 4.0.0; a major bump lands at >= 5.0.0. We compare the integer major
# component to fail-closed against any future regression that drops
# below 5.x.
# ---------------------------------------------------------------------------
PLUGIN_VER="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('version',''))" "$PLUGIN_JSON" 2>/dev/null || echo "")"

if [[ -z "$PLUGIN_VER" ]]; then
  err "(3) plugin.json missing 'version' field"
elif [[ ! "$PLUGIN_VER" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
  err "(3) plugin.json version '$PLUGIN_VER' does not parse as semver MAJOR.MINOR.PATCH"
else
  PLUGIN_MAJOR="${BASH_REMATCH[1]}"
  if (( PLUGIN_MAJOR >= 5 )); then
    pass "(3) plugin.json version '$PLUGIN_VER' satisfies FR-4 major-bump invariant (major >= 5; was 4.x at sprint-03 boundary)"
  else
    err "(3) plugin.json version '$PLUGIN_VER' fails FR-4: major component $PLUGIN_MAJOR < 5 (sprint-03 boundary held 4.0.0; FR-4 requires at least major)"
  fi
fi

# ---------------------------------------------------------------------------
# Case (4) — marketplace.json mirrors plugin.json's version (cross-consistency).
#
# tests/plugin-distribution.test.sh enforces this invariant for the
# repo's general plugin-distribution surface. Pin it here so an
# AC-003-4 verdict cannot mask a half-applied bump where one manifest
# moved and the other did not.
# ---------------------------------------------------------------------------
if [[ ! -f "$MARKETPLACE_JSON" ]]; then
  err "(4) .claude-plugin/marketplace.json missing"
else
  MP_META_VER="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('metadata',{}).get('version',''))" "$MARKETPLACE_JSON" 2>/dev/null || echo "")"
  MP_PLUGIN_VER="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('plugins',[{}])[0].get('version',''))" "$MARKETPLACE_JSON" 2>/dev/null || echo "")"

  if [[ "$PLUGIN_VER" == "$MP_META_VER" && "$PLUGIN_VER" == "$MP_PLUGIN_VER" ]]; then
    pass "(4) marketplace.json version mirrors plugin.json (plugin=$PLUGIN_VER, marketplace.metadata=$MP_META_VER, marketplace.plugins[0]=$MP_PLUGIN_VER)"
  else
    err "(4) manifest versions diverge — plugin=$PLUGIN_VER marketplace.metadata=$MP_META_VER marketplace.plugins[0]=$MP_PLUGIN_VER"
  fi
fi

# ---------------------------------------------------------------------------
# Case (5) — marketplace.json's plugin description mentions /yoke:fix.
#
# Same logic as case (2) at the marketplace.json layer: the plugins[0]
# entry's description is the marketplace-listing surface a Claude Code
# user sees when discovering plugins. /yoke:fix must be visible there.
# ---------------------------------------------------------------------------
if [[ -f "$MARKETPLACE_JSON" ]]; then
  MP_PLUGIN_DESC="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('plugins',[{}])[0].get('description',''))" "$MARKETPLACE_JSON" 2>/dev/null || echo "")"
  if [[ "$MP_PLUGIN_DESC" == *"/yoke:fix"* ]]; then
    pass "(5) marketplace.json plugins[0].description mentions /yoke:fix (marketplace-listing surface)"
  else
    err "(5) marketplace.json plugins[0].description does NOT mention /yoke:fix"
  fi
fi

# ---------------------------------------------------------------------------
# Case (6) — CHANGELOG.md most-recent released heading matches plugin.json.
#
# Keep-a-Changelog discipline: the most-recent `## [<semver>]` heading
# must equal plugin.json's version (skipping `[Unreleased]`). Reuses
# the awk recipe from tests/plugin-distribution.test.sh so any future
# tightening of that recipe propagates here.
# ---------------------------------------------------------------------------
if [[ ! -f "$CHANGELOG" ]]; then
  err "(6) CHANGELOG.md missing"
else
  CHANGELOG_VER="$(awk '
    /^## \[[0-9]+\.[0-9]+\.[0-9]+/ {
      match($0, /\[[0-9]+\.[0-9]+\.[0-9]+[^]]*\]/)
      print substr($0, RSTART+1, RLENGTH-2)
      exit
    }
  ' "$CHANGELOG" 2>/dev/null || echo "")"

  if [[ -z "$CHANGELOG_VER" ]]; then
    err "(6) CHANGELOG.md has no released '## [<semver>]' heading"
  elif [[ "$CHANGELOG_VER" == "$PLUGIN_VER" ]]; then
    pass "(6) CHANGELOG.md most-recent released heading matches plugin.json ($CHANGELOG_VER)"
  else
    err "(6) CHANGELOG.md most-recent released heading is [$CHANGELOG_VER] but plugin.json is $PLUGIN_VER"
  fi
fi

# ---------------------------------------------------------------------------
# Case (7) — both .claude-plugin/*.json files parse as JSON.
#
# AC-003-4's "passes schema validation in CI" half. The CI prep job
# today enforces json.load parseability (no JSON Schema yet); we mirror
# that exact check so the AC verdict matches the CI gate's behavior.
# ---------------------------------------------------------------------------
if python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))" >/dev/null 2>&1; then
  P1=0
else
  P1=1
fi

if python3 -c "import json; json.load(open('.claude-plugin/marketplace.json'))" >/dev/null 2>&1; then
  P2=0
else
  P2=1
fi

if (( P1 == 0 && P2 == 0 )); then
  pass "(7) both .claude-plugin/{plugin,marketplace}.json parse as JSON (mirrors CI prep schema validation)"
else
  err "(7) JSON parse failure: plugin.json rc=$P1 marketplace.json rc=$P2"
fi

harness::summary
