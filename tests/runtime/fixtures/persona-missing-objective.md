---
name: fixture-missing-objective
description: Fixture persona missing the required `objective` key. The persona-loader must reject this file with a `wm:`-prefixed stderr line naming the missing key.
tools: Read, Write, Edit, Grep, Glob, Bash, Skill
sensor-toolkit:
  - shellcheck-clean
review-skill: ""
---

# Fixture persona — missing objective

This file is malformed on purpose: the `objective` key is absent from the
frontmatter. The persona-loader must surface a `wm:` diagnostic naming the
missing key and exit non-zero.
