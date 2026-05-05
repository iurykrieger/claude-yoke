---
name: implement
description: >
  Phase 4 — adversarial ralph loop (v3.0 council protocol). Walks
  sprints serially: reads `current_sprint:` from
  `.yoke/runtime/progress.md`, loads
  `.yoke/sprints/<slug>-s<current_sprint>.md` as the cycle's working
  set, drives every cycle through three named phases — Phase A
  (parallel persona Tasks behind a deterministic file-marker barrier),
  Phase B (bounded council loop with quiescence + LLM contradiction-
  detection arbiter), Phase C (cycle entry on consensus or Trigger 4
  on cap-exhausted divergence). Iterates ≤8 cycles against the binding
  Acceptance Contract, advances the pointer and resets the cycle
  counter on per-sprint convergence. Sprint contracts on consensus
  persist to `.yoke/contracts/<slug>.md`; runtime state under
  `.yoke/runtime/`. At full convergence (every sprint complete),
  issues one final Orchestrator call with `mode=canonize` to apply
  the five-criteria filter and propose Model C writes to canonical
  memory.
argument-hint: ""
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /yoke:implement — Phase 4 (council ralph loop, v3.0)

Drive a 3-persona council (Sr Eng / Sr QA / Sr Staff) inside the
envelope of the binding Acceptance Contract, sprint by sprint, with
the Orchestrator subagent owning the canonization handoff at full-run
termination.

> **v3.0 architectural note (Sprint 02 cutover).** The v2.x
> Generator/Validator/Orchestrator-monitor invocation path is
> **REMOVED** from this skill. Each cycle now has three named phases
> reflected in `progress.md`:
>
> - **Phase A** — three persona Tasks (`agents/sr-eng.md`,
>   `agents/sr-qa.md`, `agents/sr-staff.md`) spawn in parallel via
>   a single Task batch; each writes its slice file at
>   `.yoke/runtime/cycles/<N>/<persona>.md` and its Phase-A marker
>   at `.yoke/runtime/.phase-a-done.<persona>` before exit.
>   `lib/runtime/cycle.sh pre-spawn` clears stale markers and
>   validates persona files before the spawn; `post-spawn` defensively
>   waits on every marker after Task completion.
> - **Phase B** — `lib/runtime/council.sh phase-b` runs up to
>   `overrides.runtime.council_rounds_max` réplica rounds (default 3),
>   detecting quiescence deterministically (zero new réplicas in a
>   round → consensus) and invoking `agents/council-arbiter.md` only
>   between rounds that produced réplicas. The arbiter emits a
>   structured JSON verdict; the loop branches on `consensus` plus
>   `contradictions[]` length.
> - **Phase C** — on consensus, the cycle ends and the next cycle
>   opens. On cap-exhausted divergence, `lib/runtime/trigger-4.sh
>   render` produces the user-facing escalation message and
>   `lib/ralph-loop/escalate.sh --reason divergence` emits the
>   Trigger-4 packet.
>
> Per Sprint 04 of the agent-council PRD (the v3.0 cutover cleanup),
> the legacy v2.x agent files (the binary-loop pair under `agents/`)
> have been deleted. `agents/orchestrator.md` survives in
> canonize-only mode for the termination handoff in §3 below; its
> body no longer carries the legacy non-canonize mode sections.
> Per-cycle canonical-memory reads are issued by the council
> personas themselves via direct `/yoke:search-canonical-memory`
> calls, and divergence detection is owned by
> `lib/runtime/sync-barrier.sh` plus `agents/council-arbiter.md`
> inside Phase B.
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

- Enforce the v2.0.0 hard break: `source <plugin_dir>/lib/yoke-prelude.sh && yoke_require_provider || exit 1`. The helper aborts non-zero with a stderr diagnostic when `canonical_memory.provider` is missing or empty (unmigrated v1.x projects); surface its stderr verbatim and exit. See Acceptance Contract Scenario 12 / FR-6.
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
- **Dry-run inspection mode (production feature, not a test-only branch).**
  Setting the environment variable `YOKE_IMPLEMENT_DRY_RUN=1` runs
  every preflight gate check (config presence, upstream-artifact
  approval, AC ratification, gate-state ladder, sprint-file
  presence) and exits 0 with stdout `dry-run: ok` BEFORE Phase A
  council spawn. The cycle loop reads the marker and short-circuits
  — useful for verifying gate state on a real working tree without
  paying the council-spawn cost (e.g., a user checking that
  `/yoke:generate-sprints` is the correct next step before
  committing to a full implement run). The dry-run path honors the
  same gate semantics as the regular path; it differs only in
  exiting after the deterministic node finishes and before the
  agentic node begins.
- Run `lib/ralph-loop/orchestrate.sh preflight`. The script verifies:
  - `.yoke/config.yaml` exists.
  - `.yoke/runtime/.current` exists and points at a valid slug.
  - `wm_phase1_artifact_path "$slug"` (the Phase-1 artifact resolver
    returning either `.yoke/prds/<slug>.md` or `.yoke/fixes/<slug>.md`,
    aborting with a structured FR-9 recovery diagnostic when both
    archives exist or when neither does) and `wm_spec_path "$slug"`
    exist and carry `Status: approved`.
  - **Flow detection (legacy / new).** The presence of
    `.yoke/acceptance-criteria/<slug>.md` selects the new-flow
    ladder; absence selects the legacy ladder
    (`.yoke/acceptance-contracts/<slug>.md`). Both archives must
    carry `Status: ratified` to advance.
  - **Gate-state refusal (new flow only).** After the upstream
    artifacts are validated, the preflight calls
    `lib/working-memory/gate-state.sh :: detect_gate_state`. When
    the active task sits at `awaiting:generate-sprints` (spec +
    AC ratified, zero sprint files), the preflight aborts non-zero
    with the literal stderr `wm: run /yoke:generate-sprints to
    advance to Phase 4` and exit code 4. Legacy tasks (no AC under
    `acceptance-criteria/`) never reach this branch — the
    `is_legacy` short-circuit keeps them walking unaffected, per
    FR-15 / Decision 6A of
    `.yoke/prds/2026-05-03-generate-sprints-skill.md`.
  - At least one sprint file MUST exist for the cycle loop to have
    a working set to load. (For new-flow tasks the gate-state
    refusal above already surfaces the actionable next step; this
    final check is the safety net for both flows.)
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
  was retired in ask-source-agnostic-read Part 1 — `/yoke:search-canonical-memory` is now a
  pure read and emits no trace.
- **Resolve per-role models.** Source
  `lib/runtime/agent-config.sh`. Compute:
  ```
  sr_eng_model="$(yoke_resolve_model sr-eng)"
  sr_qa_model="$(yoke_resolve_model sr-qa)"
  sr_staff_model="$(yoke_resolve_model sr-staff)"
  arbiter_model="$(yoke_resolve_model council-arbiter)"
  orch_canonize_model="$(yoke_resolve_model orchestrator.canonize)"
  ```
  In v3.0 every recognized role inherits the session model by default;
  hosts override per-role under `runtime.models.<role>` in
  `.yoke/config.yaml` (e.g. `runtime.models.sr-eng: claude-sonnet-4-6`)
  and per-orchestrator-mode under
  `runtime.models.orchestrator.canonize`. Empty resolved values mean
  "no pinning — inherit session model". Log every resolved value via
  `yoke_log_resolved_models "$(wm_runtime_dir)/.task-spawn-log"` —
  the log is append-only and lives alongside the cycle counter; it is
  the cheapest verification gate for pinning provenance. Quality is
  king on Model C governance writes (canonize), so the canonize call
  never auto-downgrades.

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
sprint boundaries), drive the cycle through **Phase A → Phase B →
Phase C**. The phase boundaries are reflected in `progress.md`'s
per-cycle entry.

1. **Phase A — parallel persona spawn (single agentic turn, three
   background Task calls).** Each cycle's Phase A is a deterministic
   pre-spawn step + a single Task batch + a deterministic post-spawn
   wait.

   1a. **Pre-spawn (deterministic).** Source
   `lib/runtime/cycle.sh` and call `cycle.sh pre-spawn "$slug"
   "$cycle_count"`. The helper:
   - Calls `bash lib/runtime/sync-barrier.sh clear-markers` to
     clear any leftover Phase-A markers from a prior interrupted
     cycle (idempotent — no-op when no markers exist).
   - Calls `bash lib/runtime/persona-loader.sh validate-all
     agents/`. Fail-fast on any invalid persona file (a
     `wm:`-prefixed stderr line names the offending file plus
     key); this is a pre-condition failure that surfaces to the
     user without spawning the cycle's Tasks.
   - Prints the sorted council persona-name list to stdout
     (`sr-eng`, `sr-qa`, `sr-staff` for the v3.0 default;
     arbitrary `sr-*` files for host overrides). The coordinator
     reads the list and issues one Task per persona.

   1b. **Spawn (single assistant turn, three concurrent Task calls).**
   Issue exactly **three concurrent Task calls** in a single
   assistant turn — one per persona returned by `pre-spawn`. Each
   Task call sets `run_in_background: true` so the assistant turn
   does not block on completion. Each Task call sets
   `subagent_type: <persona-id>` (the persona file's frontmatter
   `name:`) so Claude Code's loader picks `agents/<persona>.md`.
   No `model:` override is applied to council personas — they
   inherit the user's session model. The per-role
   `agent-config.sh::yoke_resolve_model` resolution is **retired**
   for the council protocol; only the canonize-mode handoff at
   §3 honors a model pin (via `$orch_canonize_model`).

   Each persona Task is prompted with:
   - The persona's body template (resolved by Claude Code's loader
     from the persona file).
   - The cycle's working set: PRD, Spec, the **active sprint file**
     at `.yoke/sprints/<slug>-s<current_sprint>.md`, the binding
     Acceptance Contract, the prior cycle's snapshot at
     `$(wm_snapshots_dir)/cycle-<N-1>.yaml`, and the slice path
     `wm_persona_slice_path "$slug" "$cycle_count" "$persona"`.
   - An instruction to write its slice file + drop the Phase-A
     marker `.yoke/runtime/.phase-a-done.<persona>` before
     exiting.

   Per-persona file-write contracts are documented in
   `agents/sr-*.md`'s "Anti-scope" section: each persona writes
   only its own slice file, never another persona's; Sr QA writes
   acceptance-contract-anchored tests under
   `tests/acceptance/<contract-slug>/`; Sr Eng writes production
   code + happy-path unit tests; Sr Staff writes verdicts and
   review-skill output. No persona writes `progress.md` —
   `progress.md` is a Phase-C artifact owned by the coordinator.

   1c. **Post-spawn wait (deterministic).** After dispatching the
   three Task calls, **wait for all three completion notifications**
   before advancing to Phase B. Do **not** poll, sleep, or
   otherwise probe for state — Claude Code emits a completion
   notification automatically when each background Task ends.
   Then call `cycle.sh post-spawn "$slug" "$cycle_count"`; the
   helper invokes `lib/runtime/sync-barrier.sh wait-all` against
   the persona list as a defensive guard. A timeout here is
   sensor-bug or harness-bug, not normal flow — `wait-all`'s
   `wm: sync-barrier timeout:` stderr line names the missing
   marker.

2. **Phase B — council loop (deterministic outer wrapper, agentic
   inner rounds).** Run `bash lib/runtime/council.sh phase-b
   "$slug" "$cycle_count"`. The helper drives the bounded round
   loop:
   - Reads `overrides.runtime.council_rounds_max` from
     `.yoke/config.yaml` (default 3).
   - For each round R (1..cap):
     - Merges every persona's slice via
       `lib/runtime/council-merge.sh merge <cycle-dir>` to produce
       the merged council view.
     - Issues three concurrent Task calls (one per persona) prompted
       to read the merged view and append `## Phase B round R —
       readings` and optional `## Phase B round R — réplica`
       sections to their slice. `run_in_background: true`. Wait
       for all three completions.
     - Counts non-empty `## Phase B round R — réplica` sections.
     - If zero (quiescence) → exit `consensus`.
     - Else → spawn `agents/council-arbiter.md` via Task tool with
       `subagent_type: council-arbiter`, prompted with the merged
       view + the round's réplicas. Parse the arbiter's JSON
       verdict (round, consensus, contradictions[],
       tone_only_pairs[]). When `consensus: true`, exit
       `consensus`. Else continue to round R+1 if R < cap.
   - On cap exhausted with `consensus: false`, exit `trigger-4`
     and persist the last arbiter verdict at
     `<cycle-dir>/.last-arbiter-verdict.json`.
   - Emits a YAML summary on stdout (rounds_consumed,
     per_round_replica_counts, exit_status, arbiter_verdict_summary,
     last_arbiter_verdict_path on cap exhaustion). The coordinator
     persists this verbatim into the cycle's `progress.md` entry.

3. **Phase C — convergence or escalation (deterministic).** Read
   the Phase B summary's `exit_status:`:
   - `consensus` → continue to step 4 (sensor execution + the rest
     of the deterministic tail).
   - `trigger-4` → render the user-facing escalation message and
     emit the Trigger-4 packet:
     ```
     bash lib/runtime/trigger-4.sh render \
       <merged-view> \
       <last-arbiter-verdict> \
       .yoke/runtime/.trigger4-council-message.md
     bash lib/ralph-loop/escalate.sh \
       --reason divergence \
       --category quality-policies-broken \
       --council-merged-view <merged-view> \
       --council-arbiter-verdict <last-arbiter-verdict>
     ```
     The Trigger-4 packet references the rendered message via
     `council_message_path:`. The loop pauses for human
     arbitration; the canonize handoff (§3 below) still fires.

   The semantic-judge inferential-sensor batch is **retired** for
   the council protocol — Sr QA owns the Validation interpretation
   per the binding contract, and the council arbiter handles
   pairwise disagreement classification. The
   `.yoke/runtime/.judge-verdicts/` and
   `.deferred-sensors.json` paths remain for backward compatibility
   with sensor files that pre-date v3.0; v3.x can prune them
   under a follow-up PRD.

4. **Sensor execution — cheap-equivalent (deterministic).** Run
   `hooks/verify-acceptance.sh --max-time-cost 60` to capture cycle N's
   post-Generator sensor state at the cheap-equivalent cost ceiling
   (sensors whose `time_cost:` exceeds the cap are skipped; the cap is
   the coordinator's filter, replacing the retired `--tier cheap`
   flag per the sensor-harness-realignment refactor — cost-based
   filtering of which sensors run this cycle is the coordinator's
   job, not a council persona's). Pass `--criterion <id>` where
   `<id>` is the active sprint's currently-failing criterion (read
   from the most recent `citing_criterion:` entry in
   `wm_progress_path`); pass
   `--fragments-dir "$(wm_runtime_dir)/.pending-fragments"`;
   redirect stdout to `$(wm_runtime_dir)/.pending-snapshot.yaml`.
   Sensors run in parallel via `xargs -P "$(yoke_sensor_concurrency)"`
   (default 4, configurable via `runtime.sensor_concurrency` in
   `.yoke/config.yaml`). When no `citing_criterion` is recorded
   (cycle 0 / fallback) omit `--criterion` and run every sensor that
   fits the cap. Sr QA reads the resulting snapshot during the next
   cycle's Phase A (Model A lag-by-one) — Sr QA never invokes
   `verify-acceptance.sh` itself.

5. **Sensor execution — expensive-equivalent (deterministic).**
   From cycle 2 onward, run a higher-ceiling sweep that lets
   inferential / longer-running sensors fire without flooding cheap
   cycles with their cost. Sr QA's verdict no longer emits a
   `schedule_next:` block to gate this — that mechanism was retired
   in the sensor-harness-realignment refactor; cost-based filtering
   moved to the coordinator. Skip the expensive sweep on cycle 1
   (no prior adversarial signal yet to justify the cost). On
   cycle ≥ 2, run
   `hooks/verify-acceptance.sh --max-time-cost 600 --criterion <id>
   --fragments-dir "$(wm_runtime_dir)/.pending-fragments"` and
   **append** its results to the same
   `$(wm_runtime_dir)/.pending-snapshot.yaml` (the snapshot is the
   union of Phase A + Phase B). Sensors that already fit the
   cheap-equivalent cap from Phase A are de-duplicated by
   `verify-acceptance.sh` (it skips sensors whose snapshot entry is
   already present in the merge target). Both phases respect the
   `runtime.inferential_sensor_concurrency` cap and the deferred-
   sensors queue. The cheap-vs-expensive split is no longer a hard
   tier classification — it is a soft cost-ceiling shift between the
   two phases; the same sensor file is eligible for either phase
   depending on whether its `time_cost:` fits the cap. Source PRD:
   `.yoke/prds/2026-04-27-sensor-cost-tiering.md` (Part 4's
   `schedule_next` mechanism was retired by the
   `2026-04-30-sensor-harness-realignment` PRD).

6. **Contradiction check (deterministic).** Run
   `lib/ralph-loop/orchestrate.sh check-contradiction`. If a sprint
   contract textually contradicts an Acceptance Contract criterion
   (heuristic: contains a relax/remove/skip/disable/bypass/ignore
   verb together with a criterion identifier), the script exits 10
   and the loop pauses with a clear message: "Sprint contract
   contradicts Acceptance Contract. Pausing for human arbitration."

7. **Persist (deterministic).** Run `hooks/post-iteration.sh`. The
   hook:
   - Increments the cycle counter at `wm_cycle_counter_path`
     (`.yoke/runtime/.cycle-counter`).
   - Snapshots `verify-acceptance.sh` output to
     `$(wm_snapshots_dir)/cycle-<N>.yaml`.

8. **Hard-bound check (deterministic).** Run
   `hooks/check-hard-bounds.sh`. If cycles, timeout, or token
   budget is exceeded, the hook invokes
   `lib/ralph-loop/escalate.sh --reason hard-bound` and exits 10.
   The skill treats this as a pause-with-arbitration-packet.

9. **Stop check — per-sprint convergence + full-run merge-ready
   sweep.** This step decides three outcomes: (a) advance to the
   next sprint, (b) declare MERGE-READY (last sprint just
   converged), or (c) continue this sprint's loop.
   - First, run `hooks/verify-acceptance.sh --concurrency 1
     --sprint <current_sprint>` (no `--criterion`, no cost cap),
     filtering sensors / criteria to those declared in the active
     sprint file's `## Functional acceptance criteria` and
     `## Sensors` blocks. The convergence sweep runs every
     in-sprint sensor regardless of cost — the cheap-equivalent /
     expensive-equivalent ceilings used in steps 2–3 are per-cycle
     filters, not convergence filters. Redirect stdout to
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
     --concurrency 1` (no `--criterion`, no `--sprint`, no cost cap)
     and redirect stdout to
     `$(wm_runtime_dir)/.merge-ready-snapshot.yaml`. Every sensor
     across every criterion MUST pass before the run terminates,
     regardless of any per-cycle cost-cap filtering. Scoped /
     parallel / cost-capped modes never decide convergence; the
     serial full-suite sweep at no cost cap is the authoritative
     final check (sensor-cost-tiering Part 5). If every criterion
     in the Acceptance Contract has `status: pass` in this snapshot
     AND no `divergence` verdict from the Validator, return
     MERGE-READY and advance to the canonization handoff (§3).
     Otherwise, escalate `escalate.sh --reason divergence
     --category quality-policies-broken` — a converged-per-sprint
     run that fails the cross-sprint sweep is a coupling regression
     between sprints.
   - On no per-sprint convergence: continue to step 8.

10. **Cycle status snapshot (deterministic, exactly once per cycle).**
   Run `bash lib/ralph-loop/status-snapshot.sh "$(wm_runtime_dir)"`
   and emit its stdout to the user verbatim. Fires once per cycle,
   only when the loop continues to the next cycle — i.e. **after**
   step 5 (`post-iteration.sh`) and step 6 (`check-hard-bounds.sh`)
   have completed and step 7 chose to continue. Do **not** emit on
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
- Orchestrator (in canonize mode) invokes `/yoke:canonize` via the
  Skill tool, passing the active task's `.yoke/<task-slug>/` path
  and `--from-orchestrator`. `/yoke:canonize` resolves the active
  provider via `lib/canonical-memory/resolve-provider.sh` and
  dispatches to the provider's pinned canonize skill (e.g.
  `/bedrock:teach` for the bedrock provider per `providers.yaml`),
  which applies the five-criterion cascade, reads each candidate's
  `impact_level`, and opens PRs per Model C.
- Per Model C: low-impact PRs auto-merge after CI; medium PRs open
  with veto window; high-impact and regulatory PRs surface for
  synchronous human review without blocking the skill's exit.
- This is the **only** canonical-memory write path during the loop.
  Mid-loop Orchestrator invocations (consult / monitor mode) never
  invoke `/yoke:canonize`.

Exit with the loop's termination reason and a one-line summary of
PRs opened (count + URLs).

### 4. Sensor consolidation teardown (single Skill invocation)

After the canonize handoff in §3 returns and **before** the runtime
cleanup in §5, invoke `/yoke:consolidate-sensors` via the Skill tool
to distill the loop's runtime evidence (verdicts under
`.yoke/runtime/.judge-verdicts/`, durations under
`.yoke/runtime/progress.md`) back into the durable per-sensor files
at `.yoke/sensors/<id>.md`. The skill:

- Reads `.yoke/config.yaml`'s `sensor_consolidation:` key
  (`review` | `auto` | `skip`, default `review`) and short-circuits
  to a silent no-op when set to `skip`.
- Is non-blocking by design — a non-zero exit does NOT roll back the
  implement run. Log the skill's exit code and proceed to §5.
- Reads the up-to-date `.yoke/runtime/progress.md` (which the
  per-cycle persist step has finalized by this point), so observed
  durations and citations reflect the full loop history.

When the Skill tool is unavailable (e.g. CLI runtime that does not
expose the Skill tool), print a clear instruction telling the user
to run `/yoke:consolidate-sensors` manually before the next
implement invocation, and proceed to §5. The teardown does not
block on the missing-tool path; deferring consolidation to a manual
invocation is acceptable when the harness cannot dispatch it
automatically.

This is the **only** invocation of `/yoke:consolidate-sensors` in
the loop. Do not invoke it mid-loop — runtime evidence is
incomplete until the loop terminates.

### 5. Termination paths

After §4's consolidation teardown returns, call
`wm_runtime_cleanup "$termination_reason" "$canonize_exit_code"`
(from `lib/working-memory/cleanup.sh`) **before** printing the exit
summary. The helper is gated on `(reason == merge-ready &&
canonize_exit == 0)` and is a no-op otherwise — so paused
terminations (divergence, contract-conflict, hard-bound,
infeasibility) and canonize failures preserve `.yoke/runtime/`
intact for the user to arbitrate, resume, or manually re-canonize.

- **All criteria pass** → loop returns MERGE-READY; canonize handoff
  fires (Orchestrator invokes `/yoke:canonize` via the Skill tool).
  On canonize success, `wm_runtime_cleanup` deletes the contents of
  `wm_runtime_dir` (the directory itself stays). Print:
  "Merge-ready. Canonization summary: <count> PRs opened."
  `/yoke:canonize` can also be invoked manually for re-canonization
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
  (`status: approved`), `.yoke/acceptance-criteria/<slug>.md`
  (ratified).

## Output contract

- Exit 0 with merge-ready code + canonize summary on full
  convergence.
- Exit non-zero with a clear pause/abort message on divergence,
  contradiction, hard-bound, or pre-condition failure. The canonize
  handoff still fires before exit (except on pre-condition failure).

## Anti-patterns

- Do NOT spawn the three personas sequentially. They must launch in
  a **single assistant turn with three concurrent Task calls** so
  they execute in parallel (Phase A step 1b).
- Do NOT spawn the Phase A persona Tasks or the Phase B per-round
  Tasks in foreground. They must use `run_in_background: true` so
  the assistant turn does not block on completion. The termination
  canonization handoff (§3) is the **only** Task call in the loop
  that runs foreground — its result is needed inline for the exit
  summary.
- Do NOT poll, sleep, or otherwise probe for completion state during
  the Phase A or Phase B waits. The skill relies on Claude Code's
  automatic completion notifications; manual probing introduces
  latency without changing semantics.
- Do NOT let the personas share context. Each Task call passes only
  the explicit inputs listed in Phase A step 1b; communication is
  via working-memory files (per-persona slices + the merged view
  produced by `lib/runtime/council-merge.sh`).
- Do NOT spawn `agents/orchestrator.md` from inside
  `/yoke:implement`'s per-cycle loop. The legacy v2.x runtime spawn
  path (Generator / Validator / Orchestrator-monitor) was REMOVED in
  Sprint 02 of the v3.0 council protocol PRD
  (`.yoke/prds/2026-05-01-agent-council.md`); the residual legacy
  agent files were deleted in Sprint 04 of the same PRD. The
  canonize-mode Orchestrator call at §3 is the ONLY place where
  `agents/orchestrator.md` is spawned, and it fires exactly once at
  full-run termination (every sprint complete).
- Do NOT spawn `semantic-judge` for council cycles. The v3.0 council
  protocol delegates Validation interpretation to Sr QA per the
  binding contract and pairwise-disagreement classification to
  `agents/council-arbiter.md`. The `semantic-judge` subagent file
  remains on disk for legacy sensors that still reference it; new
  inferential sensors authored under v3.0 should target the
  council-arbiter dispatch path instead.
- Do NOT invoke `/yoke:canonize` mid-loop. Canonization fires only
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
  council persona — only this skill spawns subagents. The canonize
  handoff at §3 is the only orchestrator spawn under the council
  protocol.
- Do NOT spawn `agents/council-arbiter.md` from inside a council
  persona Task. Only `lib/runtime/council.sh phase-b` (driven by
  this skill) spawns the arbiter, and only between réplica rounds
  that produced ≥ 1 réplica. Council personas reading the merged
  view never trigger arbiter Tasks themselves.
- Do NOT emit user-visible status mid-cycle — between Phase A spawn
  (step 1b) and the cycle status snapshot (step 10) the skill must
  stay silent. The status block is a single, fixed-format emission
  per cycle; per-notification or per-step output dilutes back-
  pressure (`conventions.md`: "success is silent, failures are
  verbose") and turns the cycle log into a scrollable mess.

## See also

- `concepts/yoke-pattern-ralph-loop`.
- `concepts/yoke-pattern-roles`.
- `concepts/yoke-pattern-model-c-governance` — termination-time
  write protocol.
- `agents/sr-eng.md`, `agents/sr-qa.md`, `agents/sr-staff.md`
  (council personas).
- `agents/council-arbiter.md` (contradiction-detection JSON verdict).
- `agents/orchestrator.md` (canonize-only termination handoff).
- `lib/ralph-loop/orchestrate.sh`, `lib/ralph-loop/escalate.sh`.
- `lib/canonical-memory/resolve-provider.sh` (provider resolution
  for the canonize handoff).
- `skills/search-canonical-memory/SKILL.md` (canonical-memory reads;
  v2.0.0 facade — every council persona read goes through this).
- `skills/canonize/SKILL.md` (canonical-memory writes; v2.0.0
  facade — only the canonize-mode Orchestrator invokes it).
- `hooks/pre-implementation.sh`, `hooks/post-iteration.sh`,
  `hooks/verify-acceptance.sh`, `hooks/check-hard-bounds.sh`.
