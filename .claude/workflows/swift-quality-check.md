# Swift Quality Check Pipeline

**Most frequently used workflow** - Runs the complete quality pipeline: lint fix → lint → build → test

## Description
This workflow performs the essential quality checks we run constantly during development. It automatically fixes linting issues, validates code quality, ensures compilation, and runs all tests.

## Usage
```
@swift-quality-check
```

## Steps

### 1. Fix Linting Issues
Run SwiftLint with automatic fixes:
```bash
swiftlint --fix
```

### 2. Check for Remaining Violations  
Verify zero linting violations:
```bash
swiftlint
```
**Success criteria**: Must show "Found 0 violations, 0 serious"

### 3. Build Main Package
Compile the core CodeEditorPlugin:
```bash
swift build
```

### 4. Run Main Package Tests
Execute all 284 core tests:
```bash
swift test
```

### 5. Build Sample App
Compile the CodeEditorSample:
```bash
cd CodeEditorSample && swift build
```

### 6. Run Sample App Tests  
Execute all 35 sample tests:
```bash
cd CodeEditorSample && swift test
```

## Success Criteria
- ✅ SwiftLint shows 0 violations across all files
- ✅ Main package builds without errors
- ✅ All 284 core tests pass (100% pass rate)
- ✅ Sample app builds without errors  
- ✅ All 35 sample tests pass (100% pass rate)
- ✅ Total: 319 tests passing

## Error Handling

### Linting Violations
If SwiftLint shows violations after `--fix`:
1. Review the specific violations listed
2. Fix manually using the project's coding standards
3. Common fixes:
   - Method name corrections (see EditorConfigurationBuilder patterns)
   - Actor isolation annotations (@MainActor)
   - Import statement ordering

### Build Failures
If build fails:
1. Check for Swift 6 concurrency issues
2. Verify platform abstraction imports (#if canImport patterns)
3. Check for missing methods in configuration builders

### Test Failures
If tests fail:
1. Check for memory management issues (TextKit2 retention)
2. Review actor isolation in test setup
3. Verify mock delegate implementations

## Related Workflows
- Run `@performance-analysis` if tests show memory issues
- Run `@cross-platform-test` if platform-specific failures occur
- Run `@documentation-update` after successful quality check
- Run `@git-commit-push` to commit quality improvements

## File Locations
- **Main SwiftLint**: `/Users/ajmcclary/Dev/CodeEditorPlugin/.swiftlint.yml`
- **Main Package**: `/Users/ajmcclary/Dev/CodeEditorPlugin/`
- **Sample App**: `/Users/ajmcclary/Dev/CodeEditorPlugin/CodeEditorSample/`

## Notes
This workflow maintains our project standards:
- Zero SwiftLint violations across 272 files
- 100% test pass rate (319/319 tests)
- Swift 6 concurrency compliance
- Production-ready quality gates