---
name: "source-command-project-build"
description: "Build the main package and sample app"
---

# source-command-project-build

Use this skill when the user asks to run the migrated source command `project-build`.

## Command Template

# Build Package and Sample

Build both the main CodeEditorPlugin package and CodeEditorSample:

```bash
# Build main package
swift build

# Build sample app
cd CodeEditorSample && swift build && cd ..
```

This command builds both components to verify compilation without running tests.
