import Foundation

/// Sendable-safe representation of an error.
///
/// `Swift.Error` is not `Sendable`, so values that need to travel across
/// actor boundaries (e.g. event publishers hopping to the main actor) must be
/// boxed into a value-typed payload. `SendableError` captures the
/// information call sites actually need — a domain string, a human-readable
/// message, and (when available) the localized description of the source
/// error — without retaining the original instance.
public struct SendableError: Sendable, Hashable, CustomStringConvertible {
    /// Optional domain or category for the error (e.g. `"Highlighting"`,
    /// `"LSP"`). Use this to disambiguate identical messages from
    /// different subsystems.
    public let domain: String?

    /// Short human-readable message describing the error.
    public let message: String

    /// Localized description of the source error, if one existed.
    public let localizedDescription: String?

    public init(message: String, domain: String? = nil, localizedDescription: String? = nil) {
        self.domain = domain
        self.message = message
        self.localizedDescription = localizedDescription
    }

    /// Convenience initializer that wraps any `Error` by capturing its
    /// `localizedDescription`. The source instance is not retained.
    public init(_ error: any Error, domain: String? = nil) {
        self.domain = domain
        self.message = String(describing: error)
        self.localizedDescription = error.localizedDescription
    }

    public var description: String {
        if let domain {
            return "[\(domain)] \(message)"
        }
        return message
    }
}
