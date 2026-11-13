#if canImport(AppKit)
import AppKit
import CodeEditorConfiguration
import CodeEditorDiagnostics
@testable import CodeEditorView
import XCTest

/// A memory-pressure pass touches only what belongs to this editor and only
/// reports memory for work it did.
@MainActor
final class MemoryCleanupScopeTests: XCTestCase {
    private var window: NSWindow?

    override func setUp() {
        super.setUp()
        window = nil
    }

    override func tearDown() {
        window?.orderOut(nil)
        window?.close()
        window = nil
        super.tearDown()
    }

    func testCleanupLeavesOtherViewsUndoAndTheUsersFoldsAlone() async throws {
        let editor = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 300, height: 300), memoryMonitor: MemoryMonitor.mock())
        var configuration = EditorConfiguration()
        configuration.display.isCodeFoldingEnabled = true
        editor.configuration = configuration
        editor.language = .swift
        let neighbour = NSTextView(frame: NSRect(x: 300, y: 0, width: 300, height: 300))
        neighbour.allowsUndo = true
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 300))
        content.addSubview(editor)
        content.addSubview(neighbour)
        let window = NSWindow(contentRect: content.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = content
        self.window = window

        window.makeFirstResponder(neighbour)
        neighbour.insertText("typed elsewhere", replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(window.undoManager?.canUndo ?? false)

        editor.string = "func f() {\n  a\n  b\n}\n"
        let deadline = Date().addingTimeInterval(arrivalTimeout)
        while editor.codeFoldingEngine.foldableRegions.isEmpty, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(editor.toggleFold(at: 1))

        _ = editor.memoryCoordinator.performMemoryCleanup()

        XCTAssertTrue(window.undoManager?.canUndo ?? false, "another view's undo history was discarded")
        XCTAssertTrue(editor.isFolded(at: 1), "the user's fold was undone")
    }

    func testCleanupWithNothingToDoReportsNothingFreed() {
        let editor = CodeEditorView(frame: .zero, memoryMonitor: MemoryMonitor.mock())
        editor.string = String(repeating: "x", count: 200_000)
        editor.isEditable = false

        let result = editor.memoryCoordinator.performMemoryCleanup()

        XCTAssertEqual(result.memoryFreedMB, 0)
    }
}
#endif
