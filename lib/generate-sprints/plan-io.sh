#!/usr/bin/env bash
# plan-io.sh — read/write helpers for the structured intermediate plan
# at .yoke/runtime/.generate-sprints-plan.yaml.
#
# The plan is the contract between the synthesis stage (LLM step) and
# the partition + render stages (deterministic Bash). It is gitignored
# runtime state — never promoted to the versioned archive. Sprint 02
# ships only the empty stub writer + reader; the synthesis stage in
# Sprint 03 mutates the file via `yq -i` in place.
#
# Schema (top-level YAML keys, exactly):
#
#   slug: <slug>
#   generated_at: <iso8601>
#   tasks:
#     - task_id: <slug>-s<NN>-t<MM>
#       realizes_user_stories: [US-001, US-003]
#       applies_decisions: ["<spec-section-anchor>", ...]
#       instructions: |
#         <unified instruction block>
#       sensors: [<sensor-id>, ...]
#       acceptance_criterion: <one binary observable check>
#   sprint_partition:
#     - sprint_id: <slug>-s<NN>
#       delivery_objective: <one paragraph>
#       dod: [<binary check>, ...]
#       task_ids: [<slug>-s<NN>-t01, ...]
#
# Sprint 02 invariant: the empty stub MUST emit `tasks: []` and
# `sprint_partition: []` as YAML empty sequences (`!!seq` per `yq`),
# not as `~` / null. Downstream stages depend on the keys being
# addressable by `yq`.
#
# Error contract: every helper emits `wm:`-prefixed stderr and returns
# non-zero on filesystem errors (missing parent dir, read-only target,
# malformed YAML, etc.).

# Idempotent re-source guard.
if [[ -n "${_GENERATE_SPRINTS_PLAN_IO_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly _GENERATE_SPRINTS_PLAN_IO_LOADED=1

# Path to the structured intermediate plan. The path is fixed (one
# plan per active task; the active task is identified by the `.current`
# pointer + the plan's `slug:` key — there is no per-slug plan suffix,
# matching the singleton runtime state convention).
readonly GENERATE_SPRINTS_PLAN_PATH=".yoke/runtime/.generate-sprints-plan.yaml"
# Scratch directory for intermediate JSON (parser stdout) consumed by
# downstream stages. Gitignored under the same .yoke/runtime/ block.
readonly GENERATE_SPRINTS_TMP_DIR=".yoke/runtime/.generate-sprints-tmp"

# Internal: emit "wm:"-prefixed stderr and return 1.
_gs_io_fail() {
    echo "wm: $1" >&2
    return 1
}

# init_plan_file <slug>
#   Writes the empty plan stub at $GENERATE_SPRINTS_PLAN_PATH:
#     slug: <slug>
#     generated_at: <UTC ISO8601 of "now">
#     tasks: []
#     sprint_partition: []
#   Returns 0 on success; non-zero with `wm:`-prefixed stderr on FS
#   errors. Idempotent: overwrites any pre-existing plan file (the
#   skill's pre-flight clears stale runtime state per the standard
#   .yoke/runtime/ contract).
init_plan_file() {
    local slug="${1:-}"
    if [[ -z "$slug" ]]; then
        _gs_io_fail "init_plan_file requires <slug>"
        return $?
    fi

    local target="$GENERATE_SPRINTS_PLAN_PATH"
    local parent
    parent="$(dirname "$target")"
    if ! mkdir -p "$parent" 2>/dev/null; then
        _gs_io_fail "failed to create parent directory: $parent"
        return $?
    fi

    local now_iso
    now_iso="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

    # Emit a literal YAML stub. The empty arrays use the inline `[]`
    # form so `yq '.tasks | type'` returns `!!seq` (not `!!null`).
    if ! cat > "$target" <<EOF
slug: $slug
generated_at: $now_iso
tasks: []
sprint_partition: []
EOF
    then
        _gs_io_fail "failed to write plan file: $target"
        return $?
    fi

    return 0
}

# read_plan_file [<slug>]
#   Loads $GENERATE_SPRINTS_PLAN_PATH and emits its contents on stdout.
#   When <slug> is provided, asserts the plan's `slug:` key matches
#   (cross-check against accidentally reading a stale plan from a
#   prior task). Returns 0 on success; non-zero with `wm:`-prefixed
#   stderr on missing file, malformed YAML, or slug mismatch.
read_plan_file() {
    local slug="${1:-}"

    local target="$GENERATE_SPRINTS_PLAN_PATH"
    if [[ ! -f "$target" ]]; then
        _gs_io_fail "plan file not found: $target"
        return $?
    fi

    if [[ -n "$slug" ]]; then
        # Cross-check the slug key. Use yq when available; fall back
        # to a grep-based extraction on the canonical 1-line shape
        # that init_plan_file emits.
        local actual_slug=""
        if command -v yq >/dev/null 2>&1; then
            actual_slug="$(yq -r '.slug // ""' "$target" 2>/dev/null || true)"
        fi
        if [[ -z "$actual_slug" || "$actual_slug" == "null" ]]; then
            actual_slug="$(awk '/^slug:[[:space:]]+/ { sub(/^slug:[[:space:]]+/, "", $0); print; exit }' "$target")"
        fi
        if [[ "$actual_slug" != "$slug" ]]; then
            _gs_io_fail "plan slug mismatch: expected '$slug', got '$actual_slug' in $target"
            return $?
        fi
    fi

    cat "$target"
    return 0
}

# ensure_plan_tmp_dir
#   Creates $GENERATE_SPRINTS_TMP_DIR if missing. The skill's
#   Read-inputs stage stores parser stdout under this directory for
#   later stages; the directory itself is gitignored under the same
#   .yoke/runtime/ tree.
ensure_plan_tmp_dir() {
    if ! mkdir -p "$GENERATE_SPRINTS_TMP_DIR" 2>/dev/null; then
        _gs_io_fail "failed to create tmp directory: $GENERATE_SPRINTS_TMP_DIR"
        return $?
    fi
    return 0
}
