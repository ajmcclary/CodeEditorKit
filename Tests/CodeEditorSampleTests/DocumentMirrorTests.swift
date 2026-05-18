#if canImport(AppKit)
@testable import CodeEditorSample
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import XCTest

final class DocumentMirrorTests: XCTestCase {
    private func tempRoot() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MirrorTest-" + UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @MainActor
    func testOpenTabWritesShadowFile() throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let mirror = DocumentMirror(rootDirectory: root)
        let id = UUID()

        let url = try mirror.openTab(id: id, text: "let x = 1\n", fileExtension: "swift")

        XCTAssertTrue(url.path.hasPrefix(root.path))
        let onDisk = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(onDisk, "let x = 1\n")
    }

    @MainActor
    func testHandleTextChangeDebouncesWrites() async throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let mirror = DocumentMirror(rootDirectory: root, debounceInterval: 0.05)
        let id = UUID()
        let url = try mirror.openTab(id: id, text: "v1", fileExtension: "swift")

        mirror.handleTextChange(id: id, newText: "v2")
        mirror.handleTextChange(id: id, newText: "v3")
        mirror.handleTextChange(id: id, newText: "v4")

        try await Task.sleep(nanoseconds: 150_000_000)

        let onDisk = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(onDisk, "v4")
    }

    @MainActor
    func testCloseTabDeletesShadowFile() throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let mirror = DocumentMirror(rootDirectory: root)
        let id = UUID()
        let url = try mirror.openTab(id: id, text: "x", fileExtension: "swift")

        mirror.closeTab(id: id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    @MainActor
    func testCleanupStaleShadowsRemovesUnknownFiles() throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let mirror = DocumentMirror(rootDirectory: root)
        let stale = root.appendingPathComponent(".codeeditor-sample")
            .appendingPathComponent("stale.swift")
        try "old".write(to: stale, atomically: true, encoding: .utf8)

        mirror.cleanupStaleShadows()

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
    }

    @MainActor
    func testCleanupStaleShadowsPreservesOpenTabFiles() throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let mirror = DocumentMirror(rootDirectory: root)
        let id = UUID()
        let url = try mirror.openTab(id: id, text: "alive", fileExtension: "swift")

        mirror.cleanupStaleShadows()

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
}
#endif
