import Foundation

// MARK: - Configuration Pending Changes

/// Manages a queue of pending configuration changes
@available(macOS 10.15, iOS 13.0, *)
@MainActor
public final class ConfigurationPendingChanges {
    // MARK: - Properties

    /// Queue of pending changes
    private var pendingChanges: [HotReloadConfigurationChange] = []

    // MARK: - Initialization

    /// Creates a new pending changes manager
    public init() {}

    // MARK: - Public API

    /// Adds a configuration change to the pending queue
    /// - Parameter change: The change to add
    public func addChange(_ change: HotReloadConfigurationChange) {
        pendingChanges.append(change)
    }

    /// Returns whether there are pending changes
    public var hasPendingChanges: Bool {
        !pendingChanges.isEmpty
    }

    /// Returns the current pending changes
    public var changes: [HotReloadConfigurationChange] {
        pendingChanges
    }

    /// Applies all pending changes to a configuration
    /// - Parameter config: The configuration to modify
    public func applyChanges(to config: inout EditorConfiguration) {
        for change in pendingChanges {
            change.apply(to: &config)
        }
    }

    /// Clears all pending changes
    public func clearChanges() {
        pendingChanges.removeAll()
    }
}

// MARK: - Configuration Change Types

/// Represents specific types of configuration changes for hot reload functionality
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
    /// - Parameter config: The configuration to modify
    public func apply(to config: inout EditorConfiguration) {
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

// MARK: - Configuration Updates Structure

/// A structure for specifying partial configuration updates
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

// MARK: - Configuration Presets

/// Predefined configuration presets for common use cases
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
