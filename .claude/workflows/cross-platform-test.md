# Cross-Platform Testing Workflow

**macOS, iOS, and Mac Catalyst compatibility verification** - Platform-specific validation

## Description
Validates cross-platform compatibility by testing platform abstractions, building for different architectures, and verifying platform-specific functionality across macOS, iOS, and Mac Catalyst.

## Usage
```
@cross-platform-test
```

## Platform Testing Operations

### 1. Platform Abstraction Validation
Test the platform abstraction layer:
```bash
swift test --filter PlatformAbstractionTests
```

Validates:
- Platform detection logic
- Type alias correctness
- Capability detection
- Semantic color system
- Font creation across platforms

### 2. Architecture-Specific Builds
Test different CPU architectures:
```bash
# Apple Silicon
swift build --arch arm64

# Intel
swift build --arch x86_64

# Universal (if supported)
swift build --arch arm64 --arch x86_64
```

### 3. Platform-Specific Container Testing
Test iOS container architecture:
```bash
swift test --filter CodeEditorContainerViewTests
```

Validates:
- iOS text containment
- Keyboard handling
- Gesture recognition
- Input accessory views

### 4. Cross-Platform UI Testing
Test platform-specific UI components:
```bash
swift test --filter LineCountingTests  # Tests macOS vs iOS line numbers
swift test --filter EdgeInsetsTests    # Tests platform-specific insets
```

## Platform Support Matrix

### macOS (Primary Platform)
- **Minimum**: macOS 12.0+
- **Optimized**: macOS 14+
- **Features**:
  - Full TextKit2 support
  - Native scroll bars
  - AppKit integration
  - Hardware acceleration

### iOS 
- **Minimum**: iOS 16.0+
- **Features**:
  - Touch-optimized interactions
  - Keyboard-aware layout
  - Container view architecture
  - UIKit integration

### Mac Catalyst
- **Minimum**: Mac Catalyst 16.0+
- **Features**:
  - Hybrid touch/mouse support
  - Adaptive UI elements
  - Consistent behavior across input methods
  - Unified app experience

## Platform Abstraction Validation

### 1. Import Guards Testing
Verify correct platform imports:
```swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
public typealias PlatformColor = NSColor
#else
import UIKit  
public typealias PlatformColor = UIColor
#endif
```

### 2. Capability Detection
Test platform capability detection:
```swift
let capabilities = PlatformCapabilities.shared

#if targetEnvironment(macCatalyst)
XCTAssertEqual(capabilities.currentPlatform, .catalyst)
#elseif canImport(AppKit)
XCTAssertEqual(capabilities.currentPlatform, .macOS) 
#else
XCTAssertEqual(capabilities.currentPlatform, .iOS)
#endif
```

### 3. Semantic Color System
Validate adaptive colors:
```swift
// Test semantic colors work across platforms
let backgroundColor = PlatformColors.systemBackground
let textColor = PlatformColors.label
let controlBackground = PlatformColors.controlBackground
```

## Sample App Cross-Platform Testing

### 1. Build Sample for All Platforms
```bash
cd CodeEditorSample

# Build for macOS
swift build

# Test platform-specific configurations
swift test --filter ConfigurationUITests
swift test --filter SimplifiedIntegrationTests
```

### 2. Platform-Specific Features
Test sample app features on each platform:
- **macOS**: Full feature set, native menus, keyboard shortcuts
- **iOS**: Touch interactions, keyboard handling, container layout
- **Catalyst**: Hybrid interactions, adaptive UI scaling

## Success Criteria
- ✅ Platform abstraction tests pass
- ✅ Builds successfully on all architectures (arm64, x86_64)
- ✅ Container view tests pass for iOS
- ✅ Platform detection works correctly
- ✅ Semantic color system functional
- ✅ Sample app demonstrates cross-platform capabilities
- ✅ No platform-specific compilation errors

## Common Platform Issues

### Mac Catalyst Import Problems
Symptoms:
- Build errors with AppKit on Catalyst
- Type alias mismatches
- Feature availability issues

Solutions:
1. Ensure all AppKit imports include `!targetEnvironment(macCatalyst)`
2. Use platform capability detection
3. Test on actual Catalyst environment

### iOS Container Issues
Symptoms:
- Text input not working properly
- Keyboard appearance problems
- Layout constraint conflicts

Solutions:
1. Use `CodeEditorContainerView` for iOS
2. Implement proper keyboard handling
3. Test on physical iOS devices

### Feature Availability Differences
Symptoms:
- Features work on one platform but not others
- Performance differences between platforms
- UI inconsistencies

Solutions:
1. Use `PlatformCapabilities` for feature detection
2. Implement platform-specific optimizations
3. Test on real hardware for each platform

## Platform-Specific Optimizations

### macOS Optimizations
- Leverage TextKit2 advanced features
- Use native scroll behavior
- Implement full keyboard shortcuts
- Optimize for larger screens

### iOS Optimizations  
- Touch gesture recognition
- Keyboard appearance handling
- Content inset management
- Battery-conscious processing

### Catalyst Optimizations
- Adaptive input handling
- Scaled UI elements
- Cross-input method consistency
- Desktop-class feature parity

## Testing Environment Requirements

### Development Environment
- **Xcode**: 16.0+ with all platform SDKs
- **macOS**: 14+ for optimal testing
- **Simulator**: iOS 16+ simulators installed
- **Hardware**: Access to iOS devices for real testing

### Testing Matrix
Test combinations:
- **macOS**: arm64, x86_64
- **iOS**: arm64 (device), x86_64 (simulator)
- **Catalyst**: arm64, x86_64

## Error Handling

### Platform Detection Failures
If platform detection doesn't work:
1. Check `PlatformCapabilities` implementation
2. Verify capability detection logic
3. Test on actual target platforms

### Build Failures on Specific Platforms
If builds fail for specific platforms:
1. Check platform-specific imports
2. Verify availability annotations
3. Review conditional compilation blocks

### Runtime Platform Issues
If runtime behavior differs between platforms:
1. Test platform abstractions
2. Check for platform-specific code paths
3. Verify feature availability at runtime

## Integration Points

### With Quality Workflows
Run after quality checks to ensure platform compatibility:
```
@swift-quality-check
@cross-platform-test
```

### With Performance Analysis
Validate performance across platforms:
```
@performance-analysis
@cross-platform-test
```

### With Sample App Testing
Demonstrate cross-platform capabilities:
```
@sample-app-workflow
@cross-platform-test
```

## Related Workflows
- Run `@swift-quality-check` before platform testing
- Run `@performance-analysis` for platform-specific performance
- Run `@sample-app-workflow` to demonstrate cross-platform features
- Follow with `@documentation-update` to record compatibility status

## File Locations
- **Platform Abstractions**: `/Users/ajmcclary/Dev/CodeEditorPlugin/Sources/CodeEditorPlugin/Platform/`
- **Platform Tests**: `/Users/ajmcclary/Dev/CodeEditorPlugin/Tests/CodeEditorPluginTests/PlatformAbstractionTests.swift`
- **Container Tests**: `/Users/ajmcclary/Dev/CodeEditorPlugin/Tests/CodeEditorPluginTests/CodeEditorContainerViewTests.swift`

## Notes
Cross-platform testing ensures:
- True native experience on each platform
- Consistent API across platforms
- Optimal performance for each environment
- Future-proof platform support

This workflow maintains the project's commitment to genuine cross-platform support rather than lowest-common-denominator compatibility.