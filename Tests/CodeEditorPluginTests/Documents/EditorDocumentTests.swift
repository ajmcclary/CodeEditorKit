import CodeEditorCommon
@testable import CodeEditorPlugin
@testable import CodeEditorView
import XCTest

final class EditorDocumentTests: XCTestCase {
    func testInitDefaultsAreEmpty() {
        let document = EditorDocument(name: "Untitled.swift")
        XCTAssertEqual(document.name, "Untitled.swift")
        XCTAssertEqual(document.text, "")
        XCTAssertNil(document.url)
        XCTAssertNil(document.language)
        XCTAssertEqual(document.interactionState, EditorInteractionState())
        XCTAssertFalse(document.isDirty)
    }

    func testIdForwardsToTabId() {
        let id = UUID()
        let document = EditorDocument(name: "x.swift", id: id)
        XCTAssertEqual(document.id, id)
        XCTAssertEqual(document.id, document.tab.id)
    }

    func testNameAccessorReadsAndWritesThroughTab() {
        var document = EditorDocument(name: "old.swift")
        document.name = "new.swift"
        XCTAssertEqual(document.name, "new.swift")
        XCTAssertEqual(document.tab.name, "new.swift")
    }

    func testUrlAccessorReadsAndWritesThroughTab() {
        var document = EditorDocument(name: "x.swift")
        let url = URL(fileURLWithPath: "/tmp/x.swift")
        document.url = url
        XCTAssertEqual(document.url, url)
        XCTAssertEqual(document.tab.url, url)
    }

    func testLanguageAccessorReadsAndWritesThroughTab() {
        var document = EditorDocument(name: "x.swift")
        document.language = .swift
        XCTAssertEqual(document.language, .swift)
        XCTAssertEqual(document.tab.language, .swift)
    }

    func testIsDirtyAccessorReadsAndWritesThroughTab() {
        var document = EditorDocument(name: "x.swift")
        document.isDirty = true
        XCTAssertTrue(document.isDirty)
        XCTAssertTrue(document.tab.isDirty)
    }

    func testCodableRoundTrip() throws {
        let original = EditorDocument(
            name: "round.swift",
            text: "let x = 1\n",
            url: URL(fileURLWithPath: "/tmp/round.swift"),
            language: .swift,
            interactionState: EditorInteractionState(
                cursorPositions: [EditorCursorPosition(line: 1, column: 3)]
            ),
            isDirty: true,
            id: UUID()
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EditorDocument.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.url, original.url)
        XCTAssertEqual(decoded.language, original.language)
        XCTAssertEqual(decoded.interactionState, original.interactionState)
        XCTAssertEqual(decoded.isDirty, original.isDirty)
    }
}
