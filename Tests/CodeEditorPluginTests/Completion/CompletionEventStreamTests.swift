import Foundation
import XCTest

@testable import CodeEditorPlugin

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
}
