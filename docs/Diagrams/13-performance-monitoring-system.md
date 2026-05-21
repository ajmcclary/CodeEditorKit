# Performance Monitoring & Optimization System

This diagram reflects the current implementation split across `Sources/CodeEditorDiagnostics/` and the view-coupled optimization helpers in `Sources/CodeEditorView/`. The system is split into low-level operation timing, user-facing insights, production aggregation, budget reporting, adaptive mode selection, viewport tracking, memory pressure handling, and iOS large-file optimization.

```mermaid
classDiagram
    direction LR

    class UnifiedPerformanceSystem {
        <<@MainActor coordinator>>
        -metrics [PerformanceMetricType: [PerformanceMetric]]
        -activeOperations [UUID: OperationInfo]
        -performanceProfiles [String: PerformanceProfile]
        +track(_:operation:) async throws
        +generateInsights() UnifiedPerformanceInsights
        +applyOptimizations(basedOn:)
        +getCurrentStatus() PerformanceStatus
    }

    class PerformanceMonitor {
        <<actor>>
        -metrics [MonitoringPerformanceMetric]
        +startMeasuring(_:) MeasurementToken
        +endMeasuring(_:)
        +measure(_:block:) async throws
        +generateReport() PerformanceReport
        +clearMetrics() async
    }

    class PerformanceInsights {
        <<@MainActor ObservableObject>>
        +status InsightsPerformanceStatus
        +issues [InsightsPerformanceIssue]
        +recommendations [InsightsPerformanceRecommendation]
        +metrics RealTimeMetrics
        +startMonitoring()
        +stopMonitoring()
        +generateDetailedReport() async DetailedPerformanceReport
        +configureMonitoring(_:)
    }

    class PerformanceInsightsPanel {
        <<SwiftUI View>>
        +insights PerformanceInsights
        +body some View
    }

    class MemoryMonitor {
        <<ObservableObject>>
        +memoryThresholdMB Double
        +enableAutomaticCleanup Bool
        +isUnderMemoryPressure Bool
        +monitoringInterval Duration
        +periodicCleanupInterval Duration
        +startMonitoring()
        +performCleanup(trigger:) async
        +getMemoryStatistics() MemoryStatistics
    }

    class ProductionPerformanceMetrics {
        <<actor>>
        -highlightingMetrics [HighlightingMetric]
        -scrollingMetrics [ScrollingMetric]
        -memoryMetrics [MemoryMetric]
        -foldingMetrics [CodeFoldingMetric]
        +recordHighlightingMetric(_:) async
        +recordScrollingMetric(_:) async
        +recordMemoryMetric(_:) async
        +recordFoldingMetric(_:) async
        +generateReport() async ProductionPerformanceReport
    }

    class PerformanceBudget {
        <<value type>>
        +budgets [PerformanceMetricType: Budget]
        +check(metric:) BudgetStatus
        +violations(for:) [BudgetViolation]
    }

    class PerformanceBudgetReporter {
        <<actor>>
        +recordViolation(_:) async
        +generateReport() async PerformanceBudgetReport
        +clear() async
    }

    class AdaptivePerformanceMode {
        <<ObservableObject>>
        +currentMode PerformanceMode
        +configuration PerformanceModeConfiguration
        +updateMode(for:) async
        +applyConfiguration(_:)
    }

    class ViewportManager {
        <<ObservableObject>>
        +currentViewport Viewport
        +metrics ViewportMetrics
        +updateViewport(_:)
        +visibleRange(in:) NSRange
        +optimizationHints() [OptimizationHint]
    }

    class IOSLargeFileOptimizer {
        <<iOS only ObservableObject>>
        +optimizationThreshold Int
        +maxHighlightingRange Int
        +viewportExpansion CGFloat
        +memoryPressureMode MemoryPressureMode
        +isOptimizing Bool
        +currentMode OptimizationMode
        +enableOptimizations()
        +disableOptimizations()
    }

    class PerformanceHistory {
        <<trend storage>>
        +record(_:)
        +getTrends() [PerformanceTrend]
        +analyzeTrend(for:) PerformanceTrend?
        +clear()
    }

    class PerformanceThresholds {
        <<thresholds>>
        +maxLayoutTime TimeInterval
        +minFrameRate Double
        +maxMemoryUsageGB Double
        +minCacheHitRate Double
    }

    UnifiedPerformanceSystem --> PerformanceMetric : records
    UnifiedPerformanceSystem --> UnifiedPerformanceInsights : returns
    UnifiedPerformanceSystem --> PerformanceProfile : applies
    UnifiedPerformanceSystem --> PerformanceStatus : reports

    PerformanceInsights --> PerformanceMonitor : reads reports from
    PerformanceInsights --> MemoryMonitor : reads memory stats from
    PerformanceInsights --> PerformanceHistory : records trends in
    PerformanceInsights --> PerformanceThresholds : evaluates against
    PerformanceInsightsPanel --> PerformanceInsights : displays

    ProductionPerformanceMetrics --> HighlightingMetric : aggregates
    ProductionPerformanceMetrics --> ScrollingMetric : aggregates
    ProductionPerformanceMetrics --> MemoryMetric : aggregates
    ProductionPerformanceMetrics --> CodeFoldingMetric : aggregates

    PerformanceBudgetReporter --> PerformanceBudget : reports against
    AdaptivePerformanceMode --> PerformanceModeConfiguration : applies
    ViewportManager --> Viewport : tracks
    IOSLargeFileOptimizer --> MemoryMonitor : responds to pressure from
    IOSLargeFileOptimizer --> UnifiedPerformanceSystem : records activity in
```

## Data Flow

```mermaid
flowchart TD
    Operation["Editor operation"] --> Track["PerformanceMonitor.measure or UnifiedPerformanceSystem.track"]
    Track --> Metric["PerformanceMetric / MonitoringPerformanceMetric"]
    Metric --> Insights["PerformanceInsights"]
    Metric --> Production["ProductionPerformanceMetrics"]
    Metric --> Budget["PerformanceBudgetReporter"]

    Memory["MemoryMonitor"] --> Insights
    Memory --> IOS["IOSLargeFileOptimizer"]
    Viewport["ViewportManager"] --> IOS

    Insights --> Panel["PerformanceInsightsPanel"]
    Insights --> Recommendations["InsightsPerformanceRecommendation"]
    Budget --> BudgetReport["PerformanceBudgetReport"]
    Production --> ProductionReport["ProductionPerformanceReport"]
```

## Current Responsibilities

| Component | Responsibility |
|---|---|
| `PerformanceMonitor` | Actor-isolated timing for named operations and report generation. |
| `UnifiedPerformanceSystem` | Main-actor aggregate metrics, issue detection, and profile-based optimization hooks. |
| `PerformanceInsights` | User-facing status, active issue detection, recommendations, and detailed reports. |
| `MemoryMonitor` | Memory pressure tracking, cleanup handlers, and memory statistics. |
| `ProductionPerformanceMetrics` | Production-oriented aggregation for highlighting, scrolling, memory, and folding metrics. |
| `PerformanceBudget` / `PerformanceBudgetReporter` | Budget definitions, violation capture, and reporting. |
| `AdaptivePerformanceMode` | Runtime mode selection for normal, low-power, high-performance, and constrained cases. |
| `ViewportManager` | Visible-range tracking and viewport optimization hints. |
| `IOSLargeFileOptimizer` | UIKit-only large-file behavior, chunk limits, and memory-pressure adaptation. |

## Notes

- `PerformanceInsights` performs its analysis internally with `PerformanceHistory`, `PerformanceThresholds`, and real-time metrics; there is no separate analyzer object in the current source.
- `IOSLargeFileOptimizer` is compiled only when UIKit is available.
- For public usage examples, see [`../Performance/monitoring.md`](../Performance/monitoring.md) and [`../Performance/optimizations.md`](../Performance/optimizations.md).
