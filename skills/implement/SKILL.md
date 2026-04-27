---
name: implement
description: >
  Phase 4 — adversarial ralph loop. Walks sprints serially: reads
  `current_sprint:` from `.yoke/runtime/progress.md`, loads
  `.yoke/sprints/<slug>-s<current_sprint>.md` as the cycle's working
  set, spawns the Generator, Validator, and Orchestrator subagents
  concurrently each cycle (single Task batch), iterates ≤8 cycles
  against the binding Acceptance Contract, advances the pointer and
  resets the cycle counter on per-sprint convergence. Sprint contracts
  on consensus persist to `.yoke/contracts/<slug>.md`; runtime state
  under `.yoke/runtime/`. At full convergence (every sprint complete),
  issues one final Orchestrator call with `mode=canonize` to apply the
  five-criteria filter and propose Model C writes to canonical memory.
argument-hint: ""
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /yoke:implement — Phase 4 (parallel ralph loop, v1.1.0)

Drive Generator ↔ Validator cycles inside the envelope of the binding
Acceptance Contract, sprint by sprint, with the Orchestrator subagent
consulting canonical memory live and owning the canonization handoff
at full-run termination.

> **v1.1.0 architectural note.** This skill no longer routes through
> an "Orchestrator skill in runtime-coordinator mode". Instead, it is
> a **deterministic coordinator** that spawns three runtime subagents
> (`agents/generator.md`, `agents/validator.md`,
> `agents/orchestrator.md`) **in parallel** via a single Task batch
> per cycle. No subagent spawns another. At loop termination the skill
> issues one more Orchestrator call with `mode=canonize` to perform
> the canonization handoff.
>
> **sprint-as-cycle refresh.** Per the 2026-04-27 sprint-as-cycle
> PRD, one ralph cycle = one sprint file as the working set. The
> coordinator reads `current_sprint:` from
> `.yoke/runtime/progress.md`, loads
> `.yoke/sprints/<slug>-s<current_sprint>.md` as the cycle's working
> set, runs ≤8 cycles per sprint to convergence, then advances
> `current_sprint:` and resets `cycle_count:` to 0. The full-run
> termination handoff (canonize) fires only when every sprint has
> converged (i.e. `completed_sprints:` length equals `total_sprints:`).

## Process

### 1. Pre-flight (deterministic)

- Source `lib/working-memory/paths.sh` and
  `lib/working-memory/cleanup.sh`. All paths below resolve through
  `wm_*_path` helpers; the active task slug comes from `.yoke/runtime/.current`
  via `wm_active_slug`.
- **Working-memory hygiene (deterministic, silent on success).** Call
  `wm_gitignore_self_heal` to write/repair `.yoke/.gitignore` if
  missing or incomplete (canonical content: `.current` + `runtime/`).
  Then call `wm_check_runtime_tracked` to detect host projects that
  bootstrapped before the gitignore landed and still track
  `.yoke/runtime/`; on detection it prints a one-line remediation hint
  pointing at `git rm -r --cached .yoke/runtime/` and never modifies
  git state. Both are read-only against the loop's working memory and
  must run *before* the orchestrate.sh preflight call below.
- Run `lib/ralph-loop/orchestrate.sh preflight`. The script verifies:
  - `.yoke/config.yaml` exists.
  - `.yoke/runtime/.current` exists and points at a valid slug.
  - `wm_prd_path "$slug"`, `wm_spec_path "$slug"`, and
    `wm_acceptance_contract_path "$slug"` all exist and carry
    `Status: approved` (PRD/Spec) or `Status: ratified` (Contract).
    The Phase-2 approval flow flips `Status: approved` on the spec
    AND every `.yoke/sprints/<slug>-s*.md` together — see
    `skills/tech-spec/SKILL.md` "Recording approval".
  - On any missing pre-condition, the script aborts with a clear
    message (exit codes 3 or 4).
- **Initialize the sprint walk (deterministic).** Read
  `current_sprint:` and `completed_sprints:` from
  `.yoke/runtime/progress.md` frontmatter. On first invocation the
  template seeds `current_sprint: "01"`, `completed_sprints: []`,
  `cycle_count: 0`. `total_sprints:` is inferred at preflight by
  counting `wm_list_sprint_paths "$slug"` entries. The cycle counter
  resets to 0 on every sprint advance — per-sprint hard bounds are
  per `concepts/yoke-pattern-ralph-loop`.
- Run `hooks/pre-implementation.sh`.
- Ensure `.yoke/runtime/` and `.yoke/contracts/` exist (`mkdir -p`).
  Initialize `wm_progress_path` (`.yoke/runtime/progress.md`) and
  `wm_contracts_path "$slug"` (`.yoke/contracts/<slug>.md`) from
  `templates/progress.md` and `templates/contracts.md` respectively if
  they don't exist (cycle 0 entries). The `query-trace` initialization
  was retired in ask-source-agnostic-read Part 1 — `/yoke:ask` is now a
  pure read and emits no trace.
- **Resolve per-role models (perf-quickwins Part 3).** Source
  `lib/runtime/agent-config.sh`. Compute:
  ```
  generator_model="$(yoke_resolve_model generator)"
  validator_model="$(yoke_resolve_model validator)"
  orch_consult_model="$(yoke_resolve_model orchestrator.consult)"
  orch_monitor_model="$(yoke_resolve_model orchestrator.monitor)"
  orch_canonize_model="$(yoke_resolve_model orchestrator.canonize)"
  ```
  Defaults pin `validator`, `orchestrator.consult`, and
  `orchestrator.monitor` to `claude-sonnet-4-6`; `generator` and
  `orchestrator.canonize` inherit the user's session model unless
  overridden under `runtime.models.*` in `.yoke/config.yaml`. Empty
  resolved values mean "no pinning — inherit session model". Log
  every resolved value via
  `yoke_log_resolved_models "$(wm_runtime_dir)/.task-spawn-log"` —
  the log is append-only and lives alongside the cycle counter; it is
  the cheapest verification gate for pinning provenance and for R2
  (mechanism silently no-ops). Quality is king on the Generator and
  on Model C governance writes (canonize), so those roles never
  auto-downgrade.

### 2. Cycle loop (per-sprint walk)

The coordinator walks sprints serially. Outer iteration:

```
while [ $(jq_count_array completed_sprints) -lt $total_sprints ]; do
    current_sprint=$(read_frontmatter current_sprint progress.md)
    sprint_file=".yoke/sprints/${slug}-s${current_sprint}.md"
    cycle_count=$(read_frontmatter cycle_count progress.md)

    # Inner per-sprint cycle loop, ≤8 iterations.
    while [ $cycle_count -lt 8 ]; do
        # Each cycle's working set = $sprint_file.
        # ... (cycle steps below, numbered 1–9)
        if convergence_for_sprint; then
            append_to completed_sprints "$current_sprint"
            advance current_sprint
            reset cycle_count to 0
            break  # outer while re-evaluates
        fi
        cycle_count=$((cycle_count + 1))
    done

    if [ $cycle_count -ge 8 ]; then
        # Per-sprint hard bound exhausted — escalate Trigger 4.
        bash lib/ralph-loop/escalate.sh \
            --reason hard-bound \
            --active-sprint "$current_sprint"
        break  # halt the run; canonize handoff still fires
    fi
done
```

For each cycle of the inner loop (numbered starting at 1, reset at
sprint boundaries):

1. **Concurrent subagent batch (single agentic turn, `3 + N` background Task calls).**
   In a single assistant turn, issue **`3 + N` concurrent Task calls**:
   three role calls spawning `agents/generator.md`,
   `agents/validator.md`, and `agents/orchestrator.md` simultaneously,
   plus **N inferential-sensor calls** with
   `subagent_type: semantic-judge` (one per applicable inferential
   sensor on the targeted criterion; see the inferential-sensor
   sub-step below for how `N` is resolved). Each Task call sets
   `run_in_background: true` so the assistant turn does not block on
   completion. Each role Task call also passes a per-role `model:`
   argument resolved at preflight:
   - Generator → `model: $generator_model`
   - Validator → `model: $validator_model`
   - Orchestrator (consult+monitor mode) → `model: $orch_consult_model`
     (consult and monitor modes share the per-cycle model; the
     canonize-mode call at termination uses `$orch_canonize_model`,
     see §3 below).
   When a resolved value is empty, omit the `model:` argument — the
   subagent inherits the user's session model. Each receives
   **disjoint inputs** read from the freshest snapshot of working
   memory at spawn time.

   - **Generator (`agents/generator.md`)** — input:
     - Approved upstream artifacts at `wm_prd_path`,
       `wm_spec_path`, the **active sprint file** at
       `.yoke/sprints/<slug>-s<current_sprint>.md` (the cycle's
       working set — never the full sprint set), and
       `wm_acceptance_contract_path` (read-only).
     - `active_sprint: <NN>` (the value of `current_sprint:` from
       progress.md) — passed explicitly so the Generator scopes its
       diff to the active sprint's tasks and DoD.
     - Current runtime progress at `wm_progress_path` (last cycle's
       state).
     - Current sprint contracts at `wm_contracts_path "$slug"`.
     - Last `verify-acceptance.sh` snapshot from
       `$(wm_snapshots_dir)/cycle-<N-1>.yaml` (if any).
     - Canonical-memory context: invoke `/yoke:ask` via the Skill
       tool on demand (no on-disk handoff; the skill is a pure
       source-agnostic read).

     Writes code targeting the next failing Acceptance Contract
     criterion in the **active sprint's** Functional acceptance
     criteria list; persists `wm_progress_path` at end of turn.

   - **Validator (`agents/validator.md`)** — input:
     - Approved Acceptance Contract at `wm_acceptance_contract_path`.
     - Last `verify-acceptance.sh` snapshot from
       `$(wm_snapshots_dir)/cycle-<N-1>.yaml`.
     - Current sprint contracts at `wm_contracts_path` and runtime
       progress at `wm_progress_path` (read-only).
     - Canonical-memory context: invoke `/yoke:ask` via the Skill
       tool on demand.

     Emits structured JSON verdicts per criterion against the
     freshest snapshot's sensor output; appends sprint contracts to
     `wm_contracts_path` only on consensus events (post-Validator
     verdict, never concurrent with Generator's writes).

   - **Orchestrator (`agents/orchestrator.md`)** — input:
     - `mode=consult+monitor`, `cycle=<N>`, `slug=<active slug>`,
       `active_sprint=<current_sprint>`.
     - Current `wm_progress_path`, `wm_contracts_path`.
     - Last `verify-acceptance.sh` snapshot.

     Consults canonical memory by invoking `/yoke:ask` via the Skill
     tool when context is needed; reasons over the response inline.
     Monitors for Generator↔Validator divergence; on divergence
     invokes `lib/ralph-loop/escalate.sh` to emit the Trigger-4
     packet (written to `wm_trigger4_packet_path`).

   - **Inferential sensors (`agents/semantic-judge.md`, N instances)**
     — for each applicable inferential sensor on the targeted
     criterion, issue one additional concurrent Task call with
     `subagent_type: semantic-judge` and `run_in_background: true`.
     Identification: read the active Acceptance Contract at
     `wm_acceptance_contract_path` and select sensors whose
     `class: inferential` and whose `criterion_scope` covers the
     Generator's targeted criterion (read from the most recent
     `citing_criterion:` entry in `wm_progress_path`; on cycle 1 /
     fallback, select all inferential sensors on the contract).
     Cap `N` at `runtime.inferential_sensor_concurrency` in
     `.yoke/config.yaml` (default `4`); when applicable sensors
     exceed the cap, choose deterministically (criterion order,
     ties broken by sensor id) and **defer** the surplus by
     appending their ids to
     `$(wm_runtime_dir)/.deferred-sensors.json`. The next cycle's
     spawn pass prepends deferred ids before fresh ones, so every
     applicable sensor eventually runs without exceeding the
     parallel-spawn cap. Inputs per spawn: criterion text, diff
     under review, calibration block, and a verdict-output path
     resolved via
     `wm_judge_verdict_path "$slug" "$cycle" "$criterion-id" "$sensor-id"`
     (`.yoke/runtime/.judge-verdicts/cycle-<N>/<criterion>--<sensor>.json`).
     Each judge spawn is one (criterion, sensor) pairing — multiple
     inferential sensors on the same criterion get distinct verdict
     files, supporting `patterns/sensors.md`'s any-fail-wins
     aggregation. Judges write their verdict JSON to the supplied
     path; the Validator in cycle `<N+1>` reads from
     `wm_judge_verdict_dir "$slug" "$cycle"` (Model A lag-by-one).
     Failure policy: on non-zero judge exit, log to
     `$(wm_runtime_dir)/.judge-verdicts/cycle-<N>/.failures.log`,
     treat the criterion's verdict as `skip` for the cycle, and
     surface in the cycle status block. When the same sensor fails
     in two consecutive cycles, invoke
     `lib/ralph-loop/escalate.sh --reason sensor-failure --sensor
     <id>` and pause the loop.

   Issue all `3 + N` Task calls in a **single assistant turn** so
   they execute concurrently. Per-agent file-write contracts (in
   `agents/*.md`) prevent within-batch collisions: Generator owns
   the progress file; the contracts file is appended only on
   consensus events post-batch; each judge owns its own verdict
   file under `.yoke/runtime/.judge-verdicts/cycle-<N>/`.

   After dispatching the batch, **wait for all `3 + N` completion
   notifications** before advancing to step 2. Do **not** poll, sleep,
   or otherwise probe for state — Claude Code emits a completion
   notification automatically when each background Task ends, and the
   skill resumes deterministically once the final notification
   arrives. This wait is a deterministic node in the blueprint: no
   agentic decision is made in it. The skill cannot run the cycle's
   deterministic tail (sensor execution, contradiction check, persist,
   hard-bound check, stop check) against partial state — every step
   below in this cycle assumes all `3 + N` Task calls have returned.

2. **Sensor execution — Phase A (cheap, deterministic).** Run
   `hooks/verify-acceptance.sh --tier cheap` to capture cycle N's
   post-Generator sensor state for the **cheap tier**. Pass
   `--criterion <id>` where `<id>` is the Generator's last targeted
   criterion (read from the most recent `citing_criterion:` entry in
   `wm_progress_path`); pass
   `--fragments-dir "$(wm_runtime_dir)/.pending-fragments"`; redirect
   stdout to `$(wm_runtime_dir)/.pending-snapshot.yaml`. Sensors run
   in parallel via `xargs -P "$(yoke_sensor_concurrency)"` (default 4,
   configurable via `runtime.sensor_concurrency` in
   `.yoke/config.yaml`). When no `citing_criterion` is recorded
   (cycle 0 / fallback) omit `--criterion` and run the full cheap
   tier. The Validator (`agents/validator.md`) reads the resulting
   snapshot — it never invokes `verify-acceptance.sh` itself.

3. **Sensor execution — Phase B (expensive, gated, deterministic).**
   Decide whether to run the expensive tier this cycle by reading
   cycle `<N-1>`'s `schedule_next` from `wm_progress_path` (Validator-
   owned scheduling, sensor-cost-tiering Part 4 — see
   `agents/validator.md`'s "schedule_next emission" contract).
   - **Cycle 1**: skip Phase B. No prior `schedule_next` exists; the
     coordinator runs cheap-only by design. Phase B becomes possible
     from cycle 2 onward via the Validator's authorization.
   - **Cycle ≥ 2**: parse the `schedule_next:` block from the most
     recent `## Cycle <N-1>` entry in `wm_progress_path`. If
     `tiers:` includes `expensive`, OR `sensors:` lists explicit
     ids whose `applies_to` covers the current criterion, run
     `hooks/verify-acceptance.sh --tier expensive --criterion <id>
     --fragments-dir "$(wm_runtime_dir)/.pending-fragments"` and
     **append** its results to the same
     `$(wm_runtime_dir)/.pending-snapshot.yaml` (the snapshot is the
     union of Phase A + Phase B). Otherwise, skip Phase B.
   This dual phase is the **two-phase per-cycle execution** of
   sensor-cost-tiering — cheap sensors fire every cycle (shift-left
   on actionable feedback), expensive sensors fire only when
   pre-convergence failure would yield actionable signal. Source PRD:
   `.yoke/prds/2026-04-27-sensor-cost-tiering.md`. Both phases respect the
   `runtime.inferential_sensor_concurrency` cap and the deferred-
   sensors queue when tier filtering authorizes inferential judges.

4. **Run-history append (deterministic).** After Phase A (always)
   and Phase B (when authorized), invoke
   `bash lib/sensors/append-runs.sh "$(wm_runtime_dir)/.pending-snapshot.yaml" <N> <criterion>`
   to append one entry to each executed sensor's
   `.yoke/sensors/<id>.md` `runs:` history. The helper applies a
   retention cap of N=20 (oldest entries roll off on overflow) and
   writes atomically. Sensors that did not run this cycle (Phase B
   was skipped, or the sensor was filtered out by `--criterion`)
   are not touched. Sensors with no per-sensor file (not registered
   under `## Sensors registry`) are skipped silently — readiness
   mode is the right place to surface that. The persisted history
   is the durable record the Validator reads next cycle when
   emitting `schedule_next`. `hooks/post-iteration.sh` then promotes
   the scratch snapshot to `$(wm_snapshots_dir)/cycle-<N>.yaml` —
   the snapshot file is the union of Phase A + Phase B and is never
   re-run when the scratch is already present.

5. **Contradiction check (deterministic).** Run
   `lib/ralph-loop/orchestrate.sh check-contradiction`. If a sprint
   contract textually contradicts an Acceptance Contract criterion
   (heuristic: contains a relax/remove/skip/disable/bypass/ignore
   verb together with a criterion identifier), the script exits 10
   and the loop pauses with a clear message: "Sprint contract
   contradicts Acceptance Contract. Pausing for human arbitration."

6. **Persist (deterministic).** Run `hooks/post-iteration.sh`. The
   hook:
   - Increments the cycle counter at `wm_cycle_counter_path`
     (`.yoke/runtime/.cycle-counter`).
   - Snapshots `verify-acceptance.sh` output to
     `$(wm_snapshots_dir)/cycle-<N>.yaml`.

7. **Hard-bound check (deterministic).** Run
   `hooks/check-hard-bounds.sh`. If cycles, timeout, or token
   budget is exceeded, the hook invokes
   `lib/ralph-loop/escalate.sh --reason hard-bound` and exits 10.
   The skill treats this as a pause-with-arbitration-packet.

8. **Stop check — per-sprint convergence + full-run merge-ready
   sweep.** This step decides three outcomes: (a) advance to the
   next sprint, (b) declare MERGE-READY (last sprint just
   converged), or (c) continue this sprint's loop.
   - First, run `hooks/verify-acceptance.sh --concurrency 1 --tier
     all --sprint <current_sprint>` (no `--criterion`), filtering
     sensors / criteria to those declared in the active sprint
     file's `## Functional acceptance criteria` and `## Sensors`
     blocks. Redirect stdout to
     `$(wm_runtime_dir)/.sprint-converge-snapshot.yaml`. If every
     active-sprint criterion has `status: pass` AND no `divergence`
     verdict from the Validator, the sprint has converged.
   - On per-sprint convergence: append `<current_sprint>` to
     `completed_sprints:` in `wm_progress_path`, increment
     `current_sprint:` to the next zero-padded sprint id (with
     bounds), reset `cycle_count:` to 0, append the sprint-scoped
     contract section to `.yoke/contracts/<slug>.md`, and **write
     a sprint-boundary entry** to `wm_progress_path` summarizing
     the sprint outcome before resuming the outer walk.
   - When `current_sprint` would exceed the last sprint id (i.e.
     every sprint has been completed), promote to the **full-run
     merge-ready sweep**: run `hooks/verify-acceptance.sh
     --concurrency 1 --tier all` (no `--criterion`, no `--sprint`)
     and redirect stdout to
     `$(wm_runtime_dir)/.merge-ready-snapshot.yaml`. The merge-ready
     sweep ignores `schedule_next` entirely — every sensor (cheap
     AND expensive) across every criterion MUST pass before the run
     terminates, regardless of any per-sprint authorization. Scoped
     / parallel / tier-filtered modes never decide convergence; the
     serial full-suite sweep across all tiers is the authoritative
     final check (sensor-cost-tiering Part 5). If every criterion
     in the Acceptance Contract has `status: pass` in this snapshot
     AND no `divergence` verdict from the Validator, return
     MERGE-READY and advance to the canonization handoff (§3).
     Otherwise, escalate `escalate.sh --reason divergence
     --category quality-policies-broken` — a converged-per-sprint
     run that fails the cross-sprint sweep is a coupling regression
     between sprints.
   - On no per-sprint convergence: continue to step 9.

9. **Cycle status snapshot (deterministic, exactly once per cycle).**
   Run `bash lib/ralph-loop/status-snapshot.sh "$(wm_runtime_dir)"`
   and emit its stdout to the user verbatim. Fires once per cycle,
   only when the loop continues to the next cycle — i.e. **after**
   step 6 (`post-iteration.sh`) and step 7 (`check-hard-bounds.sh`)
   have completed and step 8 chose to continue. Do **not** emit on
   MERGE-READY (the canonize handoff prints the exit summary) or on
   escalation paths (`escalate.sh` already surfaces full state via
   the Trigger-4 packet). Do **not** emit between step 1 and step 8
   — the per-notification / mid-cycle window must remain silent.
   On non-zero helper exit, log a single line `(status snapshot
   unavailable: <stderr summary>)` and continue — the snapshot is a
   user-visibility node, never a cycle-blocking node.

### 3. Termination handoff — Orchestrator canonize call (single agentic call)

The handoff fires once when the loop terminator hits — whether the
loop converged (MERGE-READY) or paused (Trigger-4 / hard-bound /
infeasibility). Issue a **single Orchestrator-only Task call** with
input `mode=canonize` and `model: $orch_canonize_model` (resolved at
preflight; see §1). This call is **foreground** — background spawning
applies only to the per-cycle batch in step 1; the canonize handoff's
result is needed inline for the skill's exit summary ("Merge-ready.
Canonization summary: <count> PRs opened.") and for downstream PR-URL
reporting.
Canonize-mode never reuses the per-cycle consult/monitor model —
Model C governance writes stay top-tier, even when consult/monitor
were pinned to a smaller class. Per
`concepts/yoke-pattern-model-c-governance`, canonization decides
canonical-memory writes — mismatching the canonize model is an R4
defect that the Part-3 smoke gates against.

- Input includes `wm_progress_path`, `wm_contracts_path`, all
  `$(wm_snapshots_dir)/cycle-*.yaml`, and the loop's termination
  reason
  (`merge-ready` | `divergence` | `contract-conflict` |
  `hard-bound` | `infeasibility`).
- Orchestrator (in canonize mode) invokes `/yoke:preserve` via the
  Skill tool, passing the active task's `.yoke/<task-slug>/` path
  and `--from-orchestrator`. `/yoke:preserve` invokes
  `lib/canonical-memory/canonization-criteria.sh` to apply the
  five-criterion cascade, reads each candidate's `impact_level`,
  and opens PRs per Model C.
- Per Model C: low-impact PRs auto-merge after CI; medium PRs open
  with veto window; high-impact and regulatory PRs surface for
  synchronous human review without blocking the skill's exit.
- This is the **only** canonical-memory write path during the loop.
  Mid-loop Orchestrator invocations (consult / monitor mode) never
  invoke `/yoke:preserve`.

Exit with the loop's termination reason and a one-line summary of
PRs opened (count + URLs).

### 4. Termination paths

After the canonize handoff in §3 returns, call
`wm_runtime_cleanup "$termination_reason" "$canonize_exit_code"`
(from `lib/working-memory/cleanup.sh`) **before** printing the exit
summary. The helper is gated on `(reason == merge-ready &&
canonize_exit == 0)` and is a no-op otherwise — so paused
terminations (divergence, contract-conflict, hard-bound,
infeasibility) and canonize failures preserve `.yoke/runtime/`
intact for the user to arbitrate, resume, or manually re-canonize.

- **All criteria pass** → loop returns MERGE-READY; canonize handoff
  fires (Orchestrator invokes `/yoke:preserve` via the Skill tool).
  On canonize success, `wm_runtime_cleanup` deletes the contents of
  `wm_runtime_dir` (the directory itself stays). Print:
  "Merge-ready. Canonization summary: <count> PRs opened."
  `/yoke:preserve` can also be invoked manually for re-canonization
  against canonical memory (e.g. after a model upgrade) — note that
  runtime working memory has been cleared by the cleanup step, so
  manual re-canonization re-evaluates canonical entries directly,
  not stale runtime state.
- **Sprint contract contradicts Acceptance Contract** → invoke
  `lib/ralph-loop/escalate.sh --reason contract-conflict`; emits
  Trigger-4 packet; canonize handoff still fires (with termination
  reason `contract-conflict`) so partial learnings are not lost.
- **Divergence verdict from Validator** → invoke
  `lib/ralph-loop/escalate.sh --reason divergence --category <quality-policies-broken|technical-infeasibility|business-conflict|requires-contract-modification>`;
  Trigger-4 packet; canonize handoff fires.
- **Hard bound reached** → `check-hard-bounds.sh` invokes
  `escalate.sh --reason hard-bound` and exits 10; canonize handoff
  fires (the loop's partial state is the canonization signal).
- **Fundamental infeasibility detected by Generator** → `escalate.sh
  --reason infeasibility`; canonize handoff fires.

The Trigger-4 packet is non-coalescable with Triggers 1, 2, 3, 5 —
see `concepts/yoke-pattern-human-triggers`.

## Pre-conditions

- `.yoke/config.yaml` exists.
- `.yoke/runtime/.current` exists and points at a valid slug.
- `.yoke/prds/<slug>.md` (approved), `.yoke/specs/<slug>.md`
  (approved), every `.yoke/sprints/<slug>-s*.md`
  (`status: approved`), `.yoke/acceptance-contracts/<slug>.md`
  (ratified).

## Output contract

- Exit 0 with merge-ready code + canonize summary on full
  convergence.
- Exit non-zero with a clear pause/abort message on divergence,
  contradiction, hard-bound, or pre-condition failure. The canonize
  handoff still fires before exit (except on pre-condition failure).

## Anti-patterns

- Do NOT spawn the three subagents sequentially. They must launch in
  a **single assistant turn with three concurrent Task calls** so
  they execute in parallel.
- Do NOT spawn the per-cycle batch in foreground. The three Task
  calls in step 1 must use `run_in_background: true` so the
  assistant turn does not block on completion. The termination
  canonization handoff (step 3) is the **only** Task call in the
  loop that runs foreground — its result is needed inline for the
  exit summary.
- Do NOT poll, sleep, or otherwise probe for completion state during
  the wait between step 1 and step 2. The skill relies on Claude
  Code's automatic completion notifications; manual probing
  introduces latency without changing semantics.
- Do NOT let the subagents share context. Each Task call passes only
  the explicit inputs listed in step 2; communication is via
  working-memory files.
- Do NOT invoke `/yoke:preserve` mid-loop. Canonization fires only
  at termination via the Orchestrator's canonize-mode handoff.
  Canonical-memory writes happen only in the termination handoff
  (step 3).
- Do NOT skip `hooks/verify-acceptance.sh` between cycles — sensor
  output is the structured channel through which the Validator
  judges the next cycle.
- Do NOT call `wm_runtime_cleanup` on non-MERGE-READY exits — paused
  loops (Trigger-4 divergence, contract-conflict, hard-bound,
  infeasibility) require cycle history for resumption. The helper is
  internally gated on `(reason == merge-ready && canonize_exit == 0)`;
  bypassing the gate destroys the user's ability to resume after
  arbitration.
- Do NOT silently relax the Acceptance Contract. Sprint contracts
  that contradict the Contract pause the loop.
- Do NOT proceed past 5–8 cycles without an external `timeout`
  before Sprint 6's hard bounds are wired.
- Do NOT spawn `agents/orchestrator.md` recursively from inside any
  subagent — only this skill spawns subagents.
- Do NOT spawn `semantic-judge` (or any inferential-sensor agent)
  from inside any subagent — only `/yoke:implement` spawns
  inferential-sensor agents. The Validator never invokes
  `Agent(subagent_type: semantic-judge, …)`; it consumes verdicts
  written to `.yoke/runtime/.judge-verdicts/cycle-<N-1>/` by judges
  spawned in the previous cycle's batch.
- Do NOT emit user-visible status mid-cycle — between step 1
  (per-cycle batch dispatch) and step 9 (cycle status snapshot) the
  skill must stay silent. The status block is a single, fixed-format
  emission per cycle; per-notification or per-step output dilutes
  back-pressure (`conventions.md`: "success is silent, failures are
  verbose") and turns the cycle log into a scrollable mess.

## See also

- `concepts/yoke-pattern-ralph-loop`.
- `concepts/yoke-pattern-roles`.
- `concepts/yoke-pattern-model-c-governance` — termination-time
  write protocol.
- `agents/generator.md`, `agents/validator.md`,
  `agents/orchestrator.md`.
- `lib/ralph-loop/orchestrate.sh`,
  `lib/ralph-loop/escalate.sh`,
  `lib/canonical-memory/canonization-criteria.sh` (invoked from
  inside `/yoke:preserve`).
- `skills/ask/SKILL.md` (canonical-memory reads — Part 3 of the
  bedrock canonical-memory port retired `query.sh`).
- `skills/preserve/SKILL.md` (canonical-memory writes — Part 4
  retired `propose-write.sh`).
- `hooks/pre-implementation.sh`, `hooks/post-iteration.sh`,
  `hooks/verify-acceptance.sh`, `hooks/check-hard-bounds.sh`.
