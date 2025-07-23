# Performance Budget System

This diagram shows the comprehensive performance budget system that monitors and enforces performance targets across all operations in CodeEditorPlugin.

```mermaid
classDiagram
    direction LR
    
    %% Core Budget System
    class PerformanceBudget {
        <<budget configuration>>
        +budgets [String: Budget]
        +budget(for: String) Budget?
        +checkBudgets() [BudgetViolation]
    }

    class Budget {
        <<budget definition>>
        +operation String
        +targetTime TimeInterval
        +warningTime TimeInterval
        +criticalTime TimeInterval
        +init(operation, targetTime, warningTime?, criticalTime?)
        +check(duration) BudgetStatus
    }

    class BudgetStatus {
        <<enumeration>>
        withinBudget "✅ Within Budget"
        warning "⚠️ Warning"
        critical "❌ Critical"
        exceeded "🚨 Exceeded"
        +isAcceptable Bool
    }

    %% Reporting System
    class PerformanceBudgetReporter {
        <<actor, budget reporter>>
        -measurements [String: [TimeInterval]]
        -logger CrossPlatformLogger
        +init()
        +record(operation: String, duration: TimeInterval)
        +averageMeasurements() [String: TimeInterval]
        +generateReport() PerformanceBudgetReport
        +reset()
    }

    class PerformanceBudgetReport {
        <<report>>
        +measurements [String: [TimeInterval]]
        +averages [String: TimeInterval]
        +violations [BudgetViolation]
        +summary String
    }

    class BudgetViolation {
        <<violation>>
        +operation String
        +budget Budget
        +actualTime TimeInterval
        +status BudgetStatus
        +percentageOverBudget Double
        +description String
    }

    %% Test Integration
    class XCTestCaseBudget {
        <<test extension>>
        +budgetReporter PerformanceBudgetReporter
        +measureAgainstBudget()
        +measureAsyncAgainstBudget()
        +assertFileSizePerformance()
        +generatePerformanceReport()
    }

    class PerformanceBudgetTestObserver {
        <<test observer>>
        +testBundleDidFinish()
    }

    %% Pre-defined Budgets
    class PredefinedBudgets {
        <<budget catalog>>
        +syntaxHighlighting Budget
        +textLayout Budget
        +scrolling Budget
        +completionRequest Budget
        +completionCancellation Budget
        +fileOpenSmall Budget
        +fileOpenMedium Budget
        +fileOpenLarge Budget
        +findInFile Budget
        +fuzzySearch Budget
        +memoryPressureRecovery Budget
        +contextMenuCreation Budget
        +lineNumberUpdate Budget
        +testSetup Budget
        +testTeardown Budget
    }

    %% Budget Enforcement
    class BudgetEnforcement {
        <<enforcement>>
        +enforcementLevel EnforcementLevel
        +onViolation (BudgetViolation) -> Void
        +shouldFailTest Bool
        +shouldLogWarning Bool
        +shouldThrottle Bool
    }

    class EnforcementLevel {
        <<enumeration>>
        none
        logging
        warning
        strict
    }

    %% Integration Points
    class PerformanceMonitor {
        <<existing system>>
        +budgetReporter PerformanceBudgetReporter
        +recordMetric()
        +checkBudgets()
    }

    class UnifiedPerformanceSystem {
        <<existing system>>
        +performanceBudget PerformanceBudget
        +budgetReporter PerformanceBudgetReporter
        +enforcePerformanceBudgets()
    }

    %% Relationships
    PerformanceBudget --> Budget : contains
    Budget --> BudgetStatus : evaluates to
    
    PerformanceBudgetReporter --> PerformanceBudget : uses
    PerformanceBudgetReporter --> PerformanceBudgetReport : generates
    PerformanceBudgetReporter --> BudgetViolation : reports
    
    PerformanceBudgetReport --> BudgetViolation : contains
    BudgetViolation --> Budget : references
    BudgetViolation --> BudgetStatus : has
    
    XCTestCaseBudget --> PerformanceBudgetReporter : uses
    XCTestCaseBudget --> PerformanceBudget : checks against
    
    PerformanceBudgetTestObserver --> XCTestCaseBudget : triggers report
    
    PredefinedBudgets --> Budget : creates
    PerformanceBudget --> PredefinedBudgets : uses
    
    BudgetEnforcement --> EnforcementLevel : has
    BudgetEnforcement --> BudgetViolation : handles
    
    PerformanceMonitor --> PerformanceBudgetReporter : records to
    UnifiedPerformanceSystem --> PerformanceBudget : enforces
    UnifiedPerformanceSystem --> BudgetEnforcement : uses

    %% Styling - Dark mode friendly colors
    classDef budget fill:#34C75920,stroke:#34C759,stroke-width:2px,color:#1D1D1F
    classDef reporter fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef test fill:#AF52DE20,stroke:#AF52DE,stroke-width:2px,color:#1D1D1F
    classDef enforcement fill:#FF3B3020,stroke:#FF3B30,stroke-width:2px,color:#1D1D1F
    classDef integration fill:#FF950020,stroke:#FF9500,stroke-width:2px,color:#1D1D1F
    classDef enum fill:#8E8E9320,stroke:#8E8E93,stroke-width:2px,color:#1D1D1F
    
    class PerformanceBudget budget
    class Budget budget
    class PredefinedBudgets budget
    class PerformanceBudgetReporter reporter
    class PerformanceBudgetReport reporter
    class BudgetViolation reporter
    class XCTestCaseBudget test
    class PerformanceBudgetTestObserver test
    class BudgetEnforcement enforcement
    class PerformanceMonitor integration
    class UnifiedPerformanceSystem integration
    class BudgetStatus enum
    class EnforcementLevel enum
```

## Budget Flow Diagram

```mermaid
flowchart TD
    START[Operation Starts] --> MEASURE[Measure Duration]
    MEASURE --> RECORD[Record to Reporter]
    
    RECORD --> CHECK{Check Budget}
    CHECK -->|Found| EVALUATE[Evaluate Against Budget]
    CHECK -->|Not Found| LOG[Log Measurement Only]
    
    EVALUATE --> STATUS{Budget Status?}
    STATUS -->|Within Budget| SUCCESS[✅ Log Success]
    STATUS -->|Warning| WARN[⚠️ Log Warning]
    STATUS -->|Critical/Exceeded| FAIL[❌ Handle Violation]
    
    WARN --> REPORT[Add to Report]
    FAIL --> ENFORCE{Enforcement Level?}
    
    ENFORCE -->|None| REPORT
    ENFORCE -->|Logging| LOG_VIOLATION[Log Violation]
    ENFORCE -->|Warning| ALERT[Alert + Continue]
    ENFORCE -->|Strict| THROW[Fail Test/Throttle]
    
    LOG_VIOLATION --> REPORT
    ALERT --> REPORT
    THROW --> REPORT
    
    SUCCESS --> METRICS[Update Metrics]
    LOG --> METRICS
    REPORT --> METRICS
    
    METRICS --> END[Operation Complete]

    %% Styling
    classDef start fill:#34C75920,stroke:#34C759,stroke-width:2px,color:#1D1D1F
    classDef process fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef decision fill:#FF950020,stroke:#FF9500,stroke-width:2px,color:#1D1D1F
    classDef success fill:#34C75920,stroke:#34C759,stroke-width:2px,color:#1D1D1F
    classDef warning fill:#FF950020,stroke:#FF9500,stroke-width:2px,color:#1D1D1F
    classDef error fill:#FF3B3020,stroke:#FF3B30,stroke-width:2px,color:#1D1D1F
    
    class START start
    class END start
    class MEASURE process
    class RECORD process
    class EVALUATE process
    class REPORT process
    class METRICS process
    class CHECK decision
    class STATUS decision
    class ENFORCE decision
    class SUCCESS success
    class LOG success
    class WARN warning
    class ALERT warning
    class LOG_VIOLATION warning
    class FAIL error
    class THROW error
```

## Pre-defined Performance Budgets

| Operation | Target Time | Warning Time | Critical Time |
|-----------|------------|--------------|---------------|
| **Rendering** |
| syntax_highlighting | 16ms (60fps) | 33ms (30fps) | 100ms |
| text_layout | 16ms | 50ms | 100ms |
| scrolling | 8ms (120fps) | 16ms (60fps) | 33ms |
| line_number_update | 16ms | 33ms | 100ms |
| **Completion** |
| completion_request | 50ms | 100ms | 200ms |
| completion_cancellation | 10ms | 50ms | 100ms |
| **File Operations** |
| file_open_small (<10KB) | 100ms | 200ms | 500ms |
| file_open_medium (10KB-1MB) | 500ms | 1s | 2s |
| file_open_large (>1MB) | 2s | 5s | 10s |
| **Search** |
| find_in_file | 50ms | 100ms | 200ms |
| fuzzy_search (10k items) | 100ms | 200ms | 500ms |
| **Memory** |
| memory_pressure_recovery | 500ms | 1s | 2s |
| **UI** |
| context_menu_creation | 50ms | 100ms | 500ms |
| **Test Operations** |
| test_setup | 100ms | 500ms | 1s |
| test_teardown | 100ms | 500ms | 1s |

## Usage Examples

### Basic Performance Tracking
```swift
// In production code
let reporter = PerformanceBudgetReporter()

// Record an operation
let startTime = CFAbsoluteTimeGetCurrent()
performSyntaxHighlighting()
let duration = CFAbsoluteTimeGetCurrent() - startTime

await reporter.record(operation: "syntax_highlighting", duration: duration)
```

### Test Integration
```swift
// In test code
class MyPerformanceTests: XCTestCase {
    func testSyntaxHighlightingPerformance() {
        measureAgainstBudget("syntax_highlighting") {
            // Perform syntax highlighting
            highlighter.highlight(text: largeDocument)
        }
    }
    
    func testAsyncCompletionPerformance() async throws {
        try await measureAsyncAgainstBudget("completion_request") {
            let results = try await completionManager.requestCompletions(for: context)
            XCTAssertFalse(results.isEmpty)
        }
    }
}
```

### Enforcement Configuration
```swift
let enforcement = BudgetEnforcement(
    enforcementLevel: .warning,
    onViolation: { violation in
        logger.warning("Performance budget violation: \(violation.description)")
    },
    shouldFailTest: false,
    shouldLogWarning: true,
    shouldThrottle: false
)
```

### Report Generation
```swift
let report = await reporter.generateReport()
print(report.summary)

// Output:
// Performance Budget Report
// ==================================================
// Total Operations: 15
// Total Violations: 2
//
// Violations:
//   ❌ Critical syntax_highlighting: 0.125s (150.0% over budget of 0.050s)
//   ⚠️ Warning completion_request: 0.085s (70.0% over budget of 0.050s)
//
// All Measurements (Average):
//   completion_request: 0.085s ⚠️ Warning
//   syntax_highlighting: 0.125s ❌ Critical
//   text_layout: 0.012s ✅ Within Budget
```

## Benefits

1. **Proactive Performance Management**: Catch regressions before they reach production
2. **Automated Enforcement**: Fail tests when budgets are exceeded
3. **Comprehensive Reporting**: Detailed insights into performance trends
4. **Flexible Configuration**: Adjust budgets and enforcement per environment
5. **Test Integration**: Seamless integration with XCTest framework
6. **Platform-Aware**: Adjust budgets for simulator vs device testing

## Integration Points

- **UnifiedPerformanceSystem**: Central performance monitoring
- **PerformanceMonitor**: Real-time metric collection
- **XCTest Framework**: Automated test enforcement
- **CI/CD Pipeline**: Performance regression detection
- **Development Tools**: Local performance validation