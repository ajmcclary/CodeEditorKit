@testable import CodeEditorPlugin
import XCTest

@MainActor
final class EditorDocumentsTests: XCTestCase {
    func testInitFromEmptyDocumentsHasNilActive() {
        let documents = EditorDocuments()
        XCTAssertTrue(documents.documents.isEmpty)
        XCTAssertNil(documents.activeID)
        XCTAssertNil(documents.active)
    }

    func testInitWithDocumentsDefaultsActiveToFirst() {
        let first = EditorDocument(name: "first.swift")
        let second = EditorDocument(name: "second.swift")
        let documents = EditorDocuments(documents: [first, second])
        XCTAssertEqual(documents.activeID, first.id)
        XCTAssertEqual(documents.active?.id, first.id)
    }

    func testInitWithExplicitActiveID() {
        let first = EditorDocument(name: "first.swift")
        let second = EditorDocument(name: "second.swift")
        let documents = EditorDocuments(documents: [first, second], activeID: second.id)
        XCTAssertEqual(documents.activeID, second.id)
    }

    func testOpenAppendsAndActivates() {
        let documents = EditorDocuments()
        let document = EditorDocument(name: "x.swift")
        let returnedID = documents.open(document)
        XCTAssertEqual(returnedID, document.id)
        XCTAssertEqual(documents.documents.count, 1)
        XCTAssertEqual(documents.activeID, document.id)
    }

    func testCloseRemovesAndActivatesPrevious() {
        let first = EditorDocument(name: "first.swift")
        let second = EditorDocument(name: "second.swift")
        let third = EditorDocument(name: "third.swift")
        let documents = EditorDocuments(documents: [first, second, third], activeID: third.id)
        documents.close(third.id)
        XCTAssertEqual(documents.documents.count, 2)
        XCTAssertEqual(documents.activeID, second.id)
    }

    func testCloseOfMiddleTabKeepsActive() {
        let first = EditorDocument(name: "first.swift")
        let second = EditorDocument(name: "second.swift")
        let third = EditorDocument(name: "third.swift")
        let documents = EditorDocuments(documents: [first, second, third], activeID: third.id)
        documents.close(second.id)
        XCTAssertEqual(documents.documents.count, 2)
        XCTAssertEqual(documents.activeID, third.id)
    }

    func testCloseOfFirstTabWithFirstActive() {
        let first = EditorDocument(name: "first.swift")
        let second = EditorDocument(name: "second.swift")
        let documents = EditorDocuments(documents: [first, second], activeID: first.id)
        documents.close(first.id)
        XCTAssertEqual(documents.documents.count, 1)
        XCTAssertEqual(documents.activeID, second.id)
    }

    func testCloseLastTabNilsActive() {
        let only = EditorDocument(name: "only.swift")
        let documents = EditorDocuments(documents: [only])
        documents.close(only.id)
        XCTAssertTrue(documents.documents.isEmpty)
        XCTAssertNil(documents.activeID)
    }

    func testCloseUnknownIdNoOp() {
        let first = EditorDocument(name: "first.swift")
        let documents = EditorDocuments(documents: [first])
        documents.close(UUID())
        XCTAssertEqual(documents.documents.count, 1)
        XCTAssertEqual(documents.activeID, first.id)
    }

    func testCloseAllEmptiesEverything() {
        let documents = EditorDocuments(documents: [
            EditorDocument(name: "a.swift"),
            EditorDocument(name: "b.swift")
        ])
        documents.closeAll()
        XCTAssertTrue(documents.documents.isEmpty)
        XCTAssertNil(documents.activeID)
    }

    func testSetActiveWithKnownIdSwitches() {
        let first = EditorDocument(name: "first.swift")
        let second = EditorDocument(name: "second.swift")
        let documents = EditorDocuments(documents: [first, second], activeID: first.id)
        documents.setActive(second.id)
        XCTAssertEqual(documents.activeID, second.id)
    }

    func testSetActiveWithUnknownIdNoOp() {
        let first = EditorDocument(name: "first.swift")
        let documents = EditorDocuments(documents: [first])
        documents.setActive(UUID())
        XCTAssertEqual(documents.activeID, first.id)
    }

    func testTabsProjectionMatchesDocuments() {
        let first = EditorDocument(name: "first.swift")
        let second = EditorDocument(name: "second.swift")
        let documents = EditorDocuments(documents: [first, second])
        XCTAssertEqual(documents.tabs.map(\.id), [first.id, second.id])
        XCTAssertEqual(documents.tabs.map(\.name), ["first.swift", "second.swift"])
    }

    func testSetLanguageUpdatesTab() {
        let document = EditorDocument(name: "x.swift")
        let documents = EditorDocuments(documents: [document])
        documents.setLanguage(.python, of: document.id)
        XCTAssertEqual(documents.documents.first?.language, .python)
    }

    func testSetLanguageUnknownIdNoOp() {
        let document = EditorDocument(name: "x.swift", language: .swift)
        let documents = EditorDocuments(documents: [document])
        documents.setLanguage(.python, of: UUID())
        XCTAssertEqual(documents.documents.first?.language, .swift)
    }

    func testUpdateAppliesMutationInPlace() {
        let document = EditorDocument(name: "x.swift", text: "old")
        let documents = EditorDocuments(documents: [document])
        documents.update(document.id) { mutable in
            mutable.text = "new"
            mutable.tab.name = "renamed.py"
            mutable.tab.language = .python
            mutable.tab.isDirty = false
        }
        XCTAssertEqual(documents.documents.first?.text, "new")
        XCTAssertEqual(documents.documents.first?.name, "renamed.py")
        XCTAssertEqual(documents.documents.first?.language, .python)
        XCTAssertFalse(documents.documents.first?.isDirty ?? true)
    }

    func testUpdateUnknownIdNoOp() {
        let document = EditorDocument(name: "x.swift", text: "original")
        let documents = EditorDocuments(documents: [document])
        documents.update(UUID()) { mutable in
            mutable.text = "should not apply"
        }
        XCTAssertEqual(documents.documents.first?.text, "original")
    }
}
