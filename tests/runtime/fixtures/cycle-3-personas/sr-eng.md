---
author: sr-eng
cycle: 3
phase: a
---

## Phase A — own progress

author: sr-eng

- file: lib/runtime/council-merge.sh
- intent: ship the deterministic merge helper for the per-cycle slice protocol
- status: implemented; pure (no writes, no canonical-memory queries, no LLM calls)

## Phase B — réplicas

(no réplicas in this engineered fixture; the determinism test only inspects merged output shape)
