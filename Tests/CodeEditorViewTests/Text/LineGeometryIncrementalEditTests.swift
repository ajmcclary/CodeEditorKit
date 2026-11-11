import CodeEditorTextModel
@testable import CodeEditorView
import Foundation
import Testing

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// After any text edit, the line geometry store the editor maintains must
/// equal a store built from scratch from the edited text.
///
/// `LineGeometryEditHandler` used to rescan from the start of the line
/// *before* the edited one while replacing only the edited lines, so every
/// edit past the first line left a duplicate of the previous line behind.
/// Every assertion here reads the editor's own store; comparing a freshly
/// built store with the text proves nothing about the handler.
@MainActor
@Suite("Line geometry after incremental edits")
struct LineGeometryIncrementalEditTests {
    /// One replacement applied to a document.
    struct Edit: Sendable, CustomTestStringConvertible {
        let name: String
        let document: String
        let location: Int
        let length: Int
        let replacement: String

        var testDescription: String { name }
    }

    nonisolated private static let fiveLines = "first\nsecond\nthird\nfourth\nfifth"

    nonisolated static let edits: [Edit] = [
        Edit(name: "insert a character inside line 2", document: fiveLines, location: 8, length: 0, replacement: "x"),
        Edit(name: "insert a character at the start of line 3", document: fiveLines, location: 13, length: 0, replacement: "x"),
        Edit(name: "insert a character at the end of line 2", document: fiveLines, location: 12, length: 0, replacement: "x"),
        Edit(name: "insert a newline inside line 2", document: fiveLines, location: 8, length: 0, replacement: "\n"),
        Edit(name: "insert several lines inside line 3", document: fiveLines, location: 15, length: 0, replacement: "one\ntwo\nthree"),
        Edit(name: "insert a line at the start of line 4", document: fiveLines, location: 19, length: 0, replacement: "new\n"),
        Edit(name: "append a character", document: fiveLines, location: 31, length: 0, replacement: "x"),
        Edit(name: "append a newline", document: fiveLines, location: 31, length: 0, replacement: "\n"),
        Edit(name: "append a new line of text", document: fiveLines, location: 31, length: 0, replacement: "\nsixth"),
        Edit(name: "delete a character inside line 4", document: fiveLines, location: 21, length: 1, replacement: ""),
        Edit(name: "delete the newline that ends line 2", document: fiveLines, location: 12, length: 1, replacement: ""),
        Edit(name: "delete across three lines", document: fiveLines, location: 8, length: 14, replacement: ""),
        Edit(name: "delete the whole of line 3", document: fiveLines, location: 13, length: 6, replacement: ""),
        Edit(name: "delete the last line and the newline before it", document: fiveLines, location: 25, length: 6, replacement: ""),
        Edit(name: "delete the last line's text only", document: fiveLines, location: 26, length: 5, replacement: ""),
        Edit(name: "delete everything", document: fiveLines, location: 0, length: 31, replacement: ""),
        Edit(name: "replace a range spanning lines with several lines", document: fiveLines, location: 9, length: 12, replacement: "A\nB\nC\nD"),
        Edit(name: "replace everything", document: fiveLines, location: 0, length: 31, replacement: "new\ncontent\nhere\n"),
        Edit(name: "type on the empty last line", document: "a\nb\n", location: 4, length: 0, replacement: "c"),
        Edit(name: "add a line after a trailing newline", document: "a\nb\n", location: 4, length: 0, replacement: "c\n"),
        Edit(name: "delete a trailing newline", document: "a\nb\n", location: 3, length: 1, replacement: ""),
        Edit(name: "delete the last line before a trailing newline", document: "a\nb\n", location: 2, length: 2, replacement: ""),
        Edit(name: "type in the second line of a CRLF document", document: "a\r\nb\r\nc", location: 4, length: 0, replacement: "x"),
        Edit(name: "delete the LF of a CRLF", document: "a\r\nb\r\nc", location: 2, length: 1, replacement: ""),
        Edit(name: "delete the CR of a CRLF", document: "a\r\nb\r\nc", location: 1, length: 1, replacement: ""),
        Edit(name: "insert an LF after a lone CR", document: "a\rb\rc", location: 2, length: 0, replacement: "\n"),
        Edit(name: "delete the text between a CR and an LF", document: "a\rX\nb", location: 2, length: 1, replacement: ""),
        Edit(name: "type after an emoji on line 2", document: "a\n😀b\nc", location: 4, length: 0, replacement: "x")
    ]

    // MARK: - Helpers

    /// A line as the store describes it.
    struct Line: Equatable, CustomStringConvertible {
        let utf16Length: Int
        let lineEndingLength: Int

        var description: String { "\(utf16Length)/\(lineEndingLength)" }
    }

    private func lines(of store: LineGeometryStore) -> [Line] {
        store.allLineGeometries.map { Line(utf16Length: $0.utf16Length, lineEndingLength: $0.lineEndingLength) }
    }

    /// The lines of a store built from scratch from the editor's current text.
    private func rebuiltLines(for storage: NSTextStorage) -> [Line] {
        let reference = LineGeometryStore()
        reference.build(from: NSTextStorage(string: storage.string))
        return lines(of: reference)
    }

    /// The main queue is FIFO: once this returns, every edit event queued
    /// before the call has been delivered.
    private func deliverPendingEditEvents() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    /// An editor holding `document`, with its edit event already delivered.
    private func makeEditor(document: String) async throws -> (CodeEditorView, NSTextStorage) {
        let editor = CodeEditorView(frame: .zero)
        let storage = try #require(editor.textContentStorage?.textStorage)
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: document)
        await deliverPendingEditEvents()
        try #require(lines(of: editor.lineGeometryStore) == rebuiltLines(for: storage))
        return (editor, storage)
    }

    // MARK: - Single edits

    @Test("a single edit leaves the store equal to a rebuilt one", arguments: edits)
    func singleEdit(_ edit: Edit) async throws {
        let (editor, storage) = try await makeEditor(document: edit.document)

        storage.replaceCharacters(
            in: NSRange(location: edit.location, length: edit.length),
            with: edit.replacement
        )
        await deliverPendingEditEvents()

        #expect(lines(of: editor.lineGeometryStore) == rebuiltLines(for: storage))
        #expect(editor.lineGeometryStore.validateTree())
    }

    // MARK: - Sequences

    @Test("typing a word one character per runloop turn keeps the store right")
    func typingOneCharacterAtATime() async throws {
        let (editor, storage) = try await makeEditor(document: Self.fiveLines)

        for (index, character) in "hello".enumerated() {
            storage.replaceCharacters(in: NSRange(location: 8 + index, length: 0), with: String(character))
            await deliverPendingEditEvents()
        }

        #expect(lines(of: editor.lineGeometryStore) == rebuiltLines(for: storage))
        #expect(editor.lineCount == 5)
    }

    @Test("edits made in the same runloop turn leave the store right once their events land")
    func editsInOneTurn() async throws {
        let (editor, storage) = try await makeEditor(document: Self.fiveLines)

        // The later edit is earlier in the document, so the first event's
        // offsets no longer describe the text it is delivered against.
        storage.replaceCharacters(in: NSRange(location: 21, length: 0), with: "four\nand a half\n")
        storage.replaceCharacters(in: NSRange(location: 3, length: 5), with: "X\nY")
        await deliverPendingEditEvents()

        #expect(lines(of: editor.lineGeometryStore) == rebuiltLines(for: storage))
    }

    @Test("an edit that keeps the document length the same is applied")
    func sameLengthReplacement() async throws {
        let (editor, storage) = try await makeEditor(document: Self.fiveLines)

        // "second\nthird" → "sec\nond third": same length, different line breaks.
        storage.replaceCharacters(in: NSRange(location: 6, length: 12), with: "sec\nond third")
        await deliverPendingEditEvents()

        #expect(lines(of: editor.lineGeometryStore) == rebuiltLines(for: storage))
    }

    @Test("random edits keep the store equal to a rebuilt one", arguments: [1, 2, 3, 4] as [UInt64])
    func randomEdits(seed: UInt64) async throws {
        var random = SplitMix64(seed: seed)
        let (editor, storage) = try await makeEditor(document: Self.fiveLines)
        let fragments = ["a", "bc", "\n", "\n\n", "\r\n", "\r", "é", "😀", "x\ny", "line\n", ""]

        for step in 0..<150 {
            // Mostly one edit per turn, as typing does; sometimes two.
            let editsThisTurn = random.next(below: 8) == 0 ? 2 : 1
            for _ in 0..<editsThisTurn {
                let length = storage.length
                let location = random.next(below: length + 1)
                let maxDeletion = min(length - location, 12)
                let deletion = random.next(below: 3) == 0 ? random.next(below: maxDeletion + 1) : 0
                let replacement = fragments[random.next(below: fragments.count)]
                // Never split a surrogate pair: NSTextStorage accepts it but
                // the document is then not valid text.
                // swiftlint:disable:next legacy_objc_type
                let text = storage.string as NSString
                let range = text.rangeOfComposedCharacterSequences(
                    for: NSRange(location: location, length: deletion)
                )
                storage.replaceCharacters(in: range, with: replacement)
            }
            await deliverPendingEditEvents()

            let maintained = lines(of: editor.lineGeometryStore)
            let rebuilt = rebuiltLines(for: storage)
            guard maintained == rebuilt else {
                Issue.record("seed \(seed), step \(step): store \(maintained) but text has \(rebuilt)")
                return
            }
        }
        #expect(editor.lineGeometryStore.validateTree())
    }

    @Test("an edit keeps what layout measured for the lines it does not touch")
    func untouchedLinesKeepMeasuredHeights() async throws {
        let (editor, storage) = try await makeEditor(document: Self.fiveLines)
        let store = editor.lineGeometryStore
        for index in 0..<store.lineCount {
            store.updateMeasuredHeight(CGFloat(20 + index), forLineAt: index)
        }

        // Split line 3 in two; lines 1, 2, 4 and 5 are not part of the edit.
        storage.replaceCharacters(in: NSRange(location: 15, length: 0), with: "\n")
        await deliverPendingEditEvents()

        // A full rebuild would have discarded every measurement.
        let measured = store.allLineGeometries.map(\.measuredHeight)
        #expect(measured == [20, 21, nil, nil, 23, 24])
    }

    // MARK: - Real typing

    #if canImport(AppKit)
    @Test("typing through the text view keeps the store right")
    func typingThroughTheTextView() async throws {
        let (editor, storage) = try await makeEditor(document: Self.fiveLines)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        editor.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        window.contentView?.addSubview(editor)
        defer {
            editor.removeFromSuperview()
            window.close()
        }
        editor.isEditable = true

        for index in 0..<5 {
            editor.insertText("x", replacementRange: NSRange(location: 8 + index, length: 0))
            await deliverPendingEditEvents()
        }

        #expect(editor.string == "first\nsexxxxxcond\nthird\nfourth\nfifth")
        #expect(lines(of: editor.lineGeometryStore) == rebuiltLines(for: storage))
        #expect(editor.lineCount == 5)
    }
    #endif
}

/// A small deterministic generator, so a failing seed can be replayed.
private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    /// A value in `0..<bound`; `bound` must be positive.
    mutating func next(below bound: Int) -> Int {
        Int(next() % UInt64(max(bound, 1)))
    }
}
