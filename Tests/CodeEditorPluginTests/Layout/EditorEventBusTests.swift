#if canImport(SwiftUI)
import CodeEditorCommon
@testable import CodeEditorLayout
@testable import CodeEditorPlugin
@testable import CodeEditorView
import Combine
import Testing

@Suite("EditorEventBus")
@MainActor
struct EditorEventBusTests {
    @Test func publishesHoverEvent() async {
        let bus = EditorEventBus()
        var received: SourcePosition?
        let cancellable = bus.hoverPublisher.sink { received = $0 }

        bus.emitHover(at: SourcePosition(line: 3, character: 5))

        #expect(received == SourcePosition(line: 3, character: 5))
        _ = cancellable
    }

    @Test func publishesNilHoverWhenPointerLeavesText() {
        let bus = EditorEventBus()
        var received: SourcePosition? = SourcePosition(line: 0, character: 0)
        let cancellable = bus.hoverPublisher.sink { received = $0 }

        bus.emitHover(at: nil)

        #expect(received == nil)
        _ = cancellable
    }

    @Test func publishesCommandClickEvent() {
        let bus = EditorEventBus()
        var received: SourcePosition?
        let cancellable = bus.commandClickPublisher.sink { received = $0 }

        bus.emitCommandClick(at: SourcePosition(line: 7, character: 2))

        #expect(received == SourcePosition(line: 7, character: 2))
        _ = cancellable
    }
}
#endif
