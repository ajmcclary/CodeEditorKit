#if canImport(Combine)
import Combine
#endif
import Foundation
import os

// MARK: - ConfigurationHotReload

/// Enables hot reloading of configuration without recreating views
@available(macOS 10.15, iOS 13.0, *)
@MainActor
public final class ConfigurationHotReload: ObservableObject {
    // MARK: - Properties

    private static let logger = CrossPlatformLogger.logger(subsystem: "com.CodeEditorPlugin", category: "ConfigurationHotReload")

    /// Current configuration
    @Published public private(set) var configuration: EditorConfiguration

    /// Configuration history for undo/redo
    private var configurationHistory: [EditorConfiguration] = []
    private var historyIndex: Int = -1
    private let maxHistorySize: Int = PlatformConstants.maxConfigurationHistorySize

    /// Configuration change observers
    private var observers: [UUID: ConfigurationObserver] = [:]

    /// Pending changes that will be applied
    private var pendingChanges: [HotReloadConfigurationChange] = []

    /// Validation rules
    private var validationRules: [ConfigurationValidationRule] = []

    // MARK: - Initialization

    /// Creates a new configuration hot reload instance
    /// 
    /// Initializes the hot reload system with the specified configuration and sets up
    /// default validation rules for common configuration constraints.
    /// 
    /// - Parameter configuration: The initial configuration to use (defaults to `.default`)
    public init(configuration: EditorConfiguration = .default) {
        self.configuration = configuration
        addToHistory(configuration)
        setupDefaultValidationRules()
    }

    // MARK: - Configuration Updates

    /// Updates the current configuration with validation and change notification
    /// 
    /// This method validates the new configuration against all registered validation rules,
    /// calculates the changes from the current configuration, and notifies all observers.
    /// If validation fails, the configuration is not updated and observers are notified of the failure.
    /// 
    /// - Parameter configuration: The new configuration to apply
    public func update(_ configuration: EditorConfiguration) {
        // Validate configuration
        if let error = validate(configuration) {
            notifyObservers(of: .validationFailed(error))
            return
        }

        // Calculate changes
        let changes = calculateChanges(from: self.configuration, to: configuration)

        // Apply configuration
        let oldConfig = self.configuration
        self.configuration = configuration
        addToHistory(configuration)

        // Notify observers
        notifyObservers(of: .configurationChanged(old: oldConfig, new: configuration, changes: changes))
    }

    /// Updates specific configuration properties without replacing the entire configuration
    /// 
    /// This method allows for granular updates of configuration sections while preserving
    /// other settings. Only the specified properties will be updated.
    /// 
    /// - Parameter updates: The configuration updates containing the properties to change
    public func updateProperties(_ updates: ConfigurationUpdates) {
        var newConfig = configuration

        // Apply display updates
        if let display = updates.display {
            newConfig.display = display
        }

        // Apply layout updates
        if let layout = updates.layout {
            newConfig.layout = layout
        }

        // Apply behavior updates
        if let behavior = updates.behavior {
            newConfig.behavior = behavior
        }

        // Apply performance updates
        if let performance = updates.performance {
            newConfig.performance = performance
        }

        update(newConfig)
    }

    /// Batches multiple configuration changes into a single update operation
    /// 
    /// This method allows for efficient batching of multiple configuration changes,
    /// ensuring that validation and observer notifications happen only once for all changes.
    /// 
    /// - Parameter block: A closure that receives a mutable configuration to modify
    public func batchUpdate(_ block: (inout EditorConfiguration) -> Void) {
        var newConfig = configuration
        block(&newConfig)
        update(newConfig)
    }

    // MARK: - Pending Changes

    /// Adds a configuration change to the pending changes queue
    /// 
    /// Pending changes are stored and can be applied later using `applyPendingChanges()`.
    /// This is useful for accumulating changes that should be applied atomically.
    /// 
    /// - Parameter change: The configuration change to add to the pending queue
    public func addPendingChange(_ change: HotReloadConfigurationChange) {
        pendingChanges.append(change)
    }

    /// Applies all pending configuration changes in a single batch operation
    /// 
    /// This method applies all changes that have been added to the pending queue
    /// using `addPendingChange(_:)`. The changes are applied atomically and the
    /// pending queue is cleared after successful application.
    public func applyPendingChanges() {
        guard !pendingChanges.isEmpty else { return }

        batchUpdate { config in
            for change in pendingChanges {
                change.apply(to: &config)
            }
        }

        pendingChanges.removeAll()
    }

    /// Clears all pending configuration changes without applying them
    /// 
    /// This method discards all changes that have been added to the pending queue
    /// without applying them to the current configuration.
    public func clearPendingChanges() {
        pendingChanges.removeAll()
    }

    // MARK: - History Management

    /// Undoes the last configuration change by navigating back in history
    /// 
    /// This method restores the previous configuration from the history stack.
    /// Use `canUndo` to check if undo is available before calling this method.
    /// Observers are notified of the history navigation.
    public func undo() {
        guard canUndo else { return }

        historyIndex -= 1
        let config = configurationHistory[historyIndex]
        configuration = config

        notifyObservers(of: .historyNavigated(configuration: config, isUndo: true))
    }

    /// Redoes the last undone configuration change by navigating forward in history
    /// 
    /// This method restores the next configuration from the history stack.
    /// Use `canRedo` to check if redo is available before calling this method.
    /// Observers are notified of the history navigation.
    public func redo() {
        guard canRedo else { return }

        historyIndex += 1
        let config = configurationHistory[historyIndex]
        configuration = config

        notifyObservers(of: .historyNavigated(configuration: config, isUndo: false))
    }

    /// Indicates whether an undo operation is available
    /// 
    /// Returns `true` if there are previous configurations in the history that can be restored.
    public var canUndo: Bool {
        historyIndex > 0
    }

    /// Indicates whether a redo operation is available
    /// 
    /// Returns `true` if there are forward configurations in the history that can be restored.
    public var canRedo: Bool {
        historyIndex < configurationHistory.count - 1
    }

    /// Clears the configuration history, keeping only the current configuration
    /// 
    /// This method resets the history stack to contain only the current configuration,
    /// making undo and redo operations unavailable until new changes are made.
    public func clearHistory() {
        configurationHistory = [configuration]
        historyIndex = 0
    }

    // MARK: - Observers

    /// Adds a configuration observer to receive change notifications
    /// 
    /// The observer will be notified of all configuration changes, validation failures,
    /// and history navigation events. Use the returned token to remove the observer later.
    /// 
    /// - Parameter observer: The observer to add
    /// - Returns: A token that can be used to remove the observer
    @discardableResult
    public func addObserver(_ observer: ConfigurationObserver) -> ObserverToken {
        let id = UUID()
        observers[id] = observer
        return ObserverToken(id: id, hotReloadRef: WeakReference(self))
    }

    /// Removes a configuration observer using its unique identifier
    /// 
    /// - Parameter id: The unique identifier of the observer to remove
    public func removeObserver(with id: UUID) {
        observers.removeValue(forKey: id)
    }

    // MARK: - Validation

    /// Adds a validation rule that will be applied to all configuration updates
    /// 
    /// Validation rules are functions that take a configuration and return an error if
    /// the configuration is invalid. All rules are checked before any configuration update.
    /// 
    /// - Parameter rule: The validation rule to add
    public func addValidationRule(_ rule: @escaping ConfigurationValidationRule) {
        validationRules.append(rule)
    }

    /// Validates a configuration against all registered validation rules
    /// 
    /// This method runs all validation rules against the provided configuration
    /// and returns the first error encountered, or `nil` if the configuration is valid.
    /// 
    /// - Parameter configuration: The configuration to validate
    /// - Returns: The first validation error encountered, or `nil` if valid
    public func validate(_ configuration: EditorConfiguration) -> ConfigurationError? {
        let rules = Array(validationRules) // Create a copy to avoid escaping issues
        for rule in rules {
            if let error = rule(configuration) {
                return error
            }
        }
        return nil
    }

    // MARK: - Presets

    /// Applies a predefined configuration preset
    /// 
    /// This method replaces the current configuration with one of the predefined presets.
    /// The preset configurations are designed for common use cases and provide
    /// well-tested combinations of settings.
    /// 
    /// - Parameter preset: The preset to apply
    public func applyPreset(_ preset: ConfigurationPreset) {
        let config: EditorConfiguration

        switch preset {
        case .default:
            config = .default

        case .minimal:
            config = .minimal

        case .readOnly:
            config = .readOnly

        case .markdown:
            config = .markdown

        case .presentation:
            config = .presentation

        case .custom(let customConfig):
            config = customConfig
        }

        update(config)
    }

    // MARK: - Private Methods

    private func addToHistory(_ configuration: EditorConfiguration) {
        // Remove any forward history if we're not at the end
        if historyIndex < configurationHistory.count - 1 {
            configurationHistory = Array(configurationHistory.prefix(historyIndex + 1))
        }

        // Add new configuration
        configurationHistory.append(configuration)
        historyIndex = configurationHistory.count - 1

        // Trim history if too long
        if configurationHistory.count > maxHistorySize {
            configurationHistory.removeFirst()
            historyIndex -= 1
        }
    }

    private func calculateChanges(from old: EditorConfiguration, to new: EditorConfiguration) -> [HotReloadConfigurationChange] {
        var changes: [HotReloadConfigurationChange] = []

        // Check display changes
        if old.display != new.display {
            changes.append(.display(old: old.display, new: new.display))
        }

        // Check layout changes
        if old.layout != new.layout {
            changes.append(.layout(old: old.layout, new: new.layout))
        }

        // Check behavior changes
        if old.behavior != new.behavior {
            changes.append(.behavior(old: old.behavior, new: new.behavior))
        }

        // Check performance changes
        if old.performance != new.performance {
            changes.append(.performance(old: old.performance, new: new.performance))
        }

        return changes
    }

    private func notifyObservers(of event: ConfigurationEvent) {
        for observer in observers.values {
            observer.configurationDidChange(event)
        }
    }

    private func setupDefaultValidationRules() {
        // Font size validation
        addValidationRule { config in
            if config.display.fontSize < 8 || config.display.fontSize > 72 {
                return ConfigurationError.invalidFontSize(config.display.fontSize)
            }
            return nil
        }

        // Tab width validation
        addValidationRule { config in
            if config.layout.tabWidth < 1 || config.layout.tabWidth > 16 {
                return ConfigurationError.invalidTabWidth(config.layout.tabWidth)
            }
            return nil
        }

        // Performance validation
        addValidationRule { config in
            if config.performance.maxSyntaxHighlightingLength < 0 {
                return ConfigurationError.invalidPerformanceSetting("maxSyntaxHighlightingLength cannot be negative")
            }
            return nil
        }
    }

    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - Supporting Types

/// A structure for specifying partial configuration updates
/// 
/// This structure allows you to update specific sections of the configuration
/// without affecting other sections. Only non-nil properties will be applied.
public struct ConfigurationUpdates {
    /// Display configuration updates (font, colors, etc.)
    public var display: EditorConfiguration.Display?

    /// Layout configuration updates (line numbers, gutters, etc.)
    public var layout: EditorConfiguration.Layout?

    /// Behavior configuration updates (editing behavior, shortcuts, etc.)
    public var behavior: EditorConfiguration.Behavior?

    /// Performance configuration updates (caching, limits, etc.)
    public var performance: EditorConfiguration.Performance?

    /// Creates a new configuration updates structure
    /// 
    /// - Parameters:
    ///   - display: Optional display configuration updates
    ///   - layout: Optional layout configuration updates
    ///   - behavior: Optional behavior configuration updates
    ///   - performance: Optional performance configuration updates
    public init(
        display: EditorConfiguration.Display? = nil,
        layout: EditorConfiguration.Layout? = nil,
        behavior: EditorConfiguration.Behavior? = nil,
        performance: EditorConfiguration.Performance? = nil
    ) {
        self.display = display
        self.layout = layout
        self.behavior = behavior
        self.performance = performance
    }
}

/// Represents specific types of configuration changes for hot reload functionality
/// 
/// This enum captures the different types of configuration changes that can occur,
/// allowing for targeted updates and efficient change tracking.
public enum HotReloadConfigurationChange {
    /// A change to the display configuration (fonts, colors, themes)
    case display(old: EditorConfiguration.Display, new: EditorConfiguration.Display)

    /// A change to the layout configuration (line numbers, gutters, spacing)
    case layout(old: EditorConfiguration.Layout, new: EditorConfiguration.Layout)

    /// A change to the behavior configuration (editing behavior, shortcuts)
    case behavior(old: EditorConfiguration.Behavior, new: EditorConfiguration.Behavior)

    /// A change to the performance configuration (caching, limits, optimizations)
    case performance(old: EditorConfiguration.Performance, new: EditorConfiguration.Performance)

    /// Applies this configuration change to a mutable configuration
    /// 
    /// This method updates the appropriate section of the configuration
    /// with the new values contained in this change.
    /// 
    /// - Parameter config: The configuration to modify
    func apply(to config: inout EditorConfiguration) {
        switch self {
        case .display(_, let new):
            config.display = new

        case .layout(_, let new):
            config.layout = new

        case .behavior(_, let new):
            config.behavior = new

        case .performance(_, let new):
            config.performance = new
        }
    }
}

/// Protocol for observing configuration changes
/// 
/// Implement this protocol to receive notifications about configuration changes,
/// validation failures, and history navigation events.
public protocol ConfigurationObserver {
    /// Called when a configuration event occurs
    /// 
    /// - Parameter event: The configuration event that occurred
    func configurationDidChange(_ event: ConfigurationEvent)
}

/// Events that can occur during configuration management
/// 
/// This enum represents the different types of events that configuration observers
/// can receive, including changes, history navigation, and validation failures.
public enum ConfigurationEvent {
    /// The configuration was successfully changed
    case configurationChanged(old: EditorConfiguration, new: EditorConfiguration, changes: [HotReloadConfigurationChange])

    /// The configuration history was navigated (undo/redo)
    case historyNavigated(configuration: EditorConfiguration, isUndo: Bool)

    /// Configuration validation failed
    case validationFailed(ConfigurationError)
}

/// A token representing a configuration observer registration
/// 
/// Use this token to remove observers from the configuration hot reload system.
/// The token maintains a weak reference to avoid retain cycles.
public struct ObserverToken: Sendable {
    /// The unique identifier for this observer
    let id: UUID

    /// Weak reference to the hot reload instance
    internal let hotReloadRef: WeakReference<ConfigurationHotReload>

    /// Removes the observer associated with this token
    /// 
    /// After calling this method, the observer will no longer receive
    /// configuration change notifications.
    public func remove() {
        Task { @MainActor in
            hotReloadRef.value?.removeObserver(with: id)
        }
    }
}

// Helper for weak references in Sendable contexts
internal final class WeakReference<T: AnyObject>: @unchecked Sendable {
    weak var value: T?

    init(_ value: T) {
        self.value = value
    }

    deinit {
        // Cleanup is handled automatically by ARC
    }
}

/// A function type for validating configuration settings
/// 
/// Validation rules take a configuration and return an error if the configuration
/// is invalid, or `nil` if the configuration is valid.
public typealias ConfigurationValidationRule = @Sendable (EditorConfiguration) -> ConfigurationError?

/// Errors that can occur during configuration validation or updates
/// 
/// These errors provide specific information about what went wrong during
/// configuration validation, making it easier to provide user-friendly error messages.
public enum ConfigurationError: Error, LocalizedError {
    /// The specified font size is outside the valid range (8-72)
    case invalidFontSize(CGFloat)

    /// The specified tab width is outside the valid range (1-16)
    case invalidTabWidth(Int)

    /// A performance setting has an invalid value
    case invalidPerformanceSetting(String)

    /// Multiple settings are incompatible with each other
    case incompatibleSettings(String)

    /// A localized description of the configuration error
    /// 
    /// This property provides user-friendly error messages that can be displayed
    /// in the UI to help users understand and fix configuration problems.
    public var errorDescription: String? {
        switch self {
        case .invalidFontSize(let size):
            return "Invalid font size: \(size). Must be between 8 and 72."

        case .invalidTabWidth(let width):
            return "Invalid tab width: \(width). Must be between 1 and 16."

        case .invalidPerformanceSetting(let message):
            return "Invalid performance setting: \(message)"

        case .incompatibleSettings(let message):
            return "Incompatible settings: \(message)"
        }
    }
}

/// Predefined configuration presets for common use cases
/// 
/// These presets provide well-tested combinations of settings optimized
/// for specific scenarios like presentations, markdown editing, or minimal interfaces.
public enum ConfigurationPreset {
    /// The default configuration with balanced settings
    case `default`

    /// A minimal configuration with reduced UI elements
    case minimal

    /// A read-only configuration that prevents editing
    case readOnly

    /// A configuration optimized for markdown editing
    case markdown

    /// A configuration optimized for presentations (large fonts, minimal UI)
    case presentation

    /// A custom configuration provided by the user
    case custom(EditorConfiguration)
}

// MARK: - Integration with CodeEditorView

extension CodeEditorView {
    /// Sets up hot reload functionality for this editor view
    /// 
    /// This method establishes a connection between the editor view and the hot reload system,
    /// automatically updating the view's configuration whenever the hot reload configuration changes.
    /// 
    /// - Parameter hotReload: The hot reload instance to connect to
    /// - Returns: A cancellable that manages the connection lifecycle
    public func setupHotReload(with hotReload: ConfigurationHotReload) -> AnyCancellable {
        hotReload.$configuration
            .removeDuplicates()
            .sink { [weak self] newConfig in
                self?.configuration = newConfig
            }
    }
}

// MARK: - SwiftUI Integration

#if canImport(SwiftUI)
import SwiftUI

extension ConfigurationHotReload {
    /// Creates a SwiftUI binding for the configuration
    /// 
    /// This binding allows SwiftUI views to read and write the configuration directly,
    /// with changes automatically triggering validation and observer notifications.
    /// 
    /// - Returns: A binding that provides read/write access to the configuration
    public var configurationBinding: Binding<EditorConfiguration> {
        Binding(
            get: { self.configuration },
            set: { self.update($0) }
        )
    }
}
#endif
