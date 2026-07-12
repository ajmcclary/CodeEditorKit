import CodeEditorCommon
import CodeEditorConfiguration
import Foundation

// MARK: - Layout Cache

/// Manages caching of layout calculations for performance optimization
@MainActor
public final class LayoutCache {
    // MARK: - Properties

    private let logger = CodeEditorLog.logger(category: "LayoutCache")

    /// LRU-backed cache of computed component frames. Synchronization is
    /// provided by this type's `@MainActor` isolation; the underlying helper
    /// is intentionally thread-unsafe.
    private let lru: LinkedLRU<String, ComponentFrames>

    // MARK: - Initialization

    /// Creates a new layout cache
    /// - Parameter maxSize: Maximum number of entries to cache (default: 10)
    public init(maxSize: Int = 10) {
        self.lru = LinkedLRU(capacity: maxSize)
    }

    // MARK: - Public API

    /// Retrieves cached frames for the given key
    /// - Parameter key: The cache key
    /// - Returns: Cached frames if available, nil otherwise
    public func get(_ key: String) -> ComponentFrames? {
        lru.value(forKey: key)
    }

    /// Stores frames in the cache
    /// - Parameters:
    ///   - frames: The frames to cache
    ///   - key: The cache key
    public func store(_ frames: ComponentFrames, forKey key: String) {
        lru.setValue(frames, forKey: key)
    }

    /// Clears the entire cache
    public func clear() {
        lru.removeAll()
        logger.debug("Layout cache cleared")
    }

    /// Invalidates cache entries matching a configuration
    /// - Parameter configuration: The configuration to invalidate
    public func invalidate(for configuration: EditorConfiguration) {
        let configHash = String(configuration.hashValue)
        lru.removeAll { $0.contains(configHash) }
        logger.debug("Layout cache invalidated for configuration")
    }

    /// Returns the current number of cached entries
    public var count: Int {
        lru.count
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
        constraints: LayoutConstraints,
        lineCount: Int
    ) -> String {
        let boundsKey = "\(Int(bounds.width))x\(Int(bounds.height))"
        let configHash = String(configuration.hashValue)
        let constraintsKey = "\(Int(constraints.minimumGutterWidth))_\(Int(constraints.maximumGutterWidth))"

        return "\(boundsKey)_\(configHash)_\(constraintsKey)_\(lineCount)"
    }
}
