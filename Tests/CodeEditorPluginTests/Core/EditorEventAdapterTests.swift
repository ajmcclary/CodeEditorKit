@testable import CodeEditorView
import Combine
import Foundation
import Testing

@MainActor
@Suite("Editor event adapters")
struct EditorEventAdapterTests {
    @Test("unified adapter consumes one bus publication in order")
    func unifiedAdapterSingleDelivery() {
        let bus = EditorEventBus()
        let system = UnifiedEventSystem(
            enableDefaultFilters: false,
            eventBus: bus
        )
        var received: [String] = []
        let cancellation = system.events.sink { event in
            if case .textDidChange(let text) = event {
                received.append(text)
            }
        }

        bus.publish(.textDidChange("one"))
        system.publish(.textDidChange("two"))

        #expect(received == ["one", "two"])
        #expect(bus.recentEvents().map(\.sequence) == [1, 2])
        withExtendedLifetime(cancellation) {}
    }

    @Test("reattaching unified adapter detaches the prior bus")
    func unifiedAdapterReattachment() {
        let oldBus = EditorEventBus()
        let newBus = EditorEventBus()
        let system = UnifiedEventSystem(
            enableDefaultFilters: false,
            eventBus: oldBus
        )
        system.attach(to: newBus)

        oldBus.publish(.textDidChange("stale"))
        newBus.publish(.textDidChange("current"))

        #expect(system.lastTextChangeEvent == "current")
    }
}
