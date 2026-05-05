---
name: "source-command-project-arch"
description: "Architecture-specific builds (arm64, x86_64)"
---

# source-command-project-arch

Use this skill when the user asks to run the migrated source command `project-arch`.

## Command Template

# Architecture-Specific Builds

Build for specific CPU architectures:

```bash
# Apple Silicon (arm64)
swift build --arch arm64

# Intel (x86_64)  
swift build --arch x86_64

# Check current architecture
uname -m
```

Validates compilation across different CPU architectures for cross-platform compatibility.
