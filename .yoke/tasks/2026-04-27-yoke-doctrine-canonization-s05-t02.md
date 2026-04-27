---
task_id: 2026-04-27-yoke-doctrine-canonization-s05-t02
sprint: 5
slug: 2026-04-27-yoke-doctrine-canonization
status: approved
created_at: 2026-04-27T18:14:49Z
model: ""
traceability: ""
---

# Task 2026-04-27-yoke-doctrine-canonization-s05-t02 — Run the round-trip validation suite — one `/yoke:ask` sample query per migrated entity class — and commit the captured outputs as evidence.

## Story

Per-task `/yoke:ask` round-trips have happened all along, but the
final v0 gate is a single coherent suite that asserts every migrated
entity class is retrievable. This produces the committable evidence
file that the Validator can re-run and that the Acceptance Contract
binds to. Without it, "doctrine queryable via `/yoke:ask`" is
sentiment, not a check.

## Technical implementation

- Implement `lib/sensors/yoke-doctrine-round-trip.sh` (or `tests/round-trip/yoke-doctrine.sh` — final location is a sprint-5 implementation choice):
  - Hard-coded list of N sample queries — one per pattern (9), one per pattern of decision (3 sample decisions: most-recent, one mid-history, one superseded), one for conventions, one for project (`/yoke:ask "what is the claude-yoke project?"`), one for actor (`/yoke:ask "describe the yoke actor"`), one for an audit. ~16 queries total.
  - For each query, capture the response. Assert (deterministic substring match) that the response contains the expected entity filename or path verbatim.
  - On any miss, emit `<query> -> MISS (expected substring: <X>)` to stderr and exit non-zero.
  - On all hits, write the full transcript to `.yoke/runtime/round-trip-evidence.txt` (gitignored — the artifact lives in the runtime dir but the assertion happens at run-time).
- The query list, expected substrings, and the script itself are committed in this task file's Validation section so future readers (and the Acceptance Contract's BDD) can re-derive them.

## Validation

- The script runs against a tree where sprints 1-4 have all completed; expected outcome: every query passes.
- `.yoke/runtime/round-trip-evidence.txt` exists after a successful run and contains all 16 transcripts.
- Re-running the script is idempotent — same outputs given same vault state.
- The Validator's Acceptance-Contract sensor list includes this round-trip sensor.

## Acceptance criterion

`bash <script-path>` exits 0 AND `.yoke/runtime/round-trip-evidence.txt` exists with at least 16 distinct query/response transcripts AND every expected substring (one per query, hard-coded in the script) appears in the corresponding transcript section.
