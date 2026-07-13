import Foundation
import Testing

// Deliberately the ONLY editor-related import: the contract must be
// implementable with no dependency on the editor view or any other
// CodeEditor target.
@testable import CodeEditorHighlightingCore

/// A minimal provider that proves ``HighlightRangeProviding`` can be
/// conformed to using only value types — no editor view in sight.
private final class StubValueProvider: HighlightRangeProviding, @unchecked Sendable {
    private(set) var preparedLanguage: String?
    private(set) var lastEdit: HighlightTextEdit?

    func prepare(for document: HighlightDocumentSnapshot) async {
        preparedLanguage = document.languageID
    }

    func invalidate(
        for edit: HighlightTextEdit,
        in document: HighlightDocumentSnapshot
    ) async -> HighlightInvalidation {
        lastEdit = edit
        return .everything(length: document.utf16Length)
    }

    func highlights(
        in range: HighlightRange,
        of document: HighlightDocumentSnapshot
    ) async throws -> [HighlightToken] {
        guard !document.isEmpty, range.length > 0 else { return [] }
        return [HighlightToken(range: range, tokenType: "keyword", text: "let")]
    }
}

@Suite("Highlight contract value types")
struct HighlightContractValueTests {
    @Test("HighlightRange bridges losslessly to and from NSRange")
    func rangeBridging() {
        let ns = NSRange(location: 4, length: 7)
        let range = HighlightRange(ns)
        #expect(range.location == 4)
        #expect(range.length == 7)
        #expect(range.upperBound == 11)
        #expect(range.nsRange == ns)
        #expect(HighlightRange(location: 4, length: 7) == range)
    }

    @Test("snapshot reports UTF-16 length, not character count")
    func snapshotLength() {
        // "e" + combining acute is 2 UTF-16 units; an emoji is a surrogate pair.
        let snapshot = HighlightDocumentSnapshot(text: "e\u{0301}\u{1F600}", languageID: "swift")
        #expect(snapshot.utf16Length == 4)
        #expect(snapshot.isEmpty == false)
        #expect(HighlightDocumentSnapshot(text: "", languageID: "swift").isEmpty)
    }

    @Test("invalidation helpers cover the expected regions")
    func invalidationHelpers() {
        #expect(HighlightInvalidation.none.isEmpty)
        #expect(HighlightInvalidation.everything(length: 0).isEmpty)
        let all = HighlightInvalidation.everything(length: 10)
        #expect(all.ranges == [HighlightRange(location: 0, length: 10)])
        #expect(all.isEmpty == false)
        #expect(HighlightInvalidation.range(HighlightRange(location: 2, length: 3)).ranges.count == 1)
    }

    @Test("text edit retains the pre-edit source when provided")
    func textEditPreviousText() {
        let edit = HighlightTextEdit(
            editedRange: HighlightRange(location: 0, length: 0),
            changeInLength: 3,
            previousText: "old"
        )
        #expect(edit.previousText == "old")
        #expect(edit.changeInLength == 3)
    }
}

@Suite("Highlight provider contract")
struct HighlightProviderContractTests {
    @Test("provider drives prepare / invalidate / highlights on value types")
    func providerRoundTrip() async throws {
        let provider = StubValueProvider()
        let document = HighlightDocumentSnapshot(text: "let x = 1", languageID: "swift")

        await provider.prepare(for: document)
        #expect(provider.preparedLanguage == "swift")

        let edit = HighlightTextEdit(
            editedRange: HighlightRange(location: 0, length: 0),
            changeInLength: 1,
            previousText: "et x = 1"
        )
        let invalidation = await provider.invalidate(for: edit, in: document)
        #expect(invalidation.ranges == [HighlightRange(location: 0, length: document.utf16Length)])
        #expect(provider.lastEdit == edit)

        let tokens = try await provider.highlights(
            in: HighlightRange(location: 0, length: 3),
            of: document
        )
        #expect(tokens == [HighlightToken(range: HighlightRange(location: 0, length: 3), tokenType: "keyword", text: "let")])
    }

    @Test("provider returns no tokens for an empty document")
    func providerEmptyDocument() async throws {
        let provider = StubValueProvider()
        let tokens = try await provider.highlights(
            in: HighlightRange(location: 0, length: 0),
            of: HighlightDocumentSnapshot(text: "", languageID: "plaintext")
        )
        #expect(tokens.isEmpty)
    }
}
