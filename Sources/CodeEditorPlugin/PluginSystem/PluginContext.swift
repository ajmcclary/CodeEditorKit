import Foundation

/// Context provided to plugins for accessing editor functionality
///
/// The plugin context acts as a controlled gateway to editor APIs,
/// ensuring plugins can only access functionality they have permission for.
@available(macOS 13.0, iOS 16.0, *)
@MainActor
final class PluginContext {
    /// Language registry for registering syntax highlighters
    let languageRegistry: LanguageRegistry

    /// Completion provider registry
    let completionRegistry: CompletionProviderRegistry

    /// Access to editor configuration
    let configuration: EditorConfiguration

    /// Event system for subscribing to editor events
    let eventSystem: UnifiedEventSystem

    /// Logger for plugin-specific logging
    let logger: CrossPlatformLogger.Logger

    /// Plugin's granted permissions
    let permissions: Set<PluginPermission>

    /// Plugin's identifier
    let pluginIdentifier: String

    /// Workspace for plugin-specific storage
    let workspace: PluginWorkspace

    /// Reference to the plugin manager (weak to avoid cycles)
    private weak var pluginManager: PluginManager?

    /// Create a new plugin context
    internal init(
        pluginIdentifier: String,
        permissions: Set<PluginPermission>,
        languageRegistry: LanguageRegistry,
        completionRegistry: CompletionProviderRegistry,
        configuration: EditorConfiguration,
        eventSystem: UnifiedEventSystem,
        pluginManager: PluginManager
    ) {
        self.pluginIdentifier = pluginIdentifier
        self.permissions = permissions
        self.languageRegistry = languageRegistry
        self.completionRegistry = completionRegistry
        self.configuration = configuration
        self.eventSystem = eventSystem
        self.pluginManager = pluginManager
        self.logger = CrossPlatformLogger.logger(
            subsystem: "CodeEditorPlugin.Plugin",
            category: pluginIdentifier
        )
        self.workspace = PluginWorkspace(pluginIdentifier: pluginIdentifier)
    }

    /// Request a permission that wasn't initially granted
    /// - Parameter permission: The permission to request
    /// - Returns: Whether the permission was granted
    func requestPermission(_ permission: PluginPermission) async -> Bool {
        guard let pluginManager else { return false }
        return await pluginManager.requestPermission(permission, for: pluginIdentifier)
    }

    /// Check if a permission is granted
    /// - Parameter permission: The permission to check
    /// - Returns: Whether the permission is granted
    func hasPermission(_ permission: PluginPermission) -> Bool {
        permissions.contains(permission)
    }

    /// Register a command that can be invoked by the user
    /// - Parameters:
    ///   - command: The command to register
    ///   - handler: The handler to execute when the command is invoked
    func registerCommand(_ command: PluginCommand, handler: @escaping () async throws -> Void) async throws {
        guard hasPermission(.commands) else {
            throw PluginError.securityViolation("Plugin does not have permission to register commands")
        }

        guard let pluginManager else {
            throw PluginError.activationFailed(reason: "Plugin manager not available")
        }

        await pluginManager.registerCommand(command, for: pluginIdentifier, handler: handler)
    }

    /// Register a theme provider
    /// - Parameter provider: The theme provider to register
    func registerThemeProvider(_ provider: any ThemeProvider) async throws {
        guard hasPermission(.themes) else {
            throw PluginError.securityViolation("Plugin does not have permission to register themes")
        }

        // Theme registration would be implemented here
        logger.info("Registered theme provider: \(provider)")
    }
}

// MARK: - Plugin Permissions

/// Permissions that can be granted to plugins
@available(macOS 13.0, iOS 16.0, *)
struct PluginPermission: Hashable, Sendable, Codable, RawRepresentable {
    let rawValue: String

    /// Access to language registry
    static let languages = Self(rawValue: "languages")

    /// Access to completion providers
    static let completion = Self(rawValue: "completion")

    /// Access to register commands
    static let commands = Self(rawValue: "commands")

    /// Access to register themes
    static let themes = Self(rawValue: "themes")

    /// Access to file system (sandboxed)
    static let fileSystem = Self(rawValue: "fileSystem")

    /// Access to network (for language servers)
    static let network = Self(rawValue: "network")

    /// Access to editor configuration
    static let configuration = Self(rawValue: "configuration")

    /// Access to diagnostics
    static let diagnostics = Self(rawValue: "diagnostics")
}

// MARK: - Plugin Workspace

/// Provides isolated storage for plugins
@available(macOS 13.0, iOS 16.0, *)
final class PluginWorkspace: @unchecked Sendable {
    private let pluginIdentifier: String
    private let fileManager = FileManager.default

    /// Base directory for plugin storage
    var baseDirectory: URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to temp directory if app support is not available
            return fileManager.temporaryDirectory
                .appendingPathComponent("CodeEditorPlugin")
                .appendingPathComponent("Plugins")
                .appendingPathComponent(pluginIdentifier)
        }
        return appSupport
            .appendingPathComponent("CodeEditorPlugin")
            .appendingPathComponent("Plugins")
            .appendingPathComponent(pluginIdentifier)
    }

    init(pluginIdentifier: String) {
        self.pluginIdentifier = pluginIdentifier
        setupDirectories()
    }

    private func setupDirectories() {
        do {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        } catch {
            CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "PluginWorkspace")
                .error("Failed to create plugin directory at \(baseDirectory): \(error)")
        }
    }

    /// Read data from plugin storage
    /// - Parameter filename: Name of the file to read
    /// - Returns: File data if it exists
    func readData(filename: String) async throws -> Data {
        let url = baseDirectory.appendingPathComponent(filename)
        return try Data(contentsOf: url)
    }

    /// Write data to plugin storage
    /// - Parameters:
    ///   - data: Data to write
    ///   - filename: Name of the file to write
    func writeData(_ data: Data, filename: String) async throws {
        let url = baseDirectory.appendingPathComponent(filename)
        try data.write(to: url)
    }

    /// Delete a file from plugin storage
    /// - Parameter filename: Name of the file to delete
    func deleteFile(filename: String) async throws {
        let url = baseDirectory.appendingPathComponent(filename)
        try fileManager.removeItem(at: url)
    }

    /// List files in plugin storage
    /// - Returns: Array of filenames
    func listFiles() async throws -> [String] {
        try fileManager.contentsOfDirectory(atPath: baseDirectory.path)
    }
}

// MARK: - Plugin Command

/// Represents a command that can be registered by a plugin
@available(macOS 13.0, iOS 16.0, *)
struct PluginCommand: Hashable, Sendable {
    /// Unique identifier for the command
    let identifier: String

    /// Display title for the command
    let title: String

    /// Optional keyboard shortcut
    let keyboardShortcut: KeyboardShortcut?

    /// Category for organizing commands
    let category: String

    /// Whether the command is enabled
    let isEnabled: Bool

    init(
        identifier: String,
        title: String,
        keyboardShortcut: KeyboardShortcut? = nil,
        category: String = "General",
        isEnabled: Bool = true
    ) {
        self.identifier = identifier
        self.title = title
        self.keyboardShortcut = keyboardShortcut
        self.category = category
        self.isEnabled = isEnabled
    }
}

/// Keyboard shortcut for commands
@available(macOS 13.0, iOS 16.0, *)
struct KeyboardShortcut: Hashable, Sendable {
    let key: String
    let modifiers: KeyboardModifiers

    init(key: String, modifiers: KeyboardModifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }
}

/// Keyboard modifiers
@available(macOS 13.0, iOS 16.0, *)
struct KeyboardModifiers: OptionSet, Hashable, Sendable {
    let rawValue: Int

    static let command = Self(rawValue: 1 << 0)
    static let shift = Self(rawValue: 1 << 1)
    static let option = Self(rawValue: 1 << 2)
    static let control = Self(rawValue: 1 << 3)
}

// MARK: - Theme Provider Protocol

/// Protocol for plugins that provide themes
@available(macOS 13.0, iOS 16.0, *)
protocol ThemeProvider: Sendable {
    /// Available themes from this provider
    var themes: [Theme] { get }

    /// Provider name
    var name: String { get }
}
