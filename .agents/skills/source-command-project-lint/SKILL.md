---
name: "source-command-project-lint"
description: "Fix and check SwiftLint violations"
---

# source-command-project-lint

Use this skill when the user asks to run the migrated source command `project-lint`.

## Command Template

# SwiftLint Fix and Check

Fix linting issues and verify zero violations:

```bash
# Fix auto-correctable violations
swiftlint --fix

# Check for remaining violations
swiftlint
```

Success criteria: "Found 0 violations, 0 serious" for the configured `Sources` and `Tests` paths.
