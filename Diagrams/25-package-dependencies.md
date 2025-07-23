# Package Dependencies - CodeEditorPlugin

This diagram shows the package dependencies for the main CodeEditorPlugin framework.

## Overview

**Runtime Dependencies:**
- **SwiftSyntax 601.0.1** - Apple's Swift source code manipulation library
- **SwiftParser** - Swift source code parsing (part of swift-syntax)

**Development Dependencies:**
- **depermaid 1.1.0** - Mermaid diagram generation tool (build-time only)

**Security Status:** ✅ Low risk - Apple-maintained dependencies, no external services
**Platform Support:** macOS 14.0+, iOS 16.0+, Mac Catalyst 16.0+ (with SwiftSyntax fallbacks)

## Default View (Products Only)

```mermaid
flowchart LR
    CodeEditorPlugin-->SwiftParser[[SwiftParser]]
    CodeEditorPlugin-->SwiftSyntax[[SwiftSyntax]]
    
    style SwiftSyntax fill:#e1f5fe
    style SwiftParser fill:#e1f5fe
    style CodeEditorPlugin fill:#f3e5f5
```

## Complete View (Including Test Targets)

```mermaid
flowchart LR
    CodeEditorPlugin-->SwiftParser[[SwiftParser]]
    CodeEditorPlugin-->SwiftSyntax[[SwiftSyntax]]
    CodeEditorPluginTests{{CodeEditorPluginTests}}-->CodeEditorPlugin
    
    style SwiftSyntax fill:#e1f5fe
    style SwiftParser fill:#e1f5fe
    style CodeEditorPlugin fill:#f3e5f5
    style CodeEditorPluginTests fill:#fff3e0
```

## Dependency Details

```mermaid
flowchart TD
    subgraph "External Dependencies"
        SwiftSyntax["SwiftSyntax 601.0.1<br/>🏢 Apple Official<br/>🔒 Secure<br/>📅 Latest Stable"]
        SwiftParser["SwiftParser<br/>🔗 Part of swift-syntax<br/>🎯 AST Parsing"]
        depermaid["depermaid 1.1.0<br/>🛠️ Dev Tool Only<br/>📊 Diagram Generation<br/>🔒 No Security Issues"]
    end
    
    subgraph "CodeEditorPlugin Features"
        SyntaxHighlighter["Swift Syntax Highlighting<br/>🎨 AST-based<br/>⚡ Real-time"]
        PlatformSupport["Cross-Platform Support<br/>🍎 macOS, iOS, Catalyst<br/>🔄 Conditional Compilation"]
        Performance["Performance Optimized<br/>📈 60fps target<br/>🚀 Async processing"]
    end
    
    SwiftSyntax --> SyntaxHighlighter
    SwiftParser --> SyntaxHighlighter
    SyntaxHighlighter --> PlatformSupport
    SyntaxHighlighter --> Performance
    
    style SwiftSyntax fill:#e8f5e8
    style SwiftParser fill:#e8f5e8
    style depermaid fill:#fff9c4
    style SyntaxHighlighter fill:#f3e5f5
    style PlatformSupport fill:#e3f2fd
    style Performance fill:#fce4ec
```

## Platform Compatibility Matrix

| Dependency | macOS | iOS | Mac Catalyst | Notes |
|------------|-------|-----|--------------|-------|
| SwiftSyntax | ✅ | ✅ | ❌ | Fallback implementation provided |
| SwiftParser | ✅ | ✅ | ❌ | Included with SwiftSyntax |
| depermaid | ✅ | ✅ | ✅ | Build-time only |

## Security & Performance Notes

**Security:**
- All dependencies maintained by Apple or have clean security profiles
- No network dependencies or external services
- Regular security updates available for SwiftSyntax
- depermaid is development-only with no runtime impact

**Performance:**
- SwiftSyntax provides efficient AST-based parsing
- Background processing prevents UI blocking
- Conditional compilation minimizes overhead on Mac Catalyst
- LRU caching for syntax highlighting results

**Dependency Injection:**
- ActorCoordinator injected via EditorConfiguration
- MemoryMonitor injected through configuration
- No singleton patterns used
- Full testability through protocol abstractions
