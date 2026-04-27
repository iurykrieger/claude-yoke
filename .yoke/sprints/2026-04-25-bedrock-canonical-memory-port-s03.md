# Sprint 03 of 06: Bedrock canonical-memory port

> Migrated from: # Spec: Bedrock canonical-memory port — Part 3: `/yoke:ask` refactor


> Generated via /vibeflow:gen-spec on 2026-04-25
> Source PRD: `.vibeflow/prds/bedrock-canonical-memory-port.md`

## Objective

Replace clone-each-time `lib/canonical-memory/query.sh` with a direct
read against the registered memory, adopting bedrock's adaptive
vault-first search and preserving Yoke's bypass-detection trace
invariant.

## Context

`/yoke:ask` today shells out to `query.sh`, which clones or pulls the
canonical-memory substrate every invocation. Users pay 0.5–5s per
query, and the manifesto explicitly lists clone-on-read as an
anti-pattern under `.vibeflow/patterns/memory-model.md`. Bedrock's
`/ask` reads the vault filesystem directly with an adaptive
search (entity reads + wikilink traversal); Parts 1–2 made that
possible by giving Yoke a registered local checkout.

## Definition of Done

1. `skills/ask/SKILL.md` is rewritten: resolves the active memory via
   Part 1's resolution lib (`--memory` → CWD detection → default →
   error), then reads filesystem directly. Never invokes `git clone`
   or `git pull`.
2. The skill implements bedrock's Phase 1 (classify question), Phase 2
   (vault-first search: filename → alias → name → content; ≤15
   entities; 1-level wikilink traversal), Phase 4 (recency sort),
   Phase 5 (compose response with bare wikilinks).
3. Every invocation writes a YAML trace entry to
   `.yoke/query-traces/<slug>.md` with `timestamp`, `mode: ask`,
   `query`, `entities_read`, `invoker` — preserving the
   bypass-detection invariant from `.vibeflow/conventions.md` ("every
   query goes through the Orchestrator [or `/yoke:ask`]; absence of a
   trace entry is the bypass signal").
4. `lib/canonical-memory/query.sh` is deleted. Any remaining callers
   (Orchestrator subagent consult mode, smoke tests) are migrated to
   either invoke `/yoke:ask` via the Skill tool or read the registered
   memory through Part 1's resolution lib directly.
5. Two consecutive `/yoke:ask` invocations against the same memory
   within 60s perform zero `git fetch`, `git pull`, or `git clone` —
   verifiable by smoke test inspecting `git -C <path> reflog` count
   between invocations.
6. **Quality gate:** No violation of the conventions.md Don't *"Do NOT
   load the entire canonical memory into any agent's context."*
   Implementation caps total entity reads at 15 across Phase 2 +
   wikilink traversal, matching bedrock's limit. Verified by inspecting
   `skills/ask/SKILL.md` for the explicit cap.

## Scope

- `skills/ask/SKILL.md` rewrite (verbatim copy of bedrock 1.2.1 ask
  skill with namespace renames + Yoke trace-write integration).
- Removal of `lib/canonical-memory/query.sh`.
- Trace-write helper extracted to a shared lib if Part 4 reuses it;
  otherwise inline.
- Smoke test: two consecutive runs with zero fetch.
- Migration of any in-tree caller of `query.sh`
  (Orchestrator subagent consult mode is the main one).

## Anti-scope

- No remote-content escalation (`needs_remote_content` →
  `/yoke:teach`); that arrives with Part 5. The skill stops at
  vault-only and emits a `> [!info]` callout pointing at
  `/yoke:teach <url>` when an external URL appears in a matched
  entity's `sources`.
- No graphify escalation. The skill stubs Phase 3-G: when
  `needs_graphify` is detected, emit bedrock's
  `> [!warning] Knowledge graph unavailable` callout and continue
  with vault-only content.
- No write paths.

## Technical Decisions

- **No `/graphify` integration in v0.** Per PRD anti-scope.
  `needs_graphify` falls through to vault-only with the warning
  callout, matching bedrock's `graph_not_available` fallback.
- **Trace YAML schema unchanged.** Sprint 8 audit hooks depend on
  `timestamp / mode / query / matches / capped / invoker`. Only the
  `mode` value migrates from `mediator` to `ask`; coordinate with
  Sprint 8 audit work in CHANGELOG.
- **Resolution-failure UX.** When the registry is empty: emit
  `"No memory registered. Run /yoke:memory add <path> or re-run /yoke:bootstrap."`
  Symmetric with bedrock's no-vault error.
- **No automatic pull on read.** Users get fresh data via
  `/yoke:teach`, `/yoke:preserve` (Phase 0 pull-rebase), or by `cd`-ing
  into the memory and running `git pull` themselves. Pure reads accept
  the staleness — matches the "consult live, canonize on termination"
  decision from `.vibeflow/decisions.md`.

## Applicable Patterns

- `.vibeflow/patterns/memory-model.md` — `/yoke:ask` is one of the two
  read mediators (the other being the Orchestrator subagent's consult
  mode); this rewrite preserves that role and removes the clone-on-read
  anti-pattern.
- `.vibeflow/patterns/human-triggers.md` — no triggers fire on the
  read path.

## Risks

- **R-3.1 — Stale local checkout.** Removing `git pull` means the
  local checkout drifts behind the remote between writes.
  *Mitigation:* `/yoke:teach` and `/yoke:preserve` Phase 0.1 pull
  before any write, so the checkout converges on every write. Pure
  reads accept staleness; document this in
  `docs/canonical-memory-setup.md`.
- **R-3.2 — Trace-format regression.** Sprint 8 audit hooks depend on
  the existing trace shape. *Mitigation:* DoD-3 pins the schema; only
  the `mode` value changes. Add a CHANGELOG entry coordinating with
  Sprint 8.
- **R-3.3 — Orchestrator subagent consult mode regresses.** The
  agent's `agents/orchestrator.md` currently calls `query.sh`.
  *Mitigation:* migrate the consult-mode path to invoke `/yoke:ask`
  via the Skill tool *or* call Part 1's resolution lib directly. Part 4
  fully refactors the orchestrator; this part covers only the consult
  path so canonization isn't blocked on Part 4 landing.

## Dependencies

- `.vibeflow/specs/bedrock-canonical-memory-port-part-1.md`
- `.vibeflow/specs/bedrock-canonical-memory-port-part-2.md`
