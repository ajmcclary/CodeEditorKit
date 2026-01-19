import Foundation

// MARK: - Processing Performance Monitor

/// Performance monitor for processing operations
/// Extracted from AsyncTextProcessor for reusability and testability
internal actor ProcessingPerformanceMonitor {
    private var totalProcessed: Int = 0
    private var totalProcessingTime: TimeInterval = 0
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    private var errors: Int = 0
    private var cancellations: Int = 0

    func recordProcessingTime(_ time: TimeInterval, for operation: ProcessingOperation) {
        _ = operation // Silence unused parameter warning (may be used for detailed metrics)
        totalProcessed += 1
        totalProcessingTime += time
    }

    func recordCacheHit() {
        cacheHits += 1
    }

    func recordCacheMiss() {
        cacheMisses += 1
    }

    func recordError() {
        errors += 1
    }

    func recordCancellation() {
        cancellations += 1
    }

    func getCurrentMetrics() -> ProcessingMetrics {
        let averageTime = totalProcessed > 0 ? totalProcessingTime / Double(totalProcessed) : 0
        let cacheTotal = cacheHits + cacheMisses
        let cacheHitRate = cacheTotal > 0 ? Double(cacheHits) / Double(cacheTotal) : 0
        let errorRate = totalProcessed > 0 ? Double(errors) / Double(totalProcessed) : 0

        return ProcessingMetrics(
            totalProcessed: totalProcessed,
            averageProcessingTime: averageTime,
            cacheHitRate: cacheHitRate,
            errorRate: errorRate
        )
    }

    /// Resets all collected metrics
    func reset() {
        totalProcessed = 0
        totalProcessingTime = 0
        cacheHits = 0
        cacheMisses = 0
        errors = 0
        cancellations = 0
    }
}
