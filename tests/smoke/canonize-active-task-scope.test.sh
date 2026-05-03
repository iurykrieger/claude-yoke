#!/usr/bin/env bash
# tests/smoke/canonize-active-task-scope.test.sh
#
# Sensor: canonize-active-task-scope (computational, cheap).
#
# Pins the regression documented in
# https://github.com/iurykrieger/claude-yoke/issues/40:
# /yoke:canonize used to hand the provider the ENTIRE `.yoke/`
# directory — every historical PRD, spec, sprint bundle, and
# acceptance document from every prior task. The reference provider
# (`bedrock:teach`) re-ran graphify and entity-matching over all 138
# files when only 8 carried fresh signal during the v4.0.0 cutover
# canonization. Cost: 5-minute hand-off blew up to 30+ minutes, with
# real risk of polluting the vault if any historical file's
# frontmatter had drifted since its original canonization.
#
# This sensor pins the v4.1 fix: `lib/working-memory/canonize-stage.sh`
# stages only the active slug's archive files (plus config.yaml,
# .gitignore, and the runtime/ subtree) into a fresh tmp directory
# shaped exactly like `.yoke/`. Sensors and historical-task archives
# are explicitly excluded.
#
# Coverage:
#   (A) Helper exits 2 when invoked outside a `.yoke/` host.
#   (B) Helper exits 3 when `.yoke/runtime/.current` is missing
#       (no active slug).
#   (C) Happy path with a synthetic `.yoke/` containing 1 active
#       slug + 1 historical slug:
#         - stdout is an absolute path that exists on disk
#         - staged tree contains the active slug's prd/spec/sprints
#           (3 sprints) / acceptance-criteria / contracts
#         - staged tree does NOT contain any historical slug's files
#         - staged tree does NOT contain `.yoke/sensors/` (project-
#           scoped, not per-task)
#         - `config.yaml` and `.gitignore` are staged
#         - `runtime/` subtree is staged
#   (D) Legacy `acceptance-contracts/<slug>.md` (pre-v4.0.0) is
#       staged when present for the active slug.
#   (E) Empty archive directories (e.g. `acceptance-contracts/` when
#       the active slug only has the post-v4.0.0 `acceptance-criteria/`
#       file) are pruned from the staged tree — the shape mirrors
#       what a fresh `.yoke/` would look like, not the helper's
#       internal scaffolding.
#   (F) Explicit `--slug <slug>` flag overrides `.yoke/runtime/.current`
#       and stages the named slug. Useful for catch-up canonizations
#       and for tests.
#   (G) The staged path is a `mktemp -d` under `${TMPDIR:-/tmp}` —
#       safe to `rm -rf` from the caller without touching the host's
#       `.yoke/`.
#
# References:
# - Issue: #40
# - Helper: lib/working-memory/canonize-stage.sh
# - Skill: skills/canonize/SKILL.md (Phase 1, Phase 5)

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

set +e

# Watchdog (concepts/yoke-conventions): never let a hung subshell block CI.
(sleep 600 && kill -TERM $$ &) >/dev/null 2>&1

cd "$PLUGIN_ROOT"

HELPER="$PLUGIN_ROOT/lib/working-memory/canonize-stage.sh"
[ -x "$HELPER" ] || { err "helper missing or not executable at $HELPER"; harness::summary; }

ACTIVE_SLUG="2026-05-04-active-task"
LEGACY_SLUG="2026-04-30-historical-task"

scaffold_host() {
    local host="$1"
    rm -rf "$host"
    mkdir -p \
        "$host/.yoke/prds" \
        "$host/.yoke/specs" \
        "$host/.yoke/sprints" \
        "$host/.yoke/acceptance-criteria" \
        "$host/.yoke/acceptance-contracts" \
        "$host/.yoke/contracts" \
        "$host/.yoke/sensors" \
        "$host/.yoke/runtime"

    cat > "$host/.yoke/config.yaml" <<YAML
yoke_version: "4.0.0"
canonical_memory:
  provider: bedrock
host:
  project_name: "smoke-test-host"
YAML

    cat > "$host/.yoke/.gitignore" <<'GITIGNORE'
.current
runtime/
GITIGNORE

    # Active slug — full archive set.
    echo "# active prd"   > "$host/.yoke/prds/${ACTIVE_SLUG}.md"
    echo "# active spec"  > "$host/.yoke/specs/${ACTIVE_SLUG}.md"
    echo "# active s01"   > "$host/.yoke/sprints/${ACTIVE_SLUG}-s01.md"
    echo "# active s02"   > "$host/.yoke/sprints/${ACTIVE_SLUG}-s02.md"
    echo "# active s03"   > "$host/.yoke/sprints/${ACTIVE_SLUG}-s03.md"
    echo "# active AC"    > "$host/.yoke/acceptance-criteria/${ACTIVE_SLUG}.md"
    echo "# active contracts" > "$host/.yoke/contracts/${ACTIVE_SLUG}.md"

    # Historical slug — should NOT appear in the stage.
    echo "# legacy prd"      > "$host/.yoke/prds/${LEGACY_SLUG}.md"
    echo "# legacy spec"     > "$host/.yoke/specs/${LEGACY_SLUG}.md"
    echo "# legacy s01"      > "$host/.yoke/sprints/${LEGACY_SLUG}-s01.md"
    echo "# legacy AC (pre-v4)" > "$host/.yoke/acceptance-contracts/${LEGACY_SLUG}.md"

    # Project-scoped sensor — should NOT appear in the stage.
    cat > "$host/.yoke/sensors/lint.md" <<'SENSOR'
---
id: lint
type: computational
token_cost: 0
time_cost: 30
command: true
---

# lint
SENSOR

    # Runtime subtree — should appear in the stage.
    printf '%s' "$ACTIVE_SLUG" > "$host/.yoke/runtime/.current"
    printf '# Progress\n' > "$host/.yoke/runtime/progress.md"
    mkdir -p "$host/.yoke/runtime/.snapshots"
    printf 'cycle: 1\n' > "$host/.yoke/runtime/.snapshots/cycle-1.yaml"
}

# ----------------------------------------------------------------------
# (A) Outside a .yoke/ host — exit 2 with diagnostic.
# ----------------------------------------------------------------------
TMP_A="$(mktemp -d)"
(
    cd "$TMP_A" && bash "$HELPER" >/dev/null 2>"$TMP_A/stderr"
)
rc_a=$?
stderr_a="$(cat "$TMP_A/stderr")"

[ "$rc_a" -eq 2 ] \
    && pass "(A) helper exits 2 when no .yoke/ in CWD (got $rc_a)" \
    || err "(A) expected exit 2, got $rc_a; stderr=$stderr_a"

if printf '%s' "$stderr_a" | grep -qF ".yoke/ not found"; then
    pass "(A) stderr names the missing .yoke/ directory"
else
    err "(A) stderr does not name the missing .yoke/ — got: $stderr_a"
fi
rm -rf "$TMP_A"

# ----------------------------------------------------------------------
# (B) No .yoke/runtime/.current — exit 3.
# ----------------------------------------------------------------------
TMP_B="$(mktemp -d)"
mkdir -p "$TMP_B/.yoke/runtime"
(
    cd "$TMP_B" && bash "$HELPER" >/dev/null 2>"$TMP_B/stderr"
)
rc_b=$?
stderr_b="$(cat "$TMP_B/stderr")"

[ "$rc_b" -eq 3 ] \
    && pass "(B) helper exits 3 when .current is missing (got $rc_b)" \
    || err "(B) expected exit 3, got $rc_b; stderr=$stderr_b"

if printf '%s' "$stderr_b" | grep -qF "no active task"; then
    pass "(B) stderr surfaces 'no active task' diagnostic"
else
    err "(B) stderr does not surface 'no active task' — got: $stderr_b"
fi
rm -rf "$TMP_B"

# ----------------------------------------------------------------------
# (C) Happy path — active slug + historical slug + project sensor.
# ----------------------------------------------------------------------
HOST_C="$(mktemp -d)"
scaffold_host "$HOST_C"

stage_c="$(cd "$HOST_C" && bash "$HELPER" 2>/dev/null)"
rc_c=$?

[ "$rc_c" -eq 0 ] && [ -n "$stage_c" ] && [ -d "$stage_c" ] \
    && pass "(C) helper exits 0 with absolute path on stdout (got: $stage_c)" \
    || err "(C) helper exit $rc_c; stage='$stage_c'"

# Active-slug files present.
for active_file in \
    "prds/${ACTIVE_SLUG}.md" \
    "specs/${ACTIVE_SLUG}.md" \
    "sprints/${ACTIVE_SLUG}-s01.md" \
    "sprints/${ACTIVE_SLUG}-s02.md" \
    "sprints/${ACTIVE_SLUG}-s03.md" \
    "acceptance-criteria/${ACTIVE_SLUG}.md" \
    "contracts/${ACTIVE_SLUG}.md" \
    "config.yaml" \
    ".gitignore" \
    "runtime/.current" \
    "runtime/progress.md" \
    "runtime/.snapshots/cycle-1.yaml" \
    ; do
    if [ -f "$stage_c/$active_file" ]; then
        pass "(C) staged: $active_file"
    else
        err "(C) MISSING from stage: $active_file"
    fi
done

# Historical-slug files MUST NOT be staged.
for absent_file in \
    "prds/${LEGACY_SLUG}.md" \
    "specs/${LEGACY_SLUG}.md" \
    "sprints/${LEGACY_SLUG}-s01.md" \
    "acceptance-contracts/${LEGACY_SLUG}.md" \
    ; do
    if [ ! -e "$stage_c/$absent_file" ]; then
        pass "(C) historical file NOT staged: $absent_file"
    else
        err "(C) historical file LEAKED into stage: $absent_file"
    fi
done

# Project-scoped sensors MUST NOT be staged.
if [ ! -d "$stage_c/sensors" ] && [ ! -e "$stage_c/sensors/lint.md" ]; then
    pass "(C) sensors/ directory NOT staged (project-scoped, not per-task)"
else
    err "(C) sensors/ leaked into stage at $stage_c/sensors/"
fi

# Total stage file count: 12 (7 active-slug archive files: 1 PRD + 1
# spec + 3 sprints + 1 AC + 1 contracts; 2 dotfiles: config.yaml +
# .gitignore; 3 runtime files: .current + progress.md +
# .snapshots/cycle-1.yaml).
stage_file_count="$(find "$stage_c" -type f 2>/dev/null | wc -l | tr -d ' ')"
if [ "$stage_file_count" -eq 12 ]; then
    pass "(C) stage contains exactly 12 files (no historical bloat)"
else
    err "(C) expected 12 files in stage, got $stage_file_count; tree:
$(find "$stage_c" -type f | sort)"
fi

rm -rf "$stage_c" "$HOST_C"

# ----------------------------------------------------------------------
# (D) Legacy acceptance-contracts/<slug>.md is staged when present.
# ----------------------------------------------------------------------
HOST_D="$(mktemp -d)"
scaffold_host "$HOST_D"
# Add a legacy AC file for the ACTIVE slug (covers the "task started
# pre-v4.0.0 and is now finishing" path).
echo "# legacy active AC" > "$HOST_D/.yoke/acceptance-contracts/${ACTIVE_SLUG}.md"

stage_d="$(cd "$HOST_D" && bash "$HELPER" 2>/dev/null)"

if [ -f "$stage_d/acceptance-contracts/${ACTIVE_SLUG}.md" ]; then
    pass "(D) legacy acceptance-contracts/ staged for active slug when present"
else
    err "(D) legacy acceptance-contracts/${ACTIVE_SLUG}.md missing from stage"
fi

rm -rf "$stage_d" "$HOST_D"

# ----------------------------------------------------------------------
# (E) Empty archive directories pruned. With no contracts/<slug>.md,
# the stage's `contracts/` directory should not exist.
# ----------------------------------------------------------------------
HOST_E="$(mktemp -d)"
scaffold_host "$HOST_E"
rm -f "$HOST_E/.yoke/contracts/${ACTIVE_SLUG}.md"

stage_e="$(cd "$HOST_E" && bash "$HELPER" 2>/dev/null)"

if [ ! -e "$stage_e/contracts" ]; then
    pass "(E) empty contracts/ directory pruned from stage (no per-task file present)"
else
    err "(E) empty contracts/ directory present in stage despite no per-task file"
fi

# acceptance-contracts/ has no per-task file in scaffold_host's default;
# the active slug only has acceptance-criteria/. The stage must NOT
# carry an empty acceptance-contracts/ dir.
if [ ! -e "$stage_e/acceptance-contracts" ]; then
    pass "(E) empty acceptance-contracts/ directory pruned (active slug uses post-v4.0 path)"
else
    err "(E) empty acceptance-contracts/ leaked into stage"
fi

rm -rf "$stage_e" "$HOST_E"

# ----------------------------------------------------------------------
# (F) --slug <slug> overrides .yoke/runtime/.current.
# ----------------------------------------------------------------------
HOST_F="$(mktemp -d)"
scaffold_host "$HOST_F"
# Point .current at a slug that doesn't have any archive files, then
# pass --slug to override.
printf 'someone-else-task' > "$HOST_F/.yoke/runtime/.current.bogus"
# We can't actually point .current at an invalid slug (wm_validate_slug
# will reject it). Instead, point .current at the LEGACY slug and use
# --slug to override to the ACTIVE slug.
printf '%s' "$LEGACY_SLUG" > "$HOST_F/.yoke/runtime/.current"

stage_f="$(cd "$HOST_F" && bash "$HELPER" --slug "$ACTIVE_SLUG" 2>/dev/null)"
rc_f=$?

[ "$rc_f" -eq 0 ] \
    && pass "(F) helper exits 0 with --slug override" \
    || err "(F) helper exit $rc_f"

if [ -f "$stage_f/prds/${ACTIVE_SLUG}.md" ] && [ ! -f "$stage_f/prds/${LEGACY_SLUG}.md" ]; then
    pass "(F) --slug override stages the named slug, not the .current pointer's slug"
else
    err "(F) --slug override did not redirect; staged tree:
$(find "$stage_f" -type f | sort)"
fi

rm -rf "$stage_f" "$HOST_F"

# ----------------------------------------------------------------------
# (G) Stage path is under TMPDIR (or /tmp) — safe to rm -rf.
# ----------------------------------------------------------------------
HOST_G="$(mktemp -d)"
scaffold_host "$HOST_G"
stage_g="$(cd "$HOST_G" && bash "$HELPER" 2>/dev/null)"

tmp_root="${TMPDIR:-/tmp}"
# Resolve symlinks for both since macOS's /tmp is a symlink to /private/tmp.
real_stage="$(cd "$stage_g" && pwd -P)"
real_tmp="$(cd "$tmp_root" && pwd -P)"

case "$real_stage" in
    "$real_tmp"/*)
        pass "(G) stage path lives under TMPDIR ($tmp_root → $real_tmp): $real_stage"
        ;;
    *)
        err "(G) stage path '$real_stage' is NOT under TMPDIR '$real_tmp' — caller cannot safely rm -rf"
        ;;
esac

# rm -rf the stage and confirm host's .yoke/ is intact.
rm -rf "$stage_g"
[ ! -e "$stage_g" ] && pass "(G) stage removed cleanly with rm -rf" \
    || err "(G) stage path still present after rm -rf"

[ -f "$HOST_G/.yoke/prds/${ACTIVE_SLUG}.md" ] \
    && pass "(G) host .yoke/ intact after stage cleanup" \
    || err "(G) host .yoke/ damaged by stage cleanup"

rm -rf "$HOST_G"

harness::summary
