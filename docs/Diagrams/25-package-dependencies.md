# Package Dependencies - CodeEditorPlugin

This diagram shows the package dependencies for the main CodeEditorPlugin framework.

## Overview

**Runtime Dependencies:**
- **SwiftSyntax 602.0.0+** - Apple's Swift source code manipulation library
- **SwiftParser** - Swift source code parsing (part of swift-syntax)
- **swift-dependencies** - Dependency management library (Point-Free)
- **xctest-dynamic-overlay** - Runtime issue reporting

**Development Dependencies:**
- **swift-custom-dump** - Custom pretty-printing and diffing (Point-Free)
- **swift-snapshot-testing** - Snapshot testing (Point-Free, ajmcclary fork for Swift 6.3 compat)

**Security Status:** Low risk - Runtime dependencies come from Apple / Swift project packages and Point-Free libraries; snapshot testing currently uses the project fork documented in `Package.swift`.
**Platform Support:** macOS 26.3+, iOS 26.3+ (Mac Catalyst retired in 0.2.0)

## Default View (Products Only)

```mermaid
flowchart LR
    CodeEditorUI-->CodeEditorPlugin
    CodeEditorUI-->CodeEditorDesignTokens
    CodeEditorPlugin-->CodeEditorDesignTokens
    CodeEditorPlugin-->SwiftSyntax[[SwiftSyntax 602+]]
    CodeEditorPlugin-->SwiftParser[[SwiftParser]]
    CodeEditorPlugin-->Dependencies[[swift-dependencies]]
    CodeEditorPlugin-->IssueReporting[[IssueReporting]]
    CodeEditorSample-->CodeEditorPlugin
    CodeEditorSample-->CodeEditorUI
    CodeEditorSample-->CodeEditorDesignTokens

    style SwiftSyntax fill:#e1f5fe
    style SwiftParser fill:#e1f5fe
    style CodeEditorDesignTokens fill:#e8f5e9
    style CodeEditorUI fill:#e8f5e9
    style CodeEditorPlugin fill:#f3e5f5
    style CodeEditorSample fill:#f3e5f5
    style Dependencies fill:#fff3e0
    style IssueReporting fill:#fff3e0
```

## Complete View (Including Test Targets)

```mermaid
flowchart LR
    CodeEditorPlugin-->SwiftSyntax[[SwiftSyntax 602+]]
    CodeEditorPlugin-->SwiftParser[[SwiftParser]]
    CodeEditorPlugin-->Dependencies[[swift-dependencies]]
    CodeEditorPlugin-->IssueReporting[[IssueReporting]]
    CodeEditorPlugin-->CodeEditorDesignTokens
    CodeEditorUI-->CodeEditorPlugin
    CodeEditorUI-->CodeEditorDesignTokens
    CodeEditorSample-->CodeEditorPlugin
    CodeEditorSample-->CodeEditorUI
    CodeEditorSample-->CodeEditorDesignTokens
    CodeEditorPluginTests{{CodeEditorPluginTests}}-->CodeEditorPlugin
    CodeEditorPluginTests-->CustomDump[[swift-custom-dump]]
    CodeEditorPluginTests-->SnapshotTesting[[swift-snapshot-testing]]
    CodeEditorDesignTokensTests{{DesignTokensTests}}-->CodeEditorDesignTokens
    CodeEditorUITests{{CodeEditorUITests}}-->CodeEditorUI
    CodeEditorSampleTests{{CodeEditorSampleTests}}-->CodeEditorSample

    style SwiftSyntax fill:#e1f5fe
    style SwiftParser fill:#e1f5fe
    style CodeEditorDesignTokens fill:#e8f5e9
    style CodeEditorUI fill:#e8f5e9
    style CodeEditorPlugin fill:#f3e5f5
    style CodeEditorSample fill:#f3e5f5
    style CodeEditorPluginTests fill:#fff3e0
    style CodeEditorDesignTokensTests fill:#fff3e0
    style CodeEditorUITests fill:#fff3e0
    style CodeEditorSampleTests fill:#fff3e0
```

## Platform Compatibility Matrix

| Dependency | macOS | iOS | Notes |
|---|:---:|:---:|---|
| SwiftSyntax | ✅ | ✅ | 602.0.0+ |
| SwiftParser | ✅ | ✅ | Included with SwiftSyntax |
| swift-dependencies | ✅ | ✅ | Point-Free |
| IssueReporting | ✅ | ✅ | xctest-dynamic-overlay |
| swift-custom-dump | ✅ | ✅ | Test-only |
| swift-snapshot-testing | ✅ | ✅ | Test-only, ajmcclary fork for Swift 6.3 compatibility |

## Performance Notes

- SwiftSyntax provides efficient AST-based parsing
- Background processing via AsyncSyntaxHighlighter prevents UI blocking
- SmartTokenCache with LRU eviction for syntax highlighting results
- ActorCoordinator injected via EditorConfiguration for concurrency management
- MemoryMonitor injected through configuration for resource tracking
