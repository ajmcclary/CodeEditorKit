import Foundation

/// A Sendable performance metric
@available(macOS 13.0, iOS 16.0, *)
public struct SendablePerformanceMetric: Sendable {
    public let name: String
    public let duration: Duration
    public let metadata: [String: String]
    public let timestamp: Date

    public init(
        name: String,
        duration: Duration,
        metadata: [String: String] = [:]
    ) {
        self.name = name
        self.duration = duration
        self.metadata = metadata
        self.timestamp = Date()
    }
}

/// A Sendable file change notification
@available(macOS 13.0, iOS 16.0, *)
public struct FileChangeNotification: Sendable {
    public enum ChangeType: Sendable {
        case created
        case modified
        case deleted
        case renamed(from: String, to: String)
    }

    public let path: String
    public let changeType: ChangeType
    public let timestamp: Date

    public init(path: String, changeType: ChangeType) {
        self.path = path
        self.changeType = changeType
        self.timestamp = Date()
    }
}
