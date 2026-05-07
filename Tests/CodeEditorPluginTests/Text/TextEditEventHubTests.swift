@testable import CodeEditorPlugin
import Foundation
import Testing

// MARK: - Test observer

@MainActor
private final class TestObserver: TextEditEventObserving {
    var receivedEvents: [TextEditEvent] = []

    func textStorageDidApplyEdit(_ event: TextEditEvent) {
        receivedEvents.append(event)
    }
}

// MARK: - Tests

@Suite("TextEditEventHub")
struct TextEditEventHubTests {
    @Test("publish delivers event to registered observer")
    @MainActor
    func publishDelivers() {
        let hub = TextEditEventHub()
        let observer = TestObserver()
        hub.addObserver(observer)

        let event = TextEditEvent(
            editedRange: NSRange(location: 0, length: 5),
            changeInLength: 3,
            documentLength: 100,
            editedCharacters: true
        )
        hub.publish(event)

        #expect(observer.receivedEvents.count == 1)
        #expect(observer.receivedEvents[0].editedRange == event.editedRange)
        #expect(observer.receivedEvents[0].changeInLength == 3)
        #expect(observer.receivedEvents[0].documentLength == 100)
        #expect(observer.receivedEvents[0].editedCharacters == true)
    }

    @Test("publish delivers to multiple observers in registration order")
    @MainActor
    func publishToMultiple() {
        let hub = TextEditEventHub()
        let obs1 = TestObserver()
        let obs2 = TestObserver()
        hub.addObserver(obs1)
        hub.addObserver(obs2)

        let event = TextEditEvent(
            editedRange: NSRange(location: 0, length: 1),
            changeInLength: 0,
            documentLength: 10,
            editedCharacters: true
        )
        hub.publish(event)

        #expect(obs1.receivedEvents.count == 1)
        #expect(obs2.receivedEvents.count == 1)
    }

    @Test("remove observer stops delivery")
    @MainActor
    func removeStopsDelivery() {
        let hub = TextEditEventHub()
        let observer = TestObserver()
        hub.addObserver(observer)
        hub.removeObserver(observer)

        let event = TextEditEvent(
            editedRange: NSRange(location: 0, length: 1),
            changeInLength: 0,
            documentLength: 10,
            editedCharacters: true
        )
        hub.publish(event)

        #expect(observer.receivedEvents.isEmpty)
    }

    @Test("hub prunes deallocated observers automatically")
    @MainActor
    func prunesDeallocated() {
        let hub = TextEditEventHub()

        // Add observer in a nested scope so it deallocates.
        autoreleasepool {
            let temp = TestObserver()
            hub.addObserver(temp)
        }

        let event = TextEditEvent(
            editedRange: NSRange(location: 0, length: 1),
            changeInLength: 0,
            documentLength: 10,
            editedCharacters: true
        )
        hub.publish(event)
        // No crash = pruned correctly.
    }

    @Test("publish without observers does not crash")
    @MainActor
    func publishWithoutObservers() {
        let hub = TextEditEventHub()
        let event = TextEditEvent(
            editedRange: NSRange(location: 0, length: 1),
            changeInLength: 0,
            documentLength: 10,
            editedCharacters: true
        )
        hub.publish(event)
    }

    @Test("duplicate addObserver is idempotent")
    @MainActor
    func duplicateAddIsIdempotent() {
        let hub = TextEditEventHub()
        let observer = TestObserver()
        hub.addObserver(observer)
        hub.addObserver(observer)

        let event = TextEditEvent(
            editedRange: NSRange(location: 0, length: 1),
            changeInLength: 0,
            documentLength: 10,
            editedCharacters: true
        )
        hub.publish(event)
        #expect(observer.receivedEvents.count == 1)
    }
}
