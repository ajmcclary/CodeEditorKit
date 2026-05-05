import Foundation

/// Discovers and loads plugins from designated directories
@available(macOS 13.0, iOS 16.0, *)
@MainActor
final class PluginLoader {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "PluginLoader")
    private let fileManager = FileManager.default

    /// Plugin search paths in order of priority
    var searchPaths: [URL] {
        var paths: [URL] = []

        // User plugins directory
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            paths.append(appSupport.appendingPathComponent("CodeEditorPlugin/Plugins"))
        }

        // App bundle plugins
        if let bundlePath = Bundle.main.url(forResource: "PlugIns", withExtension: nil) {
            paths.append(bundlePath)
        }

        // Framework bundle plugins (for built-in plugins)
        if let frameworkBundle = Bundle(for: CodeEditorView.self).url(forResource: "BuiltInPlugins", withExtension: nil) {
            paths.append(frameworkBundle)
        }

        return paths
    }

    /// Discover available plugins
    /// - Returns: Array of discovered plugin bundles
    func discoverPlugins() async -> [PluginBundle] {
        var discoveredPlugins: [PluginBundle] = []

        for searchPath in searchPaths {
            guard fileManager.fileExists(atPath: searchPath.path) else { continue }

            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: searchPath,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: .skipsHiddenFiles
                )

                for url in contents {
                    if let bundle = try? loadPluginBundle(at: url) {
                        discoveredPlugins.append(bundle)
                        logger.info("Discovered plugin: \(bundle.metadata.identifier)")
                    }
                }
            } catch {
                logger.error("Failed to scan directory \(searchPath): \(error)")
            }
        }

        return discoveredPlugins
    }

    /// Load a plugin bundle from a URL
    /// - Parameter url: URL to the plugin bundle
    /// - Returns: Loaded plugin bundle
    private func loadPluginBundle(at url: URL) throws -> PluginBundle {
        // Check if it's a directory with proper extension
        guard url.pathExtension == "codeeditorplugin" else {
            throw PluginLoaderError.invalidBundleFormat
        }

        // Load manifest
        let manifestURL = url.appendingPathComponent("plugin.json")
        guard let manifestData = try? Data(contentsOf: manifestURL) else {
            throw PluginLoaderError.missingManifest
        }

        let manifest = try JSONDecoder().decode(PluginManifest.self, from: manifestData)

        // Convert manifest to metadata
        let metadata = PluginMetadata(
            identifier: manifest.identifier,
            name: manifest.name,
            version: manifest.version,
            author: manifest.author,
            description: manifest.description,
            capabilities: Set(manifest.capabilities.map { PluginCapability(rawValue: $0) }),
            minimumHostVersion: manifest.minimumHostVersion,
            dependencies: manifest.dependencies.map {
                PluginDependency(
                    identifier: $0.identifier,
                    minimumVersion: $0.minimumVersion,
                    optional: $0.optional
                )
            },
            platforms: Set(manifest.platforms.map { PluginPlatform(rawValue: $0) }),
            infoURL: manifest.infoURL.flatMap { URL(string: $0) },
            enabledByDefault: manifest.enabledByDefault
        )

        // Create plugin bundle
        return PluginBundle(
            url: url,
            metadata: metadata,
            manifest: manifest
        )
    }

    /// Install a plugin from a URL
    /// - Parameter sourceURL: URL to the plugin bundle to install
    /// - Returns: Installed plugin bundle
    func installPlugin(from sourceURL: URL) async throws -> PluginBundle {
        // Load the bundle first to validate
        let bundle = try loadPluginBundle(at: sourceURL)

        // Verify signature if required
        if kRequiresPluginSigning {
            try await verifyPluginSignature(bundle)
        }

        // Create user plugins directory if needed
        guard let userPluginsPath = searchPaths.first else {
            throw PluginLoaderError.noInstallLocation
        }

        try fileManager.createDirectory(at: userPluginsPath, withIntermediateDirectories: true)

        // Copy to user plugins directory
        let destinationURL = userPluginsPath.appendingPathComponent(sourceURL.lastPathComponent)

        // Remove existing if present
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        // Copy plugin bundle
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        logger.info("Installed plugin \(bundle.metadata.identifier) to \(destinationURL)")

        // Return installed bundle
        return PluginBundle(
            url: destinationURL,
            metadata: bundle.metadata,
            manifest: bundle.manifest
        )
    }

    /// Uninstall a plugin
    /// - Parameter identifier: Plugin identifier to uninstall
    func uninstallPlugin(identifier: String) async throws {
        // Find the plugin
        let plugins = await discoverPlugins()
        guard let plugin = plugins.first(where: { $0.metadata.identifier == identifier }) else {
            throw PluginLoaderError.pluginNotFound(identifier)
        }

        // Only allow uninstalling user-installed plugins
        guard let userPluginsPath = searchPaths.first,
              plugin.url.path.hasPrefix(userPluginsPath.path) else {
            throw PluginLoaderError.cannotUninstallBuiltIn
        }

        // Remove the plugin bundle
        try fileManager.removeItem(at: plugin.url)

        logger.info("Uninstalled plugin: \(identifier)")
    }

    /// Verify plugin signature
    private func verifyPluginSignature(_ bundle: PluginBundle) async throws {
        // This would implement actual code signing verification
        // For now, it's a placeholder
        logger.debug("Verifying signature for \(bundle.metadata.identifier)")

        // In production, this would:
        // 1. Check code signature
        // 2. Verify developer certificate
        // 3. Check notarization (on macOS)
        // 4. Validate bundle integrity
    }
}

// MARK: - Supporting Types

/// Represents a discovered plugin bundle
@available(macOS 13.0, iOS 16.0, *)
struct PluginBundle {
    /// URL to the plugin bundle
    let url: URL

    /// Plugin metadata
    let metadata: PluginMetadata

    /// Original manifest
    let manifest: PluginManifest
}

/// Plugin manifest format (plugin.json)
@available(macOS 13.0, iOS 16.0, *)
struct PluginManifest: Codable {
    let identifier: String
    let name: String
    let version: String
    let author: String
    let description: String
    let mainClass: String
    let capabilities: [String]
    let minimumHostVersion: String?
    let dependencies: [ManifestDependency]
    let platforms: [String]
    let infoURL: String?
    let enabledByDefault: Bool
    let permissions: [String]
    let resources: [String]

    private enum CodingKeys: String, CodingKey {
        case identifier, name, version, author, description, mainClass
        case capabilities, minimumHostVersion, dependencies, platforms
        case infoURL, enabledByDefault, permissions, resources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .identifier)
        name = try container.decode(String.self, forKey: .name)
        version = try container.decode(String.self, forKey: .version)
        author = try container.decode(String.self, forKey: .author)
        description = try container.decode(String.self, forKey: .description)
        mainClass = try container.decode(String.self, forKey: .mainClass)
        capabilities = try container.decodeIfPresent([String].self, forKey: .capabilities) ?? []
        minimumHostVersion = try container.decodeIfPresent(String.self, forKey: .minimumHostVersion)
        dependencies = try container.decodeIfPresent([ManifestDependency].self, forKey: .dependencies) ?? []
        platforms = try container.decodeIfPresent([String].self, forKey: .platforms) ?? []
        infoURL = try container.decodeIfPresent(String.self, forKey: .infoURL)
        enabledByDefault = try container.decodeIfPresent(Bool.self, forKey: .enabledByDefault) ?? true
        permissions = try container.decodeIfPresent([String].self, forKey: .permissions) ?? []
        resources = try container.decodeIfPresent([String].self, forKey: .resources) ?? []
    }
}

/// Dependency in manifest format
@available(macOS 13.0, iOS 16.0, *)
struct ManifestDependency: Codable {
    let identifier: String
    let minimumVersion: String?
    let optional: Bool

    private enum CodingKeys: String, CodingKey {
        case identifier, minimumVersion, optional
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .identifier)
        minimumVersion = try container.decodeIfPresent(String.self, forKey: .minimumVersion)
        optional = try container.decodeIfPresent(Bool.self, forKey: .optional) ?? false
    }
}

/// Plugin loader errors
@available(macOS 13.0, iOS 16.0, *)
enum PluginLoaderError: Error, LocalizedError {
    case invalidBundleFormat
    case missingManifest
    case invalidManifest(String)
    case noInstallLocation
    case pluginNotFound(String)
    case cannotUninstallBuiltIn
    case signatureVerificationFailed
    case incompatiblePlatform

    var errorDescription: String? {
        switch self {
        case .invalidBundleFormat:
            return "Invalid plugin bundle format"

        case .missingManifest:
            return "Plugin manifest (plugin.json) not found"

        case .invalidManifest(let reason):
            return "Invalid plugin manifest: \(reason)"

        case .noInstallLocation:
            return "No installation location available"

        case .pluginNotFound(let identifier):
            return "Plugin not found: \(identifier)"

        case .cannotUninstallBuiltIn:
            return "Cannot uninstall built-in plugins"

        case .signatureVerificationFailed:
            return "Plugin signature verification failed"

        case .incompatiblePlatform:
            return "Plugin is not compatible with this platform"
        }
    }
}

// MARK: - Configuration

/// Whether plugin signing is required
private let kRequiresPluginSigning: Bool = {
    #if DEBUG
    return false
    #else
    return true
    #endif
}()
