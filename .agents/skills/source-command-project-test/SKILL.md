---
name: "source-command-project-test"
description: "Run all tests for main package and sample app"
---

# source-command-project-test

Use this skill when the user asks to run the migrated source command `project-test`.

## Command Template

# Complete Test Suite

Run all 319 tests across main package and sample app:

```bash
# Run main package tests (284 tests)
swift test

# Run sample app tests (35 tests)
cd CodeEditorSample && swift test && cd ..
```

Success criteria: 100% pass rate across all 319 tests.
