# PRD: `/yoke:ask` — source-agnostic canonical-memory read

> Generated via /vibeflow:discover on 2026-04-25

## Problem

`/yoke:ask` is documented and described as the canonical-memory adaptive
reader for any caller (the Orchestrator at runtime, the Generator and
Validator subagents seeking context, spec-phase skills enriching their
outputs, and ad-hoc human queries per `docs/quickstart.md`). In
practice, the skill aborts unless `.yoke/.current` exists and points at
a valid slug — i.e. it only works *inside* an active task, after
`/yoke:discover` has been run.

The coupling is not architectural; it is a side-effect of the
bypass-detection trace. Phase 5.1 of `skills/ask/SKILL.md` writes a
YAML entry per query to `.yoke/query-traces/<slug>.md`, and the slug
comes from `wm_active_slug()` in `lib/working-memory/paths.sh`. No
active task → no trace path → abort. Memory resolution itself
(`lib/canonical-memory/resolve-memory.sh`) is already source-agnostic;
the trace is the only blocker.

This breaks every legitimate caller that runs *before* a task is
established (the spec-phase skills `tests/smoke/sprint-2.test.sh:95`
asserts as routing through `/yoke:ask`) and any ad-hoc invocation,
and produces an internally inconsistent contract: tests assert routing
that the skill cannot satisfy.

The trace concept is also doing more work than it should. It was
originally introduced as the bypass-detection signal per
`.vibeflow/conventions.md` ("absence of a trace entry is the bypass
signal"), but it has accreted a second role: the channel by which the
Orchestrator surfaces canonical-memory subgraphs to the Generator and
Validator (`agents/generator.md:49`, `agents/validator.md:63`). Both
roles are now fragile — bypass detection has weak teeth, and using a
markdown audit log as an inter-agent data channel inverts the
read-only intent of the skill.

The decision: **remove the query-trace concept entirely**. `/yoke:ask`
becomes a pure read against canonical memory, callable from any
source, with no working-memory dependency.

## Target Audience

Direct callers of `/yoke:ask`:

1. **Generator subagent** during runtime cycles, when the
   implementation work needs canonical-memory context.
2. **Validator subagent** during runtime cycles, when sensor evidence
   needs to be checked against canonical-memory rules.
3. **Orchestrator subagent** in consult mode at runtime and in
   canonize mode at termination.
4. **Spec-phase skills** (`/yoke:discover`, `/yoke:tech-spec`,
   `/yoke:acceptance-contract`) when enriching their outputs with
   prior decisions, ownership, or known constraints.
5. **Human users** running `/yoke:ask "<question>"` directly (per
   `docs/quickstart.md:55`).

Indirect audience: anyone maintaining `agents/` and `skills/` that
currently read or write `.yoke/query-traces/<slug>.md`.

## Proposed Solution

Refactor `/yoke:ask` so that it is a source-agnostic, read-only
canonical-memory reader, structurally aligned with `bedrock:ask` but
preserving Yoke's plugin paths, memory-registry resolution, and the
15-entity progressive-disclosure cap.

WHAT changes:

- Remove the active-task pre-condition. `/yoke:ask` no longer reads
  `.yoke/.current` and no longer requires `wm_active_slug()`.
- Remove the YAML trace write at Phase 5.1.
- Remove the query-traces directory from working-memory layout
  (`lib/working-memory/paths.sh`, `WM_ARCHIVE_CATEGORIES`,
  `wm_query_trace_path()`).
- Remove the trace-read step at the start of every Generator and
  Validator cycle. When those subagents need canonical-memory context,
  they invoke `/yoke:ask` directly via the Skill tool and consume the
  response in-conversation.
- Update `.vibeflow/conventions.md` to retire the "absence of a trace
  entry is the bypass signal" doctrine. Bypass discipline becomes a
  declarative rule on the skill itself ("agents must invoke /yoke:ask
  for canonical-memory reads; direct filesystem reads of the memory
  are prohibited"), enforced by review and by the skill's
  `allowed-tools` envelope rather than by an audit-log scan.
- Update `agents/orchestrator.md` so that consult mode no longer
  emits trace entries; the Orchestrator's responsibility narrows to
  invoking `/yoke:ask` and acting on the response (escalation,
  divergence detection, canonization candidates).
- Update tests, docs, and the changelog to reflect the new contract.

WHAT does NOT change:

- The 15-entity progressive-disclosure cap.
- The memory-resolution chain (`--memory` flag → CWD detection →
  default).
- The no-clone, no-pull, no-fetch invariant: `/yoke:ask` reads
  `$YOKE_MEMORY_PATH` directly from the local filesystem.
- The no-fabrication rule and the "read-only against the memory"
  invariant.
- The plugin-path conventions for entity definitions and templates.

## Success Criteria

A reader can confirm the fix is correct by observing all of the
following, without running an active task:

1. `/yoke:ask "<question>"` invoked from a directory with **no**
   `.yoke/.current` returns a valid answer (or the empty-state
   response) without aborting.
2. `/yoke:ask "<question>"` invoked from inside a host project that
   *does* have `.yoke/.current` returns the same valid answer; the
   active-task pointer is irrelevant to behavior.
3. No file is written under `.yoke/query-traces/` by `/yoke:ask`
   (the directory does not exist after a fresh bootstrap).
4. The Generator and Validator subagents, at the start of a runtime
   cycle, do not attempt to read a query-traces file. When they need
   canonical-memory context, they invoke `/yoke:ask` via the Skill
   tool and the response is the only channel.
5. `lib/working-memory/paths.sh` exports no `wm_query_trace_path`
   helper; `WM_ARCHIVE_CATEGORIES` does not include `query-traces`.
6. `tests/smoke/sprint-2.test.sh`, `tests/smoke/sprint-5.test.sh`,
   `tests/smoke/folder-isolation.test.sh`, and
   `tests/smoke/ask-no-clone.test.sh` are updated to assert the new
   contract (no trace, no active-task pre-condition) and pass under
   `bash tests/smoke/<file>.test.sh`.
7. `.vibeflow/conventions.md`, `CLAUDE.md`, `docs/architecture.md`,
   and `docs/lineage.md` no longer reference `query-trace.md` or
   `query-traces/<slug>.md` as live mechanisms.

## Scope v0

In scope, in this order:

1. **`skills/ask/SKILL.md`** — remove pre-condition on `.yoke/.current`,
   remove Phase 5.1 trace write, drop "trace" from critical rules and
   anti-patterns, simplify the description.
2. **`lib/working-memory/paths.sh`** — drop `wm_query_trace_path`,
   remove `query-traces` from `WM_ARCHIVE_CATEGORIES`.
3. **`agents/orchestrator.md`** — rewrite consult-mode section to
   call `/yoke:ask` and consume its response in-conversation; remove
   all "write to `.yoke/query-traces/<slug>.md`" instructions and the
   "absence of trace entry is a bypass" rule; update YAML
   `description`.
4. **`agents/generator.md`** and **`agents/validator.md`** — remove
   "read `.yoke/query-traces/<slug>.md` at the start of every cycle";
   replace with "invoke `/yoke:ask` via the Skill tool when canonical-
   memory context is needed".
5. **Tests** — update `tests/smoke/sprint-2.test.sh`,
   `tests/smoke/sprint-5.test.sh`,
   `tests/smoke/folder-isolation.test.sh`,
   `tests/smoke/ask-no-clone.test.sh` to match the new contract.
6. **Docs** — `.vibeflow/conventions.md` (retire the bypass-via-
   absence-of-trace doctrine and replace with a declarative bypass
   rule), `CLAUDE.md` (working-memory table), `docs/architecture.md`,
   `docs/lineage.md`, `docs/quickstart.md`, `docs/troubleshooting.md`,
   `examples/greenfield-payment-service/CLAUDE.md`.
7. **`CHANGELOG.md`** — add an entry describing the breaking change.

## Anti-scope

Explicitly **out** of this PRD; each is a candidate for a separate
PRD if and when it becomes a real need:

- The deferred graphify subgraph traversal (still parked).
- The `/yoke:teach` escalation path from `needs_remote_content`.
- A replacement bypass-detection mechanism (e.g. logging,
  pre-commit hooks, runtime instrumentation). Bypass discipline
  becomes purely declarative in v0; instrumentation can return
  later if review reveals it is needed.
- Changes to `lib/canonical-memory/resolve-memory.sh` or the
  registry shape.
- Changes to the 15-entity cap.
- Any new caller-aware behavior (rate limits per invoker,
  per-invoker filtering, etc.).
- Migration tooling for repos that already have `.yoke/query-traces/`
  on disk; the directory is simply ignored.
- Backwards-compatibility shims for the removed
  `wm_query_trace_path` helper. Any caller still referencing it is a
  bug to fix in this same PRD's scope, not a callsite to preserve.

## Technical Context

Existing patterns and constraints to follow:

- **Plugin-path resolution** in skills uses the "Base directory for
  this skill" injected at invocation; entity definitions and templates
  live at `<plugin_dir>/entities/` and `<plugin_dir>/templates/`. This
  PRD does not change that.
- **Memory resolution** is delegated to
  `lib/canonical-memory/resolve-memory.sh`, which already supports
  `--memory <name>`, CWD detection, and a `default` registry entry.
  No changes needed.
- **Working-memory layout** is documented in
  `lib/working-memory/paths.sh` and tested in
  `tests/smoke/folder-isolation.test.sh`. The query-traces category
  must be removed from both, and the v0.6.0 per-category folders
  doctrine remains otherwise intact.
- **Conventions doctrine** lives in `.vibeflow/conventions.md`, which
  currently lists `query-trace.md` as a working-memory artifact (line
  80) and frames bypass detection around its absence. Both must be
  rewritten.
- **Reference implementation**: the `bedrock:ask` skill at
  `~/.claude/plugins/marketplaces/claude-bedrock/skills/ask/SKILL.md`
  is the structural reference — no working-memory dependency, no
  trace, vault-first read with self-assessment. Yoke deviates only
  where Yoke-specific architecture demands (memory registry instead
  of vault registry; deferred graphify; deferred `/yoke:teach`
  escalation).
- **Pre-existing tests that must keep passing** after the fix:
  `tests/smoke/sprint-1.test.sh`, `tests/smoke/sprint-3.test.sh`,
  `tests/smoke/sprint-4.test.sh` (these do not assert trace
  behavior, so the change should be invisible to them).
- **Sprint discipline** (`CLAUDE.md` "Sprint discipline" section):
  this PRD spans Sprint 2 and Sprint 5 surfaces, so the resulting
  spec should be implemented as a *cross-cutting fix*, not a new
  sprint. Treat it as a bugfix at the doctrine level. The CHANGELOG
  entry must call out the breaking change for any project that has
  already bootstrapped against an older Yoke.

## Open Questions

- **Bypass discipline replacement.** Once the trace is gone, the only
  enforcement that agents go through `/yoke:ask` is declarative (the
  rule in the agent prompts and skill `allowed-tools`). If during
  implementation it becomes clear this is too weak — e.g. the skill
  gets routinely bypassed — open a follow-up PRD for an alternative
  signal. Not load-bearing for v0.
- **Orchestrator consult mode shape.** With the trace gone, consult
  mode is "Orchestrator invokes `/yoke:ask` and reasons over the
  response within its own turn." Verify during spec-writing that this
  preserves the Orchestrator's runtime responsibilities (divergence
  detection, canonization candidates) without requiring a persisted
  artifact. If a persisted artifact turns out to be necessary for a
  *different* reason (e.g. checkpointing across resumed runs), that is
  a separate concern from query-tracing and should be designed on its
  own merits.
- **Generator/Validator context delivery timing.** Today the trace
  acts as a once-per-cycle handoff (Orchestrator surfaces, agents
  read at cycle start). Calling `/yoke:ask` directly is a
  per-question handoff. Confirm during tech-spec that the per-question
  pattern is acceptable for the ralph loop's iteration cadence and
  context budget; if it is not, a different solution is needed (but
  *not* a return to the trace).
