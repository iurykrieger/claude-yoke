#!/usr/bin/env bash
# parse-inputs.sh — input parsers for /yoke:generate-sprints.
#
# Two helpers consumed by the skill's "Read inputs" stage:
#   - parse_acceptance_criteria <ac-path>
#       Walks a ratified Acceptance Criteria file and emits a JSON
#       object on stdout shaped:
#         {
#           "user_stories": [
#             {
#               "id": "US-001",
#               "title": "...",
#               "story": "...",
#               "dod": ["item 1", ...],
#               "acceptance_criteria": [
#                 {"id": "AC-001-1", "text": "..."},
#                 ...
#               ]
#             },
#             ...
#           ],
#           "functional_requirements": [
#             {"id": "FR-1", "text": "..."},
#             ...
#           ],
#           "sensor_pool": ["tests-smoke", ...]
#         }
#       Anchors on the canonical post-rename shape: `### US-<NNN> — <title>`
#       headings, with `#### Definition of Done` / `#### Acceptance
#       Criteria` sub-sections containing bullet lists; cross-cutting
#       `## Functional Requirements` and `## Sensor pool` sections at
#       the document level. The legacy `### UC-<n>` shape is rejected
#       (the binding AC mandates US-NNN).
#
#   - parse_spec_architecture <spec-path>
#       Walks an approved Tech Spec file and emits a JSON object on
#       stdout shaped:
#         {
#           "objective": "<one paragraph>",
#           "contracts": ["<bullet 1>", ...],
#           "dependencies": {
#             "external_services": ["<bullet>", ...],
#             "internal_prior_work": ["<bullet>", ...],
#             "cross_team_coordination": ["<bullet>", ...]
#           }
#         }
#
# Both helpers exit non-zero with `wm:`-prefixed stderr on parse
# failure (missing input file, malformed structure). Smoke tests under
# tests/runtime/parse-inputs.test.sh exercise both helpers.

# Idempotent re-source guard.
if [[ -n "${_GENERATE_SPRINTS_PARSE_INPUTS_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly _GENERATE_SPRINTS_PARSE_INPUTS_LOADED=1

# Internal: emit "wm:"-prefixed stderr and return 1.
_gs_parse_fail() {
    echo "wm: $1" >&2
    return 1
}

# parse_acceptance_criteria <ac-path>
#   Returns 0 + JSON on stdout on success; non-zero with stderr on failure.
parse_acceptance_criteria() {
    local ac_path="${1:-}"
    if [[ -z "$ac_path" ]]; then
        _gs_parse_fail "parse_acceptance_criteria requires <ac-path>"
        return $?
    fi
    if [[ ! -f "$ac_path" ]]; then
        _gs_parse_fail "acceptance-criteria file not found: $ac_path"
        return $?
    fi

    # Use python3 for JSON output (no jq dependency, deterministic
    # escaping, and the AC parser's section walk is naturally
    # expressed as a state machine).
    local out
    out="$(python3 - "$ac_path" 2>&1 <<'PY'
import json
import re
import sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()
except Exception as exc:  # pragma: no cover
    print(f"wm: failed to read {path}: {exc}", file=sys.stderr)
    sys.exit(1)

us_heading_re = re.compile(r"^###\s+US-(\d{3})\s*(?:[—-]\s*)?(.*)$")
ac_heading_re = re.compile(r"^####\s+Acceptance Criteria\s*$")
dod_heading_re = re.compile(r"^####\s+Definition of Done\s*$")
ac_item_re = re.compile(
    r"^[-*]\s+\*\*(AC-\d{3}-\d+):\*\*\s*(.+?)\s*$"
)
dod_item_re = re.compile(r"^[-*]\s+\[[ xX]\]\s+(.+?)\s*$")
fr_section_re = re.compile(r"^##\s+Functional Requirements\s*$")
fr_item_re = re.compile(
    r"^[-*]\s+\*\*(FR-\d+):\*\*\s*(.+?)\s*$"
)
sensor_section_re = re.compile(r"^##\s+Sensor pool\s*$")
section_break_re = re.compile(r"^##\s+\S")
sensor_item_re = re.compile(r"^[-*]\s+([a-z0-9][a-z0-9_.-]{0,63})\s*$")

user_stories = []
frs = []
sensors = []

state = "outside"
current_us = None
current_subsection = None  # "dod" | "ac" | None

# Reject legacy UC-shape early so the caller sees a precise diagnostic.
joined = "".join(lines)
if re.search(r"^###\s+UC-\d+", joined, re.MULTILINE):
    print(
        "wm: legacy UC-N shape detected in acceptance-criteria; "
        "expected US-NNN per binding AC",
        file=sys.stderr,
    )
    sys.exit(1)

for raw in lines:
    line = raw.rstrip("\n")

    # Detect cross-cutting sections. Flush any in-flight US block first.
    if fr_section_re.match(line):
        if current_us is not None:
            user_stories.append(current_us)
            current_us = None
        state = "frs"
        current_subsection = None
        continue
    if sensor_section_re.match(line):
        if current_us is not None:
            user_stories.append(current_us)
            current_us = None
        state = "sensors"
        current_subsection = None
        continue

    # Top-level section break exits cross-cutting state.
    if state in ("frs", "sensors") and section_break_re.match(line):
        if not (fr_section_re.match(line) or sensor_section_re.match(line)):
            state = "outside"

    # User story heading (US-NNN).
    m_us = us_heading_re.match(line)
    if m_us:
        if current_us is not None:
            user_stories.append(current_us)
        us_id = f"US-{m_us.group(1)}"
        title = m_us.group(2).strip()
        current_us = {
            "id": us_id,
            "title": title,
            "story": "",
            "dod": [],
            "acceptance_criteria": [],
        }
        current_subsection = None
        state = "us"
        continue

    if state == "us" and current_us is not None:
        if dod_heading_re.match(line):
            current_subsection = "dod"
            continue
        if ac_heading_re.match(line):
            current_subsection = "ac"
            continue

        if current_subsection == "dod":
            m = dod_item_re.match(line)
            if m:
                current_us["dod"].append(m.group(1).strip())
                continue
        elif current_subsection == "ac":
            m = ac_item_re.match(line)
            if m:
                current_us["acceptance_criteria"].append({
                    "id": m.group(1),
                    "text": m.group(2).strip(),
                })
                continue
        else:
            # Pre-subsection prose: capture as the story sentence.
            stripped = line.strip()
            if stripped and not stripped.startswith("#"):
                if not current_us["story"]:
                    current_us["story"] = stripped

    if state == "frs":
        m = fr_item_re.match(line)
        if m:
            frs.append({"id": m.group(1), "text": m.group(2).strip()})
            continue

    if state == "sensors":
        m = sensor_item_re.match(line)
        if m:
            sensors.append(m.group(1))
            continue

# Flush trailing user story.
if current_us is not None:
    user_stories.append(current_us)

if not user_stories:
    print(
        "wm: no US-NNN headings found in acceptance-criteria",
        file=sys.stderr,
    )
    sys.exit(1)

# Validate each US has DoD + AC populated (binding-AC invariant).
for us in user_stories:
    if not us["dod"]:
        print(
            f"wm: malformed US block: {us['id']} missing Definition of Done",
            file=sys.stderr,
        )
        sys.exit(1)
    if not us["acceptance_criteria"]:
        print(
            f"wm: malformed US block: {us['id']} missing Acceptance Criteria",
            file=sys.stderr,
        )
        sys.exit(1)

payload = {
    "user_stories": user_stories,
    "functional_requirements": frs,
    "sensor_pool": sensors,
}
json.dump(payload, sys.stdout, indent=2, sort_keys=False)
print()
PY
    )"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        # python3 already wrote the diagnostic to stderr; the captured
        # `out` may be empty or carry a stderr-merged tail. Surface
        # whatever made it through and propagate the failure.
        if [[ -n "$out" ]]; then
            printf '%s\n' "$out" >&2
        fi
        return 1
    fi
    printf '%s\n' "$out"
    return 0
}

# parse_spec_architecture <spec-path>
#   Returns 0 + JSON on stdout on success; non-zero with stderr on failure.
parse_spec_architecture() {
    local spec_path="${1:-}"
    if [[ -z "$spec_path" ]]; then
        _gs_parse_fail "parse_spec_architecture requires <spec-path>"
        return $?
    fi
    if [[ ! -f "$spec_path" ]]; then
        _gs_parse_fail "spec file not found: $spec_path"
        return $?
    fi

    local out
    out="$(python3 - "$spec_path" 2>&1 <<'PY'
import json
import re
import sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()
except Exception as exc:  # pragma: no cover
    print(f"wm: failed to read {path}: {exc}", file=sys.stderr)
    sys.exit(1)

objective_re = re.compile(r"^##\s+Overall objective\s*$")
contracts_re = re.compile(r"^##\s+Contracts and interfaces\s*$")
dependencies_re = re.compile(r"^##\s+Dependencies\s*$")
section_break_re = re.compile(r"^##\s+\S")
sub_section_re = re.compile(r"^###\s+(.+?)\s*$")
bullet_re = re.compile(r"^-\s+(.+?)\s*$")

state = None
sub_state = None
objective_lines = []
contracts = []
dependencies = {
    "external_services": [],
    "internal_prior_work": [],
    "cross_team_coordination": [],
}

dep_section_map = {
    "External services and libraries": "external_services",
    "Internal prior work": "internal_prior_work",
    "Cross-team coordination": "cross_team_coordination",
}

for raw in lines:
    line = raw.rstrip("\n")

    if objective_re.match(line):
        state = "objective"
        sub_state = None
        continue
    if contracts_re.match(line):
        state = "contracts"
        sub_state = None
        continue
    if dependencies_re.match(line):
        state = "dependencies"
        sub_state = None
        continue
    if section_break_re.match(line) and not (
        objective_re.match(line)
        or contracts_re.match(line)
        or dependencies_re.match(line)
    ):
        state = None
        sub_state = None
        continue

    if state == "objective":
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            objective_lines.append(stripped)
        continue

    if state == "contracts":
        m = bullet_re.match(line)
        if m:
            # Collapse the first 120 chars of the bullet head as the
            # contract summary; the full body is preserved by the
            # caller via the spec file path.
            head = m.group(1).strip()
            contracts.append(head[:240])
        continue

    if state == "dependencies":
        m_sub = sub_section_re.match(line)
        if m_sub:
            sub_state = dep_section_map.get(m_sub.group(1).strip())
            continue
        if sub_state is not None:
            m = bullet_re.match(line)
            if m:
                head = m.group(1).strip()
                dependencies[sub_state].append(head[:240])

if not objective_lines:
    print(
        "wm: spec missing '## Overall objective' section or its body",
        file=sys.stderr,
    )
    sys.exit(1)

payload = {
    "objective": " ".join(objective_lines),
    "contracts": contracts,
    "dependencies": dependencies,
}
json.dump(payload, sys.stdout, indent=2, sort_keys=False)
print()
PY
    )"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        if [[ -n "$out" ]]; then
            printf '%s\n' "$out" >&2
        fi
        return 1
    fi
    printf '%s\n' "$out"
    return 0
}
