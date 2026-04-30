#!/usr/bin/env bash
# tests/canonical-memory/resolve-provider.test.sh
#
# Exercises lib/canonical-memory/resolve-provider.sh against four
# scenarios drawn from Acceptance Contract Scenario 2 / Sprint 01 task
# 2026-04-30-pluggable-canonical-memory-s01-t02:
#
#   (1) Happy path — fixture project with `canonical_memory.provider: bedrock`
#       → exit 0, exported vars match the plugin root's providers.yaml.
#       Post-Sprint-02 providers.yaml repoint:
#         YOKE_PROVIDER_NAME == "bedrock",
#         YOKE_PROVIDER_SEARCH_SKILL == "bedrock:ask",
#         YOKE_PROVIDER_CANONIZE_SKILL == "bedrock:canonize".
#       Pre-Sprint-02 (legacy seed): yoke:ask / yoke:teach. Both shapes
#       are accepted by the providers-yaml-shape sensor regex (which
#       allows either branch); this test pins to whichever providers.yaml
#       actually declares so it stays green across the migration boundary.
#   (2) Missing config — no .yoke/config.yaml → exit 3.
#   (3) Missing provider key — config without `canonical_memory.provider`
#       → exit 4.
#   (4) Unknown provider name — config with a provider name absent from
#       providers.yaml → exit 5.
#
# Sensor: resolve-provider-callable (computational, cheap).
#
# Self-contained: no dependency on the developer's iury-brain vault, no
# network calls, no real provider plugin. The plugin root's providers.yaml
# (which the resolver locates via $BASH_SOURCE relative to its own
# location) is the only "fixture" the resolver actually reads on the
# canonical-registry side; the four cases above are exercised by varying
# the host project's .yoke/config.yaml.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

# Disable errexit for this script — the test deliberately captures
# non-zero exit codes from the resolver to assert exit-code semantics.
# pipefail and nounset stay on.
set +e

# The resolver under test, sourced as a function (per its sourceable
# usage contract). Run all assertions inside subshells so each case
# starts from a clean exported-variable state.
RESOLVER="$PLUGIN_ROOT/lib/canonical-memory/resolve-provider.sh"
[ -f "$RESOLVER" ] || { err "resolver missing at $RESOLVER"; harness::summary; }

PROVIDERS_YAML="$PLUGIN_ROOT/providers.yaml"
[ -f "$PROVIDERS_YAML" ] || { err "providers.yaml missing at $PROVIDERS_YAML"; harness::summary; }

# Real fixture for the happy path: tests/fixtures/resolve-provider/ ships
# a .yoke/config.yaml with `canonical_memory.provider: bedrock`. The
# resolver locates the providers.yaml via its own $BASH_SOURCE, so the
# fixture project does NOT need to carry one — it only carries the
# .yoke/config.yaml the resolver reads relative to $PWD.
FIXTURE_HAPPY="$PLUGIN_ROOT/tests/fixtures/resolve-provider"
[ -f "$FIXTURE_HAPPY/.yoke/config.yaml" ] || {
  err "fixture missing at $FIXTURE_HAPPY/.yoke/config.yaml"
  harness::summary
}

# Tmp scratch for cases (2)–(4); cleaned up on exit.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ----------------------------------------------------------------------
# (1) Happy path — fixture project with `provider: bedrock`.
# ----------------------------------------------------------------------
# Exec the resolver as a subprocess so $PWD targeting works without
# polluting the harness's own environment. The `cd` into the fixture
# directory mirrors a real /yoke:* skill's pre-flight (which sources
# the resolver after cd-ing to the host project root).
out_happy="$(
  cd "$FIXTURE_HAPPY" && \
  bash -c '
    set -uo pipefail
    source "$1" || exit $?
    yoke_resolve_provider || exit $?
    printf "name=%s\nsearch=%s\ncanonize=%s\n" \
      "$YOKE_PROVIDER_NAME" \
      "$YOKE_PROVIDER_SEARCH_SKILL" \
      "$YOKE_PROVIDER_CANONIZE_SKILL"
  ' _ "$RESOLVER"
)"
rc_happy=$?

[ "$rc_happy" -eq 0 ] && pass "(1) happy path: exit 0" || err "(1) happy path: expected exit 0, got $rc_happy"
printf '%s\n' "$out_happy" | grep -qx 'name=bedrock' && pass "(1) YOKE_PROVIDER_NAME == bedrock" || err "(1) YOKE_PROVIDER_NAME wrong (got: $(printf '%s' "$out_happy" | grep '^name='))"

# Accept either the pre-Sprint-02 seed values (yoke:ask / yoke:teach) or
# the post-Sprint-02 repointed values (bedrock:ask / bedrock:canonize).
# Whichever shape providers.yaml declares is the truth; the resolver
# returns it verbatim. The providers-yaml-shape sensor regex accepts
# both branches symmetrically.
printf '%s\n' "$out_happy" | grep -qxE 'search=(yoke:ask|bedrock:ask)' \
  && pass "(1) YOKE_PROVIDER_SEARCH_SKILL == $(printf '%s' "$out_happy" | grep '^search=' | cut -d= -f2)" \
  || err "(1) YOKE_PROVIDER_SEARCH_SKILL wrong (got: $(printf '%s' "$out_happy" | grep '^search='))"
printf '%s\n' "$out_happy" | grep -qxE 'canonize=(yoke:teach|bedrock:canonize)' \
  && pass "(1) YOKE_PROVIDER_CANONIZE_SKILL == $(printf '%s' "$out_happy" | grep '^canonize=' | cut -d= -f2)" \
  || err "(1) YOKE_PROVIDER_CANONIZE_SKILL wrong (got: $(printf '%s' "$out_happy" | grep '^canonize='))"

# ----------------------------------------------------------------------
# (2) Missing config — no .yoke/config.yaml in $PWD → exit 3.
# ----------------------------------------------------------------------
mkdir -p "$TMP/missing-config"
( cd "$TMP/missing-config" && \
  bash -c 'source "$1"; yoke_resolve_provider' _ "$RESOLVER" >/dev/null 2>&1 )
rc_missing_config=$?
[ "$rc_missing_config" -eq 3 ] && pass "(2) missing config: exit 3" || err "(2) missing config: expected exit 3, got $rc_missing_config"

# ----------------------------------------------------------------------
# (3) Missing provider key — config exists but lacks
# `canonical_memory.provider` → exit 4.
# ----------------------------------------------------------------------
mkdir -p "$TMP/missing-provider/.yoke"
cat > "$TMP/missing-provider/.yoke/config.yaml" <<'YAML'
yoke_version: "2.0.0-test"
canonical_memory:
  url: ""
  name: "no-provider-key"
  default_branch: main
host:
  project_name: "missing-provider-fixture"
YAML
( cd "$TMP/missing-provider" && \
  bash -c 'source "$1"; yoke_resolve_provider' _ "$RESOLVER" >/dev/null 2>&1 )
rc_missing_provider=$?
[ "$rc_missing_provider" -eq 4 ] && pass "(3) missing provider key: exit 4" || err "(3) missing provider key: expected exit 4, got $rc_missing_provider"

# ----------------------------------------------------------------------
# (4) Unknown provider name — config has a provider name absent from
# providers.yaml → exit 5.
# ----------------------------------------------------------------------
mkdir -p "$TMP/unknown-provider/.yoke"
cat > "$TMP/unknown-provider/.yoke/config.yaml" <<'YAML'
yoke_version: "2.0.0-test"
canonical_memory:
  provider: "no-such-provider-xyz"
  url: ""
  name: "unknown-provider"
  default_branch: main
host:
  project_name: "unknown-provider-fixture"
YAML
( cd "$TMP/unknown-provider" && \
  bash -c 'source "$1"; yoke_resolve_provider' _ "$RESOLVER" >/dev/null 2>&1 )
rc_unknown=$?
[ "$rc_unknown" -eq 5 ] && pass "(4) unknown provider: exit 5" || err "(4) unknown provider: expected exit 5, got $rc_unknown"

harness::summary
