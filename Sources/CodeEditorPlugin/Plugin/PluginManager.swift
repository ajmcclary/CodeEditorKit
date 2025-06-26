import Foundation
import os.log

// MARK: - Plugin Manager

/// Central manager for language plugins and their features
@MainActor
public final class PluginManager: ObservableObject {
    // MARK: - Singleton
    
    public static let shared = PluginManager()
    
    // MARK: - Properties
    
    /// Registered language plugins
    @Published private var plugins: [String: any LanguagePlugin] = [:]
    
    /// Lazy plugin loaders for deferred initialization
    private var lazyPluginLoaders: [String: LazyPluginLoader] = [:]
    
    /// Active plugins (subset of registered plugins that are enabled)
    @Published private var activePlugins: Set<String> = []
    
    /// Plugin loading errors
    @Published private var errors: [PluginError] = []
    
    /// Feature provider caches for lazy loading
    private var completionProviders: [String: any CompletionProvider] = [:]
    private var formatters: [String: any CodeFormatter] = [:]
    private var linters: [String: any CodeLinter] = [:]
    private var documentationProviders: [String: any DocumentationProvider] = [:]
    private var symbolProviders: [String: any SymbolProvider] = [:]
    // TODO: Re-enable once IndentationProvider is properly imported
    // private var indentationProviders: [String: any IndentationProvider] = [:]
    // TODO: Re-enable once LSPClientProtocol is properly imported
    // private var lspClients: [String: any LSPClientProtocol] = [:]
    
    /// Lazy loading statistics
    @Published public private(set) var lazyLoadingStats = LazyLoadingStatistics()
    
    /// Plugin directories to monitor
    private var pluginDirectories: [URL] = []
    
    /// File system monitor for plugin directories
    private var directoryMonitor: DispatchSourceFileSystemObject?
    
    /// Logger
    private let logger = Logger(subsystem: "com.codeeditor.plugin", category: "PluginManager")
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultPluginDirectories()
        Task {
            await loadBuiltInPlugins()
            await scanAndLoadPlugins()
        }
        
        // Register with memory monitor
        registerWithMemoryMonitor()
    }
    
    deinit {
        directoryMonitor?.cancel()
    }
    
    // MARK: - Plugin Registration
    
    /// Register a language plugin
    public func registerPlugin(_ plugin: any LanguagePlugin) async throws {
        logger.info("Registering plugin: \(plugin.identifier)")
        
        // Validate plugin
        let validation = plugin.validateCompatibility(editorVersion: CodeEditorPlugin.version)
        switch validation {
        case .incompatible(let reason):
            throw PluginError.incompatible(pluginId: plugin.identifier, reason: reason)

        case .warning(let message):
            logger.warning("Plugin \(plugin.identifier) validation warning: \(message)")

        case .compatible:
            break
        }
        
        // Check for conflicts
        if let existingPlugin = plugins[plugin.identifier] {
            if existingPlugin.pluginVersion != plugin.pluginVersion {
                logger.info("Replacing plugin \(plugin.identifier) version \(existingPlugin.pluginVersion) with \(plugin.pluginVersion)")
                await unregisterPlugin(plugin.identifier)
            } else {
                throw PluginError.alreadyRegistered(pluginId: plugin.identifier)
            }
        }
        
        // Register with language registry
        LanguageRegistry.shared.register(plugin)
        
        // Store plugin
        plugins[plugin.identifier] = plugin
        
        // Auto-enable if not explicitly disabled
        if !isPluginDisabled(plugin.identifier) {
            try await enablePlugin(plugin.identifier)
        }
        
        logger.info("Successfully registered plugin: \(plugin.identifier)")
    }
    
    /// Unregister a language plugin
    public func unregisterPlugin(_ identifier: String) async {
        logger.info("Unregistering plugin: \(identifier)")
        
        // Disable first if active
        if activePlugins.contains(identifier) {
            await disablePlugin(identifier)
        }
        
        // Remove from language registry
        LanguageRegistry.shared.unregister(identifier: identifier)
        
        // Remove from plugins
        plugins.removeValue(forKey: identifier)
        
        logger.info("Successfully unregistered plugin: \(identifier)")
    }
    
    // MARK: - Plugin Activation
    
    /// Enable a plugin
    public func enablePlugin(_ identifier: String) async throws {
        guard let plugin = plugins[identifier] else {
            throw PluginError.notFound(pluginId: identifier)
        }
        
        guard !activePlugins.contains(identifier) else {
            return // Already active
        }
        
        logger.info("Enabling plugin: \(identifier)")
        
        do {
            // Activate the plugin
            try await plugin.activate()
            
            // Register feature providers
            await registerFeatureProviders(for: plugin)
            
            // Mark as active
            activePlugins.insert(identifier)
            
            // Update completion manager
            updateCompletionManager()
            
            logger.info("Successfully enabled plugin: \(identifier)")
        } catch {
            logger.error("Failed to enable plugin \(identifier): \(error)")
            throw PluginError.activationFailed(pluginId: identifier, underlying: error)
        }
    }
    
    /// Disable a plugin
    public func disablePlugin(_ identifier: String) async {
        guard let plugin = plugins[identifier] else {
            return
        }
        
        guard activePlugins.contains(identifier) else {
            return // Not active
        }
        
        logger.info("Disabling plugin: \(identifier)")
        
        // Deactivate the plugin
        await plugin.deactivate()
        
        // Unregister feature providers
        await unregisterFeatureProviders(for: plugin)
        
        // Mark as inactive
        activePlugins.remove(identifier)
        
        // Update completion manager
        updateCompletionManager()
        
        logger.info("Successfully disabled plugin: \(identifier)")
    }
    
    // MARK: - Plugin Discovery and Loading
    
    /// Add a directory to monitor for plugins
    public func addPluginDirectory(_ url: URL) {
        pluginDirectories.append(url)
        Task {
            await scanAndLoadPlugins(in: url)
        }
    }
    
    /// Load plugins from a directory
    public func loadPluginsFromDirectory(_ url: URL) async {
        await scanAndLoadPlugins(in: url)
    }
    
    /// Scan and load all plugins from monitored directories
    private func scanAndLoadPlugins() async {
        for directory in pluginDirectories {
            await scanAndLoadPlugins(in: directory)
        }
    }
    
    /// Scan and load plugins from a specific directory
    private func scanAndLoadPlugins(in directory: URL) async {
        logger.info("Scanning for plugins in: \(directory.path)")
        
        guard FileManager.default.fileExists(atPath: directory.path) else {
            logger.warning("Plugin directory does not exist: \(directory.path)")
            return
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            for item in contents {
                if item.pathExtension == "codeeditorplugin" || item.lastPathComponent.hasSuffix(".plugin") {
                    await loadPlugin(from: item)
                }
            }
        } catch {
            logger.error("Failed to scan plugin directory \(directory.path): \(error)")
        }
    }
    
    /// Load a plugin from a bundle or directory
    private func loadPlugin(from url: URL) async {
        logger.info("Loading plugin from: \(url.path)")
        
        do {
            // This is a simplified loading mechanism
            // In a real implementation, you'd load dynamic libraries or script-based plugins
            // For now, we'll demonstrate with a plugin manifest approach
            
            let manifestURL = url.appendingPathComponent("plugin.json")
            guard FileManager.default.fileExists(atPath: manifestURL.path) else {
                logger.warning("No plugin manifest found at: \(manifestURL.path)")
                return
            }
            
            let manifestData = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: manifestData)
            
            // Create plugin instance based on manifest
            if let plugin = await createPlugin(from: manifest, bundleURL: url) {
                try await registerPlugin(plugin)
            }
        } catch {
            logger.error("Failed to load plugin from \(url.path): \(error)")
            errors.append(.loadingFailed(pluginPath: url.path, underlying: error))
        }
    }
    
    /// Create a plugin instance from manifest
    private func createPlugin(from manifest: PluginManifest, bundleURL _: URL) async -> (any LanguagePlugin)? {
        // This would be implemented based on your plugin architecture
        // For example, loading Swift Package Manager plugins, script-based plugins, etc.
        logger.info("Creating plugin from manifest: \(manifest.identifier)")
        return nil // Placeholder
    }
    
    // MARK: - Feature Provider Management
    
    /// Register feature providers for a plugin
    private func registerFeatureProviders(for plugin: any LanguagePlugin) async {
        let identifier = plugin.identifier
        
        // Register completion provider
        if let completionProvider = plugin.createCompletionProvider() {
            completionProviders[identifier] = completionProvider
            logger.debug("Registered completion provider for plugin: \(identifier)")
        }
        
        // Register formatter
        if let formatter = plugin.createFormatter() {
            formatters[identifier] = formatter
            logger.debug("Registered formatter for plugin: \(identifier)")
        }
        
        // Register linter
        if let linter = plugin.createLinter() {
            linters[identifier] = linter
            logger.debug("Registered linter for plugin: \(identifier)")
        }
        
        // Register documentation provider
        if let docProvider = plugin.createDocumentationProvider() {
            documentationProviders[identifier] = docProvider
            logger.debug("Registered documentation provider for plugin: \(identifier)")
        }
        
        // Register symbol provider
        if let symbolProvider = plugin.createSymbolProvider() {
            symbolProviders[identifier] = symbolProvider
            logger.debug("Registered symbol provider for plugin: \(identifier)")
        }
        
        // TODO: Re-enable once IndentationProvider is properly imported
        // Register indentation provider
        // if let indentProvider = plugin.createIndentationProvider() {
        //     indentationProviders[identifier] = indentProvider
        //     logger.debug("Registered indentation provider for plugin: \(identifier)")
        // }
        
        // TODO: Re-enable once LSPClientProtocol is properly imported
        // Register LSP client
        // if let lspClient = plugin.createLSPClient() {
        //     lspClients[identifier] = lspClient
        //     try? await lspClient.start()
        //     logger.debug("Registered and started LSP client for plugin: \(identifier)")
        // }
    }
    
    /// Unregister feature providers for a plugin
    private func unregisterFeatureProviders(for plugin: any LanguagePlugin) async {
        let identifier = plugin.identifier
        
        // TODO: Re-enable once LSPClientProtocol is properly imported
        // Stop LSP client
        // if let lspClient = lspClients[identifier] {
        //     await lspClient.stop()
        //     lspClients.removeValue(forKey: identifier)
        // }
        
        // Remove other providers
        completionProviders.removeValue(forKey: identifier)
        formatters.removeValue(forKey: identifier)
        linters.removeValue(forKey: identifier)
        documentationProviders.removeValue(forKey: identifier)
        symbolProviders.removeValue(forKey: identifier)
        // TODO: Re-enable once IndentationProvider is properly imported
        // indentationProviders.removeValue(forKey: identifier)
        
        logger.debug("Unregistered all feature providers for plugin: \(identifier)")
    }
    
    // MARK: - Feature Access
    
    /// Get completion providers for a language (with lazy loading)
    public func completionProviders(for language: Language) -> [any CompletionProvider] {
        // First, try to lazy load any relevant plugins
        Task {
            await lazyLoadRelevantPlugins(for: language)
        }
        
        return completionProviders.values.filter { provider in
            provider.supportedLanguages.contains(language) ||
            provider.supportedLanguages.isEmpty
        }
    }
    
    /// Get formatters for a language (with lazy loading)
    public func formatters(for language: Language) -> [any CodeFormatter] {
        Task {
            await lazyLoadRelevantPlugins(for: language)
        }
        
        return formatters.values.filter { formatter in
            formatter.supportedLanguages.contains(language)
        }
    }
    
    /// Get linters for a language (with lazy loading)
    public func linters(for language: Language) -> [any CodeLinter] {
        Task {
            await lazyLoadRelevantPlugins(for: language)
        }
        
        return linters.values.filter { linter in
            linter.supportedLanguages.contains(language)
        }
    }
    
    /// Get documentation providers for a language (with lazy loading)
    public func documentationProviders(for language: Language) -> [any DocumentationProvider] {
        Task {
            await lazyLoadRelevantPlugins(for: language)
        }
        
        return documentationProviders.values.filter { provider in
            provider.supportedLanguages.contains(language)
        }
    }
    
    /// Get symbol providers for a language (with lazy loading)
    public func symbolProviders(for language: Language) -> [any SymbolProvider] {
        Task {
            await lazyLoadRelevantPlugins(for: language)
        }
        
        return symbolProviders.values.filter { provider in
            provider.supportedLanguages.contains(language)
        }
    }
    
    // TODO: Re-enable once IndentationProvider is properly imported
    // /// Get indentation providers for a language (with lazy loading)
    // public func indentationProviders(for language: Language) -> [any IndentationProvider] {
    //     Task {
    //         await lazyLoadRelevantPlugins(for: language)
    //     }
    //     
    //     return indentationProviders.values.filter { provider in
    //         provider.supportedLanguages.contains(language)
    //     }
    // }
    
    // TODO: Re-enable once LSPClientProtocol is properly imported
    // /// Get LSP clients for a language
    // public func lspClients(for language: Language) -> [any LSPClientProtocol] {
    //     lspClients.values.filter { client in
    //         client.supportedLanguages.contains(language)
    //     }
    // }
    
    // MARK: - Plugin Information
    
    /// Get all registered plugins
    public var allPlugins: [any LanguagePlugin] {
        Array(plugins.values).sorted { $0.displayName < $1.displayName }
    }
    
    /// Get active plugins
    public var activePluginList: [any LanguagePlugin] {
        activePlugins.compactMap { plugins[$0] }.sorted { $0.displayName < $1.displayName }
    }
    
    /// Check if a plugin is active
    public func isPluginActive(_ identifier: String) -> Bool {
        activePlugins.contains(identifier)
    }
    
    /// Check if a plugin is enabled (alias for isPluginActive for UI consistency)
    public func isPluginEnabled(_ identifier: String) -> Bool {
        isPluginActive(identifier)
    }
    
    /// Get registered plugins (for UI)
    public var registeredPlugins: [any LanguagePlugin] {
        allPlugins
    }
    
    /// Performance statistics for plugins
    public var performanceStatistics: [String: PluginPerformanceStatistics] {
        // Return mock data for now - in a real implementation this would track actual metrics
        var stats: [String: PluginPerformanceStatistics] = [:]
        for plugin in plugins.values {
            stats[plugin.id] = PluginPerformanceStatistics(
                overallScore: Double.random(in: 0.5...1.0),
                startupTime: Double.random(in: 0.001...0.1),
                memoryUsage: Double.random(in: 1.0...50.0),
                errorCount: Int.random(in: 0...3)
            )
        }
        return stats
    }
    
    /// Uninstall a plugin
    public func uninstallPlugin(_ identifier: String) async {
        await disablePlugin(identifier)
        plugins.removeValue(forKey: identifier)
        logger.info("Uninstalled plugin: \(identifier)")
    }
    
    /// Get plugin by identifier
    public func plugin(withIdentifier identifier: String) -> (any LanguagePlugin)? {
        plugins[identifier]
    }
    
    /// Get plugins supporting a language
    public func plugins(supporting language: Language) -> [any LanguagePlugin] {
        plugins.values.filter { plugin in
            plugin.fileExtensions.contains { ext in
                // This is a simplified check - in reality you'd want more sophisticated matching
                language.name.lowercased().contains(ext.lowercased())
            }
        }.sorted { $0.displayName < $1.displayName }
    }
    
    // MARK: - Error Handling
    
    /// Get current plugin errors
    public var pluginErrors: [PluginError] {
        errors
    }
    
    /// Clear all errors
    public func clearErrors() {
        errors.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultPluginDirectories() {
        // Application support directory
        if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let pluginDir = appSupportURL.appendingPathComponent("CodeEditor/Plugins")
            pluginDirectories.append(pluginDir)
        }
        
        // User home directory
        let homeDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codeeditor/plugins")
        pluginDirectories.append(homeDir)
    }
    
    private func loadBuiltInPlugins() async {
        // Register built-in language plugins here
        // These would wrap the existing language providers
        logger.info("Loading built-in plugins")
    }
    
    private func updateCompletionManager() {
        // Update the global completion manager with active completion providers
        let allProviders = completionProviders.values
        for provider in allProviders {
            // This would be integrated with the existing CodeEditorView completion system
            logger.debug("Updating completion manager with provider: \(provider.id)")
        }
    }
    
    private func isPluginDisabled(_ identifier: String) -> Bool {
        // Check user preferences for disabled plugins
        UserDefaults.standard.bool(forKey: "plugin_disabled_\(identifier)")
    }
    
    /// Lazy load plugins that might support the given language
    private func lazyLoadRelevantPlugins(for language: Language) async {
        let relevantLoaders = lazyPluginLoaders.values.filter { loader in
            // Check if this loader might support the language based on identifier
            // This is a heuristic - in practice you'd want better metadata
            let identifier = loader.identifier.lowercased()
            let languageName = language.name.lowercased()
            let languageId = language.identifier.lowercased()
            
            return identifier.contains(languageName) ||
                   identifier.contains(languageId) ||
                   languageName.contains(identifier)
        }
        
        for loader in relevantLoaders {
            do {
                _ = try await loadPluginOnDemand(loader.identifier)
            } catch {
                logger.error("Failed to lazy load plugin \(loader.identifier): \(error)")
            }
        }
    }
    
    /// Register a lazy plugin loader
    public func registerLazyPlugin(_ loader: LazyPluginLoader) {
        lazyPluginLoaders[loader.identifier] = loader
        lazyLoadingStats.recordRegistration(identifier: loader.identifier)
    }
    
    /// Load a plugin on-demand
    private func loadPluginOnDemand(_ identifier: String) async throws -> any LanguagePlugin {
        guard let loader = lazyPluginLoaders[identifier] else {
            throw PluginError.notFound(pluginId: identifier)
        }
        
        let startTime = Date()
        
        do {
            let plugin = try await loader.load()
            let loadTime = Date().timeIntervalSince(startTime)
            
            // Register the loaded plugin
            plugins[identifier] = plugin
            lazyPluginLoaders.removeValue(forKey: identifier)
            
            lazyLoadingStats.recordSuccessfulLoad(
                identifier: identifier,
                loadTime: loadTime
            )
            
            logger.info("Lazy loaded plugin: \(identifier) in \(loadTime)s")
            return plugin
        } catch {
            let loadTime = Date().timeIntervalSince(startTime)
            lazyLoadingStats.recordFailedLoad(
                identifier: identifier,
                loadTime: loadTime,
                error: error
            )
            logger.error("Failed to lazy load plugin \(identifier): \(error)")
            throw error
        }
    }
    
    /// Get or lazy load a plugin
    private func getOrLoadPlugin(_ identifier: String) async throws -> any LanguagePlugin {
        if let plugin = plugins[identifier] {
            return plugin
        }
        
        return try await loadPluginOnDemand(identifier)
    }
    
    /// Register with memory monitor for cleanup
    private func registerWithMemoryMonitor() {
        Task { @MainActor in
            MemoryMonitor.shared.registerCleanupHandler(
                identifier: "plugin-manager",
                priority: .high
            ) { @MainActor [weak self] in
                guard let self else {
                    return CleanupResult(memoryFreedMB: 0, description: "PluginManager deallocated")
                }
                
                // Clear feature provider caches
                let beforeCacheCount = self.completionProviders.count +
                                     self.formatters.count +
                                     self.linters.count +
                                     self.documentationProviders.count +
                                     self.symbolProviders.count
                                     // TODO: Re-enable once IndentationProvider is properly imported
                                     // + self.indentationProviders.count
                                     // TODO: Re-enable once LSPClientProtocol is properly imported
                                     // + self.lspClients.count
                
                self.completionProviders.removeAll()
                self.formatters.removeAll()
                self.linters.removeAll()
                self.documentationProviders.removeAll()
                self.symbolProviders.removeAll()
                // TODO: Re-enable once IndentationProvider is properly imported
                // self.indentationProviders.removeAll()
                // TODO: Re-enable once LSPClientProtocol is properly imported
                // self.lspClients.removeAll()
                
                // Reset lazy loading statistics
                self.lazyLoadingStats.reset()
                
                // Clear errors
                self.errors.removeAll()
                
                // Estimate memory freed
                let estimatedMemoryMB = Double(beforeCacheCount) * 0.050 // 50KB per cached provider estimate
                
                return CleanupResult(
                    memoryFreedMB: estimatedMemoryMB,
                    description: "Cleared \\(beforeCacheCount) cached feature providers"
                )
            }
        }
    }
}

// MARK: - Lazy Plugin Loader

/// Protocol for lazy loading plugins
public protocol LazyPluginLoader: Sendable {
    var identifier: String { get }
    var estimatedLoadTime: TimeInterval { get }
    var dependencies: [String] { get }
    
    func load() async throws -> any LanguagePlugin
}

/// Default implementation for lazy plugin loading
public struct DefaultLazyPluginLoader: LazyPluginLoader {
    public let identifier: String
    public let estimatedLoadTime: TimeInterval
    public let dependencies: [String]
    
    private let factory: @Sendable () async throws -> any LanguagePlugin
    
    public init(
        identifier: String,
        estimatedLoadTime: TimeInterval = 0.1,
        dependencies: [String] = [],
        factory: @escaping @Sendable () async throws -> any LanguagePlugin
    ) {
        self.identifier = identifier
        self.estimatedLoadTime = estimatedLoadTime
        self.dependencies = dependencies
        self.factory = factory
    }
    
    public func load() async throws -> any LanguagePlugin {
        try await factory()
    }
}

/// Statistics for lazy loading performance
@MainActor
public final class LazyLoadingStatistics: ObservableObject {
    @Published public private(set) var totalRegistrations: Int = 0
    @Published public private(set) var totalLoads: Int = 0
    @Published public private(set) var successfulLoads: Int = 0
    @Published public private(set) var failedLoads: Int = 0
    @Published public private(set) var averageLoadTime: TimeInterval = 0
    @Published public private(set) var totalLoadTime: TimeInterval = 0
    
    private var loadTimes: [String: TimeInterval] = [:]
    private var loadErrors: [String: Error] = [:]
    
    public var successRate: Double {
        totalLoads > 0 ? Double(successfulLoads) / Double(totalLoads) : 0
    }
    
    public var lazyLoadingEfficiency: Double {
        totalRegistrations > 0 ? Double(totalRegistrations - totalLoads) / Double(totalRegistrations) : 0
    }
    
    internal func recordRegistration(identifier _: String) {
        totalRegistrations += 1
    }
    
    internal func recordSuccessfulLoad(identifier: String, loadTime: TimeInterval) {
        totalLoads += 1
        successfulLoads += 1
        totalLoadTime += loadTime
        loadTimes[identifier] = loadTime
        
        // Update average
        averageLoadTime = totalLoadTime / Double(totalLoads)
    }
    
    internal func recordFailedLoad(identifier: String, loadTime: TimeInterval, error: Error) {
        totalLoads += 1
        failedLoads += 1
        totalLoadTime += loadTime
        loadErrors[identifier] = error
        
        // Update average
        averageLoadTime = totalLoadTime / Double(totalLoads)
    }
    
    public func getLoadTime(for identifier: String) -> TimeInterval? {
        loadTimes[identifier]
    }
    
    public func getLoadError(for identifier: String) -> Error? {
        loadErrors[identifier]
    }
    
    public func reset() {
        totalRegistrations = 0
        totalLoads = 0
        successfulLoads = 0
        failedLoads = 0
        averageLoadTime = 0
        totalLoadTime = 0
        loadTimes.removeAll()
        loadErrors.removeAll()
    }
}
