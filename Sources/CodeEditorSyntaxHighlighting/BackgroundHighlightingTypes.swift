import CodeEditorLanguages
import Foundation
#if canImport(Combine)
import Combine
#endif

// MARK: - Priority and Request Types

/// Priority levels for highlighting requests
public enum HighlightingPriority: Int, CaseIterable, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    package var taskPriority: _Concurrency.TaskPriority? {
        switch self {
        case .low:
            return .low

        case .normal:
            return nil  // Use default priority

        case .high:
            return .high

        case .critical:
            return .high // Task priority doesn't have a critical level
        }
    }
}

/// Highlighting request data
public struct HighlightingRequest: Sendable {
    package let id: String
    package let text: String
    package let language: Language
    package var priority: HighlightingPriority
    package let visibleRange: NSRange?
    package let completion: BackgroundSyntaxHighlighter.HighlightingCompletion

    package var textRange: NSRange? {
        NSRange(location: 0, length: text.count)
    }
}

/// Cached highlighting result
public struct CachedHighlightResult: Sendable {
    package let tokens: [HighlightedToken]
    package let timestamp: Date
    package let expirationTime: TimeInterval

    package var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > expirationTime
    }
}

// MARK: - Statistics

/// Background highlighting statistics
@MainActor
@available(macOS 10.15, iOS 13.0, *)
public final class BackgroundHighlightingStatistics: ObservableObject {
    @Published public private(set) var totalRequests: Int = 0
    @Published public private(set) var completedRequests: Int = 0
    @Published public private(set) var cancelledRequests: Int = 0
    @Published public private(set) var errorRequests: Int = 0
    @Published public private(set) var cacheHits: Int = 0
    @Published public private(set) var cacheMisses: Int = 0
    @Published public private(set) var averageProcessingTime: TimeInterval = 0
    @Published public private(set) var averageTokensPerRequest: Double = 0
    @Published public private(set) var lastRequestTime: Date?
    @Published public private(set) var lastCompletionTime: Date?

    private var processingTimes: [TimeInterval] = []
    private var tokenCounts: [Int] = []
    private let maxSamples = 100

    public var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(completedRequests) / Double(totalRequests)
    }

    public var cacheHitRate: Double {
        let totalCacheRequests = cacheHits + cacheMisses
        guard totalCacheRequests > 0 else { return 0 }
        return Double(cacheHits) / Double(totalCacheRequests)
    }

    package func recordRequest() {
        totalRequests += 1
        lastRequestTime = Date()
    }

    package func recordCompletion(processingTime: TimeInterval, tokenCount: Int) {
        completedRequests += 1
        lastCompletionTime = Date()

        // Update processing time statistics
        processingTimes.append(processingTime)
        if processingTimes.count > maxSamples {
            processingTimes.removeFirst()
        }
        averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)

        // Update token count statistics
        tokenCounts.append(tokenCount)
        if tokenCounts.count > maxSamples {
            tokenCounts.removeFirst()
        }
        averageTokensPerRequest = Double(tokenCounts.reduce(0, +)) / Double(tokenCounts.count)
    }

    package func recordCancellation() {
        cancelledRequests += 1
    }

    package func recordBulkCancellation(count: Int) {
        cancelledRequests += count
    }

    package func recordError(processingTime: TimeInterval) {
        errorRequests += 1

        // Still record processing time for errors
        processingTimes.append(processingTime)
        if processingTimes.count > maxSamples {
            processingTimes.removeFirst()
        }
        averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
    }

    package func recordCacheHit() {
        cacheHits += 1
    }

    package func recordCacheMiss() {
        cacheMisses += 1
    }

    package func recordCacheClear() {
        // Reset cache-related stats when cache is cleared
        cacheHits = 0
        cacheMisses = 0
    }

    public func reset() {
        totalRequests = 0
        completedRequests = 0
        cancelledRequests = 0
        errorRequests = 0
        cacheHits = 0
        cacheMisses = 0
        averageProcessingTime = 0
        averageTokensPerRequest = 0
        lastRequestTime = nil
        lastCompletionTime = nil
        processingTimes.removeAll()
        tokenCounts.removeAll()
    }

    deinit {
        // Statistics cleanup is handled automatically by ARC
        // Arrays and primitive values don't require explicit cleanup
    }
}

// MARK: - Errors
//
// `HighlightingError` was retired in favor of `SyntaxHighlightingError` in
// `Core/AsyncOperationErrors.swift`, which conforms to `RecoverableAsyncError`
// and carries recovery strategies. Background highlighting paths now throw
// `SyntaxHighlightingError.cancelled`/`.timeout`/`.parsingFailed`/etc.
