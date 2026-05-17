import CodeEditorCommon
import Foundation

// MARK: - Layout Cache

/// Manages caching of layout calculations for performance optimization
@MainActor
public final class LayoutCache {
    // MARK: - Properties

    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "LayoutCache")

    /// The cached layout frames
    private var cache: [String: EditorLayoutService.ComponentFrames] = [:]
    private var accessOrder: [String] = []

    /// Maximum number of entries to keep in cache
    private let maxCacheSize: Int

    // MARK: - Initialization

    /// Creates a new layout cache
    /// - Parameter maxSize: Maximum number of entries to cache (default: 10)
    public init(maxSize: Int = 10) {
        self.maxCacheSize = maxSize
    }

    // MARK: - Public API

    /// Retrieves cached frames for the given key
    /// - Parameter key: The cache key
    /// - Returns: Cached frames if available, nil otherwise
    public func get(_ key: String) -> EditorLayoutService.ComponentFrames? {
        guard let frames = cache[key] else { return nil }
        markAccessed(key)
        return frames
    }

    /// Stores frames in the cache
    /// - Parameters:
    ///   - frames: The frames to cache
    ///   - key: The cache key
    public func store(_ frames: EditorLayoutService.ComponentFrames, forKey key: String) {
        cache[key] = frames
        markAccessed(key)
        while cache.count > maxCacheSize, let oldestKey = accessOrder.first {
            accessOrder.removeFirst()
            cache.removeValue(forKey: oldestKey)
        }
    }

    /// Clears the entire cache
    public func clear() {
        cache.removeAll()
        accessOrder.removeAll()
        logger.debug("Layout cache cleared")
    }

    /// Invalidates cache entries matching a configuration
    /// - Parameter configuration: The configuration to invalidate
    public func invalidate(for configuration: EditorConfiguration) {
        let configHash = String(configuration.hashValue)
        let keysToRemove = cache.keys.filter { $0.contains(configHash) }
        keysToRemove.forEach { cache.removeValue(forKey: $0) }
        accessOrder.removeAll { keysToRemove.contains($0) }
        logger.debug("Layout cache invalidated for configuration")
    }

    /// Returns the current number of cached entries
    public var count: Int {
        cache.count
    }

    private func markAccessed(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    // MARK: - Key Generation

    /// Generates a cache key from layout parameters
    /// - Parameters:
    ///   - bounds: The container bounds
    ///   - configuration: The editor configuration
    ///   - constraints: The layout constraints
    ///   - lineCount: The line count
    /// - Returns: A unique cache key
    public static func generateKey(
        bounds: CGRect,
        configuration: EditorConfiguration,
        constraints: EditorLayoutService.LayoutConstraints,
        lineCount: Int
    ) -> String {
        let boundsKey = "\(Int(bounds.width))x\(Int(bounds.height))"
        let configHash = String(configuration.hashValue)
        let constraintsKey = "\(Int(constraints.minimumGutterWidth))_\(Int(constraints.maximumGutterWidth))"

        return "\(boundsKey)_\(configHash)_\(constraintsKey)_\(lineCount)"
    }
}
