---
description: Run all tests for main package and sample app
---

# Complete Test Suite

Run all package tests, including CodeEditorSample tests:

```bash
# Run the complete SwiftPM test suite
swift test

# Or run only sample target tests
swift test --filter CodeEditorSampleTests
```

Success criteria: 100% pass rate for the requested test scope.
