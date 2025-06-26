import Foundation

// MARK: - Plugin Error Types

/// Plugin system errors
public enum PluginError: LocalizedError, Sendable {
    case notFound(pluginId: String)
    case alreadyRegistered(pluginId: String)
    case incompatible(pluginId: String, reason: String)
    case activationFailed(pluginId: String, underlying: Error)
    case loadingFailed(pluginPath: String, underlying: Error)
    case configurationError(pluginId: String, message: String)
    case dependencyMissing(pluginId: String, dependency: String)
    case unsupportedOperation(String)
    
    public var errorDescription: String? {
        switch self {
        case .notFound(let pluginId):
            return "Plugin not found: \(pluginId)"

        case .alreadyRegistered(let pluginId):
            return "Plugin already registered: \(pluginId)"

        case let .incompatible(pluginId, reason):
            return "Plugin \(pluginId) is incompatible: \(reason)"

        case let .activationFailed(pluginId, underlying):
            return "Failed to activate plugin \(pluginId): \(underlying.localizedDescription)"

        case let .loadingFailed(pluginPath, underlying):
            return "Failed to load plugin from \(pluginPath): \(underlying.localizedDescription)"

        case let .configurationError(pluginId, message):
            return "Plugin \(pluginId) configuration error: \(message)"

        case let .dependencyMissing(pluginId, dependency):
            return "Plugin \(pluginId) is missing dependency: \(dependency)"

        case .unsupportedOperation(let message):
            return "Unsupported operation: \(message)"
        }
    }
}

// MARK: - Plugin Performance Statistics

/// Performance statistics for a plugin
public struct PluginPerformanceStatistics: Sendable {
    public let overallScore: Double
    public let startupTime: TimeInterval
    public let memoryUsage: Double // in MB
    public let errorCount: Int
    
    public init(overallScore: Double, startupTime: TimeInterval, memoryUsage: Double, errorCount: Int) {
        self.overallScore = overallScore
        self.startupTime = startupTime
        self.memoryUsage = memoryUsage
        self.errorCount = errorCount
    }
}

// MARK: - Plugin Manifest

/// Plugin manifest for dynamic loading
public struct PluginManifest: Codable, Sendable {
    /// Unique plugin identifier
    public let identifier: String
    
    /// Display name
    public let displayName: String
    
    /// Plugin version
    public let version: String
    
    /// Minimum required editor version
    public let requiredEditorVersion: String
    
    /// Plugin author
    public let author: String
    
    /// Plugin description
    public let description: String
    
    /// Plugin license
    public let license: String
    
    /// Supported file extensions
    public let fileExtensions: [String]
    
    /// Plugin capabilities
    public let capabilities: PluginCapabilities
    
    /// Entry point for the plugin
    public let entryPoint: PluginEntryPoint
    
    /// Dependencies
    public let dependencies: [PluginDependency]
    
    /// Language server configuration (optional)
    public let languageServerConfig: LanguageServerConfig?
    
    public init(
        identifier: String,
        displayName: String,
        version: String,
        requiredEditorVersion: String,
        author: String,
        description: String,
        license: String,
        fileExtensions: [String],
        capabilities: PluginCapabilities,
        entryPoint: PluginEntryPoint,
        dependencies: [PluginDependency] = [],
        languageServerConfig: LanguageServerConfig? = nil
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.version = version
        self.requiredEditorVersion = requiredEditorVersion
        self.author = author
        self.description = description
        self.license = license
        self.fileExtensions = fileExtensions
        self.capabilities = capabilities
        self.entryPoint = entryPoint
        self.dependencies = dependencies
        self.languageServerConfig = languageServerConfig
    }
}

// MARK: - Plugin Entry Point

/// Plugin entry point configuration
public struct PluginEntryPoint: Codable, Sendable {
    /// Type of plugin
    public let type: PluginType
    
    /// Entry script or class name
    public let entry: String
    
    /// Runtime environment
    public let runtime: PluginRuntime
    
    public init(type: PluginType, entry: String, runtime: PluginRuntime) {
        self.type = type
        self.entry = entry
        self.runtime = runtime
    }
}

/// Plugin types
public enum PluginType: String, Codable, CaseIterable, Sendable {
    case swift
    case javascript
    case python
    case executable
    case languageServer = "lsp"
}

/// Plugin runtime environments
public enum PluginRuntime: String, Codable, CaseIterable, Sendable {
    case native
    case javascript
    case python
    case process
}

// MARK: - Plugin Dependencies

/// Plugin dependency
public struct PluginDependency: Codable, Sendable {
    /// Dependency identifier
    public let identifier: String
    
    /// Minimum version requirement
    public let minimumVersion: String
    
    /// Whether the dependency is optional
    public let isOptional: Bool
    
    public init(identifier: String, minimumVersion: String, isOptional: Bool = false) {
        self.identifier = identifier
        self.minimumVersion = minimumVersion
        self.isOptional = isOptional
    }
}

// MARK: - Text Edit

/// Represents a text edit operation
public struct TextEdit: Equatable, Codable, Sendable {
    /// Range to replace
    public let range: NSRange
    
    /// New text to insert
    public let newText: String
    
    /// Description of the edit
    public let description: String?
    
    public init(range: NSRange, newText: String, description: String? = nil) {
        self.range = range
        self.newText = newText
        self.description = description
    }
}

// MARK: - Plugin Registry Events

/// Plugin registry event types
public enum PluginRegistryEvent: Sendable {
    case pluginRegistered(identifier: String)
    case pluginUnregistered(identifier: String)
    case pluginActivated(identifier: String)
    case pluginDeactivated(identifier: String)
    case pluginError(identifier: String, error: PluginError)
}

// MARK: - Plugin Utilities

/// Utility functions for plugin system
public enum PluginUtilities {
    /// Compare semantic versions
    public static func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(v1Components.count, v2Components.count)
        
        for index in 0..<maxCount {
            let v1Part = index < v1Components.count ? v1Components[index] : 0
            let v2Part = index < v2Components.count ? v2Components[index] : 0
            
            if v1Part < v2Part {
                return .orderedAscending
            } else if v1Part > v2Part {
                return .orderedDescending
            }
        }
        
        return .orderedSame
    }
    
    /// Check if a version meets minimum requirements
    public static func versionMeetsRequirement(_ version: String, minimum: String) -> Bool {
        compareVersions(version, minimum) != .orderedAscending
    }
    
    /// Get plugin directory URLs
    public static func defaultPluginDirectories() -> [URL] {
        var directories: [URL] = []
        
        // Application support directory
        if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let pluginDir = appSupportURL.appendingPathComponent("CodeEditor/Plugins")
            directories.append(pluginDir)
        }
        
        // User home directory
        let homeDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codeeditor/plugins")
        directories.append(homeDir)
        
        // Bundle resources directory
        if let bundleURL = Bundle.main.resourceURL {
            let bundlePlugins = bundleURL.appendingPathComponent("Plugins")
            directories.append(bundlePlugins)
        }
        
        return directories
    }
}
