import CodeEditorConfiguration
#if canImport(AppKit)
import AppKit
@testable import CodeEditorView
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

    func testDrawDoesNotSynthesizeLegacyLayoutManager() throws {
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
        // Programmatic NSWindows default to isReleasedWhenClosed = true, so close()
        // would add an AppKit release on top of ARC's and over-release the window.
        window.isReleasedWhenClosed = false
        defer { window.close() }

        let gutter = try XCTUnwrap(container.macLineNumberRulerView)
        let rep = try XCTUnwrap(gutter.bitmapImageRepForCachingDisplay(in: gutter.bounds))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        gutter.drawHashMarksAndLabels(in: gutter.bounds)
        NSGraphicsContext.restoreGraphicsState()

        let legacy = legacyLayoutManagerIvarValue(for: container.textView)
        XCTAssertNil(
            legacy,
            "NSTextView._layoutManager was synthesized during gutter draw. The gutter is reading textView.layoutManager and flipping the editor off TextKit 2."
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
        // Programmatic NSWindows default to isReleasedWhenClosed = true, so close()
        // would add an AppKit release on top of ARC's and over-release the window.
        window.isReleasedWhenClosed = false
        defer { window.close() }

        let gutter = try XCTUnwrap(container.macLineNumberRulerView)

        // Synthesize a mouseDown inside the fold-control band.
        let controlPadding = container.configuration.layout.foldingControlPadding
        let controlSize = container.configuration.layout.foldingControlSize
        let pointInGutter = NSPoint(x: controlPadding + controlSize / 2, y: 10)
        let pointInWindow = gutter.convert(pointInGutter, to: nil)
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
        gutter.mouseDown(with: event)

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
        // Programmatic NSWindows default to isReleasedWhenClosed = true, so close()
        // would add an AppKit release on top of ARC's and over-release the window.
        window.isReleasedWhenClosed = false
        defer { window.close() }

        let gutter = try XCTUnwrap(container.macLineNumberRulerView)

        container.textView.setSelectedRange(NSRange(location: 0, length: 0))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        // Seed lastActiveLineNumber by drawing once.
        let rep = try XCTUnwrap(gutter.bitmapImageRepForCachingDisplay(in: gutter.bounds))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        gutter.drawHashMarksAndLabels(in: gutter.bounds)
        NSGraphicsContext.restoreGraphicsState()
        XCTAssertEqual(gutter.lastActiveLineNumber, 1, "Initial selection at offset 0 is line 1")

        container.textView.setSelectedRange(NSRange(location: 6, length: 0))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(gutter.lastActiveLineNumber, 2, "Selection at offset 6 is line 2")
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
        // Programmatic NSWindows default to isReleasedWhenClosed = true, so close()
        // would add an AppKit release on top of ARC's and over-release the window.
        window.isReleasedWhenClosed = false
        defer { window.close() }

        let gutter = try XCTUnwrap(container.macLineNumberRulerView)

        container.textView.setSelectedRange(NSRange(location: 2, length: 0))
        let rep = try XCTUnwrap(gutter.bitmapImageRepForCachingDisplay(in: gutter.bounds))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        gutter.drawHashMarksAndLabels(in: gutter.bounds)
        NSGraphicsContext.restoreGraphicsState()
        XCTAssertEqual(gutter.lastActiveLineNumber, 1)

        let drain = expectation(description: "drain main queue")
        DispatchQueue.main.async { drain.fulfill() }
        wait(for: [drain], timeout: 1.0)
        gutter.needsDisplay = false

        container.textView.setSelectedRange(NSRange(location: 5, length: 0))
        let drain2 = expectation(description: "drain after same-line move")
        DispatchQueue.main.async { drain2.fulfill() }
        wait(for: [drain2], timeout: 1.0)
        XCTAssertEqual(gutter.lastActiveLineNumber, 1)
        XCTAssertFalse(gutter.needsDisplay, "Same-line caret move must not dirty the gutter")
    }

    func testWrappedLogicalLineUsesFirstVisualLineFragmentForGutterPosition() throws {
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
        // Programmatic NSWindows default to isReleasedWhenClosed = true, so close()
        // would add an AppKit release on top of ARC's and over-release the window.
        window.isReleasedWhenClosed = false
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

        // The renderer now anchors against the first textLineFragment of each
        // fragment directly. Assert that the first non-extra line fragment is
        // smaller in height than the multi-visual-line layoutFragmentFrame —
        // this is the property the renderer relies on for correct wrap Y.
        let firstVisualLine = try XCTUnwrap(layoutFragment.textLineFragments.first { !$0.isExtraLineFragment })
        XCTAssertLessThan(
            firstVisualLine.typographicBounds.height,
            layoutFragment.layoutFragmentFrame.height,
            "The first text line fragment of a wrapped paragraph must be smaller than the multi-line fragment frame for the gutter to anchor correctly."
        )
    }
}
#endif
