import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
///             logger.debug("Text changed: \(newText)")
///         case .textSelectionDidChange(let range):
///             logger.debug("Selection: \(range)")
///         case .error(let error):
///             logger.debug("Error: \(error)")
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
///         logger.debug("Text: \(event.text)")
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
    case completionItemSelected(any CompletionItem)
    
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
    /// but should be reported to the user or logged.
    case error(Error)
}

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
///             logger.error("Editor error: \(error)")
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
///         logger.debug("New text: \(text)")
///     case .error(let error):
///         logger.debug("Error: \(error)")
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
public final class ClosureEventHandler: EditorEventHandler, @unchecked Sendable {
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

/// Publisher for editor events using Combine.
///
/// `EditorEventPublisher` manages event distribution to multiple subscribers
/// and provides Combine integration for reactive event handling. It maintains
/// weak references to handlers to prevent retain cycles.
///
/// ## Basic Usage
///
/// ```swift
/// // Subscribe with event handler
/// let handler = MyEventHandler()
/// eventPublisher.subscribe(handler)
///
/// // Publish events
/// eventPublisher.publish(.textDidChange("new text"))
///
/// // Unsubscribe when done
/// eventPublisher.unsubscribe(handler)
/// ```
///
/// ## Combine Integration
///
/// ```swift
/// // Subscribe to all events
/// eventPublisher.publisher()
///     .sink { event in
///         logger.debug("Event: \(event)")
///     }
///     .store(in: &cancellables)
///
/// // Subscribe to specific event types
/// eventPublisher.publisher(for: TextDidChangeEvent.self)
///     .map { $0.text }
///     .removeDuplicates()
///     .sink { text in
///         logger.debug("Unique text: \(text)")
///     }
///     .store(in: &cancellables)
/// ```
///
/// ## Thread Safety
///
/// The publisher is thread-safe and can be accessed from any thread. Events
/// are always delivered on the main actor to ensure UI safety.
///
/// - SeeAlso: ``EditorEvent``, ``EditorEventHandler``, ``EditorEventType``
@available(macOS 10.15, iOS 13.0, *)
public final class EditorEventPublisher: @unchecked Sendable {
    private let lock = NSLock()
    private var handlers: [ObjectIdentifier: WeakHandler] = [:]
    
    public init() {}
    
    /// Subscribe to editor events.
    ///
    /// Adds an event handler to receive all published events. The handler
    /// is stored as a weak reference to prevent retain cycles.
    ///
    /// - Parameter handler: The event handler to add
    ///
    /// - Note: Handlers must be retained elsewhere or they will be deallocated
    public func subscribe(_ handler: any EditorEventHandler) {
        let id = ObjectIdentifier(handler)
        lock.lock()
        defer { lock.unlock() }
        handlers[id] = WeakHandler(handler)
    }
    
    /// Unsubscribe from editor events.
    ///
    /// Removes an event handler from receiving events.
    ///
    /// - Parameter handler: The event handler to remove
    public func unsubscribe(_ handler: any EditorEventHandler) {
        let id = ObjectIdentifier(handler)
        lock.lock()
        defer { lock.unlock() }
        handlers.removeValue(forKey: id)
    }
    
    /// Publish an event to all subscribers.
    ///
    /// Sends the event to all registered handlers. Events are delivered
    /// asynchronously on the main actor to ensure UI thread safety.
    ///
    /// - Parameter event: The event to publish
    ///
    /// - Note: Handlers that have been deallocated are automatically removed
    public func publish(_ event: EditorEvent) {
        lock.lock()
        let activeHandlers = handlers.values.compactMap { $0.value }
        lock.unlock()
        
        // Publish to all active handlers
        for handler in activeHandlers {
            Task { @MainActor in
                handler.handle(event)
            }
        }
    }
    
    /// Remove all handlers.
    ///
    /// Clears all event subscriptions. Useful for cleanup or reset scenarios.
    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        handlers.removeAll()
    }
}

/// Weak reference wrapper for EditorEventHandler
private final class WeakHandler {
    weak var value: (any EditorEventHandler)?
    
    init(_ value: any EditorEventHandler) {
        self.value = value
    }
}

// MARK: - Combine Support

#if canImport(Combine)
import Combine

@available(macOS 10.15, iOS 13.0, *)
extension EditorEventPublisher {
    /// Create a Combine publisher for editor events
    func publisher() -> AnyPublisher<EditorEvent, Never> {
        EditorEventCombinePublisher(eventPublisher: self)
            .eraseToAnyPublisher()
    }
    
    /// Create a filtered publisher for specific event types
    func publisher<T>(for eventType: T.Type) -> AnyPublisher<T, Never> where T: EditorEventType {
        publisher()
            .compactMap { event in
                eventType.extract(from: event)
            }
            .eraseToAnyPublisher()
    }
}

/// Protocol for typed event extraction
public protocol EditorEventType {
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

/// Combine publisher implementation with Swift 6 concurrency support
@available(macOS 10.15, iOS 13.0, *)
private struct EditorEventCombinePublisher: Publisher, Sendable {
    typealias Output = EditorEvent
    typealias Failure = Never
    
    let eventPublisher: EditorEventPublisher
    
    nonisolated func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Never, S.Input == EditorEvent {
        let subscription = EditorEventSubscription(
            subscriber: subscriber,
            eventPublisher: eventPublisher
        )
        subscriber.receive(subscription: subscription)
    }
}

@available(macOS 10.15, iOS 13.0, *)
private final class EditorEventSubscription<S: Subscriber>: Subscription, @unchecked Sendable
    where S.Input == EditorEvent, S.Failure == Never {
    private let lock = NSLock()
    private var subscriber: S?
    private let eventPublisher: EditorEventPublisher
    private var handlerWrapper: HandlerWrapper?
    private var pendingSetup = true
    
    init(subscriber: S, eventPublisher: EditorEventPublisher) {
        self.subscriber = subscriber
        self.eventPublisher = eventPublisher
    }
    
    private func ensureSetup() {
        guard pendingSetup else { return }
        pendingSetup = false
        
        // Create handler box to avoid capturing generic type
        let box = HandlerBox { [weak self] event in
            self?.handleEvent(event)
        }
        
        // Store references for async setup
        let pub = eventPublisher
        
        // Defer setup to avoid capturing self in init
        DispatchQueue.main.async {
            let wrapper = HandlerWrapper()
            wrapper.handlerBox = box
            pub.subscribe(wrapper)
            
            self.lock.lock()
            self.handlerWrapper = wrapper
            self.lock.unlock()
        }
    }
    
    nonisolated func request(_: Subscribers.Demand) {
        // Ensure setup when subscription is activated
        ensureSetup()
        // Events are pushed, so we don't need to handle demand
    }
    
    nonisolated func cancel() {
        lock.lock()
        subscriber = nil
        let wrapper = handlerWrapper
        handlerWrapper = nil
        lock.unlock()
        
        if let wrapper {
            let pub = eventPublisher
            DispatchQueue.main.async {
                pub.unsubscribe(wrapper)
            }
        }
    }
    
    private func handleEvent(_ event: EditorEvent) {
        lock.lock()
        let sub = subscriber
        lock.unlock()
        
        _ = sub?.receive(event)
    }
    
    // Type-erased handler box to avoid capturing generic types
    private final class HandlerBox: @unchecked Sendable {
        private let handler: (EditorEvent) -> Void
        
        init(handler: @escaping (EditorEvent) -> Void) {
            self.handler = handler
        }
        
        func handle(_ event: EditorEvent) {
            handler(event)
        }
    }
    
    // Wrapper class to handle events on MainActor
    @MainActor
    private final class HandlerWrapper: EditorEventHandler {
        var handlerBox: HandlerBox?
        
        func handle(_ event: EditorEvent) {
            handlerBox?.handle(event)
        }
    }
}
#endif

// Note: Annotation type is defined in Models/Annotation.swift
