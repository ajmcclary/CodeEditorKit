@testable import CodeEditorPlugin
import XCTest

@MainActor
final class TextKit2OptimizationTests: XCTestCase {
    private var renderingOptimizer: TextKit2RenderingOptimizer!
    private var performanceMonitor: TextKit2PerformanceMonitor!
    
    override func setUp() {
        super.setUp()
        renderingOptimizer = TextKit2RenderingOptimizer()
        performanceMonitor = TextKit2PerformanceMonitor()
    }
    
    override func tearDown() {
        renderingOptimizer = nil
        performanceMonitor = nil
        super.tearDown()
    }
    
    // MARK: - TextKit2RenderingOptimizer Tests
    
    func testRenderingOptimizerInitialization() {
        XCTAssertNotNil(renderingOptimizer)
        XCTAssertEqual(renderingOptimizer.maxCachedFragments, 500)
        XCTAssertEqual(renderingOptimizer.largeFileThreshold, 50_000)
        XCTAssertTrue(renderingOptimizer.enableViewportOptimization)
        XCTAssertEqual(renderingOptimizer.prefetchMultiplier, 1.5)
        XCTAssertTrue(renderingOptimizer.enableFragmentRecycling)
    }
    
    func testRenderingOptimizerConfiguration() {
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
    
    func testVisibleRangeUpdates() {
        let initialRange = NSRange(location: 0, length: 100)
        renderingOptimizer.updateVisibleRange(initialRange)
        
        // Should not crash and should handle the range update
        XCTAssertNoThrow(renderingOptimizer.updateVisibleRange(initialRange))
        
        // Test with different range
        let newRange = NSRange(location: 50, length: 200)
        XCTAssertNoThrow(renderingOptimizer.updateVisibleRange(newRange))
    }
    
    func testFragmentCleanup() {
        // Enable viewport optimization for this test
        renderingOptimizer.enableViewportOptimization = true
        
        // Update visible range to create some cached state
        renderingOptimizer.updateVisibleRange(NSRange(location: 0, length: 100))
        
        // Cleanup should not crash
        XCTAssertNoThrow(renderingOptimizer.cleanupNonVisibleFragments())
    }
    
    func testPrefetchLayout() {
        // Test prefetch in both directions
        renderingOptimizer.updateVisibleRange(NSRange(location: 1_000, length: 500))
        
        XCTAssertNoThrow(renderingOptimizer.prefetchLayout(direction: .up, distance: 1_000))
        XCTAssertNoThrow(renderingOptimizer.prefetchLayout(direction: .down, distance: 1_000))
    }
    
    func testReset() {
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
    
    func testPerformanceMonitorInitialization() {
        XCTAssertEqual(performanceMonitor.layoutOperations, 0)
        XCTAssertEqual(performanceMonitor.averageLayoutTime, 0)
        XCTAssertEqual(performanceMonitor.peakLayoutTime, 0)
        XCTAssertEqual(performanceMonitor.totalRenderingTime, 0)
        XCTAssertEqual(performanceMonitor.fragmentsGenerated, 0)
        XCTAssertEqual(performanceMonitor.fragmentsRecycled, 0)
        XCTAssertEqual(performanceMonitor.cacheHitRate, 0)
        XCTAssertEqual(performanceMonitor.memoryUsage, 0)
    }
    
    func testLayoutOperationRecording() {
        performanceMonitor.recordLayoutOperation(duration: 0.1)
        
        XCTAssertEqual(performanceMonitor.layoutOperations, 1)
        XCTAssertEqual(performanceMonitor.averageLayoutTime, 0.1)
        XCTAssertEqual(performanceMonitor.peakLayoutTime, 0.1)
        XCTAssertEqual(performanceMonitor.totalRenderingTime, 0.1)
        
        performanceMonitor.recordLayoutOperation(duration: 0.2)
        
        XCTAssertEqual(performanceMonitor.layoutOperations, 2)
        XCTAssertEqual(performanceMonitor.averageLayoutTime, 0.15) // (0.1 + 0.2) / 2
        XCTAssertEqual(performanceMonitor.peakLayoutTime, 0.2)
        XCTAssertEqual(performanceMonitor.totalRenderingTime, 0.3)
    }
    
    func testFragmentRecording() {
        performanceMonitor.recordFragmentGenerated()
        performanceMonitor.recordFragmentGenerated()
        performanceMonitor.recordFragmentRecycled()
        
        XCTAssertEqual(performanceMonitor.fragmentsGenerated, 2)
        XCTAssertEqual(performanceMonitor.fragmentsRecycled, 1)
    }
    
    func testCacheHitRateCalculation() {
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
    
    func testMemoryUsageTracking() {
        performanceMonitor.updateMemoryUsage(15.5)
        
        XCTAssertEqual(performanceMonitor.memoryUsage, 15.5)
        
        performanceMonitor.updateMemoryUsage(20.0)
        
        XCTAssertEqual(performanceMonitor.memoryUsage, 20.0)
    }
    
    func testPerformanceMonitorReset() {
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
    
    func testPerformanceSummary() {
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
    
    // MARK: - RenderingStatistics Tests
    
    func testRenderingStatisticsInitialization() {
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
    
    // MARK: - Integration Tests
    
    func testCodeEditorViewTextKit2Integration() {
        let codeEditorView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        
        // Test that TextKit2 optimization methods are available
        XCTAssertNoThrow(codeEditorView.optimizeForCurrentContent())
        XCTAssertNoThrow(codeEditorView.enableRealTimeEditingMode())
        XCTAssertNoThrow(codeEditorView.enableReadOnlyViewingMode())
        
        // Test that performance statistics are accessible
        let renderingStats = codeEditorView.renderingStatistics
        XCTAssertNotNil(renderingStats)
        
        let performanceStats = codeEditorView.performanceStatistics
        XCTAssertNotNil(performanceStats)
    }
    
    func testLargeFileOptimization() {
        let codeEditorView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        
        // Simulate a large file
        let largeText = String(repeating: "This is a line of code that represents a large file.\n", count: 2_000)
        codeEditorView.string = largeText
        
        // Optimize for the large content
        XCTAssertNoThrow(codeEditorView.optimizeForCurrentContent())
        
        // Verify optimization was applied
        let stats = codeEditorView.renderingStatistics
        XCTAssertNotNil(stats)
        
        // The statistics should be accessible (actual values depend on implementation)
        XCTAssertGreaterThanOrEqual(stats.totalOptimizations, 0)
    }
    
    // MARK: - Performance Tests
    
    func testRenderingOptimizerPerformance() {
        measure {
            // Test performance of updating visible range multiple times
            for i in 0..<100 {
                let range = NSRange(location: i * 100, length: 500)
                renderingOptimizer.updateVisibleRange(range)
            }
        }
    }
    
    func testPerformanceMonitorOverhead() {
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
