---
name: fixture-toolkit-string
description: Fixture persona where `sensor-toolkit` is a scalar string instead of a YAML list. The persona-loader must reject this with a `wm:`-prefixed stderr line naming the type violation.
tools: Read, Write, Edit, Grep, Glob, Bash, Skill
objective: Exercise the persona-loader's type-violation path for the sensor-toolkit field.
sensor-toolkit: "shellcheck-clean, persona-file-shape-valid"
review-skill: ""
---

# Fixture persona — sensor-toolkit as scalar

This file is malformed on purpose: `sensor-toolkit` is a scalar string instead
of a YAML list. The persona-loader must surface a `wm:` diagnostic naming the
type violation and exit non-zero.
