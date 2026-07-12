import CodeEditorConfiguration
import CodeEditorDiagnostics
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorView
import XCTest

final class TextKit2OptimizationTests: IsolatedTestCase {
    deinit {}

    @MainActor
    private func withMonitor<T>(_ body: (TextKit2PerformanceMonitor) async throws -> T) async throws -> T {
        let monitor = TextKit2PerformanceMonitor()
        return try await body(monitor)
    }

    // MARK: - TextKit2PerformanceHelper Tests

    func testFileSizeCategories() {
        XCTAssertEqual(TextKit2PerformanceHelper.FileSize(characterCount: 5_000), .small)
        XCTAssertEqual(TextKit2PerformanceHelper.FileSize(characterCount: 50_000), .medium)
        XCTAssertEqual(TextKit2PerformanceHelper.FileSize(characterCount: 500_000), .large)
        XCTAssertEqual(TextKit2PerformanceHelper.FileSize(characterCount: 2_000_000), .veryLarge)
    }

    func testPerformanceConfigurationForFileSize() {
        let smallConfig = TextKit2PerformanceHelper.PerformanceConfiguration.optimal(for: .small)
        XCTAssertFalse(smallConfig.enableViewportOptimization)
        XCTAssertFalse(smallConfig.enableFragmentRecycling)
        XCTAssertFalse(smallConfig.enableAsyncLayout)
        XCTAssertEqual(smallConfig.maxCachedFragments, 100)

        let mediumConfig = TextKit2PerformanceHelper.PerformanceConfiguration.optimal(for: .medium)
        XCTAssertTrue(mediumConfig.enableViewportOptimization)
        XCTAssertFalse(mediumConfig.enableFragmentRecycling)
        XCTAssertTrue(mediumConfig.enableAsyncLayout)
        XCTAssertEqual(mediumConfig.maxCachedFragments, 300)

        let largeConfig = TextKit2PerformanceHelper.PerformanceConfiguration.optimal(for: .large)
        XCTAssertTrue(largeConfig.enableViewportOptimization)
        XCTAssertTrue(largeConfig.enableFragmentRecycling)
        XCTAssertTrue(largeConfig.enableAsyncLayout)
        XCTAssertEqual(largeConfig.maxCachedFragments, 500)

        let veryLargeConfig = TextKit2PerformanceHelper.PerformanceConfiguration.optimal(for: .veryLarge)
        XCTAssertTrue(veryLargeConfig.enableViewportOptimization)
        XCTAssertTrue(veryLargeConfig.enableFragmentRecycling)
        XCTAssertTrue(veryLargeConfig.enableAsyncLayout)
        XCTAssertEqual(veryLargeConfig.maxCachedFragments, 1_000)
    }

    // MARK: - TextKit2PerformanceMonitor Tests

    @MainActor
    func testPerformanceMonitorInitialization() async throws {
        try await withMonitor { performanceMonitor in
            XCTAssertEqual(performanceMonitor.layoutOperations, 0)
            XCTAssertEqual(performanceMonitor.averageLayoutTime, 0)
            XCTAssertEqual(performanceMonitor.peakLayoutTime, 0)
            XCTAssertEqual(performanceMonitor.totalRenderingTime, 0)
            XCTAssertEqual(performanceMonitor.fragmentsGenerated, 0)
            XCTAssertEqual(performanceMonitor.fragmentsRecycled, 0)
            XCTAssertEqual(performanceMonitor.cacheHitRate, 0)
            XCTAssertEqual(performanceMonitor.memoryUsage, 0)
        }
    }

    @MainActor
    func testLayoutOperationRecording() async throws {
        // Use isolated test runner with timing measurements
        try await runIsolatedTest(timeout: 5) {
            try await TestIsolationHelper.measureTime(
                operation: "testLayoutOperationRecording",
                warningThreshold: 0.5
            ) {
                try await self.withMonitor { performanceMonitor in
                    performanceMonitor.recordLayoutOperation(duration: 0.1)

                    XCTAssertEqual(performanceMonitor.layoutOperations, 1)
                    XCTAssertEqual(performanceMonitor.averageLayoutTime, 0.1)
                    XCTAssertEqual(performanceMonitor.peakLayoutTime, 0.1)
                    XCTAssertEqual(performanceMonitor.totalRenderingTime, 0.1)

                    performanceMonitor.recordLayoutOperation(duration: 0.2)

                    XCTAssertEqual(performanceMonitor.layoutOperations, 2)
                    XCTAssertEqual(performanceMonitor.averageLayoutTime, 0.15, accuracy: 0.001) // (0.1 + 0.2) / 2
                    XCTAssertEqual(performanceMonitor.peakLayoutTime, 0.2)
                    XCTAssertEqual(performanceMonitor.totalRenderingTime, 0.3, accuracy: 0.001)
                }
            }
        }
    }

    @MainActor
    func testFragmentRecording() async throws {
        try await withMonitor { performanceMonitor in
            performanceMonitor.recordFragmentGenerated()
            performanceMonitor.recordFragmentGenerated()
            performanceMonitor.recordFragmentRecycled()

            XCTAssertEqual(performanceMonitor.fragmentsGenerated, 2)
            XCTAssertEqual(performanceMonitor.fragmentsRecycled, 1)
        }
    }

    @MainActor
    func testCacheHitRateCalculation() async throws {
        try await withMonitor { performanceMonitor in
            // Initially no hits or misses
            XCTAssertEqual(performanceMonitor.cacheHitRate, 0)

            // Record some hits and misses
            performanceMonitor.recordCacheHit()
            performanceMonitor.recordCacheHit()
            performanceMonitor.recordCacheMiss()

            // Hit rate should be 2/3 = 0.666...
            XCTAssertEqual(performanceMonitor.cacheHitRate, 2.0 / 3.0, accuracy: 0.001)

            performanceMonitor.recordCacheMiss()

            // Hit rate should be 2/4 = 0.5
            XCTAssertEqual(performanceMonitor.cacheHitRate, 0.5)
        }
    }

    @MainActor
    func testMemoryUsageTracking() async throws {
        try await withMonitor { performanceMonitor in
            performanceMonitor.updateMemoryUsage(15.5)

            XCTAssertEqual(performanceMonitor.memoryUsage, 15.5)

            performanceMonitor.updateMemoryUsage(20.0)

            XCTAssertEqual(performanceMonitor.memoryUsage, 20.0)
        }
    }

    @MainActor
    func testPerformanceMonitorReset() async throws {
        try await withMonitor { performanceMonitor in
            // Set up some state
            performanceMonitor.recordLayoutOperation(duration: 0.1)
            performanceMonitor.recordFragmentGenerated()
            performanceMonitor.recordCacheHit()
            performanceMonitor.updateMemoryUsage(10.0)

            // Reset should clear all metrics
            performanceMonitor.reset()

            XCTAssertEqual(performanceMonitor.layoutOperations, 0)
            XCTAssertEqual(performanceMonitor.averageLayoutTime, 0)
            XCTAssertEqual(performanceMonitor.peakLayoutTime, 0)
            XCTAssertEqual(performanceMonitor.totalRenderingTime, 0)
            XCTAssertEqual(performanceMonitor.fragmentsGenerated, 0)
            XCTAssertEqual(performanceMonitor.fragmentsRecycled, 0)
            XCTAssertEqual(performanceMonitor.cacheHitRate, 0)
            XCTAssertEqual(performanceMonitor.memoryUsage, 0)
        }
    }

    @MainActor
    func testPerformanceSummary() async throws {
        try await withMonitor { performanceMonitor in
            // Set up some performance data
            performanceMonitor.recordLayoutOperation(duration: 0.1)
            performanceMonitor.recordLayoutOperation(duration: 0.2)
            performanceMonitor.recordFragmentGenerated()
            performanceMonitor.recordFragmentRecycled()
            performanceMonitor.recordCacheHit()
            performanceMonitor.recordCacheMiss()
            performanceMonitor.updateMemoryUsage(12.5)

            let summary = performanceMonitor.performanceSummary

            XCTAssertTrue(summary.contains("Layout Operations: 2"))
            XCTAssertTrue(summary.contains("Fragments Generated: 1"))
            XCTAssertTrue(summary.contains("Fragments Recycled: 1"))
            XCTAssertTrue(summary.contains("Cache Hit Rate: 50.0%"))
            XCTAssertTrue(summary.contains("Memory Usage: 12.5MB"))
            XCTAssertTrue(summary.contains("Recycling Rate: 100.0%"))
        }
    }

    // MARK: - Integration Tests

    @MainActor
    func testCodeEditorViewTextKit2Integration() async throws {
        let codeEditorView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        // Test that CodeEditorView can be created and configured
        XCTAssertNotNil(codeEditorView)

        // Test basic configuration
        var config = EditorConfiguration()
        config.performance.useHardwareAcceleration = true
        codeEditorView.configuration = config

        XCTAssertTrue(codeEditorView.configuration.performance.useHardwareAcceleration)
    }

    @MainActor
    func testLargeFileOptimization() async throws {
        let codeEditorView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        // Simulate a large file
        let largeText = String(repeating: "This is a line of code that represents a large file.\n", count: 2_000)
        #if canImport(AppKit)
        codeEditorView.string = largeText
        #elseif canImport(UIKit)
        codeEditorView.text = largeText
        #endif

        // Configure for performance
        var config = EditorConfiguration()
        config.performance.maxSyntaxHighlightingLength = 500_000
        config.performance.useHardwareAcceleration = true
        codeEditorView.configuration = config

        // Verify text was set
        #if canImport(AppKit)
        XCTAssertEqual(codeEditorView.string.count, largeText.count)
        #elseif canImport(UIKit)
        XCTAssertEqual(codeEditorView.text.count, largeText.count)
        #endif
    }

    // MARK: - Performance Tests

    @MainActor
    func testPerformanceMonitorOverhead() async throws {
        let performanceMonitor = TextKit2PerformanceMonitor()
        measure(options: Self.standardMeasureOptions) {
            // Test overhead of recording many operations
            for _ in 0..<1_000 {
                performanceMonitor.recordLayoutOperation(duration: 0.001)
                performanceMonitor.recordFragmentGenerated()
                performanceMonitor.recordCacheHit()
            }
        }
    }
}
