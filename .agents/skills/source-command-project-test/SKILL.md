---
name: "source-command-project-test"
description: "Run all tests for main package and sample app"
---

# source-command-project-test

Use this skill when the user asks to run the migrated source command `project-test`.

## Command Template

# Complete Test Suite

Run all package tests, including CodeEditorSample tests:

```bash
# Run the complete SwiftPM test suite
swift test

# Or run only sample target tests
swift test --filter CodeEditorSampleTests
```

Success criteria: 100% pass rate for the requested test scope.
