---
name: fixture-tools-missing
description: Fixture persona missing the required `tools` key. The persona-loader must reject this file with a `wm:`-prefixed stderr line naming the missing key.
objective: Exercise the persona-loader's missing-required-key path for the tools field.
sensor-toolkit:
  - shellcheck-clean
review-skill: ""
---

# Fixture persona — missing tools

This file is malformed on purpose: the `tools` key is absent from the
frontmatter. The persona-loader must surface a `wm:` diagnostic naming the
missing key and exit non-zero.
