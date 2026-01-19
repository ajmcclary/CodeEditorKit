#if canImport(Combine)
import Combine
#endif
import Foundation
import os

// MARK: - ConfigurationHotReload

/// Enables hot reloading of configuration without recreating views
///
/// This class serves as a facade that coordinates history management, validation,
/// observer notifications, and pending changes through dedicated components.
@available(macOS 10.15, iOS 13.0, *)
@MainActor
public final class ConfigurationHotReload: ObservableObject {
    // MARK: - Properties

    private static let logger = CrossPlatformLogger.logger(subsystem: "com.CodeEditorPlugin", category: "ConfigurationHotReload")

    /// Current configuration
    @Published public private(set) var configuration: EditorConfiguration

    /// History manager for undo/redo
    private let history: ConfigurationHistory

    /// Inline validation rules (separate from ConfigurationValidator to avoid API conflicts)
    private var validationRules: [HotReloadValidationRule] = []

    /// Observer registry for change notifications
    private let observerRegistry: ConfigurationObserverRegistry

    /// Pending changes manager
    private let pendingChangesManager: ConfigurationPendingChanges

    // MARK: - Initialization

    /// Creates a new configuration hot reload instance
    ///
    /// Initializes the hot reload system with the specified configuration and sets up
    /// default validation rules for common configuration constraints.
    ///
    /// - Parameter configuration: The initial configuration to use (defaults to `.default`)
    public init(configuration: EditorConfiguration = .default) {
        self.configuration = configuration
        self.history = ConfigurationHistory(initialConfiguration: configuration)
        self.observerRegistry = ConfigurationObserverRegistry()
        self.pendingChangesManager = ConfigurationPendingChanges()

        // Set up observer registry with self reference
        observerRegistry.setHotReload(self)

        // Set up default validation rules
        setupDefaultValidationRules()
    }

    private func setupDefaultValidationRules() {
        // Font size validation
        addValidationRule { config in
            if config.display.fontSize < 8 || config.display.fontSize > 72 {
                return HotReloadValidationError.invalidFontSize(config.display.fontSize)
            }
            return nil
        }

        // Tab width validation
        addValidationRule { config in
            if config.layout.tabWidth < 1 || config.layout.tabWidth > 16 {
                return HotReloadValidationError.invalidTabWidth(config.layout.tabWidth)
            }
            return nil
        }

        // Performance validation
        addValidationRule { config in
            if config.performance.maxSyntaxHighlightingLength < 0 {
                return HotReloadValidationError.invalidPerformanceSetting("maxSyntaxHighlightingLength cannot be negative")
            }
            return nil
        }
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
        if let error = validateConfiguration(configuration) {
            observerRegistry.notifyObservers(of: .validationFailed(error))
            return
        }

        // Calculate changes
        let changes = calculateChanges(from: self.configuration, to: configuration)

        // Apply configuration
        let oldConfig = self.configuration
        self.configuration = configuration
        history.addToHistory(configuration)

        // Notify observers
        observerRegistry.notifyObservers(of: .configurationChanged(old: oldConfig, new: configuration, changes: changes))
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
        pendingChangesManager.addChange(change)
    }

    /// Applies all pending configuration changes in a single batch operation
    ///
    /// This method applies all changes that have been added to the pending queue
    /// using `addPendingChange(_:)`. The changes are applied atomically and the
    /// pending queue is cleared after successful application.
    public func applyPendingChanges() {
        guard pendingChangesManager.hasPendingChanges else { return }

        batchUpdate { [pendingChangesManager] config in
            pendingChangesManager.applyChanges(to: &config)
        }

        pendingChangesManager.clearChanges()
    }

    /// Clears all pending configuration changes without applying them
    ///
    /// This method discards all changes that have been added to the pending queue
    /// without applying them to the current configuration.
    public func clearPendingChanges() {
        pendingChangesManager.clearChanges()
    }

    // MARK: - History Management

    /// Undoes the last configuration change by navigating back in history
    ///
    /// This method restores the previous configuration from the history stack.
    /// Use `canUndo` to check if undo is available before calling this method.
    /// Observers are notified of the history navigation.
    public func undo() {
        guard let config = history.undo() else { return }
        configuration = config
        observerRegistry.notifyObservers(of: .historyNavigated(configuration: config, isUndo: true))
    }

    /// Redoes the last undone configuration change by navigating forward in history
    ///
    /// This method restores the next configuration from the history stack.
    /// Use `canRedo` to check if redo is available before calling this method.
    /// Observers are notified of the history navigation.
    public func redo() {
        guard let config = history.redo() else { return }
        configuration = config
        observerRegistry.notifyObservers(of: .historyNavigated(configuration: config, isUndo: false))
    }

    /// Indicates whether an undo operation is available
    ///
    /// Returns `true` if there are previous configurations in the history that can be restored.
    public var canUndo: Bool {
        history.canUndo
    }

    /// Indicates whether a redo operation is available
    ///
    /// Returns `true` if there are forward configurations in the history that can be restored.
    public var canRedo: Bool {
        history.canRedo
    }

    /// Clears the configuration history, keeping only the current configuration
    ///
    /// This method resets the history stack to contain only the current configuration,
    /// making undo and redo operations unavailable until new changes are made.
    public func clearHistory() {
        history.clearHistory()
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
    public func addObserver(_ observer: ConfigurationObserver) -> ObserverToken? {
        observerRegistry.addObserver(observer)
    }

    /// Removes a configuration observer using its unique identifier
    ///
    /// - Parameter id: The unique identifier of the observer to remove
    public func removeObserver(with id: UUID) {
        observerRegistry.removeObserver(with: id)
    }

    // MARK: - Validation

    /// Adds a validation rule that will be applied to all configuration updates
    ///
    /// Validation rules are functions that take a configuration and return an error if
    /// the configuration is invalid. All rules are checked before any configuration update.
    ///
    /// - Parameter rule: The validation rule to add
    public func addValidationRule(_ rule: @escaping HotReloadValidationRule) {
        validationRules.append(rule)
    }

    /// Validates a configuration against all registered validation rules
    ///
    /// This method runs all validation rules against the provided configuration
    /// and returns the first error encountered, or `nil` if the configuration is valid.
    ///
    /// - Parameter configuration: The configuration to validate
    /// - Returns: The first validation error encountered, or `nil` if valid
    public func validate(_ configuration: EditorConfiguration) -> HotReloadValidationError? {
        validateConfiguration(configuration)
    }

    private func validateConfiguration(_ configuration: EditorConfiguration) -> HotReloadValidationError? {
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

    deinit {
        // Cleanup is handled automatically by ARC
    }
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

// MARK: - Hot Reload Validation Types

/// A function type for validating configuration settings in hot reload context
public typealias HotReloadValidationRule = @Sendable (EditorConfiguration) -> HotReloadValidationError?

/// Errors that can occur during hot reload configuration validation
public enum HotReloadValidationError: Error, LocalizedError {
    /// The specified font size is outside the valid range (8-72)
    case invalidFontSize(CGFloat)

    /// The specified tab width is outside the valid range (1-16)
    case invalidTabWidth(Int)

    /// A performance setting has an invalid value
    case invalidPerformanceSetting(String)

    /// Multiple settings are incompatible with each other
    case incompatibleSettings(String)

    /// A localized description of the validation error
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
