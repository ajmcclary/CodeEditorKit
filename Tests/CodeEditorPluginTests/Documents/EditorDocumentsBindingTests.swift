import CodeEditorLanguages
@testable import CodeEditorPlugin
import SwiftUI
import XCTest

@MainActor
final class EditorDocumentsBindingTests: XCTestCase {
    func testTextBindingReadsStoredText() {
        let document = EditorDocument(name: "x.swift", text: "let x = 1")
        let documents = EditorDocuments(documents: [document])
        let binding = documents.textBinding(for: document.id)
        XCTAssertEqual(binding.wrappedValue, "let x = 1")
    }

    func testTextBindingReadsEmptyForUnknownId() {
        let documents = EditorDocuments()
        let binding = documents.textBinding(for: UUID())
        XCTAssertEqual(binding.wrappedValue, "")
    }

    func testTextBindingWriteUpdatesStoredText() {
        let document = EditorDocument(name: "x.swift", text: "")
        let documents = EditorDocuments(documents: [document])
        let binding = documents.textBinding(for: document.id)
        binding.wrappedValue = "let y = 2"
        XCTAssertEqual(documents.documents.first?.text, "let y = 2")
    }

    func testTextBindingWriteFlipsDirtyOnDifferentValue() {
        let document = EditorDocument(name: "x.swift", text: "old")
        let documents = EditorDocuments(documents: [document])
        XCTAssertFalse(documents.documents.first?.isDirty ?? true)
        let binding = documents.textBinding(for: document.id)
        binding.wrappedValue = "new"
        XCTAssertTrue(documents.documents.first?.isDirty ?? false)
    }

    func testTextBindingWriteOfSameValueKeepsClean() {
        let document = EditorDocument(name: "x.swift", text: "same")
        let documents = EditorDocuments(documents: [document])
        let binding = documents.textBinding(for: document.id)
        binding.wrappedValue = "same"
        XCTAssertFalse(documents.documents.first?.isDirty ?? true)
    }

    func testMarkCleanResetsDirty() {
        var document = EditorDocument(name: "x.swift")
        document.isDirty = true
        let documents = EditorDocuments(documents: [document])
        documents.markClean(document.id)
        XCTAssertFalse(documents.documents.first?.isDirty ?? true)
    }

    func testMarkCleanUnknownIdNoOp() {
        let document = EditorDocument(name: "x.swift", isDirty: true)
        let documents = EditorDocuments(documents: [document])
        documents.markClean(UUID())
        XCTAssertTrue(documents.documents.first?.isDirty ?? false)
    }

    func testInteractionBindingReadsStored() {
        let initial = EditorInteractionState(
            cursorPositions: [EditorCursorPosition(line: 5, column: 10)]
        )
        let document = EditorDocument(name: "x.swift", interactionState: initial)
        let documents = EditorDocuments(documents: [document])
        let binding = documents.interactionBinding(for: document.id)
        XCTAssertEqual(binding.wrappedValue, initial)
    }

    func testInteractionBindingWriteUpdatesStored() {
        let document = EditorDocument(name: "x.swift")
        let documents = EditorDocuments(documents: [document])
        let binding = documents.interactionBinding(for: document.id)
        let newState = EditorInteractionState(
            cursorPositions: [EditorCursorPosition(line: 1, column: 1)]
        )
        binding.wrappedValue = newState
        XCTAssertEqual(documents.documents.first?.interactionState, newState)
    }

    func testInteractionBindingReadsEmptyForUnknownId() {
        let documents = EditorDocuments()
        let binding = documents.interactionBinding(for: UUID())
        XCTAssertEqual(binding.wrappedValue, EditorInteractionState())
    }

    func testTextBindingHotSwapsOnActiveChange() {
        let first = EditorDocument(name: "first.swift", text: "first text")
        let second = EditorDocument(name: "second.swift", text: "second text")
        let documents = EditorDocuments(documents: [first, second], activeID: first.id)
        let firstBinding = documents.textBinding(for: first.id)
        let secondBinding = documents.textBinding(for: second.id)
        // Bindings are id-keyed, so they don't change with activeID — each
        // binding always reads the document it was created for.
        XCTAssertEqual(firstBinding.wrappedValue, "first text")
        XCTAssertEqual(secondBinding.wrappedValue, "second text")
        documents.setActive(second.id)
        XCTAssertEqual(firstBinding.wrappedValue, "first text")
        XCTAssertEqual(secondBinding.wrappedValue, "second text")
    }

    func testTabsBindingGetReturnsTabs() {
        let first = EditorDocument(name: "first.swift")
        let second = EditorDocument(name: "second.swift")
        let documents = EditorDocuments(documents: [first, second])
        let binding = documents.tabsBinding
        XCTAssertEqual(binding.wrappedValue.map(\.id), [first.id, second.id])
    }

    func testTabsBindingSetRemovesMissingId() {
        let first = EditorDocument(name: "first.swift")
        let second = EditorDocument(name: "second.swift")
        let documents = EditorDocuments(documents: [first, second], activeID: second.id)
        let binding = documents.tabsBinding
        binding.wrappedValue = [first.tab]
        XCTAssertEqual(documents.documents.map(\.id), [first.id])
        XCTAssertEqual(documents.activeID, first.id)
    }

    func testTabsBindingSetReordersDocuments() {
        let first = EditorDocument(name: "first.swift", text: "first")
        let second = EditorDocument(name: "second.swift", text: "second")
        let third = EditorDocument(name: "third.swift", text: "third")
        let documents = EditorDocuments(documents: [first, second, third])
        let binding = documents.tabsBinding
        binding.wrappedValue = [third.tab, first.tab, second.tab]
        XCTAssertEqual(documents.documents.map(\.id), [third.id, first.id, second.id])
        XCTAssertEqual(documents.documents.first?.text, "third")
    }

    func testTabsBindingSetIgnoresUnknownIds() {
        let first = EditorDocument(name: "first.swift")
        let documents = EditorDocuments(documents: [first])
        let phantom = TabModel(name: "phantom.swift")
        let binding = documents.tabsBinding
        binding.wrappedValue = [first.tab, phantom]
        XCTAssertEqual(documents.documents.map(\.id), [first.id])
    }
}
