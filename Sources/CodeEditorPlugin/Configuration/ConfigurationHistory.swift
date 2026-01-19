import Foundation

// MARK: - Configuration History Manager

/// Manages undo/redo history for configuration changes
@available(macOS 10.15, iOS 13.0, *)
@MainActor
public final class ConfigurationHistory {
    // MARK: - Properties

    /// Configuration history stack
    private var configurationHistory: [EditorConfiguration] = []

    /// Current position in history
    private var historyIndex: Int = -1

    /// Maximum number of history entries to keep
    private let maxHistorySize: Int

    // MARK: - Initialization

    /// Creates a new configuration history manager
    /// - Parameters:
    ///   - initialConfiguration: The initial configuration to add to history
    ///   - maxHistorySize: Maximum number of history entries (defaults to platform constant)
    public init(initialConfiguration: EditorConfiguration, maxHistorySize: Int = PlatformConstants.maxConfigurationHistorySize) {
        self.maxHistorySize = maxHistorySize
        addToHistory(initialConfiguration)
    }

    // MARK: - Public API

    /// Indicates whether an undo operation is available
    public var canUndo: Bool {
        historyIndex > 0
    }

    /// Indicates whether a redo operation is available
    public var canRedo: Bool {
        historyIndex < configurationHistory.count - 1
    }

    /// Gets the current configuration from history
    public var currentConfiguration: EditorConfiguration? {
        guard historyIndex >= 0, historyIndex < configurationHistory.count else {
            return nil
        }
        return configurationHistory[historyIndex]
    }

    /// Undoes the last configuration change
    /// - Returns: The restored configuration, or nil if undo is not available
    public func undo() -> EditorConfiguration? {
        guard canUndo else { return nil }

        historyIndex -= 1
        return configurationHistory[historyIndex]
    }

    /// Redoes the last undone configuration change
    /// - Returns: The restored configuration, or nil if redo is not available
    public func redo() -> EditorConfiguration? {
        guard canRedo else { return nil }

        historyIndex += 1
        return configurationHistory[historyIndex]
    }

    /// Adds a configuration to the history
    /// - Parameter configuration: The configuration to add
    public func addToHistory(_ configuration: EditorConfiguration) {
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

    /// Clears the configuration history, keeping only the current configuration
    public func clearHistory() {
        guard let current = currentConfiguration else { return }
        configurationHistory = [current]
        historyIndex = 0
    }
}
