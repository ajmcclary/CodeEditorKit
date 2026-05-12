import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

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
///         print("Event: \(event)")
///     }
///     .store(in: &cancellables)
///
/// // Subscribe to specific event types
/// eventPublisher.publisher(for: TextDidChangeEvent.self)
///     .map { $0.text }
///     .removeDuplicates()
///     .sink { text in
///         print("Unique text: \(text)")
///     }
///     .store(in: &cancellables)
/// ```
///
/// ## Thread Safety
///
/// The publisher uses Swift's actor model for thread-safe access. Events
/// are always delivered on the main actor to ensure UI safety.
///
/// - SeeAlso: ``EditorEvent``, ``EditorEventHandler``, ``EditorEventType``
@available(macOS 10.15, iOS 13.0, *)
public actor EditorEventPublisher {
    private var handlers: [ObjectIdentifier: WeakHandler] = [:]

    /// Creates a new event publisher.
    /// 
    /// The publisher starts with no subscribers and is ready to receive
    /// event subscriptions and publish events immediately.
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
        handlers[id] = WeakHandler(handler)

        // Clean up any deallocated handlers
        cleanupDeallocatedHandlers()
    }

    /// Unsubscribe from editor events.
    ///
    /// Removes an event handler from receiving events.
    ///
    /// - Parameter handler: The event handler to remove
    public func unsubscribe(_ handler: any EditorEventHandler) {
        let id = ObjectIdentifier(handler)
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
        // Get active handlers
        let activeHandlers = handlers.values.compactMap { $0.value }

        // Clean up deallocated handlers
        cleanupDeallocatedHandlers()

        // Publish to all active handlers in a single task to avoid excessive task creation
        guard !activeHandlers.isEmpty else { return }

        Task { @MainActor in
            for handler in activeHandlers {
                handler.handle(event)
            }
        }
    }

    /// Remove all handlers.
    ///
    /// Clears all event subscriptions. Useful for cleanup or reset scenarios.
    public func removeAll() {
        handlers.removeAll()
    }

    /// Clean up handlers that have been deallocated
    private func cleanupDeallocatedHandlers() {
        handlers = handlers.filter { _, weakHandler in
            weakHandler.value != nil
        }
    }

    // MARK: - Convenience Methods for Non-async Contexts

    /// Publish an event from a non-async context.
    ///
    /// This is a convenience method that creates a Task to call the async publish method.
    /// Use this when you need to publish from a synchronous context.
    ///
    /// - Parameter event: The event to publish
    nonisolated public func publishSync(_ event: EditorEvent) {
        Task {
            await publish(event)
        }
    }

    /// Subscribe from a non-async context.
    ///
    /// This is a convenience method that creates a Task to call the async subscribe method.
    ///
    /// - Parameter handler: The event handler to add
    nonisolated public func subscribeSync(_ handler: any EditorEventHandler) {
        Task {
            await subscribe(handler)
        }
    }

    /// Unsubscribe from a non-async context.
    ///
    /// This is a convenience method that creates a Task to call the async unsubscribe method.
    ///
    /// - Parameter handler: The event handler to remove
    nonisolated public func unsubscribeSync(_ handler: any EditorEventHandler) {
        Task {
            await unsubscribe(handler)
        }
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
@preconcurrency import Combine

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

// MARK: - Helper Types for EditorEventSubscription

// Thread-safe handler reference.
//
// `@unchecked Sendable` rationale: the only mutable property is `handler`,
// guarded by `NSLock` on every read and write below. Combine's `Subscriber`
// protocol predates Swift concurrency, so synthesized `Sendable` is unavailable
// for this lock-protected reference pattern.
@available(macOS 10.15, iOS 13.0, *)
private final class HandlerReference: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: ((EditorEvent) -> Void)?

    func set(_ handler: @escaping (EditorEvent) -> Void) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    func clear() {
        lock.lock()
        handler = nil
        lock.unlock()
    }

    func handle(_ event: EditorEvent) {
        lock.lock()
        let eventHandler = handler
        lock.unlock()
        eventHandler?(event)
    }
}

// Thread-safe wrapper storage.
//
// `@unchecked Sendable` rationale: `wrapper` is the only mutable state and
// every set/get/clear takes `lock` first. Same Combine-interop reason as
// `HandlerReference` for the unchecked variant.
@available(macOS 10.15, iOS 13.0, *)
private final class WrapperStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var wrapper: HandlerWrapper?

    func set(_ wrapper: HandlerWrapper) {
        lock.lock()
        self.wrapper = wrapper
        lock.unlock()
    }

    func get() -> HandlerWrapper? {
        lock.lock()
        let result = wrapper
        lock.unlock()
        return result
    }

    func clear() -> HandlerWrapper? {
        lock.lock()
        let result = wrapper
        wrapper = nil
        lock.unlock()
        return result
    }
}

// Type-erased handler box to avoid capturing generic types.
//
// `@unchecked Sendable` rationale: `handler` is captured immutably at
// initialization and never mutated. The closure itself is provided by callers
// and contractually expected to be safe to invoke from any actor. We can't
// synthesize `Sendable` because the function-typed property isn't `@Sendable`
// — but its immutability after init is what makes the box safe to share.
@available(macOS 10.15, iOS 13.0, *)
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
@available(macOS 10.15, iOS 13.0, *)
@MainActor
private final class HandlerWrapper: EditorEventHandler {
    var handlerBox: HandlerBox?

    func handle(_ event: EditorEvent) {
        handlerBox?.handle(event)
    }
}

// IMPORTANT: Swift Concurrency and Combine Interoperability
//
// This class uses @unchecked Sendable because Combine's Subscriber protocol
// predates Swift concurrency and doesn't require Sendable conformance.
// 
// The warnings about capturing non-sendable S.Type in isolated closures are
// unavoidable but safe because:
// 1. All access to the subscriber is protected by locks
// 2. The generic type S is never directly accessed in async contexts
// 3. We use type-erased handlers to avoid capturing generic types where possible
//
// These warnings can be safely ignored as we ensure thread safety manually.

@available(macOS 10.15, iOS 13.0, *)
private final class EditorEventSubscription<S: Subscriber>: Subscription, @unchecked Sendable
    where S.Input == EditorEvent, S.Failure == Never {
    private let lock = NSLock()
    private var subscriber: S?
    private let eventPublisher: EditorEventPublisher
    private var pendingSetup = true
    private let wrapperStorage = WrapperStorage()
    private let handlerReference = HandlerReference()

    init(subscriber: S, eventPublisher: EditorEventPublisher) {
        self.subscriber = subscriber
        self.eventPublisher = eventPublisher

        // Set up the handler reference immediately
        handlerReference.set { [weak self] event in
            self?.handleEvent(event)
        }
    }

    nonisolated private func ensureSetup() {
        lock.lock()
        let shouldSetUp = pendingSetup
        if shouldSetUp {
            pendingSetup = false
        }
        lock.unlock()

        guard shouldSetUp else { return }

        let handlerRef = self.handlerReference
        let publisher = self.eventPublisher
        let storage = self.wrapperStorage

        // Use structured concurrency for main actor isolation
        Task { @MainActor in
            // Create and set up the handler on the main actor
            let box = HandlerBox { event in
                handlerRef.handle(event)
            }
            let wrapper = HandlerWrapper()
            wrapper.handlerBox = box

            // Subscribe the wrapper to the publisher
            publisher.subscribeSync(wrapper)
            storage.set(wrapper)
        }
    }

    private func handleEvent(_ event: EditorEvent) {
        lock.lock()
        let sub = subscriber
        lock.unlock()

        _ = sub?.receive(event)
    }

    nonisolated func request(_: Subscribers.Demand) {
        // Ensure setup when subscription is activated
        ensureSetup()
        // Events are pushed, so we don't need to handle demand
    }

    nonisolated func cancel() {
        lock.lock()
        subscriber = nil
        lock.unlock()

        // Clear the handler reference
        handlerReference.clear()

        // Remove wrapper and unsubscribe on main actor
        let wrapper = wrapperStorage.clear()
        guard let wrappedValue = wrapper else { return }

        // Extract publisher before Task to avoid capturing self
        let publisher = eventPublisher
        publisher.unsubscribeSync(wrappedValue)
    }
}
#endif
