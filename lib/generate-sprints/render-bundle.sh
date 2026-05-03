#!/usr/bin/env bash
# render-bundle.sh — Stage 5 helper that materialises one
# `.yoke/sprints/<slug>-s<NN>.md` runtime bundle per `sprint_partition`
# entry of `.yoke/runtime/.generate-sprints-plan.yaml`.
#
# Render is intentionally LLM-free: the synthesis stage authored the
# task instructions; the partition stage assigned final task ids and
# delivery objectives; this stage performs the deterministic placeholder
# substitution against `templates/sprint.md` plus the body fill from
# the partitioned plan.
#
# I/O contract:
#   - Caller: `render_sprint_bundle <slug> <sprint_num> <plan-yaml-path>`
#       Reads the matching `sprint_partition` entry from the plan,
#       resolves the target path via `wm_sprint_path`, performs the
#       four placeholder substitutions on `templates/sprint.md`, fills
#       the five body sections (Sprint objective, Sprint DoD, Tasks,
#       Functional acceptance criteria, Sensors), writes the file,
#       then validates the post-write shape (5 H2 headings present and
#       ordered). Exits 0 on success; non-zero with `wm:`-prefixed
#       stderr on any failure (missing plan, missing partition entry,
#       missing template, frontmatter / shape violation).
#
#   - Caller: `render_all_bundles <slug> <plan-yaml-path>`
#       Convenience wrapper that iterates over every `sprint_partition`
#       entry and calls `render_sprint_bundle` for each. Emits one
#       `wm:` info line per produced file on stderr. Returns the first
#       non-zero rc encountered (fail-fast).
#
# Body shape produced for each task subsection (matches
# `templates/sprint.md` exactly):
#
#   ### Task <slug>-s<NN>-t<MM>
#
#   **Story:** <story> (Realizes: US-NNN[, US-MMM])
#
#   **Technical implementation:** <instructions>
#
#   **Validation:** <validation>
#
#   **Acceptance criterion:** <acceptance_criterion>
#
# `instructions` from the synthesis stage is split into a
# Story / Technical implementation / Validation triple at render time
# — the synthesis emits a single unified block (FR-1 of the binding
# AC: no per-persona forks) but the produced sprint file's per-task
# subsection requires the four-label shape per AC-005-1 and the
# `templates/sprint.md` contract. The split is a documented projection
# (Story = first paragraph; Validation = last paragraph; Technical
# implementation = remainder); when the synthesis-stage task carries
# explicit `story` / `validation` keys those override the projection
# (the synthesis stage MAY include them for richer rendering — see
# `skills/generate-sprints/SKILL.md` Stage 3 contract).
#
# Tests: `tests/runtime/render-bundle.test.sh` (happy-path unit, owned
# by Sr Eng); `tests/smoke/render-bundle-shape.test.sh` (acceptance,
# owned by Sr QA).

# Idempotent re-source guard.
if [[ -n "${_GENERATE_SPRINTS_RENDER_BUNDLE_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly _GENERATE_SPRINTS_RENDER_BUNDLE_LOADED=1

# Internal: emit "wm:"-prefixed stderr and return 1.
_gs_render_fail() {
    echo "wm: $1" >&2
    return 1
}

# Resolve the plugin root so render_sprint_bundle can locate
# templates/sprint.md regardless of the caller's CWD.
_GS_RENDER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_GS_RENDER_PLUGIN_ROOT="$(cd "${_GS_RENDER_SCRIPT_DIR}/../.." && pwd)"

# render_sprint_bundle <slug> <sprint_num> <plan-yaml-path>
#   Writes `.yoke/sprints/<slug>-s<NN>.md` from the matching
#   sprint_partition entry of <plan-yaml-path>. Validates the post-
#   write shape. Returns 0 on success; non-zero with `wm:`-prefixed
#   stderr on failure.
render_sprint_bundle() {
    local slug="${1:-}"
    local sprint_num="${2:-}"
    local plan_path="${3:-}"

    if [[ -z "$slug" || -z "$sprint_num" || -z "$plan_path" ]]; then
        _gs_render_fail "render_sprint_bundle requires <slug> <sprint_num> <plan-yaml-path>"
        return $?
    fi
    if [[ ! -f "$plan_path" ]]; then
        _gs_render_fail "plan file not found: $plan_path"
        return $?
    fi

    local template_path="${_GS_RENDER_PLUGIN_ROOT}/templates/sprint.md"
    if [[ ! -f "$template_path" ]]; then
        _gs_render_fail "sprint template not found: $template_path"
        return $?
    fi

    # Resolve target path via wm_sprint_path; the caller is responsible
    # for sourcing lib/working-memory/paths.sh before invoking us.
    if ! command -v wm_sprint_path >/dev/null 2>&1; then
        _gs_render_fail "wm_sprint_path helper unavailable; source lib/working-memory/paths.sh"
        return $?
    fi
    local target_path
    target_path="$(wm_sprint_path "$slug" "$sprint_num")" || return 1

    mkdir -p "$(dirname "$target_path")"

    # Render via python3: the body assembly is more robust as a single
    # template-fill pass than as nested bash heredocs.
    local rendered
    rendered="$(python3 - \
        "$slug" \
        "$sprint_num" \
        "$plan_path" \
        "$template_path" \
        2>&1 <<'PY'
import json
import re
import sys

try:
    import yaml
except Exception as exc:
    print(f"wm: PyYAML unavailable: {exc}", file=sys.stderr)
    sys.exit(1)

slug, sprint_num_raw, plan_path, template_path = sys.argv[1:5]
sprint_num = int(sprint_num_raw)
sprint_padded = f"{sprint_num:02d}"
sprint_id = f"{slug}-s{sprint_padded}"

try:
    with open(plan_path, encoding="utf-8") as f:
        plan = yaml.safe_load(f) or {}
except Exception as exc:
    print(f"wm: failed to parse plan YAML at {plan_path}: {exc}", file=sys.stderr)
    sys.exit(1)

partition = plan.get("sprint_partition", []) or []
entry = None
for cand in partition:
    if cand.get("sprint_id") == sprint_id:
        entry = cand
        break
if entry is None:
    print(
        f"wm: sprint_partition entry not found for '{sprint_id}' in {plan_path}",
        file=sys.stderr,
    )
    sys.exit(1)

task_ids = entry.get("task_ids", []) or []
if not task_ids:
    print(f"wm: sprint '{sprint_id}' has zero tasks", file=sys.stderr)
    sys.exit(1)

# Index tasks by final id.
all_tasks = plan.get("tasks", []) or []
task_by_id = {t.get("task_id"): t for t in all_tasks if isinstance(t, dict)}

sprint_tasks = []
for tid in task_ids:
    task = task_by_id.get(tid)
    if task is None:
        print(
            f"wm: task '{tid}' referenced by sprint '{sprint_id}' missing from plan tasks",
            file=sys.stderr,
        )
        sys.exit(1)
    sprint_tasks.append(task)

# --- Compute aggregate sets ---------------------------------------------

# Functional acceptance criteria: union of US-IDs realized by tasks in
# this sprint, deduplicated and sorted ascending for stability.
fac_set = []
for t in sprint_tasks:
    for us in t.get("realizes_user_stories", []) or []:
        if us not in fac_set:
            fac_set.append(us)
fac_set = sorted(fac_set)

# Sensors: union of sensor IDs the synthesis attached to each task,
# deduplicated and sorted ascending.
sensors_set = []
for t in sprint_tasks:
    for s in t.get("sensors", []) or []:
        if s not in sensors_set:
            sensors_set.append(s)
sensors_set = sorted(sensors_set)

# --- Read template and apply placeholder substitution -------------------

try:
    with open(template_path, encoding="utf-8") as f:
        template = f.read()
except Exception as exc:
    print(f"wm: failed to read template: {exc}", file=sys.stderr)
    sys.exit(1)

# Compute UTC ISO8601 timestamp.
import datetime as _dt
now_iso = _dt.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

# Apply the four documented substitutions. Order matters: longer /
# more specific substitutions first so they don't get clobbered by
# shorter ones.
body = template
body = body.replace("<slug>-s<NN>", sprint_id)
body = body.replace("<slug>", slug)
body = body.replace("<NN>", sprint_padded)
body = body.replace("<N>", str(sprint_num))
body = body.replace("<iso8601>", now_iso)

# --- Frontmatter rewrite ------------------------------------------------
#
# The template's frontmatter carries placeholder defaults for `status`,
# `model`, `traceability`, `Migrated-from`. We finalise:
#   - status         := "draft"        (Trigger 2.5 flips to approved)
#   - model          := <env-derived>  (best-effort; CLAUDE_MODEL or "")
#   - traceability   := "<spec_path>; <ac_path>"   (semicolon-joined)
#   - Migrated-from  := []              (always empty for new bundles)

spec_path_str = f".yoke/specs/{slug}.md"
ac_path_str = f".yoke/acceptance-criteria/{slug}.md"
traceability = f"{spec_path_str}; {ac_path_str}"

# Detect frontmatter span (between leading '---' and the next '---').
lines = body.split("\n")
if not lines or lines[0].strip() != "---":
    print("wm: rendered body has no opening frontmatter delimiter", file=sys.stderr)
    sys.exit(1)
fm_end = None
for i in range(1, len(lines)):
    if lines[i].strip() == "---":
        fm_end = i
        break
if fm_end is None:
    print("wm: rendered body has no closing frontmatter delimiter", file=sys.stderr)
    sys.exit(1)

import os
model_id = os.environ.get("CLAUDE_MODEL", "") or os.environ.get("MODEL", "")

new_fm = []
for i in range(1, fm_end):
    line = lines[i]
    if line.startswith("status:"):
        new_fm.append("status: draft")
    elif line.startswith("model:"):
        if model_id:
            new_fm.append(f"model: {model_id}")
        else:
            new_fm.append('model: ""')
    elif line.startswith("traceability:"):
        new_fm.append(f'traceability: "{traceability}"')
    elif line.startswith("Migrated-from:"):
        new_fm.append("Migrated-from: []")
    else:
        new_fm.append(line)

body = "---\n" + "\n".join(new_fm) + "\n---\n" + "\n".join(lines[fm_end + 1:])

# --- Body section fill --------------------------------------------------
#
# The template body has placeholder content under each H2. We rewrite
# the body section by section using a state-machine walk over the
# post-frontmatter lines.

post_fm_idx = body.find("\n---\n") + len("\n---\n")
header = body[:post_fm_idx]
rest = body[post_fm_idx:]

# Build the new body.
def render_tasks_section(sprint_tasks):
    chunks = []
    for task in sprint_tasks:
        tid = task["task_id"]
        rus = task.get("realizes_user_stories", []) or []
        rus_clause = f"(Realizes: {', '.join(rus)})"

        # Story projection: when the synthesis emitted explicit `story`,
        # use it; otherwise project from the first non-empty paragraph
        # of `instructions`. The Realizes clause is appended adjacent
        # to the Story line (same line, parenthesized) per AC-005-3.
        story = task.get("story")
        if not story:
            instructions = task.get("instructions", "") or ""
            paragraphs = [p.strip() for p in instructions.split("\n\n") if p.strip()]
            story = paragraphs[0] if paragraphs else "(no story provided)"

        validation = task.get("validation")
        if not validation:
            instructions = task.get("instructions", "") or ""
            paragraphs = [p.strip() for p in instructions.split("\n\n") if p.strip()]
            validation = paragraphs[-1] if len(paragraphs) > 1 else "(no validation provided)"

        # Technical implementation: middle paragraphs (or the entire
        # instructions block when there's only one paragraph).
        tech = task.get("technical_implementation")
        if not tech:
            instructions = task.get("instructions", "") or ""
            paragraphs = [p.strip() for p in instructions.split("\n\n") if p.strip()]
            if len(paragraphs) <= 2:
                tech = instructions.strip() or "(no technical implementation provided)"
            else:
                tech = "\n\n".join(paragraphs[1:-1])

        crit = task.get("acceptance_criterion", "") or "(no acceptance criterion)"

        chunks.append(
            f"### Task {tid}\n\n"
            f"**Story:** {story.strip()} {rus_clause}\n\n"
            f"**Technical implementation:** {tech.strip()}\n\n"
            f"**Validation:** {validation.strip()}\n\n"
            f"**Acceptance criterion:** {crit.strip()}\n"
        )
    return "\n".join(chunks)

def render_bullets(items):
    if not items:
        return "- (none)"
    return "\n".join(f"- {it}" for it in items)

delivery_objective = entry.get("delivery_objective", "") or "(no delivery objective)"
sprint_dod_items = entry.get("dod", []) or []

# Build the body anew with the canonical 5 H2 sections in fixed order.
# We reuse the substituted-template heading line (`# Sprint <NN>...`)
# and the leading blockquote prologue from the template post-fm
# region; everything from the first `## Sprint objective` onward is
# replaced.
m = re.search(r"^## Sprint objective\s*$", rest, flags=re.MULTILINE)
if not m:
    print("wm: rendered body missing '## Sprint objective' anchor", file=sys.stderr)
    sys.exit(1)
prologue = rest[:m.start()]

new_body = (
    f"## Sprint objective\n\n"
    f"{delivery_objective}\n\n"
    f"## Sprint DoD\n\n"
    f"{render_bullets(sprint_dod_items)}\n\n"
    f"## Tasks\n\n"
    f"{render_tasks_section(sprint_tasks)}\n"
    f"## Functional acceptance criteria\n\n"
    f"{render_bullets(fac_set)}\n\n"
    f"## Sensors\n\n"
    f"{render_bullets(sensors_set)}\n\n"
    f"---\n\n"
    f"> Generated by `/yoke:generate-sprints` (Stage 5) from "
    f"`.yoke/runtime/.generate-sprints-plan.yaml`. Status flips to "
    f"`approved` when Trigger 2.5 ratifies the sprint plan.\n"
)

final_body = header + prologue + new_body

# --- Post-write shape validation ----------------------------------------
#
# Assert the 5 H2 headings are present in fixed order before writing
# (so a render bug fails fast and never leaves a malformed file on
# disk).
required_h2 = [
    "## Sprint objective",
    "## Sprint DoD",
    "## Tasks",
    "## Functional acceptance criteria",
    "## Sensors",
]
last_pos = -1
for heading in required_h2:
    idx = final_body.find(heading)
    if idx == -1:
        print(
            f"wm: render shape violation at <pre-write>: missing heading {heading}",
            file=sys.stderr,
        )
        sys.exit(1)
    if idx <= last_pos:
        print(
            f"wm: render shape violation at <pre-write>: heading order broken at {heading}",
            file=sys.stderr,
        )
        sys.exit(1)
    last_pos = idx

print(final_body, end="")
PY
    )"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        if [[ -n "$rendered" ]]; then
            printf '%s\n' "$rendered" >&2
        fi
        return 1
    fi

    # Write the rendered body to the target path atomically (write
    # to a sibling temp then rename). Atomicity matters because the
    # Trigger 2.5 approve flow flips frontmatter status on every
    # produced file in a single sweep — a half-written render would
    # leave a corrupt bundle on disk.
    local tmp_path="${target_path}.tmp.$$"
    if ! printf '%s' "$rendered" > "$tmp_path"; then
        _gs_render_fail "failed to write temp file: $tmp_path"
        return $?
    fi
    if ! mv -f "$tmp_path" "$target_path"; then
        rm -f "$tmp_path" 2>/dev/null || true
        _gs_render_fail "failed to rename $tmp_path -> $target_path"
        return $?
    fi

    # Post-write shape validation: re-read the file and assert the 5
    # required H2 headings are present and ordered. Mirror the pre-
    # write check defensively (filesystems can corrupt; the cost of
    # the duplicate check is negligible).
    local h2_check_rc
    h2_check_rc="$(python3 - "$target_path" 2>&1 <<'PY'
import sys
required = [
    "## Sprint objective",
    "## Sprint DoD",
    "## Tasks",
    "## Functional acceptance criteria",
    "## Sensors",
]
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        body = f.read()
except Exception as exc:
    print(f"wm: render shape violation at {path}: failed to read post-write: {exc}",
          file=sys.stderr)
    sys.exit(1)
last_pos = -1
for heading in required:
    idx = body.find(heading)
    if idx == -1:
        print(f"wm: render shape violation at {path}: missing heading {heading}",
              file=sys.stderr)
        sys.exit(1)
    if idx <= last_pos:
        print(f"wm: render shape violation at {path}: heading order broken at {heading}",
              file=sys.stderr)
        sys.exit(1)
    last_pos = idx
PY
    )"
    local check_rc=$?
    if [[ $check_rc -ne 0 ]]; then
        if [[ -n "$h2_check_rc" ]]; then
            printf '%s\n' "$h2_check_rc" >&2
        fi
        # Remove the malformed file so re-runs don't leave drift.
        rm -f "$target_path" 2>/dev/null || true
        return 1
    fi

    echo "wm: rendered $target_path" >&2
    return 0
}

# render_all_bundles <slug> <plan-yaml-path>
#   Iterates over every sprint_partition entry in the plan and calls
#   render_sprint_bundle for each. Fail-fast: returns the first non-
#   zero rc encountered; later sprints are not rendered.
render_all_bundles() {
    local slug="${1:-}"
    local plan_path="${2:-}"

    if [[ -z "$slug" || -z "$plan_path" ]]; then
        _gs_render_fail "render_all_bundles requires <slug> <plan-yaml-path>"
        return $?
    fi
    if [[ ! -f "$plan_path" ]]; then
        _gs_render_fail "plan file not found: $plan_path"
        return $?
    fi

    # Extract sprint numbers from the plan's sprint_partition array.
    local sprint_nums
    sprint_nums="$(python3 - "$plan_path" "$slug" 2>&1 <<'PY'
import re
import sys
try:
    import yaml
except Exception as exc:
    print(f"wm: PyYAML unavailable: {exc}", file=sys.stderr)
    sys.exit(1)
plan_path, slug = sys.argv[1:3]
try:
    with open(plan_path, encoding="utf-8") as f:
        plan = yaml.safe_load(f) or {}
except Exception as exc:
    print(f"wm: failed to parse plan YAML at {plan_path}: {exc}", file=sys.stderr)
    sys.exit(1)
partition = plan.get("sprint_partition", []) or []
if not partition:
    print("wm: sprint_partition is empty; run partition stage first", file=sys.stderr)
    sys.exit(1)
sid_re = re.compile(rf"^{re.escape(slug)}-s(\d{{2}})$")
nums = []
for entry in partition:
    sid = entry.get("sprint_id", "")
    m = sid_re.match(sid)
    if not m:
        print(f"wm: invalid sprint_id '{sid}' (expected '{slug}-sNN')", file=sys.stderr)
        sys.exit(1)
    nums.append(int(m.group(1)))
print("\n".join(str(n) for n in nums))
PY
    )"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        if [[ -n "$sprint_nums" ]]; then
            printf '%s\n' "$sprint_nums" >&2
        fi
        return 1
    fi

    local n
    while IFS= read -r n; do
        [[ -z "$n" ]] && continue
        render_sprint_bundle "$slug" "$n" "$plan_path" || return 1
    done <<< "$sprint_nums"

    return 0
}
