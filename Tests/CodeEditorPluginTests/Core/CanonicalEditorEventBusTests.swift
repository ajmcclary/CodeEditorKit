@testable import CodeEditorView
import Foundation
import Testing

@MainActor
@Suite("EditorEventBus")
struct CanonicalEditorEventBusTests {
    @Test("independent streams observe one global order")
    func orderedIndependentStreams() async {
        let bus = EditorEventBus()
        let streamA = bus.stream()
        let streamB = bus.stream()
        bus.publish(.textDidChange("one"))
        bus.publish(.textSelectionDidChange(NSRange(location: 2, length: 0)))
        bus.publish(.didBecomeFirstResponder)

        let valuesA = await first(3, from: streamA)
        let valuesB = await first(3, from: streamB)

        #expect(valuesA.map(\.sequence) == [1, 2, 3])
        #expect(valuesB.map(\.sequence) == [1, 2, 3])
        #expect(eventNames(valuesA) == eventNames(valuesB))
    }

    @Test("history limit and predicate filtering are deterministic")
    func historyAndFiltering() {
        let bus = EditorEventBus(historyLimit: 2)
        bus.publish(.textDidChange("one"))
        bus.publish(.didBecomeFirstResponder)
        bus.publish(.textDidChange("two"))

        #expect(bus.recentEvents().map(\.sequence) == [2, 3])
        let textEvents = bus.recentEvents { event in
            if case .textDidChange = event { return true }
            return false
        }
        #expect(textEvents.map(\.sequence) == [3])
    }

    @Test("stream cancellation removes its continuation")
    func terminationCleanup() async {
        let bus = EditorEventBus()
        var stream: AsyncStream<SequencedEditorEvent>? = bus.stream()
        #expect(bus.subscriberCount == 1)
        stream = nil
        _ = stream
        for _ in 0..<10 where bus.subscriberCount != 0 {
            await Task.yield()
        }
        #expect(bus.subscriberCount == 0)
    }

    private func first(
        _ count: Int,
        from stream: AsyncStream<SequencedEditorEvent>
    ) async -> [SequencedEditorEvent] {
        var values: [SequencedEditorEvent] = []
        for await value in stream {
            values.append(value)
            if values.count == count { break }
        }
        return values
    }

    private func eventNames(_ values: [SequencedEditorEvent]) -> [String] {
        values.map { value in
            switch value.event {
            case .textDidChange: "text"
            case .textSelectionDidChange: "selection"
            case .didBecomeFirstResponder: "focus"
            default: "other"
            }
        }
    }
}
