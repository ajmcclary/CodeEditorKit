# AGENTS.md

AI assistant guidance for CodeEditorPlugin - a TextKit2-based code editor framework for Apple platforms.

## Quick Reference

### Essential Commands
```bash
# Build, lint, and test
swift build && swiftlint && swift test --parallel

# Fix linting issues
swiftlint --fix

# Generate package documentation
swift package generate-documentation --target CodeEditorPlugin
```

### Project Stats
- **437 Source Files** across **18 top-level source directories**
- **70 Test Files** with comprehensive coverage
- **20 Languages Supported** (Swift, JavaScript, TypeScript, Python, Go, Rust, C, C++, Java, HTML, CSS, JSON, Markdown, YAML, XML, SQL, Ruby, PHP, Shell, Plain Text)
- **Zero SwiftLint Violations** maintained

## Architecture

### Directory Structure
```
Sources/CodeEditorPlugin/
├── Core/                    # Main APIs, services, event system
├── Text/                    # TextKit handling, layout, processing
├── Layout/                  # UI components + ViewModels
├── Configuration/           # Settings & presets
├── SyntaxHighlighting/      # Language highlighting
├── Languages/               # Language-specific providers
├── Completion/              # Code completion
├── Features/                # Optional features
├── SwiftUI/                 # SwiftUI integration
├── Platform/                # Cross-platform abstractions
├── PluginSystem/            # Internal plugin infrastructure
├── Extensions/              # Type extensions (+Extensions suffix)
├── Performance/             # Monitoring & optimization
├── LSP/                     # Language Server Protocol
├── Annotations/             # Code annotations
├── Models/                  # Data models
├── Utilities/               # Shared utilities
└── Documentation.docc/      # DocC documentation
```

### Core Components

- **CodeEditorView**: Main TextKit2 text view with cross-platform support
- **EditorConfiguration**: Nested config (`display`, `layout`, `behavior`, `performance`)
- **Platform Abstraction**: `PlatformColor`, `PlatformFont`, `PlatformView`
- **Services**: `TextEditingService`, `LanguageDetectionService`, `SyntaxHighlightingService`
- **Event System**: `UnifiedEventSystem`, `CrossPlatformCoordinator`

## Key Patterns

### Configuration
```swift
// Direct updates (preferred)
config.display.isLineNumbersEnabled = true
config.layout.tabWidth = 4

// Use presets
let config = EditorConfiguration.minimal

// Batch updates
appState.updateConfiguration { config in
    config.display.isLineNumbersEnabled = true
    config.display.fontSize = 16
}

// Dependency injection for ActorCoordinator
var config = EditorConfiguration()
config.actorCoordinator = ActorCoordinator.create()
```

### SwiftUI Integration
```swift
CodeEditor(text: $code)
    .codeLanguage(.swift)
    .environment(\.codeEditorConfiguration, config)

// Direct bindings (✅ RECOMMENDED)
Toggle("Line Numbers", isOn: $config.display.isLineNumbersEnabled)

// Avoid recreating configuration wrappers when a direct binding is available.
```

### Platform Code
```swift
// ✅ CORRECT: Use canImport
#if canImport(AppKit)
import AppKit
#endif

// ❌ WRONG: Don't use os()
#if os(macOS)  // Don't do this
```

### Language Detection
```swift
// Auto-detect
textView.setLanguage(fileExtension: "swift")

// Direct
textView.language = .python
```

## Development Rules

### Must Follow
- **Swift 6 Concurrency**: Use actors for background work
- **Extension Naming**: ALL extension files use the `+Extensions` suffix; domain-local extension files are preferred when the extension belongs to a specific feature area
- **Platform Detection**: Use `#if canImport()` NOT `#if os()`
- **Logging**: Use `CrossPlatformLogger.logger()` not `print()`
- **Memory**: Clean up in `removeFromSuperview`
- **Force Unwraps**: Never use `!` - always safe unwrap
- **SwiftLint**: Zero violations (run `swiftlint --fix`)

### Architecture Guidelines
- **UI/Logic Separation**: Business logic in services, not views
- **ViewModels**: Co-located with features (e.g., `GutterViewModel` in `Layout/`)
- **Dependency Injection**: No singletons - use DI for all services
  - ActorCoordinator: Pass via `EditorConfiguration.actorCoordinator`
  - MemoryMonitor: Inject through configuration
- **Error Handling**: Comprehensive error types, no silent failures
- **Testing**: Test new features (53+ test files exist)

### Performance Targets
- **60fps** rendering during all operations
- **500KB+** file support without lag
- **Async** syntax highlighting with LRU cache
- **Background** processing for expensive operations

## Common Tasks

### Add Configuration Option
1. Add property to config section
2. Update presets if needed
3. Add SwiftUI modifier
4. Update DocC documentation

### Add Platform Feature
1. Create abstraction in `Platform/`
2. Update `PlatformCapabilities`
3. Test on all platforms (macOS, iOS, Catalyst)

### Debug Issues
```bash
# Run specific test
swift test --filter TestName

# Platform testing
xcodebuild -scheme CodeEditorPlugin -destination 'platform=iOS Simulator,name=iPhone 15'
```

## API Notes

### API Notes
- Use direct bindings for SwiftUI configuration controls.
- Use dependency injection for services.

### Key Services
- `TextEditingService` - Text manipulation
- `LanguageDetectionService` - File type detection  
- `SyntaxHighlightingService` - Highlighting coordination
- `UniversalCompletionProvider` - Completion factory

### Important Files
- `CodeEditorAPI.swift` - Public API protocol
- `EditorConfiguration.swift` - Config structure
- `PlatformCapabilities.swift` - Runtime detection
- `UnifiedEventSystem.swift` - Event handling

## Testing Checklist
- [ ] Builds without warnings
- [ ] SwiftLint passes
- [ ] Tests pass on all platforms
- [ ] 60fps performance maintained
- [ ] Memory properly managed
- [ ] Documentation updated
