import Combine
import Foundation
import os

// MARK: - ConfigurationHotReload

/// Enables hot reloading of configuration without recreating views
@MainActor
public final class ConfigurationHotReload: ObservableObject {
    // MARK: - Properties
    
    private static let logger = Logger(subsystem: "com.CodeEditorPlugin", category: "ConfigurationHotReload")
    
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
    
    /// Animation settings for configuration changes
    public var animateChanges: Bool = true
    public var animationDuration: Duration = .seconds(PlatformConstants.defaultAnimationDuration)
    
    /// Validation rules
    private var validationRules: [ConfigurationValidationRule] = []
    
    // MARK: - Initialization
    
    public init(configuration: EditorConfiguration = .default) {
        self.configuration = configuration
        addToHistory(configuration)
        setupDefaultValidationRules()
    }
    
    // MARK: - Configuration Updates
    
    /// Update configuration with animated transition
    public func update(_ configuration: EditorConfiguration, animated: Bool = true) {
        let shouldAnimate = animated && animateChanges
        
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
        
        // Apply animated transitions if needed
        if shouldAnimate && !changes.isEmpty {
            // Animation support is not yet implemented
            // Future versions will add cross-platform animation support
            Self.logger.debug("Animation requested for \(changes.count) changes, but animations are not yet supported")
        }
    }
    
    /// Update specific configuration properties
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
    
    /// Batch multiple changes together
    public func batchUpdate(_ block: (inout EditorConfiguration) -> Void) {
        var newConfig = configuration
        block(&newConfig)
        update(newConfig)
    }
    
    // MARK: - Pending Changes
    
    /// Add a pending change that will be applied later
    public func addPendingChange(_ change: HotReloadConfigurationChange) {
        pendingChanges.append(change)
    }
    
    /// Apply all pending changes
    public func applyPendingChanges() {
        guard !pendingChanges.isEmpty else { return }
        
        batchUpdate { config in
            for change in pendingChanges {
                change.apply(to: &config)
            }
        }
        
        pendingChanges.removeAll()
    }
    
    /// Clear pending changes without applying
    public func clearPendingChanges() {
        pendingChanges.removeAll()
    }
    
    // MARK: - History Management
    
    /// Undo the last configuration change
    public func undo() {
        guard canUndo else { return }
        
        historyIndex -= 1
        let config = configurationHistory[historyIndex]
        configuration = config
        
        notifyObservers(of: .historyNavigated(configuration: config, isUndo: true))
    }
    
    /// Redo the last undone configuration change
    public func redo() {
        guard canRedo else { return }
        
        historyIndex += 1
        let config = configurationHistory[historyIndex]
        configuration = config
        
        notifyObservers(of: .historyNavigated(configuration: config, isUndo: false))
    }
    
    /// Check if undo is available
    public var canUndo: Bool {
        historyIndex > 0
    }
    
    /// Check if redo is available
    public var canRedo: Bool {
        historyIndex < configurationHistory.count - 1
    }
    
    /// Clear configuration history
    public func clearHistory() {
        configurationHistory = [configuration]
        historyIndex = 0
    }
    
    // MARK: - Observers
    
    /// Add a configuration observer
    @discardableResult
    public func addObserver(_ observer: ConfigurationObserver) -> ObserverToken {
        let id = UUID()
        observers[id] = observer
        return ObserverToken(id: id, hotReloadRef: WeakReference(self))
    }
    
    /// Remove an observer
    public func removeObserver(with id: UUID) {
        observers.removeValue(forKey: id)
    }
    
    // MARK: - Validation
    
    /// Add a validation rule
    public func addValidationRule(_ rule: @escaping ConfigurationValidationRule) {
        validationRules.append(rule)
    }
    
    /// Validate a configuration
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
    
    /// Apply a configuration preset with animation
    public func applyPreset(_ preset: ConfigurationPreset, animated: Bool = true) {
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
        
        update(config, animated: animated)
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
    
    /// Applies configuration changes with animations.
    ///
    /// - Parameter changes: The configuration changes to animate
    ///
    /// - Note: Animation support is not yet implemented. Changes are applied immediately.
    ///         Future versions may add cross-platform animation support using:
    ///         - NSAnimationContext on macOS
    ///         - UIView.animate on iOS
    ///         - Coordinated animations for complex changes
    @available(*, deprecated, message: "Animation support is not yet implemented. This method currently applies changes immediately without animation.")
    private func applyAnimatedTransitions(for changes: [HotReloadConfigurationChange]) {
        // Log that animations were requested but not supported
        Self.logger.debug("Animation requested for \(changes.count) changes, but animations are not yet supported")
        
        // Apply changes immediately without animation
        // In the future, this could coordinate animations across different UI elements
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

/// Configuration updates structure
public struct ConfigurationUpdates {
    public var display: EditorConfiguration.Display?
    public var layout: EditorConfiguration.Layout?
    public var behavior: EditorConfiguration.Behavior?
    public var performance: EditorConfiguration.Performance?
    
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

/// Configuration change types for hot reload
public enum HotReloadConfigurationChange {
    case display(old: EditorConfiguration.Display, new: EditorConfiguration.Display)
    case layout(old: EditorConfiguration.Layout, new: EditorConfiguration.Layout)
    case behavior(old: EditorConfiguration.Behavior, new: EditorConfiguration.Behavior)
    case performance(old: EditorConfiguration.Performance, new: EditorConfiguration.Performance)
    
    /// Apply this change to a configuration
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

/// Configuration observer protocol
public protocol ConfigurationObserver {
    func configurationDidChange(_ event: ConfigurationEvent)
}

/// Configuration events
public enum ConfigurationEvent {
    case configurationChanged(old: EditorConfiguration, new: EditorConfiguration, changes: [HotReloadConfigurationChange])
    case historyNavigated(configuration: EditorConfiguration, isUndo: Bool)
    case validationFailed(ConfigurationError)
    case animationRequested(changes: [HotReloadConfigurationChange], duration: Duration)
}

/// Observer token for removing observers
public struct ObserverToken: Sendable {
    let id: UUID
    internal let hotReloadRef: WeakReference<ConfigurationHotReload>
    
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

/// Configuration validation rule
public typealias ConfigurationValidationRule = @Sendable (EditorConfiguration) -> ConfigurationError?

/// Configuration errors
public enum ConfigurationError: Error, LocalizedError {
    case invalidFontSize(CGFloat)
    case invalidTabWidth(Int)
    case invalidPerformanceSetting(String)
    case incompatibleSettings(String)
    
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

/// Configuration presets
public enum ConfigurationPreset {
    case `default`
    case minimal
    case readOnly
    case markdown
    case presentation
    case custom(EditorConfiguration)
}

// MARK: - Integration with CodeEditorView

extension CodeEditorView {
    /// Setup hot reload for this editor view
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
    /// Create a SwiftUI binding for the configuration
    public var configurationBinding: Binding<EditorConfiguration> {
        Binding(
            get: { self.configuration },
            set: { self.update($0) }
        )
    }
}
#endif
