import Foundation

/// Core protocol that all plugins must implement
///
/// This protocol defines the basic contract for CodeEditorPlugin extensions,
/// providing lifecycle methods and metadata requirements.
///
/// ## Example Implementation
///
/// ```swift
/// public final class MyLanguagePlugin: Plugin {
///     public static let identifier = "com.example.mylanguage"
///     
///     public var metadata: PluginMetadata {
///         PluginMetadata(
///             identifier: Self.identifier,
///             name: "My Language Support",
///             version: "1.0.0",
///             author: "Example Corp",
///             description: "Adds support for My Language",
///             capabilities: [.syntaxHighlighting, .codeCompletion]
///         )
///     }
///     
///     public init() {}
///     
///     public func activate(context: PluginContext) async throws {
///         // Register language provider
///         let provider = MyLanguageProvider()
///         try await context.languageRegistry.register(provider, for: .custom("mylang"))
///     }
///     
///     public func deactivate(context: PluginContext) async throws {
///         // Cleanup resources
///         try await context.languageRegistry.unregister(for: .custom("mylang"))
///     }
/// }
/// ```
@available(macOS 13.0, iOS 16.0, *)
public protocol Plugin: AnyObject, Sendable {
    /// Unique identifier for the plugin (reverse DNS recommended)
    static var identifier: String { get }
    
    /// Plugin metadata including version, author, and capabilities
    var metadata: PluginMetadata { get }
    
    /// Required initializer for plugin instantiation
    init()
    
    /// Called when the plugin is activated
    /// - Parameter context: The plugin context providing access to editor APIs
    /// - Throws: Any errors during activation
    func activate(context: PluginContext) async throws
    
    /// Called when the plugin is deactivated
    /// - Parameter context: The plugin context for cleanup
    /// - Throws: Any errors during deactivation
    func deactivate(context: PluginContext) async throws
    
    /// Called when the plugin should save its state
    /// - Returns: Dictionary of state to persist
    func saveState() async -> PluginState
    
    /// Called when the plugin should restore its state
    /// - Parameter state: Previously saved state dictionary
    func restoreState(_ state: PluginState) async
}

// MARK: - Default Implementations

@available(macOS 13.0, iOS 16.0, *)
public extension Plugin {
    /// Default implementation returns empty state
    func saveState() async -> PluginState {
        PluginState()
    }
    
    /// Default implementation does nothing
    func restoreState(_: PluginState) async {
        // No-op by default
    }
}

// MARK: - Plugin Metadata

/// Metadata describing a plugin's capabilities and requirements
@available(macOS 13.0, iOS 16.0, *)
public struct PluginMetadata: Sendable, Codable {
    /// Unique identifier (reverse DNS recommended)
    public let identifier: String
    
    /// Human-readable name
    public let name: String
    
    /// Semantic version string (e.g., "1.0.0")
    public let version: String
    
    /// Plugin author or organization
    public let author: String
    
    /// Brief description of the plugin's functionality
    public let description: String
    
    /// Plugin capabilities
    public let capabilities: Set<PluginCapability>
    
    /// Minimum CodeEditorPlugin version required
    public let minimumHostVersion: String?
    
    /// Other plugins this plugin depends on
    public let dependencies: [PluginDependency]
    
    /// Platform requirements
    public let platforms: Set<PluginPlatform>
    
    /// URL for more information
    public let infoURL: URL?
    
    /// Whether the plugin is enabled by default
    public let enabledByDefault: Bool
    
    public init(
        identifier: String,
        name: String,
        version: String,
        author: String,
        description: String,
        capabilities: Set<PluginCapability> = [],
        minimumHostVersion: String? = nil,
        dependencies: [PluginDependency] = [],
        platforms: Set<PluginPlatform> = [.macOS, .iOS, .catalyst],
        infoURL: URL? = nil,
        enabledByDefault: Bool = true
    ) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.author = author
        self.description = description
        self.capabilities = capabilities
        self.minimumHostVersion = minimumHostVersion
        self.dependencies = dependencies
        self.platforms = platforms
        self.infoURL = infoURL
        self.enabledByDefault = enabledByDefault
    }
}

// MARK: - Plugin Capabilities

/// Capabilities that a plugin can provide
@available(macOS 13.0, iOS 16.0, *)
public struct PluginCapability: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    /// Plugin provides syntax highlighting
    public static let syntaxHighlighting = Self(rawValue: "syntaxHighlighting")
    
    /// Plugin provides code completion
    public static let codeCompletion = Self(rawValue: "codeCompletion")
    
    /// Plugin provides code formatting
    public static let codeFormatting = Self(rawValue: "codeFormatting")
    
    /// Plugin provides code folding
    public static let codeFolding = Self(rawValue: "codeFolding")
    
    /// Plugin provides error diagnostics
    public static let diagnostics = Self(rawValue: "diagnostics")
    
    /// Plugin provides custom themes
    public static let theming = Self(rawValue: "theming")
    
    /// Plugin provides custom commands
    public static let commands = Self(rawValue: "commands")
    
    /// Plugin provides language server protocol support
    public static let languageServer = Self(rawValue: "languageServer")
}

// MARK: - Plugin Dependencies

/// Represents a dependency on another plugin
@available(macOS 13.0, iOS 16.0, *)
public struct PluginDependency: Sendable, Codable {
    /// Identifier of the required plugin
    public let identifier: String
    
    /// Minimum version required (nil means any version)
    public let minimumVersion: String?
    
    /// Whether the dependency is optional
    public let optional: Bool
    
    public init(identifier: String, minimumVersion: String? = nil, optional: Bool = false) {
        self.identifier = identifier
        self.minimumVersion = minimumVersion
        self.optional = optional
    }
}

// MARK: - Plugin Platforms

/// Supported platforms for a plugin
@available(macOS 13.0, iOS 16.0, *)
public struct PluginPlatform: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static let macOS = Self(rawValue: "macOS")
    public static let iOS = Self(rawValue: "iOS")
    public static let catalyst = Self(rawValue: "catalyst")
    public static let visionOS = Self(rawValue: "visionOS")
}

// MARK: - Plugin State

/// State that can be persisted for a plugin
@available(macOS 13.0, iOS 16.0, *)
public struct PluginState: Sendable, Codable {
    /// String key-value pairs
    public var strings: [String: String]
    
    /// Boolean key-value pairs
    public var booleans: [String: Bool]
    
    /// Integer key-value pairs
    public var integers: [String: Int]
    
    /// Double key-value pairs
    public var doubles: [String: Double]
    
    /// Data key-value pairs
    public var data: [String: Data]
    
    /// Array of string arrays
    public var stringArrays: [String: [String]]
    
    /// Last saved timestamp
    public let lastSaved: Date
    
    public init(
        strings: [String: String] = [:],
        booleans: [String: Bool] = [:],
        integers: [String: Int] = [:],
        doubles: [String: Double] = [:],
        data: [String: Data] = [:],
        stringArrays: [String: [String]] = [:],
        lastSaved: Date = Date()
    ) {
        self.strings = strings
        self.booleans = booleans
        self.integers = integers
        self.doubles = doubles
        self.data = data
        self.stringArrays = stringArrays
        self.lastSaved = lastSaved
    }
}

// MARK: - Plugin Errors

/// Errors that can occur in the plugin system
@available(macOS 13.0, iOS 16.0, *)
public enum PluginError: Error, LocalizedError {
    case incompatibleVersion(required: String, current: String)
    case missingDependency(identifier: String)
    case activationFailed(reason: String)
    case deactivationFailed(reason: String)
    case unsupportedPlatform(PluginPlatform)
    case invalidMetadata(String)
    case alreadyRegistered(identifier: String)
    case notFound(identifier: String)
    case securityViolation(String)
    
    public var errorDescription: String? {
        switch self {
        case .incompatibleVersion(let required, let current):
            return "Plugin requires version \(required) but current version is \(current)"

        case .missingDependency(let identifier):
            return "Missing required dependency: \(identifier)"

        case .activationFailed(let reason):
            return "Plugin activation failed: \(reason)"

        case .deactivationFailed(let reason):
            return "Plugin deactivation failed: \(reason)"

        case .unsupportedPlatform(let platform):
            return "Plugin does not support platform: \(platform.rawValue)"

        case .invalidMetadata(let reason):
            return "Invalid plugin metadata: \(reason)"

        case .alreadyRegistered(let identifier):
            return "Plugin already registered: \(identifier)"

        case .notFound(let identifier):
            return "Plugin not found: \(identifier)"

        case .securityViolation(let reason):
            return "Security violation: \(reason)"
        }
    }
}
