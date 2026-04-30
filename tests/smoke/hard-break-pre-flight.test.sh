#!/usr/bin/env bash
# tests/smoke/hard-break-pre-flight.test.sh
#
# Sensor: hard-break-pre-flight-enforced (computational, cheap).
#
# Acceptance Contract Scenario 12 / FR-6 / Sprint 03 task
# 2026-04-30-pluggable-canonical-memory-s03-t02 binding criterion:
#
#   "Running /yoke:search-canonical-memory \"test\" against a fixture
#    project whose .yoke/config.yaml lacks canonical_memory.provider
#    exits non-zero with stderr containing the literal string
#    `wm: canonical_memory.provider not configured. Run /yoke:bootstrap
#     to migrate.`"
#
# True E2E for the binding criterion would require Skill-tool dispatch
# (the /yoke:search-canonical-memory facade is a Skill, not an
# executable). Following the Sprint 01/02 pragmatic-structural pattern
# documented at the head of search-facade-equivalence.test.sh and
# canonize-progress-log-line.test.sh, this test exercises the ALREADY-
# DECIDED dispatch chain by sourcing lib/yoke-prelude.sh directly
# (which is exactly what every eligible skill's pre-flight does) and
# asserts the documented exit code + stderr message.
#
# Coverage:
#   (A) Hard break — fixture project missing canonical_memory.provider
#       → exit 1 + literal stderr.
#   (B) Pass-through — fixture project with canonical_memory.provider:
#       bedrock → exit 0 (the prelude does NOT enforce that the
#       provider name resolves; that's resolve-provider.sh's job). The
#       happy path of the hard break is "stop blocking".
#
# Self-contained: no real plugin install needed. The prelude is a pure
# filesystem read; sourcing it here is byte-equivalent to a skill
# pre-flight sourcing it.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

set +e

PRELUDE="$PLUGIN_ROOT/lib/yoke-prelude.sh"
[ -f "$PRELUDE" ] || { err "prelude missing at $PRELUDE"; harness::summary; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BINDING_MESSAGE='wm: canonical_memory.provider not configured. Run /yoke:bootstrap to migrate.'

# ----------------------------------------------------------------------
# (A) Hard-break path — fixture project's .yoke/config.yaml lacks
# canonical_memory.provider. Mirrors the unmigrated v1.x case the
# v2.0.0 hard break exists to refuse.
# ----------------------------------------------------------------------
mkdir -p "$TMP/unmigrated/.yoke"
cat > "$TMP/unmigrated/.yoke/config.yaml" <<'YAML'
yoke_version: "1.1.0"
canonical_memory:
  url: ""
  name: "iury-brain"
  default_branch: main
host:
  project_name: "unmigrated"
YAML

stderr_a="$(
  cd "$TMP/unmigrated" && \
  bash -c 'source "$1" && yoke_require_provider' _ "$PRELUDE" 2>&1 1>/dev/null
)"
rc_a=$?

[ "$rc_a" -ne 0 ] \
  && pass "(A) hard break: exit non-zero (got $rc_a)" \
  || err "(A) hard break: expected non-zero exit, got 0"

printf '%s' "$stderr_a" | grep -qF "$BINDING_MESSAGE" \
  && pass "(A) hard break: stderr contains the binding literal" \
  || err "(A) hard break: stderr lacks binding literal — got: $stderr_a"

# Echo of the binding criterion's literal expectation, surfaced for
# whoever reads the cycle's snapshot output_excerpt.
printf '\n[binding criterion echoed]\n  %s\n' "$BINDING_MESSAGE"

# ----------------------------------------------------------------------
# (B) Pass-through path — same skill harness against a fixture that
# DID migrate. The pre-flight gate releases; downstream resolution
# (which the prelude doesn't do — that's resolve-provider.sh) is out of
# scope for this sensor.
# ----------------------------------------------------------------------
mkdir -p "$TMP/migrated/.yoke"
cat > "$TMP/migrated/.yoke/config.yaml" <<'YAML'
yoke_version: "2.0.0"
canonical_memory:
  provider: "bedrock"
  url: ""
  name: "iury-brain"
  default_branch: main
host:
  project_name: "migrated"
YAML

stderr_b="$(
  cd "$TMP/migrated" && \
  bash -c 'source "$1" && yoke_require_provider' _ "$PRELUDE" 2>&1 1>/dev/null
)"
rc_b=$?
[ "$rc_b" -eq 0 ] \
  && pass "(B) pass-through: exit 0 after migration" \
  || err "(B) pass-through: expected exit 0, got $rc_b — stderr: $stderr_b"
[ -z "$stderr_b" ] \
  && pass "(B) pass-through: stderr is silent on success" \
  || err "(B) pass-through: expected silent stderr, got: $stderr_b"

# ----------------------------------------------------------------------
# (C) Audit assertion — every eligible skill's SKILL.md sources
# lib/yoke-prelude.sh AND calls yoke_require_provider in its
# pre-flight. Mirrors the prelude-source-line-audit sensor; failing
# this here surfaces the audit gap inside the smoke test instead of
# as a separate sensor red flag.
# ----------------------------------------------------------------------
ELIGIBLE=(discover tech-spec acceptance-contract implement search-canonical-memory canonize drift-sense status ack-sensors)
for s in "${ELIGIBLE[@]}"; do
  skill="$PLUGIN_ROOT/skills/$s/SKILL.md"
  if [ ! -f "$skill" ]; then
    err "(C) audit: skills/$s/SKILL.md missing"
    continue
  fi
  if grep -q 'yoke-prelude.sh' "$skill" && grep -q 'yoke_require_provider' "$skill"; then
    pass "(C) audit: skills/$s/SKILL.md sources lib/yoke-prelude.sh + calls yoke_require_provider"
  else
    err "(C) audit: skills/$s/SKILL.md missing prelude source line"
  fi
done

# Bootstrap MUST NOT source the prelude — it's the migration entry point.
if grep -q 'yoke_require_provider' "$PLUGIN_ROOT/skills/bootstrap/SKILL.md" 2>/dev/null; then
  err "(C) audit: skills/bootstrap/SKILL.md must NOT source yoke-prelude (migration entry point)"
else
  pass "(C) audit: skills/bootstrap/SKILL.md correctly does NOT source yoke-prelude"
fi

harness::summary
