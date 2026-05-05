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
    private actor ValidationCache {
        private var cache: [Int: Bool] = [:]

        func validate(_ configuration: EditorConfiguration) -> Bool {
            let cacheKey = configuration.hashValue
            if let cached = cache[cacheKey] {
                return cached
            }

            let errors = configuration.validate()
            let isValid = errors.isEmpty

            // Limit cache size to prevent unbounded growth.
            if cache.count > 100 {
                cache.removeAll()
            }

            cache[cacheKey] = isValid
            return isValid
        }

        func clear() {
            cache.removeAll()
        }
    }

    private static let validationCache = ValidationCache()

    /// Validates configuration with caching
    public func validateWithCache() async -> Bool {
        await Self.validationCache.validate(self)
    }

    /// Clears the validation cache
    public static func clearValidationCache() async {
        await validationCache.clear()
    }
}

/// Lazy property wrapper for expensive computations
@propertyWrapper
public struct LazyComputed<Value> {
    private var storage: Value?
    private let compute: () -> Value

    /// Creates a new lazy computed property wrapper
    /// - Parameter compute: An autoclosure that computes the value when first accessed
    public init(wrappedValue compute: @autoclosure @escaping () -> Value) {
        self.compute = compute
    }

    /// The computed value, lazily evaluated on first access
    /// 
    /// The getter computes the value on first access and caches it for subsequent calls.
    /// The setter allows direct assignment of a new value, replacing any cached computation.
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

    /// Resets the cached value, forcing recomputation on next access
    /// 
    /// After calling this method, the next access to `wrappedValue` will trigger
    /// the computation closure again rather than returning a cached value.
    public mutating func reset() {
        storage = nil
    }
}
