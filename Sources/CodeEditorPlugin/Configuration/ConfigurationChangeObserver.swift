import Foundation

// MARK: - Configuration Change Observer

/// Protocol for observing configuration changes
public protocol ConfigurationObserver {
    /// Called when a configuration event occurs
    /// - Parameter event: The configuration event that occurred
    func configurationDidChange(_ event: ConfigurationEvent)
}

// MARK: - Configuration Events

/// Events that can occur during configuration management
public enum ConfigurationEvent {
    /// The configuration was successfully changed
    case configurationChanged(old: EditorConfiguration, new: EditorConfiguration, changes: [HotReloadConfigurationChange])

    /// The configuration history was navigated (undo/redo)
    case historyNavigated(configuration: EditorConfiguration, isUndo: Bool)

    /// Configuration validation failed
    case validationFailed(HotReloadValidationError)
}

// MARK: - Observer Token

/// A token representing a configuration observer registration
public struct ObserverToken: Sendable {
    /// The unique identifier for this observer
    let id: UUID

    /// Weak reference to the hot reload instance
    internal let hotReloadRef: WeakReference<ConfigurationHotReload>

    /// Removes the observer associated with this token
    public func remove() {
        Task { @MainActor in
            hotReloadRef.value?.removeObserver(with: id)
        }
    }
}

// MARK: - Weak Reference Helper

/// Helper for weak references in Sendable contexts
internal final class WeakReference<T: AnyObject>: @unchecked Sendable {
    weak var value: T?

    init(_ value: T) {
        self.value = value
    }

    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - Observer Registry

/// Manages a collection of configuration observers
@available(macOS 10.15, iOS 13.0, *)
@MainActor
public final class ConfigurationObserverRegistry {
    // MARK: - Properties

    /// Registered observers keyed by their unique ID
    private var observers: [UUID: ConfigurationObserver] = [:]

    /// Weak reference to the hot reload instance for token creation
    private weak var hotReload: ConfigurationHotReload?

    // MARK: - Initialization

    /// Creates a new observer registry
    /// - Parameter hotReload: The hot reload instance this registry is associated with
    public init(hotReload: ConfigurationHotReload? = nil) {
        self.hotReload = hotReload
    }

    /// Sets the hot reload instance for token creation
    /// - Parameter hotReload: The hot reload instance
    public func setHotReload(_ hotReload: ConfigurationHotReload) {
        self.hotReload = hotReload
    }

    // MARK: - Public API

    /// Adds an observer and returns a token for later removal
    /// - Parameter observer: The observer to add
    /// - Returns: A token that can be used to remove the observer
    @discardableResult
    public func addObserver(_ observer: ConfigurationObserver) -> ObserverToken? {
        guard let hotReload else { return nil }

        let id = UUID()
        observers[id] = observer
        return ObserverToken(id: id, hotReloadRef: WeakReference(hotReload))
    }

    /// Removes an observer by its unique identifier
    /// - Parameter id: The unique identifier of the observer to remove
    public func removeObserver(with id: UUID) {
        observers.removeValue(forKey: id)
    }

    /// Notifies all observers of a configuration event
    /// - Parameter event: The event to send to observers
    public func notifyObservers(of event: ConfigurationEvent) {
        for observer in observers.values {
            observer.configurationDidChange(event)
        }
    }

    /// Returns the current number of registered observers
    public var observerCount: Int {
        observers.count
    }
}
