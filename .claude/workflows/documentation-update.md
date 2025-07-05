# Documentation Update Workflow

**Sync documentation with current project state** - Updates READMEs, metrics, and status badges

## Description
Maintains documentation consistency by updating test counts, quality metrics, status badges, and achievement sections across all README files. Ensures documentation accurately reflects the current state of the project.

## Usage
```
@documentation-update
```

## Update Operations

### 1. Collect Current Metrics
Gather latest project statistics:
```bash
# Count total tests
swift test --list-tests 2>/dev/null | wc -l  # Main package tests
cd CodeEditorSample && swift test --list-tests 2>/dev/null | wc -l  # Sample tests

# Verify linting status
swiftlint | grep "Found.*violations"

# Count total files
find . -name "*.swift" | grep -v ".build" | wc -l
```

### 2. Update Main README.md
Update `/Users/ajmcclary/Dev/CodeEditorPlugin/README.md`:

#### Status Badges
```markdown
[![Tests](https://img.shields.io/badge/tests-319%20passing-brightgreen)](#testing--quality)
[![SwiftLint](https://img.shields.io/badge/SwiftLint-0%20violations-brightgreen)](#code-quality-standards)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Mac%20Catalyst-lightgrey)](#requirements)
```

#### Quality Metrics Section
- **319 Total Tests**: 284 core package tests + 35 sample app tests
- **100% Test Pass Rate**: All tests passing with zero failures
- **Zero Linting Violations**: 0 violations across 272 files
- **Swift 6 Strict Concurrency**: Complete compliance

### 3. Update Sample App README.md
Update `/Users/ajmcclary/Dev/CodeEditorPlugin/CodeEditorSample/README.md`:

#### Status Badges
```markdown
[![Tests](https://img.shields.io/badge/tests-35%20passing-brightgreen)](#testing--quality)
[![SwiftLint](https://img.shields.io/badge/SwiftLint-0%20violations-brightgreen)](#quality-metrics)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange)](https://swift.org)
[![Files](https://img.shields.io/badge/files-66-blue)](#quality-metrics)
```

#### Test Breakdown
- BasicFunctionalityTests (4 tests)
- ConfigurationUITests (12 tests)
- PluginConfigurationTests (11 tests)
- QuickIsFlippedTest (1 test)
- SampleCodeTests (12 tests)
- SimplifiedIntegrationTests (6 tests)

### 4. Update CLAUDE.md
Update project instructions with latest achievements:
- Test counts and pass rates
- Quality metrics and violations status
- Recent architectural improvements
- Performance optimizations

### 5. Sync Achievement Sections
Update achievement callouts across all docs:
- ✅ Perfect Test Suite: 319 tests passing
- ✅ Zero Code Quality Issues: 0 violations across 272 files
- ✅ Swift 6 Ready: Full actor-based concurrency
- ✅ Production Performance: Optimized builds
- ✅ Cross-Platform Excellence: macOS, iOS, Catalyst verified

## Template Sections

### Status Badges Template
```markdown
[![Tests](https://img.shields.io/badge/tests-{TOTAL_TESTS}%20passing-brightgreen)](#testing--quality)
[![SwiftLint](https://img.shields.io/badge/SwiftLint-{VIOLATIONS}%20violations-{COLOR})](#code-quality-standards)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange)](https://swift.org)
[![Files](https://img.shields.io/badge/files-{FILE_COUNT}-blue)](#quality-metrics)
```

### Test Coverage Template
```markdown
### Comprehensive Test Coverage
- **{TOTAL} Total Tests**: {CORE} core package tests + {SAMPLE} sample app tests
- **100% Test Pass Rate**: All tests passing with zero failures in final validation
- **{CATEGORIES} Test Categories**: From low-level text processing to high-level UI integration
```

### Quality Metrics Template
```markdown
### Code Quality Standards
- **Zero Linting Violations**: Strict SwiftLint configuration with **0 violations across 272 files**
- **Swift 6 Strict Concurrency**: Complete compliance with Swift's strictest concurrency checking
- **Actor-Based Safety**: All potentially unsafe operations properly isolated to background actors
```

## Validation Steps

### 1. Verify Badge Accuracy
- Test counts match `swift test --list-tests` output
- Violation counts match `swiftlint` output
- File counts match actual project files

### 2. Check Consistency
- All READMEs use same metrics
- Status badges reflect current state
- Achievement sections are synchronized

### 3. Validate Links
- All badges link to correct sections
- Internal documentation links work
- External links are accessible

## Success Criteria
- ✅ All metrics accurately reflect current project state
- ✅ Status badges show correct counts and colors
- ✅ Achievement sections highlight latest improvements
- ✅ Documentation consistency across all files
- ✅ Links and references work properly

## Common Updates

### After Test Changes
- Update total test counts (core + sample)
- Verify test pass rates
- Update test breakdown by category

### After Quality Improvements
- Update violation counts (should be 0)
- Update file counts if new files added
- Refresh achievement sections

### After Feature Additions
- Update supported language counts
- Update platform compatibility info
- Add new feature descriptions

## Error Handling

### Metric Mismatches
If documentation doesn't match actual state:
1. Re-run metric collection commands
2. Verify test counting logic
3. Check for uncommitted changes affecting counts

### Badge Display Issues
If badges don't display correctly:
1. Check badge URL syntax
2. Verify color and status parameters
3. Test badge links in preview

## Related Workflows
- Run after `@swift-quality-check` to sync latest metrics
- Run before `@git-commit-push` to ensure documentation accuracy
- Run as part of `@release-preparation` for release docs

## File Locations
- **Main README**: `/Users/ajmcclary/Dev/CodeEditorPlugin/README.md`
- **Sample README**: `/Users/ajmcclary/Dev/CodeEditorPlugin/CodeEditorSample/README.md`
- **Project Docs**: `/Users/ajmcclary/Dev/CodeEditorPlugin/CLAUDE.md`

## Notes
Documentation is crucial for:
- Project credibility and professionalism
- Developer onboarding and integration
- Showcasing quality and capabilities
- Maintaining contribution standards

Keep documentation current to reflect the project's true state and achievements.