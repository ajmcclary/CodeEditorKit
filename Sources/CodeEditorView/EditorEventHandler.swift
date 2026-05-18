import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Protocol for handling editor events.
///
/// Implement this protocol to receive and process events from the code editor.
/// Event handlers are weakly referenced by the editor to prevent retain cycles.
///
/// ## Implementing an Event Handler
///
/// ```swift
/// @MainActor
/// class MyEventHandler: EditorEventHandler {
///     func handle(_ event: EditorEvent) {
///         switch event {
///         case .textDidChange(let text):
///             // Update UI or perform validation
///             validateSyntax(text)
///             
///         case .completionRequested(let context):
///             // Provide custom completions
///             provideCompletions(for: context)
///             
///         case .error(let error):
///             // Log or display errors
///             print("Editor error: \(error)")
///             
///         default:
///             // Handle other events as needed
///             break
///         }
///     }
/// }
/// ```
///
/// ## Registration
///
/// ```swift
/// let handler = MyEventHandler()
/// editor.subscribe(handler)
/// 
/// // Later, to stop receiving events
/// editor.unsubscribe(handler)
/// ```
///
/// - Important: Event handlers must be retained by your code. The editor only
///              keeps weak references to prevent memory leaks.
///
/// - SeeAlso: ``EditorEvent``, ``ClosureEventHandler``, ``EditorEventPublisher``
@MainActor
public protocol EditorEventHandler: AnyObject, Sendable {
    /// Handle an editor event.
    ///
    /// This method is called on the main actor whenever an event occurs.
    /// Implementation should be efficient as it may be called frequently.
    ///
    /// - Parameter event: The event that occurred in the editor
    func handle(_ event: EditorEvent)
}

/// Simple closure-based event handler.
///
/// Provides a convenient way to handle editor events using a closure instead of
/// implementing a full class. Useful for simple event handling scenarios.
///
/// ## Example
///
/// ```swift
/// let handler = ClosureEventHandler { event in
///     switch event {
///     case .textDidChange(let text):
///         print("New text: \(text)")
///     case .error(let error):
///         print("Error: \(error)")
///     default:
///         break
///     }
/// }
///
/// editor.subscribe(handler)
/// ```
///
/// - Note: Remember to retain the handler instance to keep receiving events.
///
/// - SeeAlso: ``EditorEventHandler``, ``EditorEvent``
@MainActor
public final class ClosureEventHandler: EditorEventHandler {
    private let handler: @Sendable (EditorEvent) -> Void

    /// Creates a closure-based event handler.
    ///
    /// - Parameter handler: The closure to call for each event. Must be Sendable
    ///                     to ensure thread safety across actor boundaries.
    public init(_ handler: @escaping @Sendable (EditorEvent) -> Void) {
        self.handler = handler
    }

    public func handle(_ event: EditorEvent) {
        handler(event)
    }
}
