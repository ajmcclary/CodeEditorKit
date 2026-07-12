@testable import CodeEditorCompletion
import CodeEditorDiagnostics
import CodeEditorLanguages
@testable import CodeEditorSwiftUI
import Foundation
import XCTest

/// Tests for `CompletionManager.events()` and `CompletionEventBroadcaster`.
///
/// Spec: docs/superpowers/specs/2026-05-14-completion-event-stream-design.md.
@available(macOS 13.0, iOS 16.0, *)
@MainActor
final class CompletionEventStreamTests: XCTestCase {
    // MARK: - Fixtures

    /// A controllable provider used by every test in this suite. Pick a
    /// behavior at construction time; the same instance can be re-fired.
    struct StubCompletionProvider: CompletionProvider {
        enum Behavior: Sendable {
            case returns(itemCount: Int)
            case throwing(any Error & Sendable)
            case counter(AtomicCounter)
        }

        let id: String
        let supportedLanguages: [Language]
        let triggerCharacters: [String]
        let supportsSnippets: Bool
        let behavior: Behavior

        init(
            behavior: Behavior,
            id: String = "stub.\(UUID().uuidString)",
            supportedLanguages: [Language] = [],
            triggerCharacters: [String] = [],
            supportsSnippets: Bool = false
        ) {
            self.id = id
            self.supportedLanguages = supportedLanguages
            self.triggerCharacters = triggerCharacters
            self.supportsSnippets = supportsSnippets
            self.behavior = behavior
        }

        @MainActor
        func completions(for context: CompletionContextModel) async throws -> CompletionResult {
            switch behavior {
            case .returns(let itemCount):
                let items = (0..<itemCount).map { index in
                    CompletionItemModel(
                        label: "item-\(index)",
                        insertText: "item-\(index)",
                        kind: .text
                    )
                }
                return CompletionResult(items: items, context: context)

            case .throwing(let error):
                throw error

            case .counter(let counter):
                let next = counter.incrementAndGet()
                let items = [
                    CompletionItemModel(
                        label: "item-\(next)",
                        insertText: "item-\(next)",
                        kind: .text
                    )
                ]
                return CompletionResult(items: items, context: context)
            }
        }
    }

    final class AtomicCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0

        func incrementAndGet() -> Int {
            lock.lock()
            defer { lock.unlock() }
            value += 1
            return value
        }

        func get() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    struct TestError: Error, Sendable, CustomStringConvertible {
        let description: String
    }

    /// Builds a `CompletionContextModel` whose `currentWord` is exactly the
    /// supplied length. Uses the documented constructor — `wordRange` covers
    /// the leading `length` UTF-16 units of `text`.
    func makeContext(
        language: Language = .swift,
        triggerCharacter: String? = nil,
        currentWordLength: Int = 4
    ) -> CompletionContextModel {
        let word = String(repeating: "a", count: currentWordLength)
        return CompletionContextModel(
            text: word + "\n",
            cursorPosition: currentWordLength,
            language: language,
            triggerCharacter: triggerCharacter,
            wordRange: NSRange(location: 0, length: currentWordLength)
        )
    }

    func makeManager() -> CompletionManager {
        CompletionManager(memoryMonitor: MemoryMonitor(), enableCaching: false)
    }

    /// Drains the next `count` events from `stream` with a 2-second timeout.
    /// `static` so callers can use `async let` from `@MainActor` tests
    /// without sending `self` across isolation domains.
    static func awaitEvents(
        _ count: Int,
        from stream: AsyncStream<CompletionEvent>,
        timeout seconds: TimeInterval = 2
    ) async throws -> [CompletionEvent] {
        try await withThrowingTaskGroup(of: [CompletionEvent].self) { group in
            group.addTask {
                var collected: [CompletionEvent] = []
                for await event in stream {
                    collected.append(event)
                    if collected.count >= count { break }
                }
                return collected
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TestError(description: "awaitEvents timed out after \(seconds)s")
            }
            let first = try await group.next() ?? []
            group.cancelAll()
            return first
        }
    }

    // MARK: - Tests

    func testSucceedingProviderPublishesEvent() async throws {
        let manager = makeManager()
        let provider = StubCompletionProvider(
            behavior: .returns(itemCount: 3),
            id: "swift.stub",
            supportedLanguages: [.swift]
        )
        manager.registerProvider(provider)

        let stream = manager.events()
        let context = makeContext(currentWordLength: 4)

        async let drained = Self.awaitEvents(1, from: stream)
        _ = try await manager.requestCompletions(for: context)
        let events = try await drained

        XCTAssertEqual(events.count, 1)
        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(event.providerID, "swift.stub")
        XCTAssertEqual(event.language, .swift)
        XCTAssertNil(event.triggerCharacter)
        XCTAssertEqual(event.prefix, "aaaa")
        XCTAssertGreaterThanOrEqual(event.durationMilliseconds, 0)
        if case .succeeded(let itemCount) = event.outcome {
            XCTAssertEqual(itemCount, 3)
        } else {
            XCTFail("Expected .succeeded outcome, got \(event.outcome)")
        }
    }

    func testFailingProviderPublishesEventAndIsolatesFailure() async throws {
        let manager = makeManager()
        let failingProvider = StubCompletionProvider(
            behavior: .throwing(TestError(description: "boom")),
            id: "swift.failing",
            supportedLanguages: [.swift]
        )
        let succeedingProvider = StubCompletionProvider(
            behavior: .returns(itemCount: 2),
            id: "swift.ok",
            supportedLanguages: [.swift]
        )
        manager.registerProvider(failingProvider)
        manager.registerProvider(succeedingProvider)

        let stream = manager.events()
        let context = makeContext()

        async let drained = Self.awaitEvents(2, from: stream)
        let result = try await manager.requestCompletions(for: context)
        let events = try await drained

        XCTAssertEqual(events.count, 2)

        let byID = Dictionary(uniqueKeysWithValues: events.map { ($0.providerID, $0) })
        let failed = try XCTUnwrap(byID["swift.failing"])
        let succeeded = try XCTUnwrap(byID["swift.ok"])

        if case .failed(let err) = failed.outcome {
            XCTAssertTrue(
                err.message.contains("boom"),
                "SendableError.message (\(err.message)) should contain the thrown error description."
            )
        } else {
            XCTFail("Expected .failed outcome for the throwing provider, got \(failed.outcome)")
        }
        if case .succeeded(let itemCount) = succeeded.outcome {
            XCTAssertEqual(itemCount, 2)
        } else {
            XCTFail("Expected .succeeded outcome for the OK provider, got \(succeeded.outcome)")
        }

        // Failure isolation: the throwing provider does not poison the batch.
        XCTAssertEqual(result.items.count, 2, "Successful provider's items must still surface in the merged result.")
    }

    func testMultipleSubscribersEachReceiveEveryEvent() async throws {
        let manager = makeManager()
        let provider = StubCompletionProvider(
            behavior: .returns(itemCount: 1),
            id: "swift.multi",
            supportedLanguages: [.swift]
        )
        manager.registerProvider(provider)

        let streamA = manager.events()
        let streamB = manager.events()
        let context = makeContext()

        async let drainedA = Self.awaitEvents(1, from: streamA)
        async let drainedB = Self.awaitEvents(1, from: streamB)
        _ = try await manager.requestCompletions(for: context)

        let eventsA = try await drainedA
        let eventsB = try await drainedB

        XCTAssertEqual(eventsA.count, 1)
        XCTAssertEqual(eventsB.count, 1)
        XCTAssertEqual(eventsA.first?.providerID, "swift.multi")
        XCTAssertEqual(eventsB.first?.providerID, "swift.multi")
        XCTAssertEqual(eventsA.first?.id, eventsB.first?.id, "Both subscribers must see the same event instance (UUID).")
    }

    func testTerminationRemovesContinuation() async throws {
        let manager = makeManager()
        let provider = StubCompletionProvider(
            behavior: .returns(itemCount: 1),
            id: "swift.term",
            supportedLanguages: [.swift]
        )
        manager.registerProvider(provider)

        do {
            let stream = manager.events()
            XCTAssertEqual(manager.testOnlyBroadcaster.subscriberCount, 1, "Subscribing must register exactly one continuation.")

            async let drained = Self.awaitEvents(1, from: stream)
            _ = try await manager.requestCompletions(for: makeContext())
            _ = try await drained
            // `stream` goes out of scope at the end of this `do { ... }`. The
            // AsyncStream iterator created by `awaitEvents` is also gone after
            // it observed its first event and broke.
        }

        // Allow onTermination to run. The closure is dispatched off the lock;
        // a single yield is enough on the cooperative pool, but loop a few
        // times to keep the test robust under load.
        for _ in 0..<5 {
            await Task.yield()
            if manager.testOnlyBroadcaster.subscriberCount == 0 { break }
        }

        XCTAssertEqual(manager.testOnlyBroadcaster.subscriberCount, 0, "Dropping the stream must remove the continuation.")

        let nextStream = manager.events()
        defer { _ = nextStream }
        XCTAssertEqual(manager.testOnlyBroadcaster.subscriberCount, 1, "Resubscribing must register exactly one new continuation.")
    }

    func testBufferDropsOldestWhenSubscriberLags() async throws {
        let manager = makeManager()
        let counter = AtomicCounter()
        let provider = StubCompletionProvider(
            behavior: .counter(counter),
            id: "swift.lag",
            supportedLanguages: [.swift]
        )
        manager.registerProvider(provider)

        let stream = manager.events()

        for _ in 0..<300 {
            _ = try await manager.requestCompletions(for: makeContext())
        }

        XCTAssertEqual(counter.get(), 300, "All 300 fires should have hit the provider before we drain.")

        // Drain whatever survives in the buffer. Once we've taken 256, stop —
        // the buffer cap should be exactly 256.
        let drainTask = Task<[CompletionEvent], Never> {
            var collected: [CompletionEvent] = []
            for await event in stream {
                collected.append(event)
                if collected.count >= 256 { break }
            }
            return collected
        }
        let timeout = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            drainTask.cancel()
        }
        let drained = await drainTask.value
        timeout.cancel()

        XCTAssertEqual(drained.count, 256, "Buffer must cap at 256 events; saw \(drained.count).")

        // Events must surface in publish order.
        let timestamps = drained.map(\.timestamp)
        XCTAssertEqual(timestamps, timestamps.sorted(), "Drained events must be timestamp-monotonic.")
    }

    func testEditorControllerCompletionEventsTerminatesWhenUnattached() async throws {
        let controller = EditorController()
        let stream = controller.completionEvents()
        var observed: [CompletionEvent] = []
        for await event in stream {
            observed.append(event)
        }
        XCTAssertTrue(observed.isEmpty, "Unattached controller must yield no events and terminate immediately.")
    }
}
