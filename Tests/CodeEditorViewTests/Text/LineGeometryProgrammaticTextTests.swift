@testable import CodeEditorView
import Foundation
import Testing

/// Setting an editor's text must leave the line geometry store describing
/// exactly that text.
///
/// The text setters rebuild the store on the spot. The same assignment also
/// queues an edit event on the main queue, and that event describes a change
/// the rebuilt store already contains. Applying it again as an incremental
/// edit counted the document's lines twice: a five-line document ended with
/// nine lines in the store, inflating `lineCount`, the total height and the
/// minimap's line total.
@MainActor
@Suite("Line geometry after programmatic text")
struct LineGeometryProgrammaticTextTests {
    private static let fiveLines = "first\nsecond\nthird\nfourth\nfifth"

    private func setText(_ text: String, on editor: CodeEditorView) {
        #if canImport(AppKit)
        editor.string = text
        #else
        editor.text = text
        #endif
    }

    /// The main queue is FIFO: once this returns, every edit event queued
    /// before the call has been delivered.
    private func deliverPendingEditEvents() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    /// The store's line lengths, which must always sum to the document length.
    private func lineLengths(of editor: CodeEditorView) -> [Int] {
        editor.lineGeometryStore.allLineGeometries.map(\.utf16Length)
    }

    @Test("setting the text leaves one store line per document line once its edit event lands")
    func settingTextCountsEachLineOnce() async {
        let editor = CodeEditorView(frame: .zero)

        setText(Self.fiveLines, on: editor)
        await deliverPendingEditEvents()

        #expect(lineLengths(of: editor) == [6, 7, 6, 7, 5])
        #expect(editor.lineCount == 5)
    }

    @Test("an edit made after the text was set is still applied")
    func laterEditIsApplied() async throws {
        let editor = CodeEditorView(frame: .zero)
        setText(Self.fiveLines, on: editor)
        await deliverPendingEditEvents()

        let storage = try #require(editor.textContentStorage?.textStorage)
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "zeroth\n")
        await deliverPendingEditEvents()

        #expect(lineLengths(of: editor) == [7, 6, 7, 6, 7, 5])
    }

    @Test("an edit queued behind the text assignment is applied exactly once")
    func editQueuedBehindAssignmentIsAppliedOnce() async throws {
        let editor = CodeEditorView(frame: .zero)

        // Both edit events are still pending when the second edit is made.
        setText(Self.fiveLines, on: editor)
        let storage = try #require(editor.textContentStorage?.textStorage)
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "zeroth\n")
        await deliverPendingEditEvents()

        #expect(lineLengths(of: editor) == [7, 6, 7, 6, 7, 5])
    }
}
