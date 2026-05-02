---
name: fixture-valid
description: Fixture persona for the persona-loader pass case (Sprint 01 / Task t03 / Acceptance Contract Scenario 3 / FR-1). All required keys present with the expected types.
tools: Read, Write, Edit, Grep, Glob, Bash, Skill
objective: Pass the persona-loader's validate subcommand cleanly so the loader's success path is exercised in the unit test.
sensor-toolkit:
  - shellcheck-clean
  - persona-file-shape-valid
review-skill: ""
---

# Fixture persona — valid frontmatter

This file exists only as a fixture for `tests/runtime/persona-loader.test.sh`.
Every required Yoke persona key is present with the right type. The body is
intentionally short — the loader inspects the YAML frontmatter only.
