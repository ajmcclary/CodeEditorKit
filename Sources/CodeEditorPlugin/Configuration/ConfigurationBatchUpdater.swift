import Foundation

/// Batches configuration updates to minimize change notifications
public final class ConfigurationBatchUpdater: @unchecked Sendable {
    private var pendingUpdates: [(EditorConfiguration) -> EditorConfiguration] = []
    private var updateTimer: Timer?
    private let updateDelay: TimeInterval
    private let onUpdate: (EditorConfiguration) -> Void

    public init(
        updateDelay: TimeInterval = 0.05,
        onUpdate: @escaping (EditorConfiguration) -> Void
    ) {
        self.updateDelay = updateDelay
        self.onUpdate = onUpdate
    }

    deinit {
        updateTimer?.invalidate()
    }

    /// Queues a configuration update to be batched
    public func queueUpdate(_ update: @escaping (EditorConfiguration) -> EditorConfiguration) {
        pendingUpdates.append(update)
        scheduleUpdate()
    }

    /// Applies all pending updates immediately
    public func applyPendingUpdates(to configuration: EditorConfiguration) -> EditorConfiguration {
        guard !pendingUpdates.isEmpty else { return configuration }

        updateTimer?.invalidate()
        updateTimer = nil

        let updates = pendingUpdates
        pendingUpdates.removeAll()

        // Apply all updates in sequence
        let updatedConfig = updates.reduce(configuration) { config, update in
            update(config)
        }

        onUpdate(updatedConfig)
        return updatedConfig
    }

    private func scheduleUpdate() {
        updateTimer?.invalidate()

        updateTimer = Timer.scheduledTimer(
            withTimeInterval: updateDelay,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }

            // Trigger update through the onUpdate callback
            // The actual configuration will be provided by the caller
            self.onUpdate(EditorConfiguration())
        }
    }
}

/// Extension for lazy evaluation of expensive configuration properties
extension EditorConfiguration {
    // Simple in-memory cache without NSCache to avoid NSString requirement
    nonisolated(unsafe) private static var validationCache: [Int: Bool] = [:]
    private static let cacheLock = NSLock()

    /// Validates configuration with caching
    public func validateWithCache() -> Bool {
        let cacheKey = self.hashValue

        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }

        if let cached = Self.validationCache[cacheKey] {
            return cached
        }

        let errors = validate()
        let isValid = errors.isEmpty

        // Limit cache size to prevent unbounded growth
        if Self.validationCache.count > 100 {
            Self.validationCache.removeAll()
        }

        Self.validationCache[cacheKey] = isValid
        return isValid
    }

    /// Clears the validation cache
    public static func clearValidationCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        validationCache.removeAll()
    }
}

/// Lazy property wrapper for expensive computations
@propertyWrapper
public struct LazyComputed<Value> {
    private var storage: Value?
    private let compute: () -> Value

    public init(wrappedValue compute: @autoclosure @escaping () -> Value) {
        self.compute = compute
    }

    public var wrappedValue: Value {
        mutating get {
            if let value = storage {
                return value
            }
            let value = compute()
            storage = value
            return value
        }
        set {
            storage = newValue
        }
    }

    public mutating func reset() {
        storage = nil
    }
}
