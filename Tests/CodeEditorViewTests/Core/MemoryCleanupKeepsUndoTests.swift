#if canImport(AppKit)
import AppKit
import CodeEditorDiagnostics
import CodeEditorPlatform
@testable import CodeEditorSyntaxHighlighting
@testable import CodeEditorView
import XCTest

/// A host process's footprint is always over the monitor's 100 MB
/// threshold, so a cleanup pass is routine: it may drop caches that are
/// rebuilt on demand, but it must not touch the user's undo history, text,
/// selection or caret. Up to 0.1.0-beta.15 each pass discarded the undo
/// history (before beta.15, the whole window's).
@MainActor
final class MemoryCleanupKeepsUndoTests: XCTestCase {
    /// A memory provider whose footprint and pressure the test sets.
    private final class AdjustableMemoryProvider: PlatformMemoryProvider, @unchecked Sendable {
        var usageMB: Double
        var pressure: MemoryPressure

        init(usageMB: Double, pressure: MemoryPressure = .normal) {
            self.usageMB = usageMB
            self.pressure = pressure
        }

        func getCurrentMemoryUsage() -> Double { usageMB }
        func getPhysicalMemory() -> UInt64 { 16 << 30 }
        func getMemoryPressure() -> MemoryPressure { pressure }
        func isUnderMemoryPressure() -> Bool { pressure != .normal }
    }

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

    private static let original = "let a = 1\nlet b = 2\n"

    /// An editor in a window with the default policy and three separate
    /// undo steps, its caret after the last one.
    private func makeEditorWithUndoHistory(monitor: MemoryMonitor) throws -> CodeEditorView {
        let editor = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300), memoryMonitor: monitor)
        let window = NSWindow(contentRect: editor.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = editor
        self.window = window
        editor.string = Self.original
        XCTAssertTrue(window.makeFirstResponder(editor))
        XCTAssertTrue(editor.memoryCoordinator.hasRegisteredCleanupHandler, "the default policy registers the cleanup")
        editor.setSelectedRange(NSRange(location: 0, length: 0))
        // One undo group per step: within one run-loop pass, event grouping
        // would put all three in a single group.
        let undoManager = try XCTUnwrap(editor.undoManager)
        undoManager.groupsByEvent = false
        defer { undoManager.groupsByEvent = true }
        for step in ["// three\n", "// two\n", "// one\n"] {
            undoManager.beginUndoGrouping()
            editor.insertText(step, replacementRange: NSRange(location: 0, length: 0))
            editor.breakUndoCoalescing()
            undoManager.endUndoGrouping()
        }
        editor.setSelectedRange(NSRange(location: 3, length: 0))
        XCTAssertEqual(editor.string, "// one\n// two\n// three\n" + Self.original)
        return editor
    }

    private func assertEveryStepUndoes(_ editor: CodeEditorView, file: StaticString = #filePath, line: UInt = #line) throws {
        let undoManager = try XCTUnwrap(editor.undoManager, file: file, line: line)
        let expected = [
            "// two\n// three\n" + Self.original,
            "// three\n" + Self.original,
            Self.original
        ]
        for text in expected {
            XCTAssertTrue(undoManager.canUndo, "an undo step was discarded", file: file, line: line)
            undoManager.undo()
            XCTAssertEqual(editor.string, text, file: file, line: line)
        }
        XCTAssertFalse(undoManager.canUndo, file: file, line: line)
    }

    func testAnAutomaticPassAboveTheThresholdKeepsUndoTextAndCaret() async throws {
        let provider = AdjustableMemoryProvider(usageMB: 400)
        let monitor = MemoryMonitor(memoryProvider: provider)
        let editor = try makeEditorWithUndoHistory(monitor: monitor)
        let text = editor.string
        let selection = editor.selectedRange()

        await monitor.checkMemoryUsageNow()

        XCTAssertEqual(monitor.memoryStats.totalCleanupOperations, 1, "the pass did not run")
        XCTAssertEqual(editor.string, text)
        XCTAssertEqual(editor.selectedRange(), selection)
        try assertEveryStepUndoes(editor)
    }

    func testRepeatedPassesKeepUndo() async throws {
        let provider = AdjustableMemoryProvider(usageMB: 400)
        let monitor = MemoryMonitor(memoryProvider: provider)
        monitor.minimumAutomaticCleanupInterval = 0
        let editor = try makeEditorWithUndoHistory(monitor: monitor)
        let selection = editor.selectedRange()

        for _ in 0..<5 {
            provider.usageMB += 100 // each check sees enough growth to run
            await monitor.checkMemoryUsageNow()
            await monitor.performCleanup()
        }

        XCTAssertEqual(monitor.memoryStats.totalCleanupOperations, 10)
        XCTAssertEqual(editor.selectedRange(), selection)
        try assertEveryStepUndoes(editor)
    }

    /// Critical pressure (as the monitor reads it) runs a pass too, and it
    /// is no different: the undo history is the user's, not a cache.
    func testAPassUnderCriticalPressureKeepsUndo() async throws {
        let provider = AdjustableMemoryProvider(usageMB: 400, pressure: .critical)
        let monitor = MemoryMonitor(memoryProvider: provider)
        let editor = try makeEditorWithUndoHistory(monitor: monitor)

        await monitor.checkMemoryUsageNow()

        XCTAssertEqual(monitor.memoryStats.totalCleanupOperations, 1)
        try assertEveryStepUndoes(editor)
    }

    /// The pass still does its job: the editor's highlighting token cache,
    /// rebuilt on demand, is released.
    func testAPassReleasesTheHighlightingCache() async throws {
        let monitor = MemoryMonitor(memoryProvider: AdjustableMemoryProvider(usageMB: 400))
        let editor = try makeEditorWithUndoHistory(monitor: monitor)
        let cache = editor.asyncHighlighter.tokenCache
        let key = SmartTokenCache.CacheKey(text: editor.string, language: .swift, version: 0)
        let token = HighlightedToken(range: NSRange(location: 0, length: 3), type: .keyword, text: "let")
        await cache.setCachedTokens([token], for: key, computationTime: .seconds(1))
        let before = await cache.getStatistics().cacheSize
        XCTAssertEqual(before, 1)

        await monitor.checkMemoryUsageNow()

        let after = await cache.getStatistics().cacheSize
        XCTAssertEqual(after, 0, "the cleanup pass released nothing")
        try assertEveryStepUndoes(editor)
    }
}
#endif
