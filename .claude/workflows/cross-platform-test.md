# Cross-Platform Testing Workflow

**macOS and iOS / iPadOS compatibility verification** - Platform-specific validation for the supported native Apple platforms.

## Description

Validates the current platform contract: native macOS 26.0+ and iOS / iPadOS 26.0+. Mac Catalyst was retired in 0.2.0 and should not appear as a supported build target in active docs or commands.

## Usage

```
@cross-platform-test
```

## Platform Testing Operations

### 1. Platform Abstraction Validation

```bash
swift test --filter PlatformAbstractionTests
swift test --filter PlatformCapabilitiesTests
swift test --filter LineNumbersPlatformTests
```

Validates:

- AppKit/UIKit detection via `#if canImport(...)`
- Platform type aliases and semantic colors
- TextKit2 capability assumptions
- Native macOS and iOS configuration recommendations

### 2. Architecture-Specific Builds

```bash
# Apple Silicon
swift build --arch arm64

# Intel
swift build --arch x86_64
```

### 3. iOS Container Coverage

```bash
swift test --filter CodeEditorContainerViewTests
swift test --filter IOSAnnotationTests
```

### 4. Sample Target Build

```bash
swift build --target CodeEditorSample
swift test --filter CodeEditorSampleTests
```

## Platform Support Matrix

### macOS

- **Minimum**: macOS 26.0+
- **Features**:
  - TextKit2 editor path
  - AppKit-backed SwiftUI representable
  - Local process-backed LSP support
  - Native menus, keyboard focus, and scroll behavior

### iOS / iPadOS

- **Minimum**: iOS / iPadOS 26.0+
- **Features**:
  - TextKit2 editor path
  - UIKit-backed SwiftUI representable
  - Remote WebSocket LSP support
  - Touch, keyboard, and container-view adaptations

### Mac Catalyst

- **Status**: unsupported as of 0.2.0
- **Validation**: active docs and package metadata should describe native macOS and iOS only.

## Success Criteria

- Platform abstraction and capability tests pass.
- Builds succeed for the requested CPU architectures.
- Sample target builds and sample tests pass.
- No active workflow tells contributors to `cd CodeEditorSample`.
- No active workflow treats Mac Catalyst as supported.

## File Locations

- **Platform Abstractions**: `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/Platform/`
- **Platform Docs**: `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/docs/Platform/`
- **Feature Matrix**: `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/docs/FeatureMatrix.md`
