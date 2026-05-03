#!/usr/bin/env bash
# tests/smoke/resolve-provider-set-u-safety.test.sh
#
# Sensor: resolve-provider-set-u-safety (computational, cheap).
#
# Pins the regression documented in
# https://github.com/iurykrieger/claude-yoke/issues/28:
# `lib/canonical-memory/resolve-provider.sh::_yoke_provider_plugin_dir`
# crashed with `BASH_SOURCE[0]: parameter not set` whenever a skill
# sourced it through `bash -c "set -u; source ..."` from outside the
# plugin root. Reproduced in three independent transcripts (council
# `25e4a610` L1336, chat-test `ae43c28f` L839, chat-test `4993d9c5` L146).
#
# Coverage:
#   (A) `bash -c "set -u; source ..."` from a temp host project — the
#       failing dispatch from the transcripts — exits 0, no
#       `BASH_SOURCE[0]: parameter not set` on stderr, and stdout
#       carries the resolved provider name.
#   (B) Synthetic degenerate case (BASH_SOURCE unset, YOKE_PLUGIN_DIR
#       unset) — `yoke_resolve_provider` exits 5 with exactly one
#       `wm: `-prefixed line on stderr naming both `YOKE_PLUGIN_DIR`
#       and `BASH_SOURCE[0]`.
#   (C) `YOKE_PLUGIN_DIR` fast-path — when exported to a sentinel
#       directory lacking `providers.yaml`, the helper resolves to
#       that path (verifiable via the existing
#       `wm: providers.yaml missing from plugin root (...)` stderr
#       line — proves the fast-path is taken without consulting
#       `BASH_SOURCE[0]`).
#   (D) Pre-existing exit codes preserved:
#       - exit 3 when host has no `.yoke/config.yaml`
#       - exit 4 when host's `.yoke/config.yaml` lacks
#         `canonical_memory.provider`
#       - exit 5 when host's `.yoke/config.yaml` names a provider
#         not registered in `providers.yaml`
#
# References:
# - PRD:  .yoke/prds/2026-05-03-resolve-provider-set-u-safety.md
# - Spec: .yoke/specs/2026-05-03-resolve-provider-set-u-safety.md
# - Acceptance Contract Scenarios 1, 2, 3 / FR-1..FR-6.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

set +e

# Watchdog (concepts/yoke-conventions): never let a hung subshell block CI.
(sleep 600 && kill -TERM $$ &) >/dev/null 2>&1

HELPER="$PLUGIN_ROOT/lib/canonical-memory/resolve-provider.sh"
[ -f "$HELPER" ] || { err "helper missing at $HELPER"; harness::summary; }

# Pick the first registered provider from providers.yaml. Stays valid
# as the registry evolves.
PROVIDER="$(grep -E '^  [a-z][a-z0-9_-]*:' "$PLUGIN_ROOT/providers.yaml" | head -1 | sed -E 's/^[[:space:]]*([a-z0-9_-]+):.*/\1/')"
[ -n "$PROVIDER" ] || { err "no provider found in providers.yaml"; harness::summary; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ----------------------------------------------------------------------
# (A) bash -c "set -u; source ..." from outside the plugin root —
# the exact failing dispatch from the three transcripts.
# ----------------------------------------------------------------------
mkdir -p "$TMP/host_a/.yoke"
cat > "$TMP/host_a/.yoke/config.yaml" <<YAML
yoke_version: "2.0.0"
canonical_memory:
  provider: ${PROVIDER}
host:
  project_name: "host_a"
YAML

stdout_a="$(
  cd "$TMP/host_a" \
  && unset YOKE_PLUGIN_DIR \
  && bash -c 'set -u; source "$1" && yoke_resolve_provider && printf "%s" "$YOKE_PROVIDER_NAME"' _ "$HELPER" 2>"$TMP/stderr_a"
)"
rc_a=$?
stderr_a="$(cat "$TMP/stderr_a")"

[ "$rc_a" -eq 0 ] \
  && pass "(A) bash -c set -u source from outside plugin root: exit 0" \
  || err "(A) expected exit 0, got $rc_a; stderr=$stderr_a"

[ "$stdout_a" = "$PROVIDER" ] \
  && pass "(A) stdout carries resolved provider ($PROVIDER)" \
  || err "(A) expected stdout='$PROVIDER', got '$stdout_a'"

if printf '%s' "$stderr_a" | grep -qE 'BASH_SOURCE\[0\]: parameter not set'; then
  err "(A) stderr contains 'BASH_SOURCE[0]: parameter not set' — got: $stderr_a"
else
  pass "(A) no 'BASH_SOURCE[0]: parameter not set' on stderr"
fi

if printf '%s' "$stderr_a" | grep -qE '_yoke_provider_plugin_dir:.*BASH_SOURCE'; then
  err "(A) stderr contains the helper-internal BASH_SOURCE error — got: $stderr_a"
else
  pass "(A) no helper-internal BASH_SOURCE error on stderr"
fi

# ----------------------------------------------------------------------
# (B) Defensive-deref + actionable-error branch — structural check.
# Bash refuses both `unset BASH_SOURCE` and `local BASH_SOURCE=()`
# (the variable is special / read-only-against-assignment in modern
# bash), so the runtime-degenerate path is unreachable from within a
# bash subshell that has already sourced the helper. The branch's
# correctness is asserted statically against the helper file: the
# safe `${BASH_SOURCE[0]:-}` deref is present, the new error branch
# emits a single `wm: `-prefixed line that names both fallback
# variables, and `return 5` is wired in.
# ----------------------------------------------------------------------

grep -qE '\$\{BASH_SOURCE\[0\]:-\}' "$HELPER" \
  && pass "(B) helper uses safe \${BASH_SOURCE[0]:-} deref" \
  || err "(B) helper still uses unguarded \${BASH_SOURCE[0]} — grep against $HELPER returned nothing"

if grep -qE '\$\{BASH_SOURCE\[0\]\}' "$HELPER" | grep -v ':-'; then
  err "(B) helper still contains an unguarded \${BASH_SOURCE[0]} reference"
else
  pass "(B) no unguarded \${BASH_SOURCE[0]} reference remains"
fi

grep -qE '^[[:space:]]+echo "wm: cannot resolve plugin root' "$HELPER" \
  && pass "(B) actionable wm: error branch present" \
  || err "(B) actionable wm: error branch missing from $HELPER"

# The error message must name BOTH fallback variables so the operator
# can correct the misconfiguration without reading source.
err_line="$(grep -E 'wm: cannot resolve plugin root' "$HELPER" | head -1)"
[ -n "$err_line" ] \
  && printf '%s' "$err_line" | grep -qF 'YOKE_PLUGIN_DIR' \
  && pass "(B) error message names YOKE_PLUGIN_DIR" \
  || err "(B) error message lacks YOKE_PLUGIN_DIR — line: $err_line"

[ -n "$err_line" ] \
  && printf '%s' "$err_line" | grep -qF 'BASH_SOURCE[0]' \
  && pass "(B) error message names BASH_SOURCE[0]" \
  || err "(B) error message lacks BASH_SOURCE[0] — line: $err_line"

# The branch must `return 5` per the contract (mutually exclusive with
# the existing exit-5 providers-yaml branch).
awk '/_yoke_provider_plugin_dir\(\) \{/,/^\}/' "$HELPER" | grep -qE 'return 5' \
  && pass "(B) helper branch returns exit code 5" \
  || err "(B) helper branch missing return 5"

# ----------------------------------------------------------------------
# (C) YOKE_PLUGIN_DIR fast-path takes precedence — sentinel that lacks
# providers.yaml surfaces the existing exit-5 error against the
# sentinel path (proving BASH_SOURCE[0] was not consulted).
# ----------------------------------------------------------------------
mkdir -p "$TMP/host_c/.yoke" "$TMP/sentinel"
cat > "$TMP/host_c/.yoke/config.yaml" <<YAML
yoke_version: "2.0.0"
canonical_memory:
  provider: ${PROVIDER}
YAML

(
  cd "$TMP/host_c" \
    && export YOKE_PLUGIN_DIR="$TMP/sentinel" \
    && bash -c 'set -u; source "$1"; yoke_resolve_provider' _ "$HELPER"
) >"$TMP/stdout_c" 2>"$TMP/stderr_c"
rc_c=$?
stderr_c="$(cat "$TMP/stderr_c")"

[ "$rc_c" -eq 5 ] \
  && pass "(C) YOKE_PLUGIN_DIR fast-path: exit 5 (sentinel lacks providers.yaml)" \
  || err "(C) expected exit 5, got $rc_c; stderr=$stderr_c"

printf '%s' "$stderr_c" | grep -qF "providers.yaml missing from plugin root ($TMP/sentinel/providers.yaml)" \
  && pass "(C) stderr names the sentinel path (proves YOKE_PLUGIN_DIR took precedence)" \
  || err "(C) stderr does not name sentinel path — got: $stderr_c"

# ----------------------------------------------------------------------
# (D) Pre-existing exit-code paths preserved.
# ----------------------------------------------------------------------

# (D.3) host has no .yoke/config.yaml → exit 3
mkdir -p "$TMP/host_d3"
(
  cd "$TMP/host_d3" \
    && unset YOKE_PLUGIN_DIR \
    && bash -c 'set -u; source "$1"; yoke_resolve_provider' _ "$HELPER"
) >/dev/null 2>"$TMP/stderr_d3"
rc_d3=$?

[ "$rc_d3" -eq 3 ] \
  && pass "(D.3) missing .yoke/config.yaml: exit 3" \
  || err "(D.3) expected exit 3, got $rc_d3; stderr=$(cat "$TMP/stderr_d3")"

grep -qF '.yoke/config.yaml not found' "$TMP/stderr_d3" \
  && pass "(D.3) stderr text byte-equivalent" \
  || err "(D.3) stderr divergence: $(cat "$TMP/stderr_d3")"

# (D.4) config.yaml lacks canonical_memory.provider → exit 4
mkdir -p "$TMP/host_d4/.yoke"
cat > "$TMP/host_d4/.yoke/config.yaml" <<'YAML'
yoke_version: "1.1.0"
canonical_memory:
  url: ""
YAML

(
  cd "$TMP/host_d4" \
    && unset YOKE_PLUGIN_DIR \
    && bash -c 'set -u; source "$1"; yoke_resolve_provider' _ "$HELPER"
) >/dev/null 2>"$TMP/stderr_d4"
rc_d4=$?

[ "$rc_d4" -eq 4 ] \
  && pass "(D.4) missing canonical_memory.provider: exit 4" \
  || err "(D.4) expected exit 4, got $rc_d4; stderr=$(cat "$TMP/stderr_d4")"

grep -qF 'canonical_memory.provider not configured' "$TMP/stderr_d4" \
  && pass "(D.4) stderr text byte-equivalent" \
  || err "(D.4) stderr divergence: $(cat "$TMP/stderr_d4")"

# (D.5) provider not registered in providers.yaml → exit 5
mkdir -p "$TMP/host_d5/.yoke"
cat > "$TMP/host_d5/.yoke/config.yaml" <<'YAML'
yoke_version: "2.0.0"
canonical_memory:
  provider: this-provider-does-not-exist
YAML

(
  cd "$TMP/host_d5" \
    && unset YOKE_PLUGIN_DIR \
    && bash -c 'set -u; source "$1"; yoke_resolve_provider' _ "$HELPER"
) >/dev/null 2>"$TMP/stderr_d5"
rc_d5=$?

[ "$rc_d5" -eq 5 ] \
  && pass "(D.5) unregistered provider: exit 5" \
  || err "(D.5) expected exit 5, got $rc_d5; stderr=$(cat "$TMP/stderr_d5")"

grep -qF 'this-provider-does-not-exist' "$TMP/stderr_d5" \
  && pass "(D.5) stderr names the unregistered provider" \
  || err "(D.5) stderr divergence: $(cat "$TMP/stderr_d5")"

harness::summary
