import Foundation

/// Core protocol that all plugins must implement
///
/// This protocol defines the basic contract for CodeEditorPlugin extensions,
/// providing lifecycle methods and metadata requirements.
///
/// ## Example Implementation
///
/// ```swift
/// final class MyLanguagePlugin: Plugin {
///     static let identifier = "com.example.mylanguage"
///     
///     var metadata: PluginMetadata {
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
///     init() {}
///     
///     func activate(context: PluginContext) async throws {
///         // Register language provider
///         let provider = MyLanguageProvider()
///         try await context.languageRegistry.register(provider, for: .custom("mylang"))
///     }
///     
///     func deactivate(context: PluginContext) async throws {
///         // Cleanup resources
///         try await context.languageRegistry.unregister(for: .custom("mylang"))
///     }
/// }
/// ```
@available(macOS 13.0, iOS 16.0, *)
protocol Plugin: AnyObject, Sendable {
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
extension Plugin {
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
struct PluginMetadata: Sendable, Codable {
    /// Unique identifier (reverse DNS recommended)
    let identifier: String

    /// Human-readable name
    let name: String

    /// Semantic version string (e.g., "1.0.0")
    let version: String

    /// Plugin author or organization
    let author: String

    /// Brief description of the plugin's functionality
    let description: String

    /// Plugin capabilities
    let capabilities: Set<PluginCapability>

    /// Minimum CodeEditorPlugin version required
    let minimumHostVersion: String?

    /// Other plugins this plugin depends on
    let dependencies: [PluginDependency]

    /// Platform requirements
    let platforms: Set<PluginPlatform>

    /// URL for more information
    let infoURL: URL?

    /// Whether the plugin is enabled by default
    let enabledByDefault: Bool

    init(
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
struct PluginCapability: Hashable, Sendable, Codable, RawRepresentable {
    let rawValue: String

    /// Plugin provides syntax highlighting
    static let syntaxHighlighting = Self(rawValue: "syntaxHighlighting")

    /// Plugin provides code completion
    static let codeCompletion = Self(rawValue: "codeCompletion")

    /// Plugin provides code formatting
    static let codeFormatting = Self(rawValue: "codeFormatting")

    /// Plugin provides code folding
    static let codeFolding = Self(rawValue: "codeFolding")

    /// Plugin provides error diagnostics
    static let diagnostics = Self(rawValue: "diagnostics")

    /// Plugin provides custom themes
    static let theming = Self(rawValue: "theming")

    /// Plugin provides custom commands
    static let commands = Self(rawValue: "commands")

    /// Plugin provides language server protocol support
    static let languageServer = Self(rawValue: "languageServer")
}

// MARK: - Plugin Dependencies

/// Represents a dependency on another plugin
@available(macOS 13.0, iOS 16.0, *)
struct PluginDependency: Sendable, Codable {
    /// Identifier of the required plugin
    let identifier: String

    /// Minimum version required (nil means any version)
    let minimumVersion: String?

    /// Whether the dependency is optional
    let optional: Bool

    init(identifier: String, minimumVersion: String? = nil, optional: Bool = false) {
        self.identifier = identifier
        self.minimumVersion = minimumVersion
        self.optional = optional
    }
}

// MARK: - Plugin Platforms

/// Supported platforms for a plugin
@available(macOS 13.0, iOS 16.0, *)
struct PluginPlatform: Hashable, Sendable, Codable, RawRepresentable {
    let rawValue: String

    static let macOS = Self(rawValue: "macOS")
    static let iOS = Self(rawValue: "iOS")
    static let catalyst = Self(rawValue: "catalyst")
    static let visionOS = Self(rawValue: "visionOS")
}

// MARK: - Plugin State

/// State that can be persisted for a plugin
@available(macOS 13.0, iOS 16.0, *)
struct PluginState: Sendable, Codable {
    /// String key-value pairs
    var strings: [String: String]

    /// Boolean key-value pairs
    var booleans: [String: Bool]

    /// Integer key-value pairs
    var integers: [String: Int]

    /// Double key-value pairs
    var doubles: [String: Double]

    /// Data key-value pairs
    var data: [String: Data]

    /// Array of string arrays
    var stringArrays: [String: [String]]

    /// Last saved timestamp
    let lastSaved: Date

    init(
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
enum PluginError: Error, LocalizedError {
    case incompatibleVersion(required: String, current: String)
    case missingDependency(identifier: String)
    case activationFailed(reason: String)
    case deactivationFailed(reason: String)
    case unsupportedPlatform(PluginPlatform)
    case invalidMetadata(String)
    case alreadyRegistered(identifier: String)
    case notFound(identifier: String)
    case securityViolation(String)

    var errorDescription: String? {
        switch self {
        case let .incompatibleVersion(required, current):
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
