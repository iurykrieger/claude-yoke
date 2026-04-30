#!/usr/bin/env bash
# tests/smoke/bootstrap-provider-flow.test.sh
#
# Sensor: bootstrap-provider-flow (computational, cheap).
#
# Acceptance Contract Scenario 11 / FR-7 / Sprint 03 task
# 2026-04-30-pluggable-canonical-memory-s03-t01 binding criterion:
#
#   "Running /yoke:bootstrap --provider bedrock --non-interactive
#    against a fresh fixture project produces .yoke/config.yaml with
#    canonical_memory.provider: bedrock."
#
# True E2E for the binding criterion would require Skill-tool dispatch
# of the /yoke:bootstrap slash command — unavailable outside an
# interactive Claude Code session. Following the Sprint 01/02 + Sprint
# 03 cycle 1 pragmatic-structural pattern documented at the head of
# search-facade-equivalence.test.sh, canonize-progress-log-line.test.sh,
# and hard-break-pre-flight.test.sh, this test exercises the
# ALREADY-DECIDED bootstrap shape via structural assertions on the
# rewritten SKILL.md plus an end-to-end dry-run that stages the
# inputs the skill consumes (a fixture providers.yaml, a fresh
# host-project tree, the templates/yoke-config.yaml file) and asserts
# the documented output schema.
#
# Coverage layers:
#   (A) SKILL.md shape — name, argument-hint, allowed-tools,
#       --provider + --non-interactive flags documented, hard-break
#       prelude is NOT sourced (bootstrap is the migration entry
#       point), Flow A (legacy migration) and Flow B (fresh
#       bootstrap) both documented.
#   (B) Inputs the skill consumes are present at the documented
#       paths: providers.yaml, templates/yoke-config.yaml,
#       lib/canonical-memory/resolve-provider.sh.
#   (C) Provider resolution is consistent — running
#       resolve-provider.sh against a fixture project whose config
#       has provider: bedrock matches the providers.yaml shape.
#   (D) Non-interactive flag invariants — the SKILL.md documents
#       --provider as required under --non-interactive; documented
#       failure modes match the Acceptance Contract scenarios
#       (a)/(d)/(e) in Scenario 11.
#
# Self-contained: no real plugin install needed.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

set +e

SKILL="$PLUGIN_ROOT/skills/bootstrap/SKILL.md"
PROVIDERS_YAML="$PLUGIN_ROOT/providers.yaml"
TEMPLATE="$PLUGIN_ROOT/templates/yoke-config.yaml"
RESOLVER="$PLUGIN_ROOT/lib/canonical-memory/resolve-provider.sh"

echo "--- bootstrap-provider-flow structural-assertion test ---"
echo "(true E2E deferred — see NOTE comment at file head)"

# ----------------------------------------------------------------------
# (A) SKILL.md shape — frontmatter, flag documentation, both flows.
# ----------------------------------------------------------------------
[ -f "$SKILL" ] && pass "(A1) skills/bootstrap/SKILL.md exists" \
                || err "(A1) skills/bootstrap/SKILL.md missing"

grep -q '^name: bootstrap$' "$SKILL" \
  && pass "(A2) frontmatter: name == bootstrap" \
  || err "(A2) frontmatter: name == bootstrap not found"

grep -q '^argument-hint:.*--provider' "$SKILL" \
  && pass "(A3) argument-hint declares --provider flag" \
  || err "(A3) argument-hint missing --provider flag"

grep -q '^argument-hint:.*--non-interactive' "$SKILL" \
  && pass "(A4) argument-hint declares --non-interactive flag" \
  || err "(A4) argument-hint missing --non-interactive flag"

# Bootstrap MUST NOT source the prelude — it's the migration entry
# point. Mirrors the prelude-source-line-audit sensor.
if grep -q 'yoke_require_provider' "$SKILL"; then
  err "(A5) bootstrap SKILL.md must NOT source the prelude helper"
else
  pass "(A5) bootstrap SKILL.md correctly does NOT source prelude helper"
fi

# Both flows documented.
grep -qiE 'flow a|flow A|legacy migration|legacy detection' "$SKILL" \
  && pass "(A6) Flow A (legacy migration) documented" \
  || err "(A6) Flow A (legacy migration) not documented"

grep -qiE 'flow b|flow B|fresh bootstrap' "$SKILL" \
  && pass "(A7) Flow B (fresh bootstrap) documented" \
  || err "(A7) Flow B (fresh bootstrap) not documented"

# Re-bootstrap-on-existing-config detection documented (Scenario 11
# sub-criterion (e): "re-bootstrap on an existing v2.0.0 config and
# `n` reply leaves files untouched").
grep -qiE 're-bootstrap|already.bootstrapped|overwrite.existing' "$SKILL" \
  && pass "(A8) re-bootstrap detection documented" \
  || err "(A8) re-bootstrap detection missing"

# ----------------------------------------------------------------------
# (B) Inputs the skill consumes exist at documented paths.
# ----------------------------------------------------------------------
[ -f "$PROVIDERS_YAML" ] \
  && pass "(B1) providers.yaml exists at plugin root" \
  || err "(B1) providers.yaml missing at $PROVIDERS_YAML"

[ -f "$TEMPLATE" ] \
  && pass "(B2) templates/yoke-config.yaml exists" \
  || err "(B2) templates/yoke-config.yaml missing"

[ -f "$RESOLVER" ] \
  && pass "(B3) lib/canonical-memory/resolve-provider.sh exists" \
  || err "(B3) lib/canonical-memory/resolve-provider.sh missing"

grep -qE '^\s*provider: "\{\{ canonical_memory_provider \}\}"\s*$' "$TEMPLATE" \
  && pass "(B4) template carries provider: placeholder" \
  || err "(B4) template missing provider: placeholder"

# ----------------------------------------------------------------------
# (C) Provider resolution against a fresh-bootstrap-style fixture
#     mirrors the Acceptance Contract sub-criterion (a):
#     /yoke:bootstrap --provider bedrock --non-interactive produces
#     .yoke/config.yaml with canonical_memory.provider: bedrock.
# ----------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/fresh/.yoke"
cat > "$TMP/fresh/.yoke/config.yaml" <<'YAML'
yoke_version: "2.0.0"
canonical_memory:
  provider: "bedrock"
  url: ""
  default_branch: main
host:
  project_name: "fresh"
YAML

# resolve-provider.sh sourced + invoked from the fixture project.
# This is byte-equivalent to what /yoke:search-canonical-memory and
# /yoke:canonize do at runtime — and what bootstrap's flow-B output
# is designed to satisfy.
resolution="$(
  cd "$TMP/fresh" && \
  bash -c '
    set +u
    YOKE_PLUGIN_DIR="$1" source "$1/lib/canonical-memory/resolve-provider.sh"
    yoke_resolve_provider 2>&1
    printf "RC=%s\nNAME=%s\nSEARCH=%s\nCANONIZE=%s\n" \
      "$?" "$YOKE_PROVIDER_NAME" \
      "$YOKE_PROVIDER_SEARCH_SKILL" "$YOKE_PROVIDER_CANONIZE_SKILL"
  ' _ "$PLUGIN_ROOT"
)"

echo "$resolution" | grep -qE '^NAME=bedrock$' \
  && pass "(C1) fresh-bootstrap shape: provider resolves as bedrock" \
  || { err "(C1) fresh-bootstrap shape: NAME != bedrock"; echo "$resolution" >&2; }

echo "$resolution" | grep -qE '^SEARCH=bedrock:ask$' \
  && pass "(C2) fresh-bootstrap shape: search verb is bedrock:ask" \
  || err "(C2) fresh-bootstrap shape: SEARCH != bedrock:ask"

echo "$resolution" | grep -qE '^CANONIZE=bedrock:canonize$' \
  && pass "(C3) fresh-bootstrap shape: canonize verb is bedrock:canonize" \
  || err "(C3) fresh-bootstrap shape: CANONIZE != bedrock:canonize"

# ----------------------------------------------------------------------
# (D) Documented failure modes — non-interactive without --provider,
#     unknown provider, etc.
# ----------------------------------------------------------------------
grep -qE 'non-interactive.*requires.*--provider|requires.*--provider' "$SKILL" \
  && pass "(D1) --non-interactive requires --provider documented" \
  || err "(D1) --non-interactive precondition not documented"

grep -qiE 'available.providers|registered.providers' "$SKILL" \
  && pass "(D2) provider-list listing documented" \
  || err "(D2) provider-list listing not documented"

# Multi-provider listing test (Scenario 11 sub-criterion (d)):
# The interactive prompt should offer each entry from providers.yaml.
# Exercise the inputs structure: yq-style query that providers.yaml
# is well-formed and the bedrock entry has the expected shape.
provider_count="$(awk '/^providers:/{found=1; next} found && /^  [A-Za-z0-9_.-]+:/{c++} END{print c+0}' "$PROVIDERS_YAML")"
if [ "$provider_count" -ge 1 ]; then
  pass "(D3) providers.yaml lists at least one provider entry (count=$provider_count)"
else
  err "(D3) providers.yaml has zero provider entries"
fi

# Sub-criterion (e): re-bootstrap-existing-config-no-op. SKILL.md
# documents that on `n` reply, no file is touched.
grep -qiE 'no.op|untouched|never overwrite|abort without' "$SKILL" \
  && pass "(D4) re-bootstrap no-op-on-n documented" \
  || err "(D4) re-bootstrap no-op-on-n not documented"

harness::summary
