#!/usr/bin/env bash
# tests/canonical-memory/cascade-occurrences.test.sh
#
# Self-test for the cross-archive `occurrences:` enumeration in
# `lib/canonical-memory/canonization-criteria.sh` (sprint-contract-promotion
# s01-t01). Exercises the deterministic floor that admits a recurring
# contract into cascade scoring.
#
# Subtests:
#   1. Backward-compatibility golden test — legacy single `contracts.md`,
#      no `contracts/` dir. Output equals the v0 golden output, plus the
#      additive `occurrences: 1` line. Asserts no regression for existing
#      callers (FR-10 of the binding Acceptance Contract).
#   2. Single-task per-archive test — one `.yoke/contracts/<slug>.md`,
#      one block. Reports `occurrences: 1` and a single-archive
#      traceability entry.
#   3. Cross-archive recurrence test — two archives with byte-identical
#      `topic:` strings. Reports `occurrences: 2` and a traceability
#      list containing both archive references with their contract
#      ids. THIS IS THE BINDING SUBTEST FOR FR-1 / Scenario 1.
#   4. Distinct-topic isolation test — two archives whose `topic:`
#      strings differ by one character. Each candidate reports
#      `occurrences: 1`. No coalescing.
#   5. Performance test — 1000 contract blocks across 50 archives.
#      Script completes in <5s (the documented performance contract).
#
# All subtests build their fixture in a tmpdir and run the cascade
# script with `--working-memory <tmpdir>/.yoke`. Expected outputs are
# embedded in this file as heredocs and diffed byte-for-byte against
# the script's stdout.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"

CASCADE="$PLUGIN_ROOT/lib/canonical-memory/canonization-criteria.sh"

if [ ! -x "$CASCADE" ] && [ ! -f "$CASCADE" ]; then
  err "cascade script missing at $CASCADE"
  harness::summary
fi

# ---------------------------------------------------------------------
# Helper: run the cascade against a fixture working-memory and diff its
# stdout against an expected golden string.
# ---------------------------------------------------------------------
run_and_diff() {
  local label="$1"
  local wm="$2"
  local expected="$3"

  local actual
  actual="$(bash "$CASCADE" --working-memory "$wm" 2>/dev/null || true)"

  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    err "$label — output mismatch"
    {
      printf -- '--- expected ---\n%s\n--- actual ---\n%s\n--- diff ---\n' \
        "$expected" "$actual"
      diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") || true
    } >&2
  fi
}

# ---------------------------------------------------------------------
# Subtest 1 — Backward-compatibility golden test.
#
# Legacy single-file path. Output must match the v0 golden output
# byte-for-byte EXCEPT for the additive `occurrences: 1` line — that
# is the FR-10 contract. The `traceability:` line for the legacy path
# is `contracts.md#contract-<id>` (no per-archive prefix).
# ---------------------------------------------------------------------
T1=$(mktemp -d)
trap 'rm -rf "$T1"' RETURN
mkdir -p "$T1/.yoke"
cat > "$T1/.yoke/contracts.md" <<'EOF'
# Sprint contracts

## Contract c1
- id: "c1"
- topic: "redirectUrl quoting style"
- decision: "Use single quotes around redirectUrl values"
- rationale: "matches existing host conventions"
- cycle: 3
EOF

EXPECTED_1='candidates:
  - id: c1
    kind: other
    score: 70
    impact: low
    reason: "Sprint contract on redirectUrl quoting style"
    traceability:
      - "contracts.md#contract-c1"
      - "progress.md#cycle-3"
    occurrences: 1
    content_path: "divergences/c1.md"
    content_excerpt: "Use single quotes around redirectUrl values"'

run_and_diff "(1) legacy single-file path emits additive occurrences: 1 only" "$T1/.yoke" "$EXPECTED_1"
rm -rf "$T1"
trap - RETURN

# ---------------------------------------------------------------------
# Subtest 2 — Single-task per-archive path.
#
# One archive under `contracts/`, one block. occurrences: 1, traceability
# carries the per-archive path.
# ---------------------------------------------------------------------
T2=$(mktemp -d)
mkdir -p "$T2/.yoke/contracts"
cat > "$T2/.yoke/contracts/2026-04-27-foo.md" <<'EOF'
# Sprint contracts

## Contract c1
- id: "c1"
- topic: "topic alpha"
- decision: "decision alpha"
- cycle: 2
EOF

EXPECTED_2='candidates:
  - id: c1
    kind: other
    score: 60
    impact: low
    reason: "Sprint contract on topic alpha"
    traceability:
      - "contracts/2026-04-27-foo.md#contract-c1"
      - "progress.md#cycle-2"
    occurrences: 1
    content_path: "divergences/c1.md"
    content_excerpt: "decision alpha"'

run_and_diff "(2) single per-task archive emits occurrences: 1 with per-archive traceability" "$T2/.yoke" "$EXPECTED_2"
rm -rf "$T2"

# ---------------------------------------------------------------------
# Subtest 3 — Cross-archive recurrence (BINDING for FR-1 / Scenario 1).
#
# Two archives with byte-identical `topic:` strings → both candidates
# carry occurrences: 2 and a cross-archive traceability list.
# ---------------------------------------------------------------------
T3=$(mktemp -d)
mkdir -p "$T3/.yoke/contracts"
cat > "$T3/.yoke/contracts/2026-04-26-slug-a.md" <<'EOF'
# Sprint contracts

## Contract c1
- id: "c1"
- topic: "redirectUrl quoting style"
- decision: "Use single quotes around redirectUrl values"
- cycle: 2
EOF
cat > "$T3/.yoke/contracts/2026-04-27-slug-b.md" <<'EOF'
# Sprint contracts

## Contract c1
- id: "c1"
- topic: "redirectUrl quoting style"
- decision: "Use single quotes around redirectUrl values"
- cycle: 4
EOF

EXPECTED_3='candidates:
  - id: c1
    kind: other
    score: 60
    impact: low
    reason: "Sprint contract on redirectUrl quoting style"
    traceability:
      - "contracts/2026-04-26-slug-a.md#contract-c1"
      - "progress.md#cycle-2"
      - "contracts/2026-04-27-slug-b.md#contract-c1"
    occurrences: 2
    content_path: "divergences/c1.md"
    content_excerpt: "Use single quotes around redirectUrl values"
  - id: c2
    kind: other
    score: 60
    impact: low
    reason: "Sprint contract on redirectUrl quoting style"
    traceability:
      - "contracts/2026-04-27-slug-b.md#contract-c1"
      - "progress.md#cycle-4"
      - "contracts/2026-04-26-slug-a.md#contract-c1"
    occurrences: 2
    content_path: "divergences/c1.md"
    content_excerpt: "Use single quotes around redirectUrl values"'

run_and_diff "(3) cross-archive recurrence emits occurrences: 2 with cross-archive traceability (FR-1)" "$T3/.yoke" "$EXPECTED_3"

# Spot-check the binary acceptance criterion explicitly: the emitted YAML
# from the recurrence fixture MUST contain `occurrences: 2`.
if bash "$CASCADE" --working-memory "$T3/.yoke" 2>/dev/null | grep -q '^    occurrences: 2$'; then
  pass "(3*) cross-archive fixture stdout contains 'occurrences: 2' (binding criterion)"
else
  err "(3*) cross-archive fixture stdout does NOT contain 'occurrences: 2'"
fi

rm -rf "$T3"

# ---------------------------------------------------------------------
# Subtest 4 — Distinct-topic isolation.
#
# Two archives whose `topic:` strings differ by one character → no
# coalescing. Each candidate is occurrences: 1.
# ---------------------------------------------------------------------
T4=$(mktemp -d)
mkdir -p "$T4/.yoke/contracts"
cat > "$T4/.yoke/contracts/2026-04-26-slug-a.md" <<'EOF'
# Sprint contracts

## Contract c1
- id: "c1"
- topic: "topic alpha"
- decision: "decision alpha"
- cycle: 1
EOF
cat > "$T4/.yoke/contracts/2026-04-27-slug-b.md" <<'EOF'
# Sprint contracts

## Contract c1
- id: "c1"
- topic: "topic alphA"
- decision: "decision alpha"
- cycle: 2
EOF

EXPECTED_4='candidates:
  - id: c1
    kind: other
    score: 60
    impact: low
    reason: "Sprint contract on topic alpha"
    traceability:
      - "contracts/2026-04-26-slug-a.md#contract-c1"
      - "progress.md#cycle-1"
    occurrences: 1
    content_path: "divergences/c1.md"
    content_excerpt: "decision alpha"
  - id: c2
    kind: other
    score: 60
    impact: low
    reason: "Sprint contract on topic alphA"
    traceability:
      - "contracts/2026-04-27-slug-b.md#contract-c1"
      - "progress.md#cycle-2"
    occurrences: 1
    content_path: "divergences/c1.md"
    content_excerpt: "decision alpha"'

run_and_diff "(4) distinct topics differing by one char remain occurrences: 1 (no coalescing)" "$T4/.yoke" "$EXPECTED_4"
rm -rf "$T4"

# ---------------------------------------------------------------------
# Subtest 5 — Performance: 1000 contract blocks across 50 archives in <5s.
#
# Synthesised fixture builds 50 archives × 20 blocks each = 1000 blocks.
# Topic strings are unique per block so there is no cross-archive
# recurrence (worst case for the candidate emission loop).
# ---------------------------------------------------------------------
T5=$(mktemp -d)
mkdir -p "$T5/.yoke/contracts"

# Build 50 archives × 20 blocks = 1000 contract blocks. Topics are
# unique per block so the worst-case (no recurrence) emission path is
# exercised. Pure-bash builder for portability.
for i in $(seq 1 50); do
  ii=$(printf '%02d' "$i")
  f="$T5/.yoke/contracts/2026-04-27-slug-${ii}.md"
  {
    echo "# Sprint contracts"
    echo
    for j in $(seq 1 20); do
      echo "## Contract c${j}"
      echo "- id: \"c${j}\""
      echo "- topic: \"topic-${ii}-${j}\""
      echo "- decision: \"decision-${ii}-${j}\""
      echo "- cycle: ${j}"
    done
  } > "$f"
done

# Verify fixture was built.
if ! ls "$T5/.yoke/contracts" 2>/dev/null | head -1 >/dev/null; then
  err "(5) performance fixture build failed"
  rm -rf "$T5"
  harness::summary
fi

# Time the script end-to-end. Threshold: 5s wall-clock per the contract.
# Prefer Python for sub-second timing; fall back to bash SECONDS.
elapsed_ms=""
if command -v python3 >/dev/null 2>&1; then
  elapsed_ms=$(python3 -c '
import subprocess, sys, time
cascade, wm = sys.argv[1], sys.argv[2]
t0 = time.time()
subprocess.run(["bash", cascade, "--working-memory", wm],
               check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print(int((time.time() - t0) * 1000))
' "$CASCADE" "$T5/.yoke" 2>/dev/null || echo "")
fi

if [ -z "$elapsed_ms" ]; then
  # Bash fallback timing: SECONDS counter (whole seconds).
  SECONDS=0
  bash "$CASCADE" --working-memory "$T5/.yoke" >/dev/null 2>&1 || true
  elapsed_s=$SECONDS
  if [ "$elapsed_s" -lt 5 ]; then
    pass "(5) performance: 1000 blocks / 50 archives processed in ${elapsed_s}s (<5s)"
  else
    err "(5) performance: 1000 blocks / 50 archives took ${elapsed_s}s (≥5s budget)"
  fi
else
  if [ "$elapsed_ms" -lt 5000 ]; then
    pass "(5) performance: 1000 blocks / 50 archives processed in ${elapsed_ms}ms (<5000ms)"
  else
    err "(5) performance: 1000 blocks / 50 archives took ${elapsed_ms}ms (≥5000ms budget)"
  fi
fi

# Sanity: the perf fixture should also yield 1000 candidates with
# occurrences: 1 each (no recurrence).
nblocks=$(bash "$CASCADE" --working-memory "$T5/.yoke" 2>/dev/null | grep -c '^    occurrences: 1$' || true)
if [ "$nblocks" = "1000" ]; then
  pass "(5*) performance fixture emits 1000 candidates with occurrences: 1"
else
  err "(5*) performance fixture emitted $nblocks candidates with occurrences: 1 (expected 1000)"
fi

rm -rf "$T5"

harness::summary
