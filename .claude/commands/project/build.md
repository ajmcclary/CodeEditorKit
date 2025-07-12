---
description: Build the main package and sample app
---

# Build Package and Sample

Build both the main CodeEditorPlugin package and CodeEditorSample:

```bash
# Build main package
swift build

# Build sample app
cd CodeEditorSample && swift build && cd ..
```

This command builds both components to verify compilation without running tests.