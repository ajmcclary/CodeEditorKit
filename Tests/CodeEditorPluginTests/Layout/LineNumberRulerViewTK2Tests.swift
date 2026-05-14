#if canImport(AppKit)
import AppKit
import ObjectiveC.runtime
import XCTest
@testable import CodeEditorPlugin

@MainActor
final class LineNumberRulerViewTK2Tests: XCTestCase {

    /// Reads `NSTextView._layoutManager` without going through the public
    /// getter, which would itself synthesize the TK1 compatibility shim.
    fileprivate func legacyLayoutManagerIvarValue(for textView: NSTextView) -> AnyObject? {
        guard let ivar = class_getInstanceVariable(NSTextView.self, "_layoutManager") else {
            XCTFail("NSTextView._layoutManager ivar not found — Apple may have renamed it. Update this test.")
            return nil
        }
        return object_getIvar(textView, ivar) as AnyObject?
    }

    func testDrawHashMarksAndLabelsDoesNotSynthesizeLegacyLayoutManager() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        let container = CodeEditorContainerView(frame: window.contentLayoutRect)
        container.textView.string = "alpha\nbeta\ngamma\ndelta\nepsilon"
        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        // Force the ruler to draw. CodeEditorContainerView's scroll view is
        // built via ContainerViewInitializer; pull the ruler out and call
        // drawHashMarksAndLabels directly so the test does not rely on the
        // window's natural draw cycle (which can no-op in headless test runs).
        let scrollView = try XCTUnwrap(container.textView.enclosingScrollView)
        let ruler = try XCTUnwrap(scrollView.verticalRulerView as? LineNumberRulerView)
        let rep = try XCTUnwrap(ruler.bitmapImageRepForCachingDisplay(in: ruler.bounds))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        ruler.drawHashMarksAndLabels(in: ruler.bounds)
        NSGraphicsContext.restoreGraphicsState()

        let legacy = legacyLayoutManagerIvarValue(for: container.textView)
        XCTAssertNil(
            legacy,
            "NSTextView._layoutManager was synthesized during gutter draw. The ruler is still reading textView.layoutManager and flipping the editor off TextKit 2."
        )

        XCTAssertNotNil(container.textView.textLayoutManager)
    }

    func testFoldControlClickDoesNotSynthesizeLegacyLayoutManager() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        let container = CodeEditorContainerView(frame: window.contentLayoutRect)
        container.configuration.display.isCodeFoldingEnabled = true
        container.configuration.display.areFoldingControlsVisible = true
        container.textView.string = """
        func example() {
            let value = 1
            return value
        }
        """
        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        let scrollView = try XCTUnwrap(container.textView.enclosingScrollView)
        let ruler = try XCTUnwrap(scrollView.verticalRulerView as? LineNumberRulerView)

        // Synthesize a mouseDown inside the fold-control band.
        let controlPadding = container.configuration.layout.foldingControlPadding
        let controlSize = container.configuration.layout.foldingControlSize
        let pointInRuler = NSPoint(x: controlPadding + controlSize / 2, y: 10)
        let pointInWindow = ruler.convert(pointInRuler, to: nil)
        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: pointInWindow,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        ))
        ruler.mouseDown(with: event)

        XCTAssertNil(
            legacyLayoutManagerIvarValue(for: container.textView),
            "Fold-control click read textView.layoutManager and flipped the editor off TextKit 2."
        )
    }
}
#endif
