---
description: Run all tests for main package and sample app
---

# Complete Test Suite

Run all 319 tests across main package and sample app:

```bash
# Run main package tests (284 tests)
swift test

# Run sample app tests (35 tests)
cd CodeEditorSample && swift test && cd ..
```

Success criteria: 100% pass rate across all 319 tests.