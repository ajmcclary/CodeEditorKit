import Foundation
import os.log

/// Plugin marketplace for discovering and installing language plugins
@MainActor
public class PluginMarketplace: ObservableObject {
    // MARK: - Configuration
    
    /// Marketplace configuration
    public struct Configuration: Sendable {
        public var marketplaceURL: URL
        public var cacheDirectory: URL
        public var updateCheckInterval: TimeInterval
        public var maxConcurrentDownloads: Int
        public var verifySignatures: Bool
        
        public static let `default` = Self(
            marketplaceURL: URL(string: "https://plugins.codeeditor.dev/api/v1")!,
            cacheDirectory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent("CodeEditorPlugins"),
            updateCheckInterval: 3_600, // 1 hour
            maxConcurrentDownloads: 3,
            verifySignatures: true
        )
    }
    
    // MARK: - Types
    
    /// Plugin listing from marketplace
    public struct PluginListing: Identifiable, Codable, Sendable {
        public let id: String
        public let name: String
        public let author: String
        public let description: String
        public let version: String
        public let minimumEditorVersion: String
        public let downloadURL: URL
        public let iconURL: URL?
        public let screenshotURLs: [URL]
        public let tags: [String]
        public let rating: Double
        public let downloadCount: Int
        public let lastUpdated: Date
        public let fileSize: Int64
        public let signature: String?
        
        public var isCompatible: Bool {
            // Check version compatibility
            true // Simplified for now
        }
    }
    
    /// Installation status
    public enum InstallationStatus {
        case notInstalled
        case downloading(progress: Double)
        case installing
        case installed(version: String)
        case failed(error: Error)
        case updateAvailable(currentVersion: String, newVersion: String)
    }
    
    /// Category for browsing
    public enum Category: String, CaseIterable {
        case all = "All"
        case languages = "Languages"
        case themes = "Themes"
        case formatters = "Formatters"
        case linters = "Linters"
        case debuggers = "Debuggers"
        case utilities = "Utilities"
        
        public var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .languages: return "text.cursor"
            case .themes: return "paintbrush"
            case .formatters: return "text.alignleft"
            case .linters: return "checkmark.shield"
            case .debuggers: return "ant.circle"
            case .utilities: return "wrench"
            }
        }
    }
    
    /// Sort option
    public enum SortOption: String, CaseIterable {
        case relevance = "Relevance"
        case downloads = "Downloads"
        case rating = "Rating"
        case updated = "Recently Updated"
        case name = "Name"
    }
    
    // MARK: - Properties
    
    @Published public private(set) var availablePlugins: [PluginListing] = []
    @Published public private(set) var featuredPlugins: [PluginListing] = []
    @Published public private(set) var installedPlugins: Set<String> = []
    @Published public private(set) var installationStatus: [String: InstallationStatus] = [:]
    @Published public private(set) var isLoading = false
    @Published public private(set) var searchQuery = ""
    @Published public private(set) var selectedCategory: Category = .all
    @Published public private(set) var sortOption: SortOption = .relevance
    
    public let configuration: Configuration
    private let logger = Logger(subsystem: "CodeEditorPlugin", category: "PluginMarketplace")
    private let pluginManager = PluginManager.shared
    private let networkManager = PluginNetworkManager()
    private var updateCheckTimer: Timer?
    private var downloadTasks: [String: Task<Void, Error>] = [:]
    
    // MARK: - Initialization
    
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
        setupMarketplace()
    }
    
    // MARK: - Public Methods
    
    /// Refresh available plugins from marketplace
    public func refreshPlugins() async throws {
        isLoading = true
        defer { isLoading = false }
        
        logger.info("Refreshing plugin marketplace")
        
        do {
            // Fetch all plugins
            let url = configuration.marketplaceURL.appendingPathComponent("plugins")
            let plugins = try await networkManager.fetch([PluginListing].self, from: url)
            
            availablePlugins = plugins
            
            // Fetch featured plugins
            let featuredURL = configuration.marketplaceURL.appendingPathComponent("featured")
            featuredPlugins = try await networkManager.fetch([PluginListing].self, from: featuredURL)
            
            // Update installation status
            await updateInstallationStatus()
            
            logger.info("Successfully refreshed \(plugins.count) plugins")
        } catch {
            logger.error("Failed to refresh plugins: \(error)")
            throw error
        }
    }
    
    /// Search plugins
    public func search(query: String) {
        searchQuery = query
        // In a real implementation, this would trigger a server-side search
        // For now, we filter locally
    }
    
    /// Set category filter
    public func setCategory(_ category: Category) {
        selectedCategory = category
    }
    
    /// Set sort option
    public func setSortOption(_ option: SortOption) {
        sortOption = option
    }
    
    /// Get filtered and sorted plugins
    public var displayedPlugins: [PluginListing] {
        var plugins = availablePlugins
        
        // Apply search filter
        if !searchQuery.isEmpty {
            plugins = plugins.filter { plugin in
                plugin.name.localizedCaseInsensitiveContains(searchQuery) ||
                plugin.description.localizedCaseInsensitiveContains(searchQuery) ||
                plugin.tags.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
            }
        }
        
        // Apply category filter
        if selectedCategory != .all {
            plugins = plugins.filter { plugin in
                plugin.tags.contains(selectedCategory.rawValue)
            }
        }
        
        // Apply sorting
        switch sortOption {
        case .relevance:
            // Keep existing order (server provides relevance)
            break

        case .downloads:
            plugins.sort { $0.downloadCount > $1.downloadCount }

        case .rating:
            plugins.sort { $0.rating > $1.rating }

        case .updated:
            plugins.sort { $0.lastUpdated > $1.lastUpdated }

        case .name:
            plugins.sort { $0.name < $1.name }
        }
        
        return plugins
    }
    
    /// Install a plugin
    public func installPlugin(_ listing: PluginListing) async throws {
        let currentStatus = installationStatus[listing.id]
        let canInstall: Bool
        
        if let status = currentStatus {
            switch status {
            case .notInstalled, .failed:
                canInstall = true

            default:
                canInstall = false
            }
        } else {
            canInstall = true
        }
        
        guard canInstall else {
            logger.warning("Plugin \(listing.id) is already being installed or is installed")
            return
        }
        
        logger.info("Installing plugin: \(listing.name)")
        
        // Create download task
        let task = Task<Void, Error> {
            do {
                // Update status
                installationStatus[listing.id] = .downloading(progress: 0)
                
                // Download plugin
                let downloadedURL = try await downloadPlugin(listing)
                
                // Update status
                installationStatus[listing.id] = .installing
                
                // Verify signature if required
                if configuration.verifySignatures {
                    try await verifyPluginSignature(at: downloadedURL, signature: listing.signature)
                }
                
                // Install plugin
                try await installDownloadedPlugin(at: downloadedURL, listing: listing)
                
                // Update status
                installationStatus[listing.id] = .installed(version: listing.version)
                installedPlugins.insert(listing.id)
                
                logger.info("Successfully installed plugin: \(listing.name)")
            } catch {
                installationStatus[listing.id] = .failed(error: error)
                logger.error("Failed to install plugin \(listing.name): \(error)")
                throw error
            }
        }
        
        downloadTasks[listing.id] = task
        try await task.value
        downloadTasks.removeValue(forKey: listing.id)
    }
    
    /// Uninstall a plugin
    public func uninstallPlugin(_ pluginId: String) async throws {
        logger.info("Uninstalling plugin: \(pluginId)")
        
        // Uninstall from plugin manager
        await pluginManager.uninstallPlugin(pluginId)
        
        // Update status
        installedPlugins.remove(pluginId)
        installationStatus[pluginId] = .notInstalled
        
        // Remove from disk
        let installPath = getInstallPath(for: pluginId)
        try? FileManager.default.removeItem(at: installPath)
        
        logger.info("Successfully uninstalled plugin: \(pluginId)")
    }
    
    /// Update a plugin
    public func updatePlugin(_ listing: PluginListing) async throws {
        // First uninstall old version
        try await uninstallPlugin(listing.id)
        
        // Then install new version
        try await installPlugin(listing)
    }
    
    /// Check for updates
    public func checkForUpdates() async throws {
        logger.info("Checking for plugin updates")
        
        // Refresh plugin list
        try await refreshPlugins()
        
        // Check each installed plugin
        for pluginId in installedPlugins {
            if let listing = availablePlugins.first(where: { $0.id == pluginId }),
               let plugin = pluginManager.plugin(withIdentifier: pluginId) {
                // Compare versions
                if isNewerVersion(listing.version, than: plugin.pluginVersion) {
                    installationStatus[pluginId] = .updateAvailable(
                        currentVersion: plugin.pluginVersion,
                        newVersion: listing.version
                    )
                }
            }
        }
    }
    
    /// Cancel installation
    public func cancelInstallation(_ pluginId: String) {
        if let task = downloadTasks[pluginId] {
            task.cancel()
            downloadTasks.removeValue(forKey: pluginId)
            installationStatus[pluginId] = .notInstalled
        }
    }
    
    // MARK: - Private Methods
    
    private func setupMarketplace() {
        // Create cache directory
        try? FileManager.default.createDirectory(
            at: configuration.cacheDirectory,
            withIntermediateDirectories: true
        )
        
        // Load installed plugins
        loadInstalledPlugins()
        
        // Setup update check timer
        updateCheckTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.updateCheckInterval,
            repeats: true
        ) { _ in
            Task {
                try? await self.checkForUpdates()
            }
        }
        
        // Initial load
        Task {
            try? await refreshPlugins()
        }
    }
    
    private func loadInstalledPlugins() {
        // Get installed plugins from plugin manager
        installedPlugins = Set(pluginManager.allPlugins.map { $0.identifier })
        
        // Set initial status
        for pluginId in installedPlugins {
            if let plugin = pluginManager.plugin(withIdentifier: pluginId) {
                installationStatus[pluginId] = .installed(version: plugin.pluginVersion)
            }
        }
    }
    
    private func updateInstallationStatus() async {
        for plugin in availablePlugins {
            if installedPlugins.contains(plugin.id) {
                // Check if update is available
                if let installedPlugin = pluginManager.plugin(withIdentifier: plugin.id) {
                    if isNewerVersion(plugin.version, than: installedPlugin.pluginVersion) {
                        installationStatus[plugin.id] = .updateAvailable(
                            currentVersion: installedPlugin.pluginVersion,
                            newVersion: plugin.version
                        )
                    } else {
                        installationStatus[plugin.id] = .installed(version: installedPlugin.pluginVersion)
                    }
                }
            } else if installationStatus[plugin.id] == nil {
                installationStatus[plugin.id] = .notInstalled
            }
        }
    }
    
    private func downloadPlugin(_ listing: PluginListing) async throws -> URL {
        let destinationURL = configuration.cacheDirectory
            .appendingPathComponent("\(listing.id)-\(listing.version).plugin")
        
        // Check if already cached
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            logger.info("Using cached plugin: \(listing.id)")
            return destinationURL
        }
        
        // Download with progress
        let listingId = listing.id
        return try await networkManager.download(
            from: listing.downloadURL,
            to: destinationURL
        ) { progress in
            Task { @MainActor in
                self.installationStatus[listingId] = .downloading(progress: progress)
            }
        }
    }
    
    private func verifyPluginSignature(at _: URL, signature: String?) async throws {
        guard signature != nil else {
            throw PluginMarketplaceError.invalidSignature("No signature provided")
        }
        
        // In a real implementation, this would verify the plugin's cryptographic signature
        logger.info("Verifying plugin signature")
        
        // Placeholder verification
        // throw PluginMarketplaceError.invalidSignature("Signature verification failed")
    }
    
    private func installDownloadedPlugin(at url: URL, listing: PluginListing) async throws {
        let installPath = getInstallPath(for: listing.id)
        
        // Create plugin directory
        try FileManager.default.createDirectory(
            at: installPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        // Extract/copy plugin
        if url.pathExtension == "zip" {
            // Extract zip file
            try await extractPlugin(from: url, to: installPath)
        } else {
            // Copy plugin bundle
            try FileManager.default.copyItem(at: url, to: installPath)
        }
        
        // Load plugin into manager
        await pluginManager.loadPluginsFromDirectory(installPath.deletingLastPathComponent())
    }
    
    private func extractPlugin(from zipURL: URL, to destinationURL: URL) async throws {
        // In a real implementation, this would extract a zip file
        // For now, we'll use a simple file copy
        try FileManager.default.copyItem(at: zipURL, to: destinationURL)
    }
    
    private func getInstallPath(for pluginId: String) -> URL {
        let pluginsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CodeEditor/Plugins")
        
        return pluginsDirectory.appendingPathComponent("\(pluginId).codeeditorplugin")
    }
    
    private func isNewerVersion(_ version1: String, than version2: String) -> Bool {
        // Simple version comparison - in production use a proper semver library
        version1.compare(version2, options: .numeric) == .orderedDescending
    }
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - Network Manager

/// Network manager for plugin downloads
private final class PluginNetworkManager: Sendable {
    private let session: URLSession
    private let logger = Logger(subsystem: "CodeEditorPlugin", category: "PluginNetworkManager")
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 2
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        
        self.session = URLSession(configuration: configuration)
    }
    
    nonisolated func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PluginMarketplaceError.networkError("Invalid response")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
    
    nonisolated func download(
        from url: URL,
        to destinationURL: URL,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        // In a real implementation, we'd use URLSessionDownloadDelegate for progress
        // For now, simulate progress
        progressHandler(0.5)
        
        let (tempURL, response) = try await session.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PluginMarketplaceError.networkError("Download failed")
        }
        
        progressHandler(0.9)
        
        // Move to destination
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        
        progressHandler(1.0)
        
        return destinationURL
    }
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - Plugin Errors

public enum PluginMarketplaceError: LocalizedError {
    case notFound(pluginId: String)
    case alreadyRegistered(pluginId: String)
    case incompatible(pluginId: String, reason: String)
    case activationFailed(pluginId: String, underlying: Error)
    case loadingFailed(pluginPath: String, underlying: Error)
    case invalidSignature(String)
    case networkError(String)
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .notFound(let pluginId):
            return "Plugin not found: \(pluginId)"

        case .alreadyRegistered(let pluginId):
            return "Plugin already registered: \(pluginId)"

        case let .incompatible(pluginId, reason):
            return "Plugin \(pluginId) is incompatible: \(reason)"

        case let .activationFailed(pluginId, error):
            return "Failed to activate plugin \(pluginId): \(error.localizedDescription)"

        case let .loadingFailed(path, error):
            return "Failed to load plugin from \(path): \(error.localizedDescription)"

        case .invalidSignature(let message):
            return "Invalid plugin signature: \(message)"

        case .networkError(let message):
            return "Network error: \(message)"

        case .unknown:
            return "Unknown plugin error"
        }
    }
}

// MARK: - Plugin Manifest

/// Plugin manifest structure for loading from disk
struct MarketplacePluginManifest: Codable {
    let identifier: String
    let name: String
    let version: String
    let author: String
    let description: String
    let mainClass: String
    let supportedLanguages: [String]
    let requiredCapabilities: [String]
    let minimumEditorVersion: String
}
