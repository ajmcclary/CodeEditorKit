import CodeEditorDiagnostics
@testable import CodeEditorView
import Foundation
import Testing

/// A memory-cleanup pass must leave the editor's line geometry intact.
///
/// The line geometry store is the editor's line index, not a cache: the
/// gutter numbers each visible line with `lineIndex(forUtf16Offset:) + 1`,
/// and active-line highlighting, line-at-point and the minimap read it too.
/// Nothing rebuilds it outside a text edit, so emptying it during cleanup
/// made every gutter line number read "1" until the next edit.
@MainActor
@Suite("Memory cleanup keeps line geometry")
struct MemoryCleanupLineGeometryTests {
    private static let lines = ["first", "second", "third", "fourth", "fifth"]

    /// UTF-16 offset of the start of each line of `lines` joined by "\n".
    private static var lineStartOffsets: [Int] {
        var offsets: [Int] = []
        var offset = 0
        for line in lines {
            offsets.append(offset)
            offset += line.utf16.count + 1
        }
        return offsets
    }

    /// An editor holding `lines`, with no text edit still in flight.
    ///
    /// A text edit reaches the line geometry store as an event queued on the
    /// main queue, and an event that finds the store empty rebuilds it. One
    /// still pending when the cleanup runs would repair the store behind the
    /// test's back; a cleanup pass in a running app has no such event to
    /// rely on. The text is loaded through the text storage, the way an edit
    /// arrives, so that event is the only thing that builds the store.
    private func makeSettledEditor(monitor: MemoryMonitor) async throws -> CodeEditorView {
        let editor = CodeEditorView(frame: .zero, memoryMonitor: monitor)
        let storage = try #require(editor.textContentStorage?.textStorage)
        storage.replaceCharacters(
            in: NSRange(location: 0, length: 0),
            with: Self.lines.joined(separator: "\n")
        )
        await deliverPendingEditEvents()
        return editor
    }

    /// The main queue is FIFO: once this returns, every edit event queued
    /// before the call has been delivered.
    private func deliverPendingEditEvents() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    @Test("line numbers are correct after a cleanup pass")
    func lineNumbersSurviveCleanup() async throws {
        let monitor = MemoryMonitor.mock()
        let editor = try await makeSettledEditor(monitor: monitor)
        #expect(editor.memoryCoordinator.hasRegisteredCleanupHandler)
        let numbersBefore = Self.lineStartOffsets.map { editor.lineNumber(at: $0) }
        #expect(numbersBefore == [1, 2, 3, 4, 5])

        await monitor.performCleanup()

        // The expression `GutterViewRenderer` numbers each line with.
        let numbersAfter = Self.lineStartOffsets.map { editor.lineNumber(at: $0) }
        #expect(numbersAfter == [1, 2, 3, 4, 5])
        #expect(editor.lineCount == Self.lines.count)
    }

    @Test("line ranges are still resolvable after a cleanup pass")
    func lineRangesSurviveCleanup() async throws {
        let monitor = MemoryMonitor.mock()
        let editor = try await makeSettledEditor(monitor: monitor)

        await monitor.performCleanup()

        // "third" starts after "first\nsecond\n" and its range includes the newline.
        #expect(editor.lineRange(for: 3) == NSRange(location: 13, length: 6))
    }
}
