import Foundation

/// Protocol for typed event extraction
/// Protocol for typed event extraction from editor events.
///
/// `EditorEventType` enables type-safe extraction of specific event types
/// from the generic `EditorEvent` enumeration, supporting reactive programming
/// patterns with Combine and other event handling frameworks.
///
/// ## Example Implementation
///
/// ```swift
/// public struct MyCustomEvent: EditorEventType {
///     public let data: String
///
///     public static func extract(from event: EditorEvent) -> Self? {
///         guard case let .myCustom(data) = event else { return nil }
///         return Self(data: data)
///     }
/// }
/// ```
///
/// - SeeAlso: ``EditorEvent``, ``EditorEventPublisher``
public protocol EditorEventType {
    /// Extract this event type from a generic editor event.
    ///
    /// - Parameter event: The generic editor event to extract from
    /// - Returns: An instance of this event type if extraction succeeds, `nil` otherwise
    static func extract(from event: EditorEvent) -> Self?
}

// Event type implementations
public struct TextDidChangeEvent: EditorEventType {
    public let text: String

    public static func extract(from event: EditorEvent) -> Self? {
        guard case let .textDidChange(text) = event else { return nil }
        return Self(text: text)
    }
}

public struct TextSelectionDidChangeEvent: EditorEventType {
    public let range: NSRange

    public static func extract(from event: EditorEvent) -> Self? {
        guard case let .textSelectionDidChange(range) = event else { return nil }
        return Self(range: range)
    }
}
