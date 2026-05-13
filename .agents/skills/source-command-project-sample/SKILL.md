---
name: "source-command-project-sample"
description: "CodeEditorSample build, test, and run operations"
---

# source-command-project-sample

Use this skill when the user asks to run the migrated source command `project-sample`.

## Command Template

# Sample App Operations

Build, test, and run the CodeEditorSample:

```bash
# Build sample app
swift build --target CodeEditorSample

# Run sample target tests
swift test --filter CodeEditorSampleTests

# Run sample app
swift run CodeEditorSample
```

Validates the demonstration application functionality and integration.
