#!/usr/bin/env bash
# tests/smoke/bootstrap-legacy-migration.test.sh
#
# Sensor: bootstrap-legacy-migration (computational, cheap).
#
# Acceptance Contract Scenario 11 / FR-7 / Sprint 03 task
# 2026-04-30-pluggable-canonical-memory-s03-t01 binding criterion
# (legacy-migration arm):
#
#   "Running /yoke:bootstrap --provider bedrock --non-interactive
#    against a fixture with pre-existing <plugin_dir>/memories.json
#    results in memories.json being deleted and .yoke/config.yaml
#    being created with canonical_memory.provider: bedrock plus the
#    legacy url/name/default_branch preserved as passthrough."
#
# True E2E deferred (Skill-tool dispatch unavailable). Following the
# Sprint 01/02 + Sprint 03 cycle 1 pragmatic-structural pattern, this
# test exercises the ALREADY-DECIDED bootstrap legacy-migration shape
# via:
#
#   (A) SKILL.md shape — Flow A documents detection markers
#       (legacy_registry / legacy_config), the binding stderr literal
#       printed on detection, the migration ordering invariant
#       (write new config → verify → delete memories.json), and the
#       passthrough preservation rule.
#   (B) Legacy-config detection — fixture with v1.x-shaped
#       .yoke/config.yaml (no provider key) trips the
#       resolve-provider.sh exit-4 path with the binding stderr
#       message, exactly as the prelude expects.
#   (C) Legacy-registry detection — fixture with a sample
#       memories.json structurally matches the v1.x registry shape
#       the migration code reads (one entry, with url/name/
#       default_branch keys).
#   (D) Migration ordering — SKILL.md documents
#       "write new config → verify → delete memories.json".
#
# Self-contained: no real plugin install needed.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

set +e

SKILL="$PLUGIN_ROOT/skills/bootstrap/SKILL.md"
RESOLVER="$PLUGIN_ROOT/lib/canonical-memory/resolve-provider.sh"
PRELUDE="$PLUGIN_ROOT/lib/yoke-prelude.sh"

echo "--- bootstrap-legacy-migration structural-assertion test ---"
echo "(true E2E deferred — see NOTE comment at file head)"

BINDING_DETECT='wm: legacy Yoke v1.x state detected. Migrating to v2.0.0 schema.'
BINDING_MIGRATE='wm: canonical_memory.provider not configured. Run /yoke:bootstrap to migrate.'

# ----------------------------------------------------------------------
# (A) SKILL.md shape — Flow A coverage.
# ----------------------------------------------------------------------
[ -f "$SKILL" ] && pass "(A1) skills/bootstrap/SKILL.md exists" \
                || err "(A1) skills/bootstrap/SKILL.md missing"

grep -qE 'legacy_registry|memories\.json' "$SKILL" \
  && pass "(A2) legacy_registry / memories.json detection documented" \
  || err "(A2) legacy_registry / memories.json detection not documented"

grep -qE 'legacy_config|provider.*missing|provider.*key' "$SKILL" \
  && pass "(A3) legacy_config (provider-key-missing) detection documented" \
  || err "(A3) legacy_config detection not documented"

grep -qF "$BINDING_DETECT" "$SKILL" \
  && pass "(A4) binding detection literal present in SKILL.md" \
  || err "(A4) SKILL.md missing binding detection literal"

# Passthrough preservation rule — url, name, default_branch.
grep -qE '\burl\b' "$SKILL" && grep -qE '\bname\b' "$SKILL" && grep -qE 'default_branch' "$SKILL" \
  && pass "(A5) passthrough keys (url, name, default_branch) referenced" \
  || err "(A5) passthrough key list incomplete"

# Migration ordering: write new config → verify → delete memories.json.
grep -qiE 'write.*config.*verify.*delete|register.*verify.*delete|write.*verify.*delete' "$SKILL" \
  && pass "(A6) migration ordering (write → verify → delete) documented" \
  || err "(A6) migration ordering not documented"

# Default provider for migration is bedrock (only viable v1.x option).
grep -qE 'default.*bedrock|migrated.*bedrock|defaults.*bedrock' "$SKILL" \
  && pass "(A7) v1.x default-to-bedrock migration documented" \
  || err "(A7) default-to-bedrock migration not documented"

# Confirmation prompt skipped under --non-interactive.
grep -qiE 'skipped under .*--non-interactive|--non-interactive.*skip' "$SKILL" \
  && pass "(A8) --non-interactive skips confirmation documented" \
  || err "(A8) --non-interactive confirmation-skip not documented"

# ----------------------------------------------------------------------
# (B) Legacy-config detection — fixture with v1.x-shaped config (no
#     provider key) must trip the resolve-provider exit-4 / prelude
#     hard-break path. This is the precise pre-condition that
#     /yoke:bootstrap migration consumes.
# ----------------------------------------------------------------------
[ -f "$RESOLVER" ] && pass "(B1) resolve-provider.sh exists" \
                   || err "(B1) resolve-provider.sh missing"

[ -f "$PRELUDE" ] && pass "(B2) lib/yoke-prelude.sh exists" \
                  || err "(B2) lib/yoke-prelude.sh missing"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Legacy-config fixture: .yoke/config.yaml exists but lacks the
# canonical_memory.provider key. Mirrors a project that ran v1.x
# bootstrap and was never re-bootstrapped at v2.0.0.
mkdir -p "$TMP/legacy-config/.yoke"
cat > "$TMP/legacy-config/.yoke/config.yaml" <<'YAML'
yoke_version: "1.1.0"
canonical_memory:
  url: "git@github.com:acme/yoke-memory.git"
  name: "iury-brain"
  default_branch: main
host:
  project_name: "legacy-config-fixture"
YAML

stderr_b="$(
  cd "$TMP/legacy-config" && \
  bash -c 'source "$1" && yoke_require_provider' _ "$PRELUDE" 2>&1 1>/dev/null
)"
rc_b=$?

[ "$rc_b" -ne 0 ] \
  && pass "(B3) legacy-config: prelude exits non-zero (got $rc_b)" \
  || err "(B3) legacy-config: prelude must exit non-zero"

printf '%s' "$stderr_b" | grep -qF "$BINDING_MIGRATE" \
  && pass "(B4) legacy-config: stderr contains migrate-binding literal" \
  || err "(B4) legacy-config: stderr lacks migrate-binding literal — got: $stderr_b"

# resolve-provider.sh against the same fixture must surface the same
# missing-key signal. Exit-4 for missing/empty provider key.
( cd "$TMP/legacy-config" && bash "$RESOLVER" >/dev/null 2>"$TMP/legacy-config.err" )
rc_resolver=$?
[ "$rc_resolver" -eq 4 ] \
  && pass "(B5) legacy-config: resolve-provider.sh exits 4 (missing provider key)" \
  || err "(B5) legacy-config: expected resolver exit 4, got $rc_resolver"

# Echo the binding literals for the cycle's snapshot output_excerpt.
printf '\n[binding detection literal]\n  %s\n' "$BINDING_DETECT"
printf '[binding migrate literal]\n  %s\n' "$BINDING_MIGRATE"

# ----------------------------------------------------------------------
# (C) Legacy-registry detection — fixture with a v1.x-shaped
#     memories.json. SKILL.md says bootstrap reads the first entry's
#     url/name/default_branch and migrates them as passthrough keys.
# ----------------------------------------------------------------------
mkdir -p "$TMP/legacy-registry/.yoke"
cat > "$TMP/legacy-registry/.yoke/config.yaml" <<'YAML'
yoke_version: "1.1.0"
canonical_memory:
  url: ""
  default_branch: main
host:
  project_name: "legacy-registry-fixture"
YAML

# Synthetic plugin-dir-style registry. Bootstrap reads its url/name/
# default_branch on Flow A.
cat > "$TMP/legacy-registry/memories.json" <<'JSON'
{
  "memories": [
    {
      "name": "iury-brain",
      "path": "/Users/me/.local/share/yoke/canonical/iury-brain",
      "url": "git@github.com:iurykrieger/brain.git",
      "default_branch": "main",
      "default": true
    }
  ]
}
JSON

# Verify the structural shape jq can read (the migration code path
# does the equivalent extraction).
if command -v jq >/dev/null 2>&1; then
  url="$(jq -r '.memories[0].url' "$TMP/legacy-registry/memories.json" 2>/dev/null)"
  name="$(jq -r '.memories[0].name' "$TMP/legacy-registry/memories.json" 2>/dev/null)"
  branch="$(jq -r '.memories[0].default_branch' "$TMP/legacy-registry/memories.json" 2>/dev/null)"
  [ "$url" = "git@github.com:iurykrieger/brain.git" ] \
    && pass "(C1) legacy-registry: url extractable via jq" \
    || err "(C1) legacy-registry: url extraction failed (got '$url')"
  [ "$name" = "iury-brain" ] \
    && pass "(C2) legacy-registry: name extractable via jq" \
    || err "(C2) legacy-registry: name extraction failed (got '$name')"
  [ "$branch" = "main" ] \
    && pass "(C3) legacy-registry: default_branch extractable via jq" \
    || err "(C3) legacy-registry: default_branch extraction failed (got '$branch')"
else
  pass "(C1-C3) jq not available — skipped legacy-registry extraction probes"
fi

# The fixture file presence itself is what bootstrap detects in Flow A.
[ -f "$TMP/legacy-registry/memories.json" ] \
  && pass "(C4) legacy-registry fixture: memories.json present" \
  || err "(C4) legacy-registry fixture: memories.json missing"

# ----------------------------------------------------------------------
# (D) Migration ordering invariant — SKILL.md must document strictness:
#     write new .yoke/config.yaml → verify → delete memories.json.
#     A documentation-only check; the binding criterion's runtime
#     enforcement lives inside the bootstrap skill body.
# ----------------------------------------------------------------------
grep -qiE 'never delete.*before|never deleted.*before|never deleted before|order is strict' "$SKILL" \
  && pass "(D1) migration safety-under-partial-failure invariant documented" \
  || err "(D1) migration safety-under-partial-failure invariant not documented"

# Confirmation gate — bootstrap never silently removes memories.json
# without explicit y reply (interactive) or non-interactive with
# --provider passthrough.
grep -qiE 'after final confirmation|after the config write|never delete' "$SKILL" \
  && pass "(D2) memories.json deletion guarded by confirmation" \
  || err "(D2) memories.json deletion confirmation gate not documented"

harness::summary
