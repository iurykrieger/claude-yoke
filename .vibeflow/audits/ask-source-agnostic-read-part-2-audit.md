# Audit Report: ask-source-agnostic-read-part-2

**Verdict: PASS**

> Auditor: /vibeflow:audit (autonomous run, 2026-04-25)
> Spec: `.vibeflow/specs/ask-source-agnostic-read-part-2.md`
> PRD: `.vibeflow/prds/ask-source-agnostic-read.md`
> Dependency: ask-source-agnostic-read-part-1 (PASS)

## Test execution

No project-wide test runner exists. The smoke tests
(`sprint-2.test.sh`, `sprint-5.test.sh`, `folder-isolation.test.sh`,
`ask-no-clone.test.sh`) remain failing for the same reason as Part 1's
audit: each asserts the old query-trace contract that this PR series
deliberately retires. Those failures are owned by Part 3, which depends
on Parts 1 and 2 having landed.

| Verification | Result |
| :--- | :--- |
| All three agents `tools:` includes `Skill` | PASS |
| All three agents `description` free of `query-traces` / "trace lands" | PASS |
| Orchestrator Authority section: declarative bypass rule | PASS |
| Orchestrator Mode A: invoke `/yoke:ask`, reason inline | PASS |
| Orchestrator Mode B (Monitor) and Mode C (Canonize) structurally intact | PASS |
| Generator/Validator cycle-start trace-read replaced with on-demand `/yoke:ask` | PASS |
| Generator/Validator "Never read directly" rewritten with explicit `/yoke:ask` routing | PASS |
| Decision 5 transition guards present in all three agents | PASS |

## DoD Checklist

- [x] **DoD-1** — Orchestrator Mode A consult-mode rewritten: invokes
      `/yoke:ask` via the Skill tool and reasons over the response
      in-conversation; no instructions to write
      `.yoke/query-traces/<slug>.md`.
      *Evidence:* `agents/orchestrator.md` "Mode A — Consult" bullets:
      "Read canonical memory by invoking `/yoke:ask` via the Skill
      tool", "Reason over the `/yoke:ask` response inline … no file is
      written on disk as a consult-mode side effect". `grep -nE
      "write.*query-trace|trace lands|trace entry|YAML trace"` returns
      empty.
- [x] **DoD-2** — Orchestrator no longer asserts the "absence of trace
      entry is a bypass" rule. Bypass discipline is restated
      declaratively.
      *Evidence:* `agents/orchestrator.md` "## Authority" reads:
      "Bypass discipline (declarative): the Generator and the
      Validator **must** invoke `/yoke:ask` via the Skill tool for
      every canonical-memory read. Direct filesystem reads of the
      registered memory (cat, grep, clone, pull) are prohibited."
      Also adds Trigger-4 escalation hint when the Orchestrator
      observes a violation. `grep -nE "absence.*trace|trace
      entry.*bypass|bypass.*trace"` returns empty.
- [x] **DoD-3** — Generator and Validator no longer require reading
      `.yoke/query-traces/<slug>.md` at the start of every cycle.
      *Evidence:* `agents/generator.md` "Always" bullet replaced with
      "Invoke `/yoke:ask` via the Skill tool when you need canonical
      context — ratified policies, domain ownership, prior decisions,
      patterns relevant to the Acceptance Contract criterion …
      Before relying on prior knowledge for any of those, ask the
      canonical memory." Symmetric edit in `agents/validator.md`
      ("when sensor evidence needs to be judged against canonical-
      memory rules — ratified policies, calibration metadata, prior
      decisions on similar criteria"). The "Never" sections in both
      files now state explicit `/yoke:ask` routing rather than
      Orchestrator-mediated trace consumption.
- [x] **DoD-4** — All three subagent YAML `description` fields are free
      of `query-traces`/"trace lands" mentions.
      *Evidence:* `grep -h "^description:" agents/*.md | grep -E
      "query-trace|trace lands"` returns empty. The descriptions now
      describe the canonical-memory access path positively (Orchestrator:
      "invoking /yoke:ask via the Skill tool and reasoning over the
      response in-conversation"; Generator and Validator: "Reads
      canonical memory only by invoking /yoke:ask via the Skill tool.
      Never writes canonical memory.").
- [x] **DoD-5** — `tools:` field on each agent is
      `Read, Write, Edit, Grep, Glob, Bash, Skill`. No `Write` grant
      targets `.yoke/query-traces/`. The Allowed-tools sections in
      each body describe write authority over working-memory artifacts
      and host code only — never under `.yoke/query-traces/`.
      *Evidence:* `grep "^tools:" agents/*.md`. The four query-traces
      hits in body text are negative instructions ("`.yoke/query-traces/`
      does not exist; do not read or write any path under it") — the
      Decision-5 transition guard, not live grants.
- [x] **DoD-6** — Mode B (Monitor) and Mode C (Canonize) logic untouched.
      *Evidence:* `agents/orchestrator.md` Mode B preserved verbatim:
      Generator/Validator divergence detection, escalate.sh wiring,
      hard-bound + sprint-contract-contradiction routing. Mode C
      preserved: `mode=canonize` activation, `/yoke:preserve`
      invocation with `--from-orchestrator`, five-criterion cascade
      delegated to `lib/canonical-memory/canonization-criteria.sh`,
      Model C impact-class routing, propose-write.sh retirement note.
      The only edit inside Mode C scope was removing
      `.yoke/query-traces/<slug>.md` from the working-memory reads
      list (a stale file reference the spec explicitly permits
      cleaning up).

## Pattern Compliance

- [x] **`.vibeflow/patterns/roles.md`** — followed.
      The Orchestrator remains the sole writer of canonical memory under
      Model C. Generator and Validator file ownership unchanged
      (Generator writes `.yoke/runtime/progress.md` and
      `.yoke/contracts/<slug>.md`; Validator co-writes `.yoke/contracts/<slug>.md`).
      No subagent shares context with the Orchestrator beyond what
      `/yoke:implement` orchestration surfaces. The single-Skill-call
      discipline is preserved (`tools:` adds `Skill` for canonical-memory
      reads, no other tools added). Note: the doctrine doc itself still
      describes the trace handoff — Part 4 owns that update.
- [x] **`.vibeflow/patterns/memory-model.md`** — followed.
      Read mediator pattern preserved: Generator and Validator now read
      canonical memory through the same skill (`/yoke:ask`) that the
      Orchestrator uses in consult mode. Progressive disclosure
      preserved (the 15-cap is enforced inside `/yoke:ask`). Two-tier
      memory model unchanged — only the cross-tier handoff mechanism
      changed (from trace-file → from in-cycle Skill invocation).
      Doctrine update is Part 4's responsibility.

## Convention Compliance

- [x] `.vibeflow/conventions.md` Don't *"Do NOT allow the Generator or
      the Validator to read canonical memory directly — every query
      goes through the Orchestrator."* — the spirit is preserved
      (every read goes through `/yoke:ask`); the letter shifts (the
      Orchestrator is no longer the relay). Part 4 will update the
      doctrine wording to match.
- [x] `.vibeflow/conventions.md` Don't *"Do NOT load the entire
      canonical memory into any agent's context"* — preserved.
      `/yoke:ask` enforces the 15-cap regardless of caller.
- [x] `.vibeflow/conventions.md` *"runtime subagents must never share
      context"* — preserved. Generator and Validator each invoke
      `/yoke:ask` independently; they do not see each other's
      responses.

## Anti-scope discipline

| Anti-scope item | Status |
| :--- | :--- |
| Skill or lib changes (Part 1) | RESPECTED — `skills/` and `lib/` untouched |
| Test updates (Part 3) | RESPECTED — `tests/` untouched |
| Doctrine `.vibeflow/` updates (Part 4) | RESPECTED — `.vibeflow/` untouched |
| File-ownership changes for `.yoke/contracts/<slug>.md`, `.yoke/runtime/progress.md` | RESPECTED — ownership preserved verbatim |
| Canonize-mode logic, five-criterion filter, propose-write.sh wiring | RESPECTED — Mode C body unchanged except stale reads-list line |
| Introducing a new file-based handoff to replace the trace | RESPECTED — none introduced; Mode A explicitly uses inline reasoning |

## Risks (from spec)

- **R1 / Subagents reflexively try to read `.yoke/query-traces/<slug>.md`**
  — MITIGATED. Decision-5 transition-guard lines added to all three
  agents in body text ("`.yoke/query-traces/` does not exist; do not
  read or write any path under it").
- **R2 / Generator or Validator reasons without canonical grounding** —
  MITIGATED. Both "Always" sections now say "Before relying on prior
  knowledge for [policies / decisions / calibration], ask the
  canonical memory."
- **R3 / Edit accidentally touches Orchestrator's canonize or monitor
  sections** — DID NOT HAPPEN. Mode B and Mode C bodies preserved;
  only the Mode C reads list dropped a stale file reference.
- **R4 / Allowed-tools loses something the agent still needs** — DID
  NOT HAPPEN. Existing grants preserved; only the trace-write privilege
  was removed (was implicit; now explicitly absent). The Orchestrator
  Allowed-tools section retains `Write`/`Edit` "reserved for future
  use" with a brief note.

## Gaps

None. All 6 DoD checks satisfied; budget used 3/≤4; anti-scope items
respected; convention compliance preserved.

## Notes for downstream parts

- Part 3 must remove the trace assertions from the four smoke tests
  and add a regression assertion that all three agents have `Skill` in
  their `tools:` envelope.
- Part 4 must update `.vibeflow/conventions.md`,
  `.vibeflow/patterns/memory-model.md`, and `.vibeflow/patterns/roles.md`
  so the doctrine descriptions match the runtime: Generator and
  Validator read canonical memory via `/yoke:ask`; the bypass rule is
  declarative; the consult-mode → trace-handoff narrative is replaced
  with the per-question invocation pattern.

## Next step

Ready to ship Part 2. Proceed to Part 3: smoke-test alignment.
