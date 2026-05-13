#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
import XCTest

final class DocumentStoreOpenFileTests: XCTestCase {
    @MainActor
    func testOpenFileCreatesTabAndInfersLanguage() throws {
        let store = DocumentStore()
        let initialCount = store.tabs.count
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".swift")
        try "let x = 1\n".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let id = try XCTUnwrap(store.openFile(url: tmp))

        XCTAssertEqual(store.tabs.count, initialCount + 1)
        let opened = try XCTUnwrap(store.tabs.first { $0.id == id })
        XCTAssertEqual(opened.url, tmp)
        XCTAssertEqual(opened.language, .swift)
        XCTAssertEqual(store.activeTabID, id)
    }

    @MainActor
    func testOpenFileActivatesExistingTabForSameURL() throws {
        let store = DocumentStore()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".swift")
        try "let x = 1\n".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let firstID = try XCTUnwrap(store.openFile(url: tmp))
        let countAfterFirst = store.tabs.count
        let secondID = try XCTUnwrap(store.openFile(url: tmp))

        XCTAssertEqual(firstID, secondID)
        XCTAssertEqual(store.tabs.count, countAfterFirst)
        XCTAssertEqual(store.activeTabID, firstID)
    }

    @MainActor
    func testOpenFileReturnsNilForMissingFile() {
        let store = DocumentStore()
        let nonexistent = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-missing.swift")

        let result = store.openFile(url: nonexistent)

        XCTAssertNil(result)
    }
}
#endif
