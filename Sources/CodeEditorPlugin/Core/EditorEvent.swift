import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Events emitted by the code editor.
///
/// `EditorEvent` represents all possible events that can occur within the code editor.
/// These events can be observed using the event handling system or through Combine publishers.
///
/// ## Event Categories
///
/// ### Text Events
/// - `textDidChange`: Fired after text content changes
/// - `textWillChange`: Fired before text is modified (allows validation)
/// - `textSelectionDidChange`: Fired when cursor position or selection changes
///
/// ### Editor Lifecycle
/// - `didBecomeFirstResponder`: Editor gained focus
/// - `didResignFirstResponder`: Editor lost focus
///
/// ### Code Completion
/// - `completionRequested`: User triggered completion (manually or automatically)
/// - `completionItemSelected`: User selected a completion item
///
/// ### Annotations
/// - `annotationHovered`: Mouse hovering over an annotation
/// - `annotationClicked`: User clicked on an annotation
///
/// ### System Events
/// - `performanceWarning`: Performance threshold exceeded
/// - `error`: An error occurred during editor operation
///
/// ## Example Usage
///
/// ```swift
/// // Using event handler
/// class MyEventHandler: EditorEventHandler {
///     func handle(_ event: EditorEvent) {
///         switch event {
///         case .textDidChange(let newText):
///             print("Text changed: \(newText)")
///         case .textSelectionDidChange(let range):
///             print("Selection: \(range)")
///         case .error(let error):
///             print("Error: \(error)")
///         default:
///             break
///         }
///     }
/// }
///
/// editor.subscribe(MyEventHandler())
/// ```
///
/// ## Combine Integration
///
/// ```swift
/// editor.eventPublisher.publisher()
///     .sink { event in
///         // Handle all events
///     }
///     .store(in: &cancellables)
///
/// // Type-safe event filtering
/// editor.eventPublisher.publisher(for: TextDidChangeEvent.self)
///     .sink { event in
///         print("Text: \(event.text)")
///     }
///     .store(in: &cancellables)
/// ```
///
/// - SeeAlso: ``EditorEventHandler``, ``EditorEventPublisher``, ``EditorEventType``
public enum EditorEvent: Sendable {
    // Text events

    /// Text content has changed.
    ///
    /// Fired after the text has been modified. The associated value contains
    /// the complete new text content of the editor.
    case textDidChange(String)

    /// Text is about to change.
    ///
    /// Fired before text modification occurs. Can be used for validation.
    /// - Parameters:
    ///   - range: The range of text being replaced
    ///   - replacement: The new text that will replace the range
    case textWillChange(range: NSRange, replacement: String)

    /// Text selection or cursor position has changed.
    ///
    /// Fired whenever the user moves the cursor or changes the selection.
    /// The associated value contains the new selected range.
    case textSelectionDidChange(NSRange)

    // Editor lifecycle

    /// Editor has become the first responder (gained focus).
    ///
    /// Indicates the editor is now active and will receive keyboard input.
    case didBecomeFirstResponder

    /// Editor has resigned first responder (lost focus).
    ///
    /// Indicates the editor is no longer active for keyboard input.
    case didResignFirstResponder

    // Completion

    /// Code completion has been requested.
    ///
    /// Fired when the user triggers completion, either manually or automatically.
    /// The context contains information about the current position and trigger.
    case completionRequested(context: CompletionContext)

    /// A completion item has been selected.
    ///
    /// Fired when the user selects an item from the completion list.
    /// The associated value contains the selected completion item.
    case completionItemSelected(any CompletionItemView)

    // Annotations

    /// Mouse is hovering over an annotation.
    ///
    /// Fired when the mouse enters an annotation's hover area.
    /// The associated value contains the annotation's unique identifier.
    case annotationHovered(annotationId: String)

    /// An annotation has been clicked.
    ///
    /// Fired when the user clicks on an annotation badge or marker.
    /// The associated value contains the annotation's unique identifier.
    case annotationClicked(annotationId: String)

    // Performance

    /// A performance warning has been triggered.
    ///
    /// Fired when the editor detects performance issues, such as slow
    /// syntax highlighting or excessive memory usage.
    case performanceWarning(message: String)

    // Errors

    /// An error occurred during editor operation.
    ///
    /// Fired when any error occurs that doesn't halt editor operation
    /// but should be reported to the user or logged. The payload is a
    /// ``SendableError`` so the event remains `Sendable` when it crosses
    /// actor boundaries (publishers hop events to the main actor).
    case error(SendableError)
}

/// Sendable-safe representation of an error for use in ``EditorEvent/error(_:)``.
///
/// `Swift.Error` is not `Sendable`, so values that need to travel across
/// actor boundaries (the event publisher hops to the main actor) must be
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

// Note: Event handling components are defined in separate files:
// - EditorEventHandler.swift: Event handler protocols and implementations
// - EditorEventPublisher.swift: Event publisher and Combine support
// - EditorEventTypes.swift: Type-safe event extraction
