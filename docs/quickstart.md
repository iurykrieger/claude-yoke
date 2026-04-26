# Yoke quickstart

This guide takes a fresh project from zero to a merged Yoke task.

## 0. Install

See [`installation.md`](installation.md).

## 1. Bootstrap

In a project repo (clean working tree recommended):

```
/yoke:bootstrap
```

Bootstrap will:

- Create `.yoke/config.yaml` at the project root.
- Ask where canonical memory lives — an existing URL, or create a new one (`gh repo create`).
- Verify dependencies (`gh`, bash 4+).
- Add a starter `CLAUDE.md` if your project doesn't have one (with `## Testing`, `## Linting`, `## Build` sections that Yoke parses for sensor discovery).

## 2. Discovery — Phase 1

Describe a task in natural language:

```
/yoke:discover "I want a payment-reversal service"
```

The Generator will ask clarifying questions, draft a PRD, and pause for your
approval. The PRD lands in `.yoke/prd.md`.

> **Note (v0.1.0).** Phases 1–6 are not yet implemented in this release.
> Sprint 1 ships only scaffolding + bootstrap. Subsequent sprints light up
> the rest of the flow — see `CHANGELOG.md` and the sprint specs in
> `.vibeflow/specs/`.

## 3. Next phases (preview)

Once shipped, the remaining commands are:

```
/yoke:tech-spec              # Phase 2 — Tech Spec from approved PRD
/yoke:acceptance-contract    # Phase 3 — binding contract
/yoke:implement              # Phase 4 — adversarial ralph loop
/yoke:canonize               # Phase 5 — propose canonical-memory writes
/yoke:drift-sense            # Phase 6 — continuous drift sensing
```

Plus support commands:

```
/yoke:ask "<term>"           # adaptive canonical-memory query
/yoke:status                 # current task state
```

## 4. Architecture overview

See [`architecture.md`](architecture.md) for the 1-page summary, or read the
full manifesto at <https://github.com/iurykrieger/yoke/blob/main/yoke.md>.
