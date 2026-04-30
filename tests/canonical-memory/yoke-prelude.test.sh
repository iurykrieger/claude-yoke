#!/usr/bin/env bash
# tests/canonical-memory/yoke-prelude.test.sh
#
# Exercises lib/yoke-prelude.sh against four scenarios drawn from
# Acceptance Contract Scenario 12 / FR-6 / Sprint 03 task
# 2026-04-30-pluggable-canonical-memory-s03-t02:
#
#   (1) Happy path — config.yaml with `canonical_memory.provider: bedrock`
#       → exit 0, stderr silent.
#   (2) Missing file — no `.yoke/config.yaml` in $PWD → exit 2,
#       stderr contains the documented "not found" message.
#   (3) Missing key — `canonical_memory:` block present but `provider:`
#       absent → exit 1, stderr contains the documented
#       "not configured" message.
#   (4) Empty value — `provider:` present but empty (or literal "null")
#       → exit 1, same message as (3).
#
# Sensor: yoke-prelude-helper-callable (computational, cheap).
#
# Self-contained: no plugin install needed, no network. The helper is
# pure stdin-free filesystem read; the four cases cover the entire
# decision tree of yoke_require_provider.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

# Errexit OFF — this script intentionally captures non-zero exit codes
# from the helper to assert exit-code semantics. pipefail and nounset
# remain on (per harness.sh).
set +e

PRELUDE="$PLUGIN_ROOT/lib/yoke-prelude.sh"
[ -f "$PRELUDE" ] || { err "prelude missing at $PRELUDE"; harness::summary; }
pass "(0) prelude file exists at expected path"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ----------------------------------------------------------------------
# (1) Happy path — config.yaml carries `canonical_memory.provider: bedrock`.
# ----------------------------------------------------------------------
mkdir -p "$TMP/happy/.yoke"
cat > "$TMP/happy/.yoke/config.yaml" <<'YAML'
yoke_version: "2.0.0-test"
canonical_memory:
  provider: "bedrock"
  url: ""
  name: "happy-fixture"
  default_branch: main
host:
  project_name: "happy"
YAML

stderr_happy="$(
  cd "$TMP/happy" && \
  bash -c 'source "$1"; yoke_require_provider' _ "$PRELUDE" 2>&1 1>/dev/null
)"
rc_happy=$?
[ "$rc_happy" -eq 0 ] && pass "(1) happy path: exit 0" || err "(1) happy path: expected exit 0, got $rc_happy"
[ -z "$stderr_happy" ] && pass "(1) happy path: stderr is silent" || err "(1) happy path: expected silent stderr, got: $stderr_happy"

# ----------------------------------------------------------------------
# (2) Missing file — no .yoke/config.yaml in $PWD → exit 2.
# ----------------------------------------------------------------------
mkdir -p "$TMP/missing-file"
stderr_missing="$(
  cd "$TMP/missing-file" && \
  bash -c 'source "$1"; yoke_require_provider' _ "$PRELUDE" 2>&1 1>/dev/null
)"
rc_missing=$?
[ "$rc_missing" -eq 2 ] && pass "(2) missing file: exit 2" || err "(2) missing file: expected exit 2, got $rc_missing"
printf '%s' "$stderr_missing" | grep -q 'Run /yoke:bootstrap to initialize this project' \
  && pass "(2) missing file: stderr cites '/yoke:bootstrap to initialize'" \
  || err "(2) missing file: stderr lacks expected message — got: $stderr_missing"

# ----------------------------------------------------------------------
# (3) Missing key — config exists, canonical_memory: present, but
# `provider:` key absent → exit 1.
# ----------------------------------------------------------------------
mkdir -p "$TMP/missing-key/.yoke"
cat > "$TMP/missing-key/.yoke/config.yaml" <<'YAML'
yoke_version: "2.0.0-test"
canonical_memory:
  url: ""
  name: "missing-key-fixture"
  default_branch: main
host:
  project_name: "missing-key"
YAML

stderr_missing_key="$(
  cd "$TMP/missing-key" && \
  bash -c 'source "$1"; yoke_require_provider' _ "$PRELUDE" 2>&1 1>/dev/null
)"
rc_missing_key=$?
[ "$rc_missing_key" -eq 1 ] && pass "(3) missing key: exit 1" || err "(3) missing key: expected exit 1, got $rc_missing_key"
printf '%s' "$stderr_missing_key" | grep -qF 'wm: canonical_memory.provider not configured. Run /yoke:bootstrap to migrate.' \
  && pass "(3) missing key: stderr matches binding literal" \
  || err "(3) missing key: stderr lacks the binding literal — got: $stderr_missing_key"

# ----------------------------------------------------------------------
# (4) Empty value — `provider:` present but empty string → exit 1.
# ----------------------------------------------------------------------
mkdir -p "$TMP/empty-value/.yoke"
cat > "$TMP/empty-value/.yoke/config.yaml" <<'YAML'
yoke_version: "2.0.0-test"
canonical_memory:
  provider: ""
  url: ""
  name: "empty-value-fixture"
  default_branch: main
host:
  project_name: "empty-value"
YAML

stderr_empty="$(
  cd "$TMP/empty-value" && \
  bash -c 'source "$1"; yoke_require_provider' _ "$PRELUDE" 2>&1 1>/dev/null
)"
rc_empty=$?
[ "$rc_empty" -eq 1 ] && pass "(4) empty value: exit 1" || err "(4) empty value: expected exit 1, got $rc_empty"
printf '%s' "$stderr_empty" | grep -qF 'wm: canonical_memory.provider not configured. Run /yoke:bootstrap to migrate.' \
  && pass "(4) empty value: stderr matches binding literal" \
  || err "(4) empty value: stderr lacks the binding literal — got: $stderr_empty"

harness::summary
