#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import XCTest

@MainActor
final class EditorDocumentsOpenFileTests: XCTestCase {
    func testOpenFileCreatesDocumentAndInfersLanguage() throws {
        let documents = EditorDocuments()
        let initialCount = documents.documents.count

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".swift")
        try "let x = 1\n".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let id = try XCTUnwrap(documents.openFile(url: tmp))

        XCTAssertEqual(documents.documents.count, initialCount + 1)
        let opened = try XCTUnwrap(documents.documents.first { $0.id == id })
        XCTAssertEqual(opened.url, tmp)
        XCTAssertEqual(opened.language, .swift)
        XCTAssertEqual(opened.text, "let x = 1\n")
        XCTAssertEqual(documents.activeID, id)
    }

    func testOpenFileForExistingURLReactivates() throws {
        let documents = EditorDocuments()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".swift")
        try "let x = 1\n".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let first = try XCTUnwrap(documents.openFile(url: tmp))
        let second = documents.openFile(url: tmp)

        XCTAssertEqual(documents.documents.count, 1)
        XCTAssertEqual(first, second)
    }

    func testSaveWritesBytesAndClearsDirty() throws {
        let documents = EditorDocuments()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".swift")
        try "initial\n".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let id = try XCTUnwrap(documents.openFile(url: tmp))
        documents.textBinding(for: id).wrappedValue = "updated\n"
        XCTAssertTrue(documents.documents.first?.isDirty ?? false)

        switch documents.save() {
        case .saved(let url):
            XCTAssertEqual(url, tmp)

        case .untitled, .noTab, .failed:
            XCTFail("expected .saved")
        }
        XCTAssertFalse(documents.documents.first?.isDirty ?? true)

        let onDisk = try String(contentsOf: tmp, encoding: .utf8)
        XCTAssertEqual(onDisk, "updated\n")
    }

    func testSaveUntitledTabReturnsUntitled() {
        let documents = EditorDocuments()
        documents.newTab()
        let outcome = documents.save()
        if case .untitled = outcome {
            // expected
        } else {
            XCTFail("expected .untitled")
        }
    }

    func testNewTabIncrementsUntitledCounter() {
        let documents = EditorDocuments()
        documents.newTab()
        documents.newTab()
        documents.newTab()
        let names = documents.documents.map(\.name)
        XCTAssertEqual(names, ["Untitled-1.swift", "Untitled-2.swift", "Untitled-3.swift"])
    }
}
#endif
