# Yoke

> Governed adversarial development for AI agents — as a Claude Code plugin.

[![CI](https://github.com/iurykrieger/yoke/actions/workflows/ci.yml/badge.svg)](https://github.com/iurykrieger/yoke/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Yoke v1.1](https://img.shields.io/badge/yoke-v1.1.0-FFB000)](CHANGELOG.md)

**Version:** 1.1.0
**Manifesto:** [`yoke.md`](https://github.com/iurykrieger/yoke/blob/main/yoke.md)
**License:** MIT

## What

Yoke spawns three runtime subagents (Generator, Validator, Orchestrator) in
parallel inside an envelope defined by a binding human contract, forcing
the adversarial Generator and Validator to converge or escalate to human
arbitration. It pairs that runtime loop with a pre-runtime binding spec
(PRD → Tech Spec → Acceptance Contract — driven by skills with embedded
persona, not subagents) and governed canonical memory (Model C —
contextual write authority by impact class; written only at loop
termination).

The name comes from the harness piece that couples two animals so they pull
together in the same direction. That is the central image of the framework.

## Install

```
/plugin marketplace add iurykrieger/yoke
/plugin install yoke@yoke-marketplace
```

See [`docs/installation.md`](docs/installation.md) for full pre-requisites
(Claude Code with marketplace + Task-tool support, `gh` CLI, bash 4+,
git 2.0+).

## Quickstart

```
/yoke:bootstrap                   # one-time per project
/yoke:discover "<your idea>"      # Phase 1 — produces .yoke/prd.md
/yoke:tech-spec                   # Phase 2 — produces .yoke/tech-spec.md
/yoke:acceptance-contract         # Phase 3 — produces .yoke/acceptance-contract.md (binding)
/yoke:implement                   # Phase 4 — adversarial ralph loop with hard bounds
/yoke:canonize                    # Phase 5 — propose canonical-memory writes
/yoke:drift-sense                 # Phase 6 — continuous drift sensing (also runs daily via Actions)
```

Plus support skills: `/yoke:ask` (mediated canonical-memory query) and
`/yoke:status` (current task state).

Full walkthrough: [`docs/quickstart.md`](docs/quickstart.md).
Architecture summary: [`docs/architecture.md`](docs/architecture.md).
Worked example: [`examples/greenfield-payment-service/`](examples/greenfield-payment-service/).
Trouble? See [`docs/troubleshooting.md`](docs/troubleshooting.md).

## Status — v1.1.0

This is the **runtime-only-agents refactor** of v1.0. All six manifesto
phases remain operational; agent topology simplified to three runtime
subagents (Generator, Validator, Orchestrator) spawned in parallel.
Spec phases are now skill-only.

- ✅ **Phase 1–2 (binding spec)** — `/yoke:discover`, `/yoke:tech-spec` skills with embedded Generator persona; explicit human gates (Triggers 1, 2)
- ✅ **Phase 3 (binding contract)** — `/yoke:acceptance-contract` skill with embedded Validator persona; sensor discovery from host `CLAUDE.md`; Trigger 3 binding ratification
- ✅ **Phase 4 (adversarial loop)** — `/yoke:implement` spawns 3 runtime subagents in parallel per cycle; hard bounds; Trigger-4 escalation packet
- ✅ **Phase 5 (canonization)** — auto-canonize at `/yoke:implement` loop termination via Orchestrator subagent; full Model C (low / medium / high / regulatory); `/yoke:canonize` as manual escape hatch
- ✅ **Phase 6 (drift sensing)** — `/yoke:drift-sense` with daily GitHub Actions schedule
- ✅ **Five distinct human triggers** — non-coalescable schemas
- ✅ **Progressive disclosure** — subgraph queries via `/yoke:ask --subgraph-depth N` (thin skill calling `query.sh` directly)
- ✅ **Skills deliberate; subagents adapt** — new architectural invariant codified in v1.1

What's planned for v1.1+:

- Adversarial canonical-memory audit (manifesto §17)
- Post-deploy production-signal observation (manifesto §17)
- Inferential drift-sensing detector (semantic obsolescence)
- Yoke-on-Yoke (recursive bootstrap)

## Lineage

Yoke embeds skills derived from two upstream projects, forked one-time
at the relevant sprint:

- **Vibeflow** — <https://github.com/pe-menezes/vibeflow>. Source for the
  Generator's PRD and Tech Spec drafting skills (forked Sprint 2).
- **Bedrock** — <https://github.com/iurykrieger/claude-bedrock>. Source for
  the Orchestrator's canonical-memory primitives — read, write, graph
  traversal (forked Sprint 5).

From the time of fork, those skills evolve autonomously inside Yoke.
There is no continuous port. Per-skill mapping in
[`docs/lineage.md`](docs/lineage.md).

## Project documents

- Manifesto: `yoke.md`
- Implementation plan: `yoke-implementation-plan.md`
- PRD: `.yoke/prds/2026-04-25-yoke-v1.md`
- Sprint specs: `.yoke/specs/2026-04-25-yoke-v1-sprint-{1..8}.md`
- Sprint audits: `discussions/yoke-audit-yoke-v1-sprint-{1..8}-*.md`
- Architecture, conventions, decisions, patterns: canonical memory + `.yoke/`

## Contributing

Yoke is built using its own discipline (manually for v1.0; v1.1+ may
dogfood Yoke on itself per the planned recursive transition). PR
workflow:

1. Fork + branch.
2. Run all sprint smokes locally: `for s in 2 3 4 5 6 7 8; do bash tests/smoke/sprint-${s}.test.sh; done`.
3. Open PR. CI gates every sprint smoke on every PR.
4. Document any new pattern or convention via the same `/vibeflow:teach`
   flow Yoke development used.

## License

MIT — see [`LICENSE`](LICENSE).
