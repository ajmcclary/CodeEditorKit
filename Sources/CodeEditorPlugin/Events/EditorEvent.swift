import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Events emitted by the code editor
public enum EditorEvent: Sendable {
    // Text events
    case textDidChange(String)
    case textWillChange(range: NSRange, replacement: String)
    case textSelectionDidChange(NSRange)
    
    // Editor lifecycle
    case didBecomeFirstResponder
    case didResignFirstResponder
    
    // Completion
    case completionRequested(context: CompletionContext)
    case completionItemSelected(any CompletionItem)
    
    // Annotations  
    case annotationHovered(annotationId: String)
    case annotationClicked(annotationId: String)
    
    // Performance
    case performanceWarning(message: String)
    
    // Errors
    case error(Error)
}

/// Protocol for handling editor events
@MainActor
public protocol EditorEventHandler: AnyObject, Sendable {
    func handle(_ event: EditorEvent)
}

/// Simple closure-based event handler
@MainActor
public final class ClosureEventHandler: EditorEventHandler, @unchecked Sendable {
    private let handler: @Sendable (EditorEvent) -> Void
    
    public init(_ handler: @escaping @Sendable (EditorEvent) -> Void) {
        self.handler = handler
    }
    
    public func handle(_ event: EditorEvent) {
        handler(event)
    }
}

/// Publisher for editor events using Combine
@available(macOS 10.15, iOS 13.0, *)
public final class EditorEventPublisher: @unchecked Sendable {
    private let lock = NSLock()
    private var handlers: [ObjectIdentifier: WeakHandler] = [:]
    
    public init() {}
    
    /// Subscribe to editor events
    public func subscribe(_ handler: any EditorEventHandler) {
        let id = ObjectIdentifier(handler)
        lock.lock()
        defer { lock.unlock() }
        handlers[id] = WeakHandler(handler)
    }
    
    /// Unsubscribe from editor events
    public func unsubscribe(_ handler: any EditorEventHandler) {
        let id = ObjectIdentifier(handler)
        lock.lock()
        defer { lock.unlock() }
        handlers.removeValue(forKey: id)
    }
    
    /// Publish an event to all subscribers
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
    
    /// Remove all handlers
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
    
    nonisolated func request(_ demand: Subscribers.Demand) {
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
        
        if let wrapper = wrapper {
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
