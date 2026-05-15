#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
import ObjectiveC.runtime
import XCTest

@MainActor
final class LineNumberRulerViewTK2Tests: XCTestCase {
    /// Reads `NSTextView._layoutManager` without going through the public
    /// getter, which would itself synthesize the TK1 compatibility shim.
    private func legacyLayoutManagerIvarValue(for textView: NSTextView) -> AnyObject? {
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

    func testSelectionChangeOnNewLineUpdatesLastActiveLine() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        let container = CodeEditorContainerView(frame: window.contentLayoutRect)
        container.textView.string = "alpha\nbeta\ngamma"
        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        let scrollView = try XCTUnwrap(container.textView.enclosingScrollView)
        let ruler = try XCTUnwrap(scrollView.verticalRulerView as? LineNumberRulerView)

        // Move caret to start so the seed draw establishes line 1.
        container.textView.setSelectedRange(NSRange(location: 0, length: 0))
        // Drain any pending notifications from the string-assignment path.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        // Seed lastActiveLineNumber by drawing once.
        let rep = try XCTUnwrap(ruler.bitmapImageRepForCachingDisplay(in: ruler.bounds))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        ruler.drawHashMarksAndLabels(in: ruler.bounds)
        NSGraphicsContext.restoreGraphicsState()
        XCTAssertEqual(ruler.lastActiveLineNumber, 1, "Initial selection at offset 0 is line 1")

        // Caret jumps to line 2 (offset 6, just past "alpha\n").
        container.textView.setSelectedRange(NSRange(location: 6, length: 0))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(ruler.lastActiveLineNumber, 2, "Selection at offset 6 is line 2")
    }

    func testSelectionChangeOnSameLineKeepsLastActiveLineStable() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        let container = CodeEditorContainerView(frame: window.contentLayoutRect)
        container.textView.string = "alphabetagamma"
        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        let scrollView = try XCTUnwrap(container.textView.enclosingScrollView)
        let ruler = try XCTUnwrap(scrollView.verticalRulerView as? LineNumberRulerView)

        container.textView.setSelectedRange(NSRange(location: 2, length: 0))
        let rep = try XCTUnwrap(ruler.bitmapImageRepForCachingDisplay(in: ruler.bounds))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        ruler.drawHashMarksAndLabels(in: ruler.bounds)
        NSGraphicsContext.restoreGraphicsState()
        XCTAssertEqual(ruler.lastActiveLineNumber, 1)

        // Drain pending notifications, then snapshot needsDisplay state.
        let drain = expectation(description: "drain main queue")
        DispatchQueue.main.async { drain.fulfill() }
        wait(for: [drain], timeout: 1.0)
        ruler.needsDisplay = false

        // Caret moves within line 1 — selectionDidChange should short-circuit.
        container.textView.setSelectedRange(NSRange(location: 5, length: 0))
        let drain2 = expectation(description: "drain after same-line move")
        DispatchQueue.main.async { drain2.fulfill() }
        wait(for: [drain2], timeout: 1.0)
        XCTAssertEqual(ruler.lastActiveLineNumber, 1)
        XCTAssertFalse(ruler.needsDisplay, "Same-line caret move must not dirty the ruler")
    }

    func testWrappedLogicalLineUsesFirstVisualLineFragmentForRulerPosition() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 240),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        let container = CodeEditorContainerView(frame: window.contentLayoutRect)
        var configuration = EditorConfiguration.default
        configuration.layout.wrapLines = true
        configuration.display.isMinimapVisible = false
        configuration.display.isSelectedLineHighlighted = false
        container.configuration = configuration
        container.textView.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        container.textView.string = String(repeating: "wrapped ", count: 18) + "\nshort"
        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        container.layoutSubtreeIfNeeded()
        container.textView.updateTextContainerSize()
        let textLayoutManager = try XCTUnwrap(container.textView.textLayoutManager)
        textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)

        var firstLayoutFragment: NSTextLayoutFragment?
        textLayoutManager.enumerateTextLayoutFragments(from: textLayoutManager.documentRange.location) { fragment in
            firstLayoutFragment = fragment
            return false
        }
        let layoutFragment = try XCTUnwrap(firstLayoutFragment)
        XCTAssertGreaterThan(
            layoutFragment.textLineFragments.count,
            1,
            "The test document must wrap the first logical line into multiple visual rows."
        )

        let helper = TextKitLineNumberHelper(textView: container.textView)
        let lineRanges = helper.getVisibleLineRanges()
        let firstLineRange = try XCTUnwrap(lineRanges.first?.range)
        let helperRect = try XCTUnwrap(helper.getLineFragmentRect(for: firstLineRange))
        let firstVisualLine = try XCTUnwrap(layoutFragment.textLineFragments.first)
        let expectedFirstVisualRect = CGRect(
            x: firstVisualLine.typographicBounds.minX + layoutFragment.layoutFragmentFrame.minX,
            y: firstVisualLine.typographicBounds.minY + layoutFragment.layoutFragmentFrame.minY,
            width: firstVisualLine.typographicBounds.width,
            height: firstVisualLine.typographicBounds.height
        )

        XCTAssertLessThan(
            helperRect.height,
            layoutFragment.layoutFragmentFrame.height,
            "The ruler must use the first visual row, not the full wrapped paragraph fragment."
        )
        XCTAssertEqual(helperRect.minY, expectedFirstVisualRect.minY, accuracy: 1.0)
        XCTAssertEqual(helperRect.height, expectedFirstVisualRect.height, accuracy: 1.0)
    }
}
#endif
