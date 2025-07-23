import Foundation

/// Manages the lifecycle and registration of plugins
///
/// The PluginManager is responsible for discovering, loading, activating,
/// and managing plugins throughout their lifecycle.
@available(macOS 13.0, iOS 16.0, *)
@MainActor
public final class PluginManager: ObservableObject {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "PluginManager")

    /// Registered plugins by identifier
    private var plugins: [String: PluginInstance] = [:]

    /// Active plugin contexts
    private var contexts: [String: PluginContext] = [:]

    /// Registered commands by plugin
    private var commands: [String: [PluginCommand: () async throws -> Void]] = [:]

    /// Plugin load order for dependency resolution
    private var loadOrder: [String] = []

    /// Current editor configuration
    private let configuration: EditorConfiguration

    /// Language registry
    private let languageRegistry: LanguageRegistry

    /// Completion registry
    private let completionRegistry: CompletionProviderRegistry

    /// Event system
    private let eventSystem: UnifiedEventSystem

    /// Plugin state persistence
    private let statePersistence: PluginStatePersistence

    /// Published state for SwiftUI integration
    @Published public private(set) var loadedPlugins: Set<String> = []
    @Published public private(set) var failedPlugins: Set<String> = []

    public init(
        configuration: EditorConfiguration,
        languageRegistry: LanguageRegistry,
        completionRegistry: CompletionProviderRegistry,
        eventSystem: UnifiedEventSystem
    ) {
        self.configuration = configuration
        self.languageRegistry = languageRegistry
        self.completionRegistry = completionRegistry
        self.eventSystem = eventSystem
        self.statePersistence = PluginStatePersistence()
    }

    // MARK: - Plugin Registration

    /// Register a plugin type
    /// - Parameter pluginType: The plugin class to register
    public func registerPlugin<T: Plugin>(_ pluginType: T.Type) async throws {
        let identifier = pluginType.identifier

        // Check if already registered
        if plugins[identifier] != nil {
            throw PluginError.alreadyRegistered(identifier: identifier)
        }

        // Create plugin instance
        let plugin = pluginType.init()
        let metadata = plugin.metadata

        // Validate metadata
        try validateMetadata(metadata)

        // Check platform compatibility
        try checkPlatformCompatibility(metadata)

        // Check version compatibility
        if let minVersion = metadata.minimumHostVersion {
            try checkVersionCompatibility(required: minVersion)
        }

        // Store plugin instance
        let instance = PluginInstance(
            plugin: plugin,
            metadata: metadata,
            state: .registered
        )
        plugins[identifier] = instance

        logger.info("Registered plugin: \(identifier)")
    }

    /// Load and activate all registered plugins
    public func loadPlugins() async {
        // Clear previous state
        loadedPlugins.removeAll()
        failedPlugins.removeAll()

        // Resolve load order based on dependencies
        do {
            loadOrder = try resolveLoadOrder()
        } catch {
            logger.error("Failed to resolve plugin dependencies: \(error)")
            return
        }

        // Load plugins in order
        for identifier in loadOrder {
            await loadPlugin(identifier: identifier)
        }

        // Log completion
        logger.info("Plugin loading complete: \(loadedPlugins.count) loaded, \(failedPlugins.count) failed")
    }

    /// Load a specific plugin
    /// - Parameter identifier: Plugin identifier to load
    private func loadPlugin(identifier: String) async {
        guard var instance = plugins[identifier] else {
            logger.error("Plugin not found: \(identifier)")
            failedPlugins.insert(identifier)
            return
        }

        // Check dependencies
        for dependency in instance.metadata.dependencies {
            if !dependency.optional && !loadedPlugins.contains(dependency.identifier) {
                logger.error("Missing dependency \(dependency.identifier) for plugin \(identifier)")
                failedPlugins.insert(identifier)
                instance.state = .failed(PluginError.missingDependency(identifier: dependency.identifier))
                plugins[identifier] = instance
                return
            }
        }

        // Create plugin context
        let permissions = determinePermissions(for: instance.metadata)
        let context = PluginContext(
            pluginIdentifier: identifier,
            permissions: permissions,
            languageRegistry: languageRegistry,
            completionRegistry: completionRegistry,
            configuration: configuration,
            eventSystem: eventSystem,
            pluginManager: self
        )
        contexts[identifier] = context

        // Restore plugin state if available
        if let savedState = await statePersistence.loadState(for: identifier) {
            await instance.plugin.restoreState(savedState)
        }

        // Activate plugin
        do {
            try await instance.plugin.activate(context: context)
            instance.state = .active
            loadedPlugins.insert(identifier)
            logger.info("Activated plugin: \(identifier)")

            // Plugin activated successfully
        } catch {
            instance.state = .failed(error)
            failedPlugins.insert(identifier)
            logger.error("Failed to activate plugin \(identifier): \(error)")
        }

        plugins[identifier] = instance
    }

    // MARK: - Plugin Lifecycle

    /// Deactivate a plugin
    /// - Parameter identifier: Plugin identifier to deactivate
    public func deactivatePlugin(identifier: String) async throws {
        guard var instance = plugins[identifier],
              case .active = instance.state else {
            throw PluginError.notFound(identifier: identifier)
        }

        guard let context = contexts[identifier] else {
            throw PluginError.deactivationFailed(reason: "No context found")
        }

        // Save plugin state
        let state = await instance.plugin.saveState()
        await statePersistence.saveState(state, for: identifier)

        // Deactivate plugin
        do {
            try await instance.plugin.deactivate(context: context)
            instance.state = .inactive
            loadedPlugins.remove(identifier)

            // Remove context and commands
            contexts.removeValue(forKey: identifier)
            commands.removeValue(forKey: identifier)

            logger.info("Deactivated plugin: \(identifier)")

            // Plugin deactivated successfully
        } catch {
            instance.state = .failed(error)
            throw PluginError.deactivationFailed(reason: error.localizedDescription)
        }

        plugins[identifier] = instance
    }

    /// Reload a plugin
    /// - Parameter identifier: Plugin identifier to reload
    public func reloadPlugin(identifier: String) async throws {
        if loadedPlugins.contains(identifier) {
            try await deactivatePlugin(identifier: identifier)
        }
        await loadPlugin(identifier: identifier)
    }

    // MARK: - Command Management

    /// Register a command for a plugin
    internal func registerCommand(
        _ command: PluginCommand,
        for pluginIdentifier: String,
        handler: @escaping () async throws -> Void
    ) async {
        if commands[pluginIdentifier] == nil {
            commands[pluginIdentifier] = [:]
        }
        commands[pluginIdentifier]?[command] = handler

        logger.debug("Registered command \(command.identifier) for plugin \(pluginIdentifier)")
    }

    /// Execute a command
    /// - Parameters:
    ///   - commandId: Command identifier
    ///   - pluginId: Plugin identifier
    public func executeCommand(commandId: String, from pluginId: String) async throws {
        guard let pluginCommands = commands[pluginId] else {
            throw PluginError.notFound(identifier: pluginId)
        }

        guard let (_, handler) = pluginCommands.first(where: { $0.key.identifier == commandId }) else {
            throw PluginError.notFound(identifier: commandId)
        }

        try await handler()
    }

    /// Get all available commands
    public func availableCommands() -> [(plugin: String, command: PluginCommand)] {
        var result: [(String, PluginCommand)] = []
        for (pluginId, pluginCommands) in commands {
            for command in pluginCommands.keys {
                result.append((pluginId, command))
            }
        }
        return result
    }

    // MARK: - Permission Management

    /// Request additional permission for a plugin
    internal func requestPermission(_ permission: PluginPermission, for identifier: String) async -> Bool {
        // In a real implementation, this would show a user prompt
        // For now, we'll auto-grant for development
        logger.warning("Plugin \(identifier) requested permission: \(permission.rawValue)")

        // Update context with new permission
        if let context = contexts[identifier] {
            var newPermissions = context.permissions
            newPermissions.insert(permission)

            // Create new context with updated permissions
            let newContext = PluginContext(
                pluginIdentifier: identifier,
                permissions: newPermissions,
                languageRegistry: languageRegistry,
                completionRegistry: completionRegistry,
                configuration: configuration,
                eventSystem: eventSystem,
                pluginManager: self
            )
            contexts[identifier] = newContext
            return true
        }

        return false
    }

    // MARK: - Helper Methods

    private func validateMetadata(_ metadata: PluginMetadata) throws {
        // Validate identifier format
        let identifierRegex = #"^[a-zA-Z][a-zA-Z0-9\-_.]*$"#
        guard metadata.identifier.range(of: identifierRegex, options: .regularExpression) != nil else {
            throw PluginError.invalidMetadata("Invalid identifier format")
        }

        // Validate version format (basic semantic versioning)
        let versionRegex = #"^\d+\.\d+\.\d+(-[\w.]+)?(\+[\w.]+)?$"#
        guard metadata.version.range(of: versionRegex, options: .regularExpression) != nil else {
            throw PluginError.invalidMetadata("Invalid version format")
        }
    }

    private func checkPlatformCompatibility(_ metadata: PluginMetadata) throws {
        let currentPlatform: PluginPlatform
        #if os(macOS) && !targetEnvironment(macCatalyst)
        currentPlatform = .macOS
        #elseif targetEnvironment(macCatalyst)
        currentPlatform = .catalyst
        #elseif os(iOS)
        currentPlatform = .iOS
        #elseif os(visionOS)
        currentPlatform = .visionOS
        #else
        throw PluginError.unsupportedPlatform(PluginPlatform(rawValue: "unknown"))
        #endif

        guard metadata.platforms.contains(currentPlatform) else {
            throw PluginError.unsupportedPlatform(currentPlatform)
        }
    }

    private func checkVersionCompatibility(required: String) throws {
        let currentVersion = CodeEditorPlugin.version

        // Simple version comparison (could be enhanced)
        if required > currentVersion {
            throw PluginError.incompatibleVersion(required: required, current: currentVersion)
        }
    }

    private func determinePermissions(for metadata: PluginMetadata) -> Set<PluginPermission> {
        var permissions: Set<PluginPermission> = []

        // Grant permissions based on capabilities
        if metadata.capabilities.contains(.syntaxHighlighting) {
            permissions.insert(.languages)
        }
        if metadata.capabilities.contains(.codeCompletion) {
            permissions.insert(.completion)
        }
        if metadata.capabilities.contains(.commands) {
            permissions.insert(.commands)
        }
        if metadata.capabilities.contains(.theming) {
            permissions.insert(.themes)
        }
        if metadata.capabilities.contains(.languageServer) {
            permissions.insert(.network)
        }
        if metadata.capabilities.contains(.diagnostics) {
            permissions.insert(.diagnostics)
        }

        // Always grant configuration read access
        permissions.insert(.configuration)

        return permissions
    }

    private func resolveLoadOrder() throws -> [String] {
        var resolved: [String] = []
        var visited: Set<String> = []
        var visiting: Set<String> = []

        func visit(_ identifier: String) throws {
            if visited.contains(identifier) {
                return
            }

            if visiting.contains(identifier) {
                throw PluginError.invalidMetadata("Circular dependency detected")
            }

            visiting.insert(identifier)

            if let plugin = plugins[identifier] {
                for dep in plugin.metadata.dependencies where !dep.optional {
                    try visit(dep.identifier)
                }
            }

            visiting.remove(identifier)
            visited.insert(identifier)
            resolved.append(identifier)
        }

        for identifier in plugins.keys {
            try visit(identifier)
        }

        return resolved
    }
}

// MARK: - Supporting Types

/// Internal representation of a plugin instance
@available(macOS 13.0, iOS 16.0, *)
private struct PluginInstance {
    let plugin: any Plugin
    let metadata: PluginMetadata
    var state: PluginLifecycleState
}

/// Plugin lifecycle state
@available(macOS 13.0, iOS 16.0, *)
private enum PluginLifecycleState {
    case registered
    case active
    case inactive
    case failed(Error)
}

// Plugin system events are now defined in PluginEvents.swift

/// Plugin state persistence
@available(macOS 13.0, iOS 16.0, *)
private actor PluginStatePersistence {
    private let fileManager = FileManager.default

    private var stateDirectory: URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to temp directory if app support is not available
            return fileManager.temporaryDirectory
                .appendingPathComponent("CodeEditorPlugin")
                .appendingPathComponent("PluginStates")
        }
        return appSupport
            .appendingPathComponent("CodeEditorPlugin")
            .appendingPathComponent("PluginStates")
    }

    init() {
        // Directory creation will happen lazily when needed
    }

    func saveState(_ state: PluginState, for identifier: String) async {
        // Ensure directory exists
        try? fileManager.createDirectory(at: stateDirectory, withIntermediateDirectories: true)

        let url = stateDirectory.appendingPathComponent("\(identifier).json")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(state)
            try data.write(to: url)
        } catch {
            // Log error but don't fail
            CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "PluginState")
                .error("Failed to save state for \(identifier): \(error)")
        }
    }

    func loadState(for identifier: String) async -> PluginState? {
        let url = stateDirectory.appendingPathComponent("\(identifier).json")

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(PluginState.self, from: data)
        } catch {
            CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "PluginState")
                .error("Failed to load state for \(identifier): \(error)")
            return nil
        }
    }
}
