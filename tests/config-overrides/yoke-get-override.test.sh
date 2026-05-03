#!/usr/bin/env bash
# shellcheck shell=bash
#
# yoke-get-override.test.sh — Sprint 01 / Task t01 (happy-path unit
# tests for `lib/config-overrides.sh::yoke_get_override`).
#
# Covers the three documented behaviours:
#
#   1. function exists and is sourceable                  (`type` check)
#   2. absent dotted key returns the supplied default     (read-from-disk)
#   3. present dotted key returns the configured value    (read-from-disk)
#   4. nested dotted key resolves the deepest value       (path traversal)
#   5. quoted string value strips quotes                  (yaml semantics)
#   6. missing config file returns the default            (file-absent path)
#
# These are happy-path unit tests authored by Sr Eng under the v3.0
# council protocol — Sr QA owns the acceptance-contract-anchored
# tests at `tests/acceptance/2026-05-03-tech-spec-as-design-doc/`.
# This file is pure happy-path coverage for the new code path landed
# in `lib/config-overrides.sh`.
#
# Discovery: enumerated by Sprint 01 / Task t01's
# **Acceptance criterion** line and by Acceptance Contract Scenario 1
# (Sensor `config-override-reader-callable`).

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"
cd "$PLUGIN_ROOT"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# --- 1. function exists -----------------------------------------------------
#
# Source the helper from the plugin root (not from $TMPDIR_TEST) and
# verify the public function is registered.

if bash -c "source '${PLUGIN_ROOT}/lib/config-overrides.sh' && type yoke_get_override" >/dev/null 2>&1; then
    pass "yoke_get_override is sourceable and registered as a function"
else
    err "yoke_get_override missing after sourcing lib/config-overrides.sh"
fi

# --- 2. absent dotted key returns default ----------------------------------
#
# Build a tempdir host project with a `.yoke/config.yaml` that omits
# the canonical_pattern_threshold key entirely; assert the helper
# returns the supplied default (3).

mkdir -p "$TMPDIR_TEST/case-absent/.yoke"
cat > "$TMPDIR_TEST/case-absent/.yoke/config.yaml" <<'YAML'
yoke_version: "2.0.0"
canonical_memory:
  provider: "bedrock"
overrides:
  hard_bounds:
    cycles_max: 24
YAML

absent_value="$(cd "$TMPDIR_TEST/case-absent" && bash -c "source '${PLUGIN_ROOT}/lib/config-overrides.sh' && yoke_get_override overrides.tech_spec.canonical_pattern_threshold 3")"
if [ "$absent_value" = "3" ]; then
    pass "absent key 'overrides.tech_spec.canonical_pattern_threshold' returns supplied default '3'"
else
    err "absent key 'overrides.tech_spec.canonical_pattern_threshold' returned '$absent_value' (expected '3')"
fi

# --- 3. present dotted key returns the configured value -------------------

mkdir -p "$TMPDIR_TEST/case-present/.yoke"
cat > "$TMPDIR_TEST/case-present/.yoke/config.yaml" <<'YAML'
yoke_version: "2.0.0"
canonical_memory:
  provider: "bedrock"
overrides:
  tech_spec:
    canonical_pattern_threshold: 5
YAML

present_value="$(cd "$TMPDIR_TEST/case-present" && bash -c "source '${PLUGIN_ROOT}/lib/config-overrides.sh' && yoke_get_override overrides.tech_spec.canonical_pattern_threshold 3")"
if [ "$present_value" = "5" ]; then
    pass "present key 'overrides.tech_spec.canonical_pattern_threshold' returns configured value '5' (default '3' overridden)"
else
    err "present key returned '$present_value' (expected '5')"
fi

# --- 4. deeper nested dotted key resolves the deepest value ---------------

mkdir -p "$TMPDIR_TEST/case-deep/.yoke"
cat > "$TMPDIR_TEST/case-deep/.yoke/config.yaml" <<'YAML'
overrides:
  runtime:
    models:
      validator: "claude-sonnet-4-6"
YAML

deep_value="$(cd "$TMPDIR_TEST/case-deep" && bash -c "source '${PLUGIN_ROOT}/lib/config-overrides.sh' && yoke_get_override overrides.runtime.models.validator default-fallback")"
if [ "$deep_value" = "claude-sonnet-4-6" ]; then
    pass "deeply-nested key 'overrides.runtime.models.validator' resolves to 'claude-sonnet-4-6'"
else
    err "deeply-nested key returned '$deep_value' (expected 'claude-sonnet-4-6')"
fi

# --- 5. quoted string value strips quotes ---------------------------------

mkdir -p "$TMPDIR_TEST/case-quoted/.yoke"
cat > "$TMPDIR_TEST/case-quoted/.yoke/config.yaml" <<'YAML'
overrides:
  tech_spec:
    canonical_pattern_threshold: "7"
YAML

quoted_value="$(cd "$TMPDIR_TEST/case-quoted" && bash -c "source '${PLUGIN_ROOT}/lib/config-overrides.sh' && yoke_get_override overrides.tech_spec.canonical_pattern_threshold 3")"
if [ "$quoted_value" = "7" ]; then
    pass "quoted YAML scalar '\"7\"' resolves with surrounding quotes stripped"
else
    err "quoted YAML scalar returned '$quoted_value' (expected '7')"
fi

# --- 6. missing config file returns default ------------------------------

mkdir -p "$TMPDIR_TEST/case-no-config"
no_config_value="$(cd "$TMPDIR_TEST/case-no-config" && bash -c "source '${PLUGIN_ROOT}/lib/config-overrides.sh' && yoke_get_override overrides.tech_spec.canonical_pattern_threshold 3")"
if [ "$no_config_value" = "3" ]; then
    pass "missing .yoke/config.yaml falls back to supplied default '3'"
else
    err "missing config returned '$no_config_value' (expected '3')"
fi

harness::summary
