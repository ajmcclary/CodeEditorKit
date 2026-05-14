#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing

/// Smoke coverage for the sample-only extensions on `EditorDocuments`:
/// `resetToSample(_:of:)` and `setLanguageRenaming(_:of:)`. The file-I/O
/// helpers (`openFile`, `save`, `newTab`) are exercised in
/// `EditorDocumentsOpenFileTests`.
@MainActor
@Suite("EditorDocuments sample extras")
struct EditorDocumentsSampleExtrasTests {
    @Test("resetToSample swaps text, switches language, and clears isDirty")
    func resetToSampleReplacesContent() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()  // Untitled-1.swift, language = .swift
        documents.textBinding(for: id).wrappedValue = "let dirty = true\n"
        #expect(documents.documents.first { $0.id == id }?.isDirty == true)

        documents.resetToSample(.python, of: id)

        let document = try #require(documents.documents.first { $0.id == id })
        #expect(document.language == .python)
        #expect(document.isDirty == false)
        #expect(document.text == SampleCodeCatalog.text(for: .python))
        #expect(document.name.hasSuffix(".py"))
    }

    @Test("setLanguageRenaming swaps language and renames file extension")
    func setLanguageRenamingFollowsLanguage() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()  // "Untitled-1.swift"

        documents.setLanguageRenaming(.go, of: id)

        let document = try #require(documents.documents.first { $0.id == id })
        #expect(document.language == .go)
        #expect(document.name == "Untitled-1.go")
    }

    @Test("setLanguageRenaming handles names without an extension")
    func setLanguageRenamingAddsExtensionToBareName() {
        let documents = EditorDocuments()
        let document = EditorDocument(name: "Untitled", language: .swift)
        let id = documents.open(document)

        documents.setLanguageRenaming(.python, of: id)

        let opened = documents.documents.first { $0.id == id }
        #expect(opened?.language == .python)
        #expect(opened?.name == "Untitled.py")
    }
}
#endif
