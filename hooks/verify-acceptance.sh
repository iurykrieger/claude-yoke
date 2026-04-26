#!/bin/bash
# verify-acceptance.sh — runs the sensors declared in the active task's
# Acceptance Contract and emits structured per-criterion results.
#
# Usage: verify-acceptance.sh [<acceptance-contract-path>]
# Default path: resolved via lib/working-memory/paths.sh::wm_acceptance_contract_path
#               (i.e., .yoke/acceptance-contracts/<slug>.md, where <slug> comes
#               from .yoke/.current).
#
# Sensors are extracted from the "## Sensors > ### Computational" section
# of the Acceptance Contract; the Validator (Sprint 3) writes them in this
# shape:
#
#   ## Sensors
#
#   ### Computational
#   - linter: `npm run lint`
#   - type-check: `mypy --strict` (timeout: 90s)
#   - structural: `pytest tests/contracts/`
#   - unit: `pytest tests/unit/`
#
# Each bullet's first backticked segment is the command Yoke will run.
# An optional "(timeout: <Ns>)" suffix on a bullet overrides the default
# 60-second per-sensor timeout for that sensor (computational only;
# inferential timeouts live in the Validator's Agent spawn).
#
# Discovery is delegated to `lib/sensors/ack-sensors.sh --mode readiness`
# (single source of truth — same parser used by the Validator subagent at
# runtime). This hook is the **synchronous fallback** path used by CI and
# headless callers; the Validator subagent uses the parallel-spawn
# protocol documented in agents/validator.md and patterns/sensors.md.
#
# Output (YAML to stdout):
#
#   results:
#     - sensor: "linter"
#       command: "npm run lint"
#       status: pass | fail | skip
#       exit_code: <int>
#       output_excerpt: "<first ~5 non-empty lines, joined with \n>"
#       reason: "<why skip, when applicable>"
#
# Exit codes:
#   0 — verification ran (regardless of individual sensor outcomes)
#   2 — usage error
#   3 — Acceptance Contract not found
#   4 — Acceptance Contract has no Sensors > Computational section
#
# Per-sensor timeout:
#   default 60s for computational sensors. Override per-sensor with a
#   "(timeout: <Ns>)" suffix on the bullet (e.g.,
#   `- type-check: \`mypy --strict\` (timeout: 90s)`). Timeout fires emit
#   status=skip, exit_code=124 (GNU `timeout` convention),
#   reason="timeout: <Ns>s".

set -euo pipefail

DEFAULT_COMPUTATIONAL_TIMEOUT=60

# Locate paths helper relative to this hook (so cwd doesn't matter).
hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/working-memory/paths.sh
source "${hook_dir}/../lib/working-memory/paths.sh"

# Resolve contract: explicit arg or active-task default.
if [ -n "${1:-}" ]; then
  contract="$1"
else
  contract="$(wm_acceptance_contract_path)" || exit 3
fi

if [ ! -f "$contract" ]; then
  echo "Error: Acceptance Contract not found at '$contract'." >&2
  exit 3
fi

# Delegate discovery + reachability to /yoke:ack-sensors --mode readiness
# (single source of truth). The skill exits 4 when any sensor is
# unreachable; capture stdout regardless and parse its YAML to know what
# to run vs. skip.
ack_sensors="${hook_dir}/../lib/sensors/ack-sensors.sh"
if [ ! -f "$ack_sensors" ]; then
  echo "Error: ack-sensors helper not found at '$ack_sensors'." >&2
  exit 2
fi

set +e
readiness_out="$(bash "$ack_sensors" --mode readiness "$contract" 2>/dev/null)"
readiness_code=$?
set -e

# 0 = all reachable; 4 = some unreachable (still proceed); other = bail.
if [ "$readiness_code" -ne 0 ] && [ "$readiness_code" -ne 4 ]; then
  echo "Error: ack-sensors readiness returned exit ${readiness_code}." >&2
  exit "$readiness_code"
fi

# Extract the "Computational" sensors block under "## Sensors" (used to
# pull (timeout: Ns) overrides per sensor; readiness mode does not
# surface timeouts in v0.4.0).
sensors_block=$(awk '
  /^## Sensors[[:space:]]*$/ { in_sensors = 1; next }
  in_sensors && /^## / && !/^## Sensors/ { in_sensors = 0 }
  in_sensors && /^### Computational[[:space:]]*$/ { in_comp = 1; next }
  in_sensors && in_comp && /^### / { in_comp = 0 }
  in_sensors && in_comp { print }
' "$contract")

if [ -z "$sensors_block" ]; then
  echo "Error: Acceptance Contract has no '## Sensors > ### Computational' section." >&2
  exit 4
fi

# Build a name → timeout-override map by parsing bullet lines for
# "(timeout: <Ns>)" suffixes.
declare -A SENSOR_TIMEOUT
while IFS= read -r line; do
  [ -z "$line" ] && continue
  if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+([^:]+):[[:space:]]*\`([^\`]+)\`(.*)$ ]]; then
    bullet_name="$(echo "${BASH_REMATCH[1]}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    bullet_tail="${BASH_REMATCH[3]}"
    if [[ "$bullet_tail" =~ \(timeout:[[:space:]]*([0-9]+)s?\) ]]; then
      SENSOR_TIMEOUT["$bullet_name"]="${BASH_REMATCH[1]}"
    fi
  fi
done <<< "$sensors_block"

# Parse readiness YAML into parallel arrays. Each sensor record under the
# `sensors:` section is 4 lines:
#   - sensor: "<name>"
#     command: "<command>"
#     binary: "<bin>"
#     reachable: true | false
# Stop parsing when we hit the next top-level key (`failures:` or any
# other unindented key starting at column 0) — entries under `failures:`
# are diagnostic-only and would otherwise be ingested twice.
declare -a R_NAME R_CMD R_REACH
cur_name=""; cur_cmd=""; cur_reach=""
in_sensors_section=0
while IFS= read -r line; do
  # Top-level keys (no leading whitespace, ends in ":"); these delimit YAML
  # sections.
  if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*(\[\][[:space:]]*)?$ ]]; then
    # Flush any in-flight record from the previous section.
    if [ -n "$cur_name" ]; then
      R_NAME+=("$cur_name"); R_CMD+=("$cur_cmd"); R_REACH+=("$cur_reach")
      cur_name=""; cur_cmd=""; cur_reach=""
    fi
    if [[ "$line" =~ ^sensors: ]]; then
      in_sensors_section=1
    else
      in_sensors_section=0
    fi
    continue
  fi

  [ "$in_sensors_section" -eq 1 ] || continue

  if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+sensor:[[:space:]]+\"(.*)\"[[:space:]]*$ ]]; then
    if [ -n "$cur_name" ]; then
      R_NAME+=("$cur_name"); R_CMD+=("$cur_cmd"); R_REACH+=("$cur_reach")
    fi
    cur_name="${BASH_REMATCH[1]}"; cur_cmd=""; cur_reach=""
  elif [[ "$line" =~ ^[[:space:]]+command:[[:space:]]+\"(.*)\"[[:space:]]*$ ]]; then
    cur_cmd="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^[[:space:]]+reachable:[[:space:]]+(true|false)[[:space:]]*$ ]]; then
    cur_reach="${BASH_REMATCH[1]}"
  fi
done <<< "$readiness_out"
if [ -n "$cur_name" ]; then
  R_NAME+=("$cur_name"); R_CMD+=("$cur_cmd"); R_REACH+=("$cur_reach")
fi

# Helper: escape a string for safe single-line YAML double-quoted scalar.
escape_yaml() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/}
  printf '%s' "$s"
}

# Helper: run a command with a timeout. Prefers GNU `timeout` (Linux,
# Homebrew coreutils) or `gtimeout` (macOS Homebrew). Falls back to a
# `perl`-based alarm wrapper that kills both the wrapping shell AND its
# child via SIGKILL on timeout — required because plain `kill -TERM
# <pid>` of a `bash -c` subshell does not stop the child `sleep` it
# spawned. Returns the wrapped command's exit code, or 124 on timeout.
run_with_timeout() {
  local timeout_s="$1"; shift
  local cmd="$1"

  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout --foreground "$timeout_s" bash -c "$cmd" </dev/null 2>&1
    return $?
  fi
  if command -v timeout >/dev/null 2>&1; then
    if timeout --help 2>&1 | grep -q -- '--foreground'; then
      timeout --foreground "$timeout_s" bash -c "$cmd" </dev/null 2>&1
      return $?
    fi
    timeout "$timeout_s" bash -c "$cmd" </dev/null 2>&1
    return $?
  fi

  # Perl-based fallback. Requires perl (available by default on macOS,
  # Linux, and BSD). Forks the command, sets SIGALRM via alarm(N), and
  # on timeout sends SIGKILL to the child's process group so any
  # descendants (e.g. `sleep` spawned by `bash -c`) die with it.
  if ! command -v perl >/dev/null 2>&1; then
    echo "Error: no timeout / gtimeout / perl available; cannot enforce timeout." >&2
    return 2
  fi

  perl - "$timeout_s" "$cmd" <<'PERL' 2>&1
use strict;
use warnings;
use POSIX qw(setsid :sys_wait_h);

my $timeout = shift @ARGV;
my $cmd     = shift @ARGV;

my $pid = fork();
die "fork: $!" unless defined $pid;

if ($pid == 0) {
  setsid();                        # new process group; kill -- -$pid hits all descendants
  open(STDIN, '<', '/dev/null');
  exec({'/bin/bash'} 'bash', '-c', $cmd) or die "exec: $!";
}

my $timed_out = 0;
eval {
  local $SIG{ALRM} = sub { die "TIMEOUT\n" };
  alarm $timeout;
  waitpid($pid, 0);
  alarm 0;
};
if ($@ && $@ =~ /TIMEOUT/) {
  $timed_out = 1;
  kill 'KILL', -$pid;             # negative pid → process group
  waitpid($pid, 0);
}

if ($timed_out)        { exit 124; }
elsif ($? & 127)       { exit 128 + ($? & 127); }
else                   { exit $? >> 8; }
PERL
  return $?
}

echo "results:"

for i in "${!R_NAME[@]}"; do
  sensor_name="${R_NAME[$i]}"
  command_str="${R_CMD[$i]}"
  reachable="${R_REACH[$i]}"
  timeout_s="${SENSOR_TIMEOUT[$sensor_name]:-$DEFAULT_COMPUTATIONAL_TIMEOUT}"

  status=""
  exit_code=-1
  output_excerpt=""
  reason=""

  if [ "$reachable" != "true" ]; then
    leading_bin="$(echo "$command_str" | awk '{print $1}')"
    status="skip"
    reason="binary not found: $leading_bin"
  else
    set +e
    sensor_output="$(run_with_timeout "$timeout_s" "$command_str")"
    exit_code=$?
    set -e

    if [ "$exit_code" -eq 0 ]; then
      status="pass"
    elif [ "$exit_code" -eq 124 ]; then
      status="skip"
      reason="timeout: ${timeout_s}s"
    else
      status="fail"
      reason="exit_code=$exit_code"
    fi
    # Truncate output to first 5 non-empty lines.
    output_excerpt=$(echo "$sensor_output" | grep -v '^[[:space:]]*$' | head -5 || true)
  fi

  cat <<EOF
  - sensor: "$(escape_yaml "$sensor_name")"
    command: "$(escape_yaml "$command_str")"
    status: $status
    exit_code: $exit_code
    output_excerpt: "$(escape_yaml "$output_excerpt")"
    reason: "$(escape_yaml "$reason")"
EOF
done

exit 0
