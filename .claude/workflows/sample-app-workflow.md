# CodeEditorSample Workflow

**Sample app specific operations** - Testing and validation of the demonstration application

## Description
Dedicated workflow for the CodeEditorSample application. Handles sample-specific building, testing, configuration validation, and integration verification with the main plugin.

## Usage
```
@sample-app-workflow
```

## Operations

### 1. Sample App Quality Check
```bash
cd CodeEditorSample
swiftlint --fix
swiftlint
swift build
swift test
```

### 2. Configuration Integration Test
Verify sample app configurations work with main plugin:
- Test all ConfigurationPreset cases
- Validate EditorConfigurationBuilder integration
- Check theme system functionality

### 3. Demo Features Validation
Test showcase features:
- Syntax highlighting for all 17 languages
- Theme switching (Xcode, VS Code Dark, GitHub, Solarized)
- Performance monitoring display
- Annotation system demonstration

### 4. Cross-Platform Sample Testing
```bash
# Test sample app on different targets
swift build --arch arm64    # Apple Silicon
swift build --arch x86_64   # Intel
```

## Sample App Metrics

### Test Coverage
- **35 Total Tests** across 6 test suites:
  - BasicFunctionalityTests (4 tests)
  - ConfigurationUITests (9 tests)
  - PluginConfigurationTests (8 tests)
  - QuickIsFlippedTest (1 test)
  - SampleCodeTests (9 tests)
  - SimplifiedIntegrationTests (4 tests)

### Quality Standards
- **66 Files** with zero SwiftLint violations
- **Swift 6 Compliance** with actor-based concurrency
- **Production Patterns** for integration examples

## Success Criteria
- ✅ Sample app builds without errors
- ✅ All 35 tests pass (100% pass rate)
- ✅ Zero linting violations across 66 files
- ✅ All configuration presets functional
- ✅ Demo features working properly
- ✅ Cross-platform compatibility verified

## Configuration Validation

### Preset Testing
Verify each ConfigurationPreset works:
```swift
// Test preset creation and application
let fullFeatured = ConfigurationPreset.fullFeatured.configuration
let minimal = ConfigurationPreset.minimal.configuration
let readOnly = ConfigurationPreset.readOnly.configuration
let markdown = ConfigurationPreset.markdown.configuration
let presentation = ConfigurationPreset.presentation.configuration
```

### Builder Pattern Testing
Validate EditorConfigurationBuilder methods:
- `.isEditable()` ✓
- `.enableAnnotations()` ✓
- `.useHardwareAcceleration()` ✓
- `.enableCodeCompletion()` ✓
- `.enableSyntaxHighlighting()` ✓

## Common Issues & Solutions

### Builder Method Mismatches
If sample app fails to build:
1. Check for outdated builder method names
2. Compare with main plugin's EditorConfigurationBuilder
3. Update method calls to match current API

### Theme Integration Issues
If theme switching fails:
1. Verify ThemeProvider.swift implementation
2. Check platform color abstractions
3. Test light/dark mode adaptation

### Performance Demo Problems
If performance monitoring doesn't display:
1. Check PerformanceMonitor integration
2. Verify actor isolation in UI updates
3. Test background processing coordination

## Integration Points

### With Main Plugin
- Validates public API usage patterns
- Tests real-world integration scenarios
- Demonstrates best practices

### With Documentation
Sample app serves as:
- Live documentation of features
- Integration example for developers
- Cross-platform demonstration

## Running Sample App
```bash
cd CodeEditorSample
swift run CodeEditorSample
```

### Demo Checklist
When running demo:
- [ ] App launches successfully
- [ ] All language samples load
- [ ] Syntax highlighting works for all 17 languages
- [ ] Configuration UI is responsive
- [ ] Theme switching is smooth
- [ ] Performance metrics display
- [ ] Annotations render properly

## Related Workflows
- Run `@swift-quality-check` for comprehensive validation
- Run `@cross-platform-test` for platform-specific issues
- Run `@documentation-update` to sync sample app metrics
- Run `@performance-analysis` if demo shows performance issues

## File Locations
- **Sample App Root**: `/Users/ajmcclary/Dev/CodeEditorPlugin/CodeEditorSample/`
- **Sample Tests**: `/Users/ajmcclary/Dev/CodeEditorPlugin/CodeEditorSample/Tests/`
- **Configuration**: `/Users/ajmcclary/Dev/CodeEditorPlugin/CodeEditorSample/Sources/CodeEditorSample/Models/EditorConfiguration.swift`

## Notes
The sample app is crucial for:
- Demonstrating plugin capabilities
- Validating integration patterns
- Providing copy-paste examples for developers
- Testing real-world usage scenarios

It maintains the same quality standards as the main plugin: zero violations, 100% test coverage, and production-ready code.