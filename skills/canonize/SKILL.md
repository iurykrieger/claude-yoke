---
name: canonize
description: >
  Manual canonization escape hatch. Primary canonization happens
  automatically at `/yoke:implement` loop termination via the
  Orchestrator subagent. This skill exists to **re-run** canonization
  on an existing `.yoke/` directory — useful after a failed auto-canonize,
  after a model upgrade (rippability), or to re-evaluate stale working
  memory. Spawns `agents/orchestrator.md` with `mode=canonize`. Never
  auto-runs.
argument-hint: ""
allowed-tools: Read, Write, Bash, Task
---

# /yoke:canonize — manual canonization escape hatch (v1.1.0)

Re-run canonization on an existing task's working memory. Spawns the
**Orchestrator subagent** in canonize mode against the host project's
`.yoke/`.

> **v1.1.0 architectural note.** Earlier versions positioned this skill
> as the primary Phase-5 canonization entry point and ran
> canonization-criteria.sh / propose-write.sh directly. With Orchestrator
> promoted to a runtime subagent, the **automatic** canonization
> handoff happens inside `/yoke:implement` at loop termination. This
> skill is now the **manual escape hatch** — it spawns the same
> Orchestrator subagent in canonize mode against an existing `.yoke/`,
> which is useful when:
>
> - The auto-canonize at `/yoke:implement` termination failed.
> - The user wants to re-evaluate canonization after a model upgrade
>   (rippability — Decision 2026-04-24).
> - The user wants to re-run canonization on stale working memory.
>
> Never auto-runs. Always invoked explicitly by the user.

## Pre-conditions

- `.yoke/config.yaml` exists with a populated `canonical_memory.url`.
- `.yoke/progress.md` exists.
- The most recent `verify-acceptance.sh` snapshot
  (`.yoke/.snapshots/cycle-<latest>.yaml`) shows every criterion at
  `status: pass`. Abort otherwise: "Task not complete; run
  `/yoke:implement` to convergence first, or use `--force` to
  re-canonize an incomplete task (advanced)."
- `gh` CLI authenticated.

## Process

### 1. Pre-flight

- Verify the pre-conditions above.
- Verify that `agents/orchestrator.md` is present in the plugin
  (smoke check; should always be true).

### 2. Spawn the Orchestrator subagent in canonize mode

Issue a single Task call spawning `agents/orchestrator.md` with
input:

- `mode=canonize`
- `trigger=manual` (distinguishes from automatic termination handoff)
- `.yoke/progress.md`, `.yoke/contracts.md`, `.yoke/query-trace.md`
  (read-only references)
- All `.yoke/.snapshots/cycle-*.yaml`
- Optional flags from the user: `--dry-run`, `--candidates-only`,
  `--impact-filter <low|medium|high|regulatory>`.

The Orchestrator subagent applies the five-criteria cascade per
`lib/canonical-memory/canonization-criteria.sh`, classifies impact
per Model C, and calls `lib/canonical-memory/propose-write.sh` for
each candidate that passes 1–4 and is non-contradicting (5).

### 3. Output

The Orchestrator subagent returns a structured summary; print it
verbatim:

```
[low]   c1 → PR <url>          (auto-merge after CI)
[low]   c2 → SKIP (failed criterion 5 — contradicted Acceptance Contract)
[med]   c3 → PR <url>          (veto window: 24h)
[high]  c4 → PR <url>          (synchronous approval required)
[reg]   c5 → PR <url>          (Compliance reviewers)
```

If no candidates: "No candidates passed the canonization criteria.
Working memory traces preserved for future sprints."

## Output contract

- Exit 0 with PR URLs for any candidates the Orchestrator subagent
  successfully proposed.
- Exit non-zero on missing pre-conditions, `gh` failure, or
  Orchestrator subagent abort.

## Anti-patterns

- Do NOT bypass the Orchestrator subagent and call
  `propose-write.sh` directly from this skill — Model C governance
  must flow through the Orchestrator (sole writer of canonical
  memory).
- Do NOT auto-invoke this skill from another skill or agent —
  manual-only by design.
- Do NOT canonize against the production canonical-memory repo in
  tests — use a test substrate or `--dry-run`.
- Do NOT canonize without traceability — the Orchestrator subagent
  enforces this; don't override.

## See also

- `.vibeflow/patterns/model-c-governance.md` — impact classes + PR
  protocol.
- `.vibeflow/patterns/memory-model.md` — canonical-memory frontmatter.
- `agents/orchestrator.md` — canonize mode (Mode C).
- `skills/implement/SKILL.md` — automatic canonize handoff at loop
  termination.
- `lib/canonical-memory/canonization-criteria.sh`,
  `lib/canonical-memory/propose-write.sh`.
- `templates/canonical-entry-frontmatter.yaml`.
