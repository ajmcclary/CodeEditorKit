@testable import CodeEditorPlugin
import XCTest

final class TextKit2OptimizationTests: XCTestCase {
    @MainActor
    private func withOptimizer<T>(_ body: (TextKit2RenderingOptimizer) async throws -> T) async throws -> T {
        let optimizer = TextKit2RenderingOptimizer()
        return try await body(optimizer)
    }
    
    deinit {}
    
    @MainActor
    private func withMonitor<T>(_ body: (TextKit2PerformanceMonitor) async throws -> T) async throws -> T {
        let monitor = TextKit2PerformanceMonitor()
        return try await body(monitor)
    }
    
    // MARK: - TextKit2RenderingOptimizer Tests
    
    @MainActor
    func testRenderingOptimizerInitialization() async throws {
        try await withOptimizer { renderingOptimizer in
            XCTAssertNotNil(renderingOptimizer)
        XCTAssertEqual(renderingOptimizer.maxCachedFragments, 500)
        XCTAssertEqual(renderingOptimizer.largeFileThreshold, 50_000)
        XCTAssertTrue(renderingOptimizer.enableViewportOptimization)
        XCTAssertEqual(renderingOptimizer.prefetchMultiplier, 1.5)
            XCTAssertTrue(renderingOptimizer.enableFragmentRecycling)
        }
    }
    
    @MainActor
    func testRenderingOptimizerConfiguration() async throws {
        try await withOptimizer { renderingOptimizer in
            // Test configuration with different settings
            renderingOptimizer.maxCachedFragments = 1_000
        renderingOptimizer.largeFileThreshold = 100_000
        renderingOptimizer.enableViewportOptimization = false
        renderingOptimizer.prefetchMultiplier = 2.0
        renderingOptimizer.enableFragmentRecycling = false
        
        XCTAssertEqual(renderingOptimizer.maxCachedFragments, 1_000)
        XCTAssertEqual(renderingOptimizer.largeFileThreshold, 100_000)
        XCTAssertFalse(renderingOptimizer.enableViewportOptimization)
        XCTAssertEqual(renderingOptimizer.prefetchMultiplier, 2.0)
            XCTAssertFalse(renderingOptimizer.enableFragmentRecycling)
        }
    }
    
    @MainActor
    func testVisibleRangeUpdates() async throws {
        try await withOptimizer { renderingOptimizer in
            let initialRange = NSRange(location: 0, length: 100)
            renderingOptimizer.updateVisibleRange(initialRange)
            
            // Should not crash and should handle the range update
            XCTAssertNoThrow(renderingOptimizer.updateVisibleRange(initialRange))
            
            // Test with different range
            let newRange = NSRange(location: 50, length: 200)
            XCTAssertNoThrow(renderingOptimizer.updateVisibleRange(newRange))
        }
    }
    
    @MainActor
    func testFragmentCleanup() async throws {
        try await withOptimizer { renderingOptimizer in
            // Enable viewport optimization for this test
            renderingOptimizer.enableViewportOptimization = true
            
            // Update visible range to create some cached state
            renderingOptimizer.updateVisibleRange(NSRange(location: 0, length: 100))
            
            // Cleanup should not crash
            XCTAssertNoThrow(renderingOptimizer.cleanupNonVisibleFragments())
        }
    }
    
    @MainActor
    func testPrefetchLayout() async throws {
        try await withOptimizer { renderingOptimizer in
            // Test prefetch in both directions
            renderingOptimizer.updateVisibleRange(NSRange(location: 1_000, length: 500))
            
            XCTAssertNoThrow(renderingOptimizer.prefetchLayout(direction: .up, distance: 1_000))
            XCTAssertNoThrow(renderingOptimizer.prefetchLayout(direction: .down, distance: 1_000))
        }
    }
    
    @MainActor
    func testReset() async throws {
        try await withOptimizer { renderingOptimizer in
            // Set up some state
            renderingOptimizer.updateVisibleRange(NSRange(location: 100, length: 200))
            renderingOptimizer.cleanupNonVisibleFragments()
            
            // Reset should clear all state
            renderingOptimizer.reset()
            
            // Verify reset worked
            let stats = renderingOptimizer.renderingStats
            XCTAssertEqual(stats.totalOptimizations, 0)
            XCTAssertEqual(stats.fragmentsCached, 0)
            XCTAssertEqual(stats.fragmentsCleaned, 0)
        }
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
        try await withMonitor { performanceMonitor in
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
    
    // MARK: - RenderingStatistics Tests
    
    @MainActor
    func testRenderingStatisticsInitialization() async throws {
        try await withOptimizer { renderingOptimizer in
            let stats = renderingOptimizer.renderingStats
            
            XCTAssertEqual(stats.totalOptimizations, 0)
            XCTAssertEqual(stats.averageOptimizationTime, 0)
            XCTAssertEqual(stats.fragmentsCached, 0)
            XCTAssertEqual(stats.fragmentsCleaned, 0)
            XCTAssertEqual(stats.prefetchOperations, 0)
            XCTAssertEqual(stats.averagePrefetchTime, 0)
            XCTAssertEqual(stats.largeFileOptimizationsEnabled, 0)
            XCTAssertEqual(stats.viewportOptimizationsEnabled, 0)
            XCTAssertEqual(stats.fragmentRecyclingEnabled, 0)
            XCTAssertEqual(stats.containerOptimizations, 0)
            XCTAssertNil(stats.lastOptimizationTime)
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
        
        XCTAssertEqual(codeEditorView.configuration.performance.useHardwareAcceleration, true)
    }
    
    @MainActor
    func testLargeFileOptimization() async throws {
        let codeEditorView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        
        // Simulate a large file
        let largeText = String(repeating: "This is a line of code that represents a large file.\n", count: 2_000)
        codeEditorView.string = largeText
        
        // Configure for performance
        var config = EditorConfiguration()
        config.performance.maxSyntaxHighlightingLength = 500000
        config.performance.useHardwareAcceleration = true
        codeEditorView.configuration = config
        
        // Verify text was set
        XCTAssertEqual(codeEditorView.string.count, largeText.count)
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testRenderingOptimizerPerformance() async throws {
        let renderingOptimizer = TextKit2RenderingOptimizer()
        measure {
            // Test performance of updating visible range multiple times
            for index in 0..<100 {
                let range = NSRange(location: index * 100, length: 500)
                renderingOptimizer.updateVisibleRange(range)
            }
        }
    }
    
    @MainActor
    func testPerformanceMonitorOverhead() async throws {
        let performanceMonitor = TextKit2PerformanceMonitor()
        measure {
            // Test overhead of recording many operations
            for _ in 0..<1_000 {
                performanceMonitor.recordLayoutOperation(duration: 0.001)
                performanceMonitor.recordFragmentGenerated()
                performanceMonitor.recordCacheHit()
            }
        }
    }
}
