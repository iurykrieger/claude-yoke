#!/usr/bin/env bash
# tests/smoke/scaffold-sprints-bash4.test.sh
#
# Sensor: scaffold-sprints-bash4 (computational, cheap).
#
# Pins the regression documented in
# https://github.com/iurykrieger/claude-yoke/issues/33:
# `lib/working-memory/scaffold-sprints.sh` shipped with shebang
# `#!/bin/bash` and used `mapfile` (line 87). On macOS hosts /bin/bash
# is the Apple-shipped 3.2.57 (frozen at GPLv2), which has no
# `mapfile` / `readarray`. /yoke:tech-spec stage 2 therefore failed
# with `mapfile: command not found` (exit 127) on every macOS dev
# machine until a Homebrew bash 5 was forced via explicit invocation.
# CI on ubuntu-latest always saw bash 4+ and never tripped this.
#
# Coverage:
#   (A) Shebang at line 1 is `#!/usr/bin/env bash` (so PATH resolution
#       picks up Homebrew's bash on macOS, not Apple's 3.2).
#   (B) The bash-4 runtime guard is present (`BASH_VERSINFO[0] < 4`)
#       and exits 2 with an actionable `wm: ... requires bash 4+` line
#       on stderr — the diagnostic the issue specifically called for.
#   (C) Forcing the script to run under `/bin/bash` (Apple 3.2 on macOS,
#       skipped on Linux runners where `/bin/bash` is already 4+) trips
#       the guard, exits 2, and emits the documented stderr; it does
#       NOT reach line 87 where `mapfile` would otherwise fire.
#   (D) Default invocation under bash 4+ still scaffolds correctly —
#       the guard is a no-op for the supported floor.
#   (E) Structural pin against future regressions: any script under
#       `lib/`, `skills/`, or `hooks/` that uses `mapfile` /
#       `readarray` MUST also use `#!/usr/bin/env bash` AND carry a
#       `BASH_VERSINFO` guard. This pin catches reintroduction of the
#       bug class via a different file.
#
# References:
# - Issue: #33
# - CLAUDE.md :: ## Linting — "Bash scripts target bash 4+".

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

set +e

# Watchdog (concepts/yoke-conventions): never let a hung subshell block CI.
(sleep 600 && kill -TERM $$ &) >/dev/null 2>&1

cd "$PLUGIN_ROOT"

SCRIPT="$PLUGIN_ROOT/lib/working-memory/scaffold-sprints.sh"
[ -f "$SCRIPT" ] || { err "script missing at $SCRIPT"; harness::summary; }

# ----------------------------------------------------------------------
# (A) Shebang.
# ----------------------------------------------------------------------
shebang="$(head -1 "$SCRIPT")"
if [ "$shebang" = "#!/usr/bin/env bash" ]; then
  pass "(A) shebang resolves bash via /usr/bin/env"
else
  err "(A) expected shebang '#!/usr/bin/env bash', got '$shebang'"
fi

# ----------------------------------------------------------------------
# (B) Runtime guard present (textual pin — the assertion below in (C)
# proves it actually fires).
# ----------------------------------------------------------------------
if grep -qE 'BASH_VERSINFO\[0\][[:space:]]*<[[:space:]]*4' "$SCRIPT"; then
  pass "(B) BASH_VERSINFO[0] < 4 guard present"
else
  err "(B) BASH_VERSINFO[0] < 4 guard missing — no protection against bash 3.x at runtime"
fi

if grep -qE '^[[:space:]]*echo "wm: scaffold-sprints\.sh requires bash 4\+' "$SCRIPT"; then
  pass "(B) actionable 'wm:' diagnostic line present"
else
  err "(B) actionable 'wm:' diagnostic missing (issue #33 specifically requested this)"
fi

# ----------------------------------------------------------------------
# (C) Forced invocation under stock /bin/bash. On macOS this is
# Apple's 3.2.57; on Linux runners /bin/bash is already 4+ (so the
# guard does NOT fire and this assertion is auto-skipped to keep CI
# green across both platforms — the issue is OS-dependent).
# ----------------------------------------------------------------------
if [ -x /bin/bash ]; then
  bin_bash_major="$(/bin/bash -c 'echo $BASH_VERSINFO' 2>/dev/null || echo 99)"
  if [ "$bin_bash_major" -lt 4 ]; then
    forced_stderr="$(mktemp)"
    /bin/bash "$SCRIPT" /tmp/__yoke_test_nonexistent_spec.md >/dev/null 2>"$forced_stderr"
    forced_rc=$?
    forced_stderr_content="$(cat "$forced_stderr")"
    rm -f "$forced_stderr"

    [ "$forced_rc" -eq 2 ] \
      && pass "(C) /bin/bash 3.x forces guard, exit 2 (got $forced_rc)" \
      || err "(C) /bin/bash 3.x forced invocation: expected exit 2, got $forced_rc; stderr=$forced_stderr_content"

    if printf '%s' "$forced_stderr_content" | grep -qF "requires bash 4+"; then
      pass "(C) stderr surfaces 'requires bash 4+' diagnostic"
    else
      err "(C) stderr does not surface 'requires bash 4+' — got: $forced_stderr_content"
    fi

    if printf '%s' "$forced_stderr_content" | grep -qF "mapfile: command not found"; then
      err "(C) regression: the cryptic 'mapfile: command not found' message reached the user — guard ran too late"
    else
      pass "(C) the cryptic 'mapfile: command not found' message is no longer surfaced"
    fi
  else
    pass "(C) skipped on this host (/bin/bash is already bash $bin_bash_major+; guard not exercised here)"
  fi
else
  pass "(C) skipped: no /bin/bash on this host"
fi

# ----------------------------------------------------------------------
# (D) Happy path under env-resolved bash 4+. Builds a minimal valid
# spec, runs the script, asserts both files were created, and cleans
# up. Uses the script's normal shebang resolution.
# ----------------------------------------------------------------------
TMP="$(mktemp -d)"
SPEC="$TMP/2026-05-03-scaffold-test-slug.md"
cat > "$SPEC" <<'SPEC'
# Spec for scaffold-sprints-bash4 smoke test

### Sprint 1 — Foo
delivery objective.

### Sprint 2 — Bar
delivery objective.
SPEC

# Run the script via env shebang. Capture rc but don't fail the
# whole harness on cleanup errors (the on-disk artifacts are removed
# explicitly below).
happy_stdout="$(mktemp)"
happy_stderr="$(mktemp)"
"$SCRIPT" "$SPEC" >"$happy_stdout" 2>"$happy_stderr"
happy_rc=$?

# Locate scaffolded files (relative to PLUGIN_ROOT/.yoke/sprints).
created_a="$PLUGIN_ROOT/.yoke/sprints/2026-05-03-scaffold-test-slug-s01.md"
created_b="$PLUGIN_ROOT/.yoke/sprints/2026-05-03-scaffold-test-slug-s02.md"

[ "$happy_rc" -eq 0 ] \
  && pass "(D) env-resolved bash 4+ run scaffolds with exit 0" \
  || err "(D) env-resolved scaffold exited $happy_rc; stderr=$(cat "$happy_stderr")"

if [ -f "$created_a" ] && [ -f "$created_b" ]; then
  pass "(D) both sprint files created on disk"
else
  err "(D) expected sprint files missing — a=$created_a (exists=$([ -f "$created_a" ] && echo 1 || echo 0)), b=$created_b (exists=$([ -f "$created_b" ] && echo 1 || echo 0))"
fi

# Cleanup happy-path side effects so the test is idempotent.
rm -f "$created_a" "$created_b" "$happy_stdout" "$happy_stderr"
rm -rf "$TMP"

# ----------------------------------------------------------------------
# (E) Structural pin: every script in lib/, skills/, hooks/ that uses
# `mapfile` or `readarray` MUST use the env-resolved shebang AND carry
# a BASH_VERSINFO guard. Catches future regressions in OTHER files.
# ----------------------------------------------------------------------
e_violations=""
e_count=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  e_count=$((e_count + 1))
  first_line="$(head -1 "$f")"
  has_guard=0
  grep -qE 'BASH_VERSINFO\[0\][[:space:]]*<[[:space:]]*4' "$f" && has_guard=1
  if [ "$first_line" != "#!/usr/bin/env bash" ] || [ "$has_guard" -eq 0 ]; then
    e_violations+=$'\n'"  - $f (shebang='$first_line', guarded=$has_guard)"
  fi
done < <(grep -rlE '\b(mapfile|readarray)\b' lib/ skills/ hooks/ 2>/dev/null || true)

if [ -z "$e_violations" ]; then
  pass "(E) every mapfile/readarray user has env-shebang + bash-4 guard ($e_count file(s) audited)"
else
  err "(E) bash-4-only-feature users without protection:$e_violations"
fi

harness::summary
