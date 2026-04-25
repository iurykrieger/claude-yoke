# Generator slug collision fixture

> Used to document the expected Generator behavior when `/yoke:discover`
> reports a slug collision. The fixture is reference material for
> reviewers and for any future automated test that exercises the
> Generator agent's slug-regeneration loop.

## Input prompt to the Generator

```
You are drafting a PRD titled "User authentication flow refactor".
The orchestrating /yoke:discover skill has detected the following
collisions in the host project's .yoke/ archive:

colliding_slugs:
  - 2026-05-01-auth-flow
  - 2026-05-01-auth-pipeline

Propose a new slug for today's date (2026-05-01) that preserves the
semantic intent of the PRD title but is lexically distinct from every
entry in colliding_slugs.
```

## Expected response

The Generator returns a single proposed slug that satisfies all four
rules from the "Slug collision protocol" block in `agents/generator.md`:

1. Preserves semantic intent of "User authentication flow refactor".
2. Is lexically distinct from `2026-05-01-auth-flow` and
   `2026-05-01-auth-pipeline`.
3. Does **not** end in a numeric suffix (`-2`, `-3`, `-v2`, `-new`,
   `-final`, etc.).
4. Matches the regex
   `^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]{0,49}$`.

## Acceptable example responses

Any one of the following is correct (non-exhaustive — the Generator
may produce other semantically equivalent rewrites):

- `2026-05-01-signin-handler`
- `2026-05-01-credential-exchange`
- `2026-05-01-login-orchestration`
- `2026-05-01-user-authentication-rework`
- `2026-05-01-auth-handshake`
- `2026-05-01-session-bootstrap`

## Unacceptable example responses

Any response that violates one or more of the four rules. Examples:

- `2026-05-01-auth-flow-2` — numeric suffix (rule 3).
- `2026-05-01-auth-flow-v2` — numeric suffix (rule 3).
- `2026-05-01-auth-flow-new` — synonym for "next version", not a
  semantic rewrite (rule 3, in spirit).
- `2026-05-01-auth-flow` — already in `colliding_slugs` (rule 2).
- `2026-05-01-Auth-Flow-Refactor` — uppercase letters (rule 4).
- `2026-05-01-` — empty slug body (rule 4).
- `not-a-date-auth-flow` — bad date prefix (rule 4).

## Five-attempt fallback

If the Generator's first five attempts all collide with the
`colliding_slugs` list (an unusual but possible scenario when many
similar features have already been built), it must surface the failure
to the user with its candidate list and request an explicit choice.
The Generator MUST NOT invent a numeric suffix as a fallback — the
user decides.

## See also

- `agents/generator.md` — the binding "Slug collision protocol" block
  that this fixture documents.
- `lib/working-memory/paths.sh` — the slug regex and `wm_slug_in_use`
  collision detector.
- `.vibeflow/specs/yoke-working-memory-folders.md` — Tech Spec
  Task 1.10 (this fixture's parent acceptance criterion).
