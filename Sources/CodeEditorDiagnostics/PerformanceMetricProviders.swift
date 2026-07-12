import Foundation

/// Supplies the size of the document currently represented by a host.
public protocol DocumentMetricsProviding: Sendable {
    /// Current document size in bytes, or `nil` when unavailable.
    @MainActor var fileSizeBytes: Int? { get }
}

/// Supplies measurements captured from real text-layout work.
public protocol TextLayoutMetricsProviding: Sendable {
    /// Average observed layout duration in seconds, or `nil` when unavailable.
    @MainActor var averageLayoutTime: TimeInterval? { get }

    /// Observed cache hit rate in `[0, 1]`, or `nil` when no cache reports it.
    @MainActor var cacheHitRate: Double? { get }
}

/// Provider used when a host has not connected document metrics.
public struct UnavailableDocumentMetricsProvider: DocumentMetricsProviding {
    /// Creates an unavailable provider.
    public init() {}

    public var fileSizeBytes: Int? { nil }
}

/// Provider used when a host has not connected text-layout metrics.
public struct UnavailableTextLayoutMetricsProvider: TextLayoutMetricsProviding {
    /// Creates an unavailable provider.
    public init() {}

    public var averageLayoutTime: TimeInterval? { nil }
    public var cacheHitRate: Double? { nil }
}
