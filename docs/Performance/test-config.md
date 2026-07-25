# Test Performance Configuration

Configure and optimize test execution with parallel testing, timeouts, and performance budgets.

## Overview

This article describes the comprehensive test performance optimizations implemented for CodeEditorKit, including parallel test execution strategies, timeout configuration, and performance budget enforcement to ensure reliable and fast test execution.

## Test Parallelization

### Configuration Overview

Tests are configured to run in parallel where safe, significantly reducing overall test execution time.

#### Available Test Plans

1. **CodeEditorKit.xctestplan** - Basic configuration with timeouts
2. **CodeEditorKit-Parallel.xctestplan** - Full parallel execution
3. **CodeEditorKit-SmartParallel.xctestplan** - Intelligent grouping for optimal performance

### Smart Parallelization

Tests are intelligently grouped based on their characteristics:

**Parallel Group** (Safe to run concurrently):

**Sequential Group** (Must run in order):

### Running Parallel Tests

```bash
# Using the provided script
./Scripts/run-parallel-tests.sh

# Using swift test directly
swift test --parallel --num-workers auto

# Using xcodebuild with test plan
xcodebuild test \
  -scheme CodeEditorKit \
  -testPlan CodeEditorKit-SmartParallel \
  -parallel-testing-enabled YES \
  -maximum-concurrent-test-device-destinations 4
```

## Test Timeouts

### Configuration

All test plans include timeout configuration to prevent hanging tests:

```json
{
  "defaultOptions": {
    "testTimeoutsEnabled": true,
    "maximumTestExecutionTimeAllowance": 60
  }
}
```

### Timeout Helper Methods

The `XCTestCase+Timeout` extension provides utilities for managing test timeouts:

```swift
// Run async test with timeout
func testAsyncOperation() async throws {
    try await runAsyncTest(timeout: 10.0) {
        let result = await performAsyncOperation()
        XCTAssertNotNil(result)
    }
}

// Assert operation completes within timeout
func testTimelySCompletion() async {
    await assertCompletesWithin(5.0) {
        try await someAsyncOperation()
    }
}

// Create timeout expectation
func testWithExpectation() {
    let expectation = timeoutExpectation(timeout: 30.0)
    
    performAsyncWork { result in
        XCTAssertNotNil(result)
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 31.0)
}
```

### Timeout Categories

| Category | Default Timeout | Use Case |
|----------|----------------|----------|
| Default | 10 seconds | Regular unit tests |
| Performance | 30 seconds | Performance tests |
| Integration | 60 seconds | Integration tests |
| Stress | 120 seconds | Stress tests |

### CI Environment Adjustments

Timeouts are automatically adjusted for CI environments:

```swift
// Automatic 2x multiplier in CI
let timeout = TestTimeoutConfiguration.adjustedTimeout(10.0)
// Returns 20.0 in CI, 10.0 locally

// Check if running in CI
if TestTimeoutConfiguration.isCI {
    // Use longer timeouts
}
```

## Performance Budgets

Performance regression tests enforce strict timing budgets:

### Performance Budget Enforcement

```swift
class PerformanceRegressionTests: XCTestCase {
    func testSyntaxHighlightingPerformance() {
        measureAgainstBudget("syntax_highlighting") {
            let highlighter = SyntaxHighlighter()
            highlighter.highlight(largeDocument)
        }
    }
    
    func testAsyncCompletionPerformance() async throws {
        try await measureAsyncAgainstBudget("completion_request") {
            let results = try await completionManager.requestCompletions(
                for: context
            )
            XCTAssertFalse(results.isEmpty)
        }
    }
}
```

### Budget Violations

| Test | Budget | Previous Time |
|------|--------|---------------|
| completionCancellation | 100ms | 131s → 50ms ✅ |
| layoutOperationRecording | 10ms | 46s → 8ms ✅ |
| memoryPressureRecovery | 500ms | 24s → 400ms ✅ |
| contextMenuCreation | 500ms | 74-90s → 300ms ✅ |

## Memory Leak Detection

### Tracking Memory Leaks

```swift
func testNoMemoryLeaks() {
    // Create object to track
    let editor = CodeEditorView()
    let coordinator = SyntaxHighlightingCoordinator()
    
    // Track for leaks
    trackForMemoryLeaks(editor)
    trackForMemoryLeaks(coordinator)
    
    // Use objects
    editor.text = "Hello, world!"
    _ = coordinator
    
    // Objects should be deallocated after test
}
```

### Memory Assertions

```swift
func testMemoryUsage() {
    let initialMemory = getCurrentMemoryUsage()
    
    // Perform memory-intensive operation
    processLargeFile()
    
    let peakMemory = getPeakMemoryUsage()
    let finalMemory = getCurrentMemoryUsage()
    
    // Assert memory was properly released
    XCTAssertLessThan(finalMemory - initialMemory, 10_000_000) // 10MB
    XCTAssertLessThan(peakMemory, 500_000_000) // 500MB peak
}
```

## Xcodegen Configuration

For projects using xcodegen, add these settings to `project.yml`:

```yaml
targets:
  YourTestTarget:
    settings:
      # Enable parallel testing
      PARALLEL_TESTING_ENABLED: YES
      PARALLEL_TESTING_WORKER_COUNT: 4
      
      # Enable test timeouts
      TEST_TIMEOUTS_ENABLED: YES
      MAXIMUM_TEST_EXECUTION_TIME_ALLOWANCE: 60
```

## Best Practices

### Writing Parallelizable Tests

1. **Avoid Shared State**

```swift
// ❌ Bad - Uses singleton
func testWithSingleton() {
    let cache = ParagraphStyleCache.shared
    cache.clear() // Affects other tests!
}

// ✅ Good - Uses dependency injection
func testWithDI() {
    let cache = ParagraphStyleCache()
    cache.clear() // Isolated instance
}
```

2. **Clean Up Resources**

```swift
override func tearDown() async throws {
    // Clean up any resources
    await manager.shutdown()
    temporaryFiles.forEach { try? FileManager.default.removeItem(at: $0) }
    try await super.tearDown()
}
```

3. **Use Unique Identifiers**

```swift
// ❌ Bad - Fixed port
let server = LSPServer(port: 8080)

// ✅ Good - Random port
let server = LSPServer(port: .random(in: 8000...9000))

// ✅ Good - Unique file names
let testFile = tempDirectory.appendingPathComponent("test-\(UUID()).txt")
```

### Measuring Performance

1. **Use Consistent Baselines**

```swift
func testPerformance() {
    let options = XCTMeasureOptions()
    options.iterationCount = 10
    
    measureWithTimeout(timeout: 30.0, options: options) {
        // Performance critical code
        highlighter.processLargeFile()
    }
}
```

2. **Run Performance Tests Sequentially**

### Debugging Timeout Issues

1. **Check Test Logs**

```bash
# Enable verbose logging
swift test --verbose 2>&1 | tee test-log.txt

# Find timeout errors
grep -i "timeout" test-log.txt
```

2. **Identify Slow Tests**

```bash
# Find tests taking >1s
grep -E "Test Case .* passed \\([1-9][0-9]*\\." test-log.txt
```

3. **Profile Individual Tests**

```bash
# Run specific test with profiling
swift test --filter testSlowOperation \
  --enable-code-coverage \
  --sanitize=thread
```

## Monitoring

### CI Integration

Add these checks to your CI pipeline:

```yaml
# GitHub Actions example
- name: Run Tests with Timeout
  run: |
    swift test --parallel \
      --num-workers 4 \
      --xunit-output test-results.xml
  timeout-minutes: 10

- name: Check Test Performance
  run: |
    swift test --filter PerformanceRegressionTests

- name: Upload Test Results
  uses: actions/upload-artifact@v3
  with:
    name: test-results
    path: test-results.xml
```

### Performance Tracking

Track test execution times over time:

```bash
# Generate performance report
GENERATE_REPORT=1 ./Scripts/run-parallel-tests.sh

# Parse results for tracking
cat test-report.json | jq '.testExecutionTime'
```

## Troubleshooting

### Tests Hanging

**Problem**: Tests exceed timeout and hang indefinitely

**Solutions**:
1. Enable test timeouts in test plan
2. Use timeout helper methods
3. Check for deadlocks with Thread Sanitizer

```bash
# Run with Thread Sanitizer
swift test --sanitize=thread
```

### Flaky Tests in Parallel

**Problem**: Tests pass individually but fail when run in parallel

**Solutions**:
1. Check for shared state
2. Add proper synchronization
3. Use serial execution for affected tests

```swift
// Mark test as serial
override class var runsForEachTargetApplicationUIConfiguration: Bool {
    false // Prevents parallel execution
}
```

### Performance Regression

**Problem**: Tests fail performance budgets

**Solutions**:
1. Run performance tests locally
2. Compare with baseline
3. Profile with Instruments
4. Check for O(n²) algorithms

```bash
# Profile with Instruments
xcrun xctrace record --template "Time Profiler" --launch -- \
  swift test --filter testPerformance
```

## Advanced Configuration

### Custom Test Observers

```swift
class PerformanceTestObserver: NSObject, XCTestObservation {
    func testBundleWillStart(_ testBundle: Bundle) {
        CrossPlatformLogger.logger().info("Starting test bundle: \(testBundle)")
    }
    
    func testCase(_ testCase: XCTestCase, 
                  didRecord issue: XCTIssue) {
        if issue.type == .performanceRegression {
            // Log performance regression
        }
    }
}

// Register observer
XCTestObservationCenter.shared.addTestObserver(
    PerformanceTestObserver()
)
```

### Dynamic Timeout Adjustment

```swift
extension XCTestCase {
    var dynamicTimeout: TimeInterval {
        switch Self.className {
        case "PerformanceTests":
            return 60.0
        case "IntegrationTests":
            return 120.0
        default:
            return 10.0
        }
    }
}
```

## See Also

- [Performance-Optimizations](optimizations.md)
- [Performance-Monitoring](monitoring.md)
- `PerformanceBudget`
