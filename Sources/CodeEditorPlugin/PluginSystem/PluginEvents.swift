import Foundation

/// Base protocol for plugin events
@available(macOS 13.0, iOS 16.0, *)
public protocol PluginEvent: Sendable {
    var eventId: UUID { get }
    var eventTimestamp: Date { get }
}

/// Plugin lifecycle events
@available(macOS 13.0, iOS 16.0, *)
public struct PluginLifecycleEvent: PluginEvent {
    public enum EventType: Sendable {
        case activated(pluginId: String)
        case deactivated(pluginId: String)
        case failed(pluginId: String, error: Error)
    }
    
    public let type: EventType
    public let eventId = UUID()
    public let eventTimestamp = Date()
    
    public init(type: EventType) {
        self.type = type
    }
}

/// Plugin discovery events
@available(macOS 13.0, iOS 16.0, *)
public struct PluginDiscoveryEvent: PluginEvent {
    public let discovered: [String]
    public let loaded: [String]
    public let failed: [String: Error]
    public let eventId = UUID()
    public let eventTimestamp = Date()
    
    public init(discovered: [String], loaded: [String], failed: [String: Error]) {
        self.discovered = discovered
        self.loaded = loaded
        self.failed = failed
    }
}

/// Plugin command events
@available(macOS 13.0, iOS 16.0, *)
public struct PluginCommandEvent: PluginEvent {
    public enum EventType: Sendable {
        case registered(pluginId: String, commandId: String)
        case executed(pluginId: String, commandId: String)
        case failed(pluginId: String, commandId: String, error: Error)
    }
    
    public let type: EventType
    public let eventId = UUID()
    public let eventTimestamp = Date()
    
    public init(type: EventType) {
        self.type = type
    }
}

/// Plugin diagnostic events
@available(macOS 13.0, iOS 16.0, *)
public struct PluginDiagnosticEvent: PluginEvent {
    public let pluginId: String
    public let diagnostics: [PluginDiagnostic]
    public let eventId = UUID()
    public let eventTimestamp = Date()
    
    public init(pluginId: String, diagnostics: [PluginDiagnostic]) {
        self.pluginId = pluginId
        self.diagnostics = diagnostics
    }
}

/// Plugin diagnostic information
@available(macOS 13.0, iOS 16.0, *)
public struct PluginDiagnostic: Sendable {
    public enum Severity: Int, Sendable {
        case error = 1
        case warning = 2
        case info = 3
        case hint = 4
    }
    
    public let range: NSRange
    public let severity: Severity
    public let message: String
    public let code: String?
    public let source: String?
    
    public init(
        range: NSRange,
        severity: Severity,
        message: String,
        code: String? = nil,
        source: String? = nil
    ) {
        self.range = range
        self.severity = severity
        self.message = message
        self.code = code
        self.source = source
    }
}

// Plugin events are now independent of EditorEvent
// They can be bridged through the UnifiedEventSystem when needed
