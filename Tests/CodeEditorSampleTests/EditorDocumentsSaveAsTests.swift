#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing

/// Coverage for the sample-only `EditorDocuments.saveAs(to:)` Save-As
/// primitive. Picker presentation and AppState orchestration are covered
/// by manual smoke; this suite verifies the rebind / write logic.
@MainActor
@Suite("EditorDocuments saveAs")
struct EditorDocumentsSaveAsTests {
    @Test("saveAs writes the document text to the chosen URL")
    func saveAsWritesContent() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()                    // Untitled-1.swift, .swift
        documents.textBinding(for: id).wrappedValue = "let saved = true\n"

        let destination = uniqueTempURL(extension: "swift")
        defer { try? FileManager.default.removeItem(at: destination) }

        let outcome = documents.saveAs(to: destination, id)

        guard case .saved(let url) = outcome else {
            Issue.record("expected .saved, got \(outcome)")
            return
        }
        #expect(url == destination)
        let onDisk = try String(contentsOf: destination, encoding: .utf8)
        #expect(onDisk == "let saved = true\n")
    }

    @Test("saveAs rebinds url, name, language, and clears isDirty")
    func saveAsRebindsDocument() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()
        documents.textBinding(for: id).wrappedValue = "dirty\n"
        #expect(documents.documents.first { $0.id == id }?.isDirty == true)

        let destination = uniqueTempURL(extension: "py")
        defer { try? FileManager.default.removeItem(at: destination) }

        _ = documents.saveAs(to: destination, id)

        let document = try #require(documents.documents.first { $0.id == id })
        #expect(document.url == destination)
        #expect(document.name == destination.lastPathComponent)
        #expect(document.language == .python)
        #expect(document.isDirty == false)
    }

    @Test("saveAs detects language from extension — swift")
    func saveAsDetectsSwiftFromExtension() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()
        let destination = uniqueTempURL(extension: "swift")
        defer { try? FileManager.default.removeItem(at: destination) }

        _ = documents.saveAs(to: destination, id)
        let document = try #require(documents.documents.first { $0.id == id })
        #expect(document.language == .swift)
    }

    @Test("saveAs detects language from extension — python")
    func saveAsDetectsPythonFromExtension() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()
        let destination = uniqueTempURL(extension: "py")
        defer { try? FileManager.default.removeItem(at: destination) }

        _ = documents.saveAs(to: destination, id)
        let document = try #require(documents.documents.first { $0.id == id })
        #expect(document.language == .python)
    }

    @Test("saveAs falls back to plainText for unknown extensions")
    func saveAsFallsBackToPlainText() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()
        let destination = uniqueTempURL(extension: "zzznotalang")
        defer { try? FileManager.default.removeItem(at: destination) }

        _ = documents.saveAs(to: destination, id)
        let document = try #require(documents.documents.first { $0.id == id })
        #expect(document.language == .plainText)
    }

    @Test("saveAs returns .noTab when there's no active tab and no explicit id")
    func saveAsWithNoActiveTabReturnsNoTab() {
        let documents = EditorDocuments()
        let destination = uniqueTempURL(extension: "swift")
        defer { try? FileManager.default.removeItem(at: destination) }

        let outcome = documents.saveAs(to: destination)
        if case .noTab = outcome {
            // expected
        } else {
            Issue.record("expected .noTab, got \(outcome)")
        }
    }

    @Test("saveAs returns .failed and preserves the document on write failure")
    func saveAsFailedWritePreservesDocument() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()
        let originalName = try #require(documents.documents.first { $0.id == id }?.name)
        let originalLanguage = try #require(documents.documents.first { $0.id == id }?.language)

        // Directory that does not and cannot exist — write must fail.
        let destination = URL(fileURLWithPath: "/this/path/does/not/exist/\(UUID().uuidString).swift")

        let outcome = documents.saveAs(to: destination, id)

        guard case .failed = outcome else {
            Issue.record("expected .failed, got \(outcome)")
            return
        }
        let document = try #require(documents.documents.first { $0.id == id })
        #expect(document.url == nil)
        #expect(document.name == originalName)
        #expect(document.language == originalLanguage)
    }

    @Test("saveAs overwrites an existing file at the destination")
    func saveAsOverwritesExistingFile() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()
        documents.textBinding(for: id).wrappedValue = "new\n"

        let destination = uniqueTempURL(extension: "swift")
        try "old\n".write(to: destination, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: destination) }

        _ = documents.saveAs(to: destination, id)
        let onDisk = try String(contentsOf: destination, encoding: .utf8)
        #expect(onDisk == "new\n")
    }

    // MARK: - Helpers

    private func uniqueTempURL(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).\(ext)")
    }
}
#endif
