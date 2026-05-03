# Canonical-memory provider contract

contract_version: 1

> The contract every Yoke canonical-memory provider implements. Authored
> in Sprint 1 of the pluggable-canonical-memory PRD
> (`.yoke/prds/2026-04-30-pluggable-canonical-memory.md`) when the only
> registered provider was Bedrock embedded inside Yoke; first independent
> consumer (`claude-bedrock`) lands in Sprint 2.
>
> A provider is what `/yoke:canonize` hands the host project's `.yoke/`
> directory to. The provider's contract is small and binary:
>
> 1. It accepts a single `--working-memory <abs-path>` argument and
>    treats the directory as **read-only**.
> 2. It interprets the directory tree per the layout below.
> 3. It returns a process exit code that the facade propagates verbatim.
>
> The contract is versioned. Every breaking change to this document
> bumps `contract_version:` (and the `providers.yaml :: schema_version`
> per the versioning policy below).
>
> See also:
> - `providers.yaml` — curated registry of supported providers.
> - `lib/canonical-memory/resolve-provider.sh` — runtime resolution.
> - `skills/canonize/SKILL.md` — the dispatching facade.
> - `concepts/yoke-pattern-memory-model` (canonical memory) — the
>   read/write mediator role.
> - Acceptance Contract Scenario 5 / FR-4 of the source PRD.

## --working-memory argument semantics

The provider's canonize skill is invoked exactly as:

```text
<provider-canonize-skill> --working-memory <abs-path-to-.yoke>
```

Invariants:

1. **Path is absolute.** The Yoke facade resolves the absolute path via
   `cd "$PWD/.yoke" && pwd` before dispatch. Providers MUST NOT
   re-resolve, follow `..` segments, or accept relative input as a
   workaround.
2. **Path is read-only from the provider's perspective.** Providers
   MUST NOT create, modify, rename, or delete any file under the
   given `.yoke/` directory. The directory is the framework's
   working memory; only Yoke skills (the Generator, Validator, and
   the runtime coordinator) write here. Violating this invariant is
   a contract breach.
3. **Path is a single directory.** The provider receives one path,
   not a list. Multi-project ingestion is out of scope at
   `contract_version: 1`.
4. **Argument shape is fixed.** The literal token `--working-memory`
   precedes the path. Providers MAY accept additional arguments for
   their own use, but `--working-memory <path>` MUST be supported and
   parseable as the canonical entry point.
5. **Missing flag is a usage error.** A provider canonize skill
   invoked without `--working-memory` MUST exit non-zero. The Yoke
   facade always supplies the flag.

The provider MAY copy any portion of the working memory into its own
private staging area to perform graphification, classification, or
git operations — that is implementation freedom. The on-disk
contents of `.yoke/` MUST be byte-identical before and after the
canonize call.

## Directory tree

`.yoke/` layout the provider can rely on. Annotations: **REQUIRED**
files are present whenever Yoke has reached the relevant phase;
**OPTIONAL** files appear only when the corresponding workflow has
run. The set is derived from `lib/working-memory/paths.sh` helpers.

```text
.yoke/
├── config.yaml                                # REQUIRED
├── .gitignore                                 # REQUIRED (versioned)
├── prds/<slug>.md                             # REQUIRED — one per task
├── specs/<slug>.md                            # REQUIRED — one per task
├── sprints/<slug>-s<NN>.md                    # REQUIRED — one or more per slug
├── acceptance-criteria/<slug>.md              # REQUIRED
├── contracts/<slug>.md                        # OPTIONAL — present iff sprint
│                                              #   contracts emerged at runtime
├── sensors/<sensor-id>.md                     # OPTIONAL — project-scoped
└── runtime/                                   # OPTIONAL — gitignored
    ├── .current                               # OPTIONAL — active-task pointer
    ├── progress.md                            # OPTIONAL — present iff a ralph
    │                                          #   loop has run; carries the
    │                                          #   soft `canonize:` line below
    ├── .cycle-counter                         # OPTIONAL
    ├── .trigger4-packet.yaml                  # OPTIONAL — escalation packet
    ├── .snapshots/cycle-N.yaml                # OPTIONAL — sensor snapshots
    └── .judge-verdicts/cycle-N/               # OPTIONAL — per-criterion JSON
```

The slug regex (filename without `.md`) is fixed at:

```text
^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]{0,49}$
```

Sprint files use `<slug>-s<NN>` (NN zero-padded to 2 digits).

Providers MUST NOT depend on the presence of files marked OPTIONAL.
If `runtime/` is absent, the working memory is a pre-runtime archive
(spec phase only) and the canonize call is still valid; the provider
decides whether there's anything to ingest.

## Frontmatter shapes

Every canonical artifact under `.yoke/` carries YAML frontmatter
between `---` markers as the first lines of the file. The provider
parses frontmatter to classify and route. The shapes are pinned by
the templates in the plugin:

| Artifact | Template |
|---|---|
| `prds/<slug>.md` | `templates/prd.md` |
| `specs/<slug>.md` | `templates/spec.md` |
| `sprints/<slug>-s<NN>.md` | `templates/sprint.md` |
| `acceptance-criteria/<slug>.md` | `templates/acceptance-criteria.md` |
| `contracts/<slug>.md` | `templates/contracts.md` |
| `sensors/<sensor-id>.md` | `templates/sensor.md` |
| `runtime/progress.md` | `templates/progress.md` |
| `config.yaml` | `templates/yoke-config.yaml` |

The provider MUST treat the templates in the registered Yoke plugin
as the authoritative shape. If a frontmatter key absent from the
template appears in the file, the provider SHOULD preserve it
opaquely (forward-compatible). If a key required by the template is
missing, the provider MAY skip the artifact and emit a warning —
this is not a contract breach (corrupt working memory is the
framework's bug, not the provider's).

## runtime/progress.md log conventions

`.yoke/runtime/progress.md` is a YAML-inside-markdown log written by
the Generator at the end of every ralph-loop cycle. It carries one
H2 (`## Sprint <NN>`) per sprint and one H3 (`### Cycle <C>`) per
cycle. The provider MAY read it for context but MUST NOT depend on
its structured shape — the schema is documented in
`templates/progress.md` and evolves independently of this contract.

`/yoke:canonize` appends a single line to this file at the end of its
run, immediately after the provider returns. The line begins with
the literal string `canonize:` and carries either:

- the provider's own exit-summary line (when the provider emitted
  one matching `^canonize: created=[0-9]+ updated=[0-9]+ skipped=[0-9]+$`
  on stdout, per the soft exit-summary convention below), or
- a minimal facade-emitted record:
  `canonize: provider=<name> working_memory=<abs-path> exit=<rc>`.

The line is a soft convention: the provider's stdout is authoritative
when present; the facade does not parse the provider's structured
output beyond `grep -E '^canonize:'`. Providers MUST NOT write to
`runtime/progress.md` themselves — only the facade does.

## Soft exit-summary convention

Providers SHOULD emit a single line on stdout matching:

```text
^canonize: created=<N> updated=<N> skipped=<N>$
```

where each `<N>` is a non-negative integer count of canonical-memory
entities created, updated, or skipped during this canonize call. The
line is **soft**: providers MAY omit it; the facade falls back to a
minimal facade-emitted record. The facade does **not** parse any
counts — the line is forwarded verbatim into `runtime/progress.md`.

The convention exists so that the framework's audit trail surfaces
provider-side activity counts without coupling the facade to any
specific provider's output schema. PRD Open Question Q2 is resolved
**soft** by this section.

## Versioning policy

This document is versioned by the `contract_version:` line at the top.
At v1 the contract is what's documented here.

Bumping `contract_version` requires bumping `providers.yaml ::
schema_version` in lockstep. The two version numbers MUST be equal at
all times: a provider that declares support for a contract version
declares support for the corresponding `providers.yaml` schema
version.

What constitutes a breaking change (and forces a bump):

- Removing a REQUIRED file from the directory tree.
- Changing the slug regex or the sprint-id regex.
- Changing the `--working-memory` argument shape.
- Tightening the soft exit-summary convention into a hard
  requirement.
- Removing a frontmatter key listed as required in any
  template-pinned artifact.

What does **not** constitute a breaking change (no bump):

- Adding new OPTIONAL files under `.yoke/`.
- Adding new templates that providers can opt into.
- Adding new frontmatter keys (forward-compatible: providers must
  preserve unknown keys opaquely).
- Adding new providers to `providers.yaml`.

The breaking-change bump procedure: open a PR amending this document,
amend `providers.yaml :: schema_version` in the same PR, and ship a
migration runbook under `docs/` for affected providers.

## Anti-patterns

The following patterns are explicitly forbidden by this contract.
Violations make a provider non-conformant.

- **Writing inside `.yoke/`.** The directory is read-only from the
  provider's perspective. Even "harmless" caches under
  `.yoke/runtime/` are forbidden — the framework owns that directory.
- **Structured-log parsing of `runtime/progress.md` cycle entries.**
  The progress log's YAML shape is the framework's internal contract
  with the Generator; it evolves independently. Providers that
  ingest cycle entries to derive canonical-memory writes are
  coupling to the wrong surface — derive from PRDs, specs, sprint
  files, contracts, and sensors instead.
- **Reliance on file presence beyond REQUIRED.** A provider that
  exits non-zero because `.yoke/contracts/<slug>.md` is missing has
  misread the contract — `contracts/` is OPTIONAL. The provider's
  canonize call MUST succeed against any well-formed `.yoke/`,
  including those with only the REQUIRED files present.
- **Re-resolving the working-memory path.** The path passed to
  `--working-memory` is absolute and authoritative. A provider that
  walks up from CWD to find `.yoke/` is breaking the dispatcher
  contract; the framework already did that resolution.
- **Mutating provider state from a read.** The contract is
  asymmetric: read skills (`/yoke:search-canonical-memory`) MUST be
  side-effect-free; canonize skills (`/yoke:canonize`) MAY write to
  the canonical-memory substrate but MUST NOT write to the working
  memory.
- **Hard-coding the Bedrock layout assumptions.** The contract is
  provider-agnostic by design. Future providers (vector stores,
  graph DBs, hosted SaaS) can implement it without inheriting any
  Bedrock-specific filesystem expectations.
