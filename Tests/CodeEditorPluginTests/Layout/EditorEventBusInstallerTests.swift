#if canImport(AppKit)
import AppKit
import CodeEditorCommon
@testable import CodeEditorLayout
@testable import CodeEditorPlugin
import XCTest

final class EditorEventBusInstallerTests: XCTestCase {
    @MainActor
    func testCommandClickPublishesPosition() throws {
        let bus = EditorEventBus()
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        textView.string = "let foo = 1\nlet bar = 2"
        let installer = EditorEventBusInstaller(bus: bus, textView: textView)

        var received: SourcePosition?
        let cancellable = bus.commandClickPublisher.sink { received = $0 }

        let glyphRange = textView.layoutManager?.glyphRange(
            forCharacterRange: NSRange(location: 4, length: 1),
            actualCharacterRange: nil
        ) ?? NSRange(location: 0, length: 0)
        let rect = textView.layoutManager?.boundingRect(
            forGlyphRange: glyphRange,
            in: try XCTUnwrap(textView.textContainer)
        ) ?? .zero
        // Bias the click toward the leading edge so characterIndexForInsertion
        // resolves to the index of the character itself, not the one after it.
        let point = NSPoint(x: rect.minX + 1, y: rect.midY)

        let event = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: point,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        let unwrappedEvent = try XCTUnwrap(event)

        let consumed = installer.handleMouseDown(unwrappedEvent)
        XCTAssertTrue(consumed)
        XCTAssertEqual(received?.line, 0)
        XCTAssertEqual(received?.character, 4)
        _ = cancellable
    }

    @MainActor
    func testPlainClickIsNotConsumed() throws {
        let bus = EditorEventBus()
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        textView.string = "abc"
        let installer = EditorEventBusInstaller(bus: bus, textView: textView)

        var received: SourcePosition?
        let cancellable = bus.commandClickPublisher.sink { received = $0 }

        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 5, y: 5),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        ))

        let consumed = installer.handleMouseDown(event)
        XCTAssertFalse(consumed)
        XCTAssertNil(received)
        _ = cancellable
    }
}
#endif
