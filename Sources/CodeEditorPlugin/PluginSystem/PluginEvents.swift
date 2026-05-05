import Foundation

/// Base protocol for plugin events
@available(macOS 13.0, iOS 16.0, *)
protocol PluginEvent: Sendable {
    var eventId: UUID { get }
    var eventTimestamp: Date { get }
}

/// Plugin lifecycle events
@available(macOS 13.0, iOS 16.0, *)
struct PluginLifecycleEvent: PluginEvent {
    enum EventType: Sendable {
        case activated(pluginId: String)
        case deactivated(pluginId: String)
        case failed(pluginId: String, error: Error)
    }

    let type: EventType
    let eventId = UUID()
    let eventTimestamp = Date()

    init(type: EventType) {
        self.type = type
    }
}

/// Plugin discovery events
@available(macOS 13.0, iOS 16.0, *)
struct PluginDiscoveryEvent: PluginEvent {
    let discovered: [String]
    let loaded: [String]
    let failed: [String: Error]
    let eventId = UUID()
    let eventTimestamp = Date()

    init(discovered: [String], loaded: [String], failed: [String: Error]) {
        self.discovered = discovered
        self.loaded = loaded
        self.failed = failed
    }
}

/// Plugin command events
@available(macOS 13.0, iOS 16.0, *)
struct PluginCommandEvent: PluginEvent {
    enum EventType: Sendable {
        case registered(pluginId: String, commandId: String)
        case executed(pluginId: String, commandId: String)
        case failed(pluginId: String, commandId: String, error: Error)
    }

    let type: EventType
    let eventId = UUID()
    let eventTimestamp = Date()

    init(type: EventType) {
        self.type = type
    }
}

/// Plugin diagnostic events
@available(macOS 13.0, iOS 16.0, *)
struct PluginDiagnosticEvent: PluginEvent {
    let pluginId: String
    let diagnostics: [PluginDiagnostic]
    let eventId = UUID()
    let eventTimestamp = Date()

    init(pluginId: String, diagnostics: [PluginDiagnostic]) {
        self.pluginId = pluginId
        self.diagnostics = diagnostics
    }
}

/// Plugin diagnostic information
@available(macOS 13.0, iOS 16.0, *)
struct PluginDiagnostic: Sendable {
    enum Severity: Int, Sendable {
        case error = 1
        case warning = 2
        case info = 3
        case hint = 4
    }

    let range: NSRange
    let severity: Severity
    let message: String
    let code: String?
    let source: String?

    init(
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
