---
description: Swift 6 concurrency compliance check
---

# Swift 6 Concurrency Check

Verify Swift 6 strict concurrency compliance:

```bash
# Build with strict concurrency checking
swift build -Xswiftc -strict-concurrency=complete

# Test with strict concurrency
swift test -Xswiftc -strict-concurrency=complete
```

Validates actor isolation, @MainActor annotations, and Sendable conformance across the codebase.