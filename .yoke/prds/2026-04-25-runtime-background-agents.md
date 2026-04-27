# PRD: Runtime background-agent spawning + cycle status stream

> Generated via /vibeflow:discover on 2026-04-26

## Problem

`/yoke:implement` today spawns Generator, Validator, and Orchestrator as
**foreground** subagents inside a single Task batch per cycle. The
assistant turn blocks until all three return, then deterministic nodes
run, then the next cycle starts. Two consequences:

1. **No live visibility for the user.** During a cycle the conversation
   locks; the user has no signal of which agent is running, what the
   Generator is targeting, or where the loop sits relative to hard
   bounds. The user only sees the next message after the cycle's
   deterministic tail completes — by which point arbitration windows
   may already be irrelevant.
2. **Inferential sensors are entangled with the Validator.** When the
   semantic-judge subagent landed (commit `1faaf3e`), the Validator
   became responsible for spawning one judge per applicable inferential
   sensor. That re-introduces nested subagent spawning from within a
   subagent, which the rest of the runtime explicitly forbids
   (`skills/implement/SKILL.md:290-291`), and forces the Validator to
   pay the latency of every judge it spawns serially within its own
   turn.

The two are linked: both stem from `/yoke:implement` not exercising
Claude Code's `run_in_background: true` capability and not owning
sensor spawning itself.

## Target Audience

- **Primary:** Yoke users running `/yoke:implement` on a host project.
  They need a live signal during long cycles (especially under
  hard-bound configurations of 5–8 cycles or 2–4 h timeouts).
- **Secondary:** Yoke developers (`agents/*.md`, `skills/implement/`,
  `lib/ralph-loop/`). The change reshapes their spawning model and the
  Validator's responsibilities.

## Proposed Solution

Three coordinated changes inside `/yoke:implement`, with no change to
the role boundaries codified in `.vibeflow/patterns/roles.md`:

1. **Background spawning.** Each per-cycle Task call for Generator,
   Validator, and Orchestrator is issued with `run_in_background: true`.
   The skill awaits the notifications instead of blocking the assistant
   turn on three foreground Task calls.
2. **Skill-owned inferential-sensor spawning.** `/yoke:implement` reads
   the binding Acceptance Contract, identifies the applicable
   inferential sensors for the targeted criterion, and spawns one
   background `yoke:semantic-judge` agent per sensor in the **same**
   Task batch as Generator/Validator/Orchestrator. Validator no longer
   spawns judges; it consumes the verdict files written to working
   memory.
3. **Cycle status snapshots.** Once per cycle, at cycle end (after
   all background agents and the cycle's deterministic tail complete),
   the skill prints a compact status block to the user. The block is
   intentionally minimal — enough to confirm the loop is alive and
   advancing: cycle number, per-agent state (`running` / `done` /
   `failed`) for Generator / Validator / Orchestrator / inferential
   sensors, sensor-verdict pass/fail counts, elapsed time, and
   distance to hard bounds.

Computational sensors continue to run deterministically through
`hooks/verify-acceptance.sh` with `xargs -P`. Orchestrator stays a
subagent — its consult/monitor/canonize modes are unchanged.

## Success Criteria

1. Running `/yoke:implement` on a fixture task surfaces exactly one
   user-visible status block per cycle, emitted at cycle end, with
   per-agent `running` / `done` / `failed` states and sensor pass/fail
   counts.
2. A `tasks` view (or equivalent debug surface) shows Generator,
   Validator, Orchestrator, and N inferential-sensor agents as
   background tasks during a cycle — not as foreground tool calls.
3. Validator no longer issues `Agent(subagent_type:
   yoke:semantic-judge, …)` calls. Inferential-sensor verdict files
   appear under the cycle's working-memory snapshot regardless of
   Validator state.
4. Cycle wall-clock time on the canonical sprint-4 smoke fixture is
   measurably **lower** than the current foreground-spawn baseline
   when N inferential sensors ≥ 2 (the parallelism win is the whole
   point — sensors no longer queue behind the cycle's tail). Parity
   acceptable when N ≤ 1.
5. The forbidden-pattern rule in `skills/implement/SKILL.md:290-291` is
   tightened to also forbid Validator → judge spawning; smoke gates
   catch any regression.

## Scope v0

- `skills/implement/SKILL.md` — switch the per-cycle Task batch to
  `run_in_background: true`; add the inferential-sensor spawn step;
  add the status-snapshot emission step.
- `agents/validator.md` — remove judge-spawning responsibility; spec
  the input contract for reading judge verdicts from working memory.
- `agents/yoke:semantic-judge.md` (or wherever its prompt lives) —
  unchanged inputs (criterion text, diff, calibration block); unchanged
  output (structured JSON verdict). Only its spawn point changes.
- `lib/ralph-loop/orchestrate.sh` and `hooks/verify-acceptance.sh` —
  surface the data the skill needs to render the status snapshot
  (current targeted criterion, sensor pass/fail counts, last cycle
  elapsed). No new sensor logic.
- A new helper (working name `lib/ralph-loop/status-snapshot.sh`) that
  formats the status block from the per-cycle scratch state.
- Smoke fixture under `tests/smoke/` covering: background spawn
  succeeds; status block emits; Validator reads but does not spawn
  judges.

## Anti-scope

- **Not** moving the Orchestrator into the main thread. v1.1.0
  (`.vibeflow/index.md:32-53`) deliberately put it back as a subagent;
  reverting that is out of scope.
- **Not** moving computational sensors into background agents. They
  stay in `verify-acceptance.sh`'s xargs -P pipeline.
- **Not** redesigning the Acceptance Contract format or
  computational/inferential sensor catalogs.
- **Not** adding pub/sub between agents. Communication stays via
  working-memory files.
- **Not** changing the canonization handoff (still a single
  Orchestrator-only Task call at termination, not background).
- **Not** introducing live arbitration mid-cycle. Triggers 1–5 stay
  as defined in `patterns/human-triggers.md`.
- **Not** building a TUI or rich progress UI — status snapshots are
  plain markdown blocks emitted to the chat.

## Technical Context

- **Current spawning surface:** `skills/implement/SKILL.md:84-145`
  prescribes one assistant turn with three concurrent (foreground) Task
  calls per cycle, plus a single canonize-mode Task call at
  termination.
- **Current sensor surface:**
  - Computational sensors → `hooks/verify-acceptance.sh` via
    `xargs -P "$(yoke_sensor_concurrency)"` (default 4).
  - Inferential sensors → `agents/yoke:semantic-judge.md`, spawned
    today by the Validator inside its turn.
- **Per-role model resolution** already exists at
  `lib/runtime/agent-config.sh` (`yoke_resolve_model …`). Background
  spawning must continue to honour the resolved `model:` argument or
  omit it for session inheritance — see `implement/SKILL.md:62-78`.
- **R1 (parallel-spawn depth):** project risk in
  `.vibeflow/index.md:138`. This PRD increases per-cycle parallel-Task
  width from 3 to 3 + N (N = applicable inferential sensors). Sprint-1
  Task 1.5 verified depth-1 parallel spawn works; this is still
  depth-1, only wider. Verify in the smoke fixture before relying on
  it.
- **Notification semantics:** Claude Code's Agent tool with
  `run_in_background: true` notifies on completion; the host turn must
  not poll/sleep. The skill needs to enter a wait-for-completions
  state and emit status snapshots opportunistically (on each
  notification, plus a per-cycle summary once all required
  notifications arrive).
- **Decisional precedent to keep:** `Consult live, canonize on
  termination` (`.vibeflow/decisions.md` 2026-04-25). Status snapshots
  do not justify any extra canonical-memory reads or writes.
- **Pattern alignment:** `patterns/ralph-loop.md` "Concurrent agentic
  batch (per cycle, single assistant turn)" still holds — only the
  spawning mode and the batch width change. The pattern doc must be
  updated to reflect that the inferential-sensor agents are part of
  the per-cycle batch.

## Decisions (locked during discovery)

1. **Sensor timing — Model A.** Each cycle spawns Generator, Validator,
   Orchestrator, and the applicable inferential sensors in the same
   background batch. Sensors judge the diff produced by the previous
   Generator turn (lag-by-one), the same lag the Validator already
   tolerates today via `cycle-(N-1).yaml`. Rationale: running sensors
   serially after each cycle is the slowness this PRD exists to kill.
2. **Status-snapshot cadence — once per cycle, at cycle end.** No
   per-notification emission, no wall-clock minimum.
3. **Status-block fidelity — minimal.** Per-agent state limited to
   `running` / `done` / `failed`. No mid-cycle introspection, no
   "current criterion" line. The block exists so the user can confirm
   the loop is advancing, not as a debugger.
4. **Inferential-sensor failure policy — log + skip + surface.** When a
   judge agent errors, the skill logs the failure, treats that
   criterion's verdict as `skip` for the cycle, and surfaces the
   failure in the status block. The Validator's next-cycle verdict
   reflects the missing evidence. No automatic re-spawn; no escalation
   to Trigger 4 unless the same sensor fails on consecutive cycles
   (define threshold in the tech spec).
5. **R1 width cap.** Per-cycle parallel-Task width is capped at
   `3 + N` where `N` is configurable via
   `runtime.inferential_sensor_concurrency` in `.yoke/config.yaml`
   (default 4, mirroring `runtime.sensor_concurrency`). The smoke
   fixture exercises width 3+4 = 7 to validate Claude Code's
   parallel-spawn budget at this scale.

## Open Questions

None — all discovery-phase ambiguities are resolved above. Any
remaining trade-offs (snapshot file format, exact status-block
markdown shape, consecutive-failure threshold for #4, status-helper
script location) belong in the tech spec, not the PRD.
