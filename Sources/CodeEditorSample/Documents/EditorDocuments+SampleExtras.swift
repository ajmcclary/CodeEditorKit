import CodeEditorPlugin
import Foundation

/// Sample-only conveniences on `EditorDocuments`: file I/O (open/save),
/// Untitled-N naming, sample-catalog reset, and extension-follows-language
/// renaming. The framework deliberately keeps `EditorDocuments` I/O-free;
/// these helpers live in the sample because real hosts vary on sandboxing,
/// security-scoped URLs, and naming policy.
extension EditorDocuments {
    /// Outcome of a `save(_:)` call. Hosts route Save-As through `.untitled`.
    enum SaveOutcome {
        case saved(url: URL)
        case untitled
        case noTab
        case failed(error: Error)
    }

    // MARK: - Open / save

    /// Open a file from disk into a new document and activate it.
    /// If a document is already open for the same URL, activates it and
    /// returns its id. Returns nil if the file cannot be read.
    @discardableResult
    func openFile(url: URL) -> EditorDocument.ID? {
        if let existing = documents.first(where: { $0.url == url }) {
            setActive(existing.id)
            return existing.id
        }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        let language = LanguageDetectionService().detectLanguage(fromExtension: url.pathExtension)
        let document = EditorDocument(
            name: url.lastPathComponent,
            text: text,
            url: url,
            language: language
        )
        return open(document)
    }

    /// Write the active (or specified) document's contents to its
    /// backing URL. On success, clears `isDirty`.
    @discardableResult
    func save(_ id: EditorDocument.ID? = nil) -> SaveOutcome {
        let target = id ?? activeID
        guard let target,
              let document = documents.first(where: { $0.id == target }) else {
            return .noTab
        }
        guard let url = document.url else {
            return .untitled
        }
        do {
            try document.text.write(to: url, atomically: true, encoding: .utf8)
            markClean(target)
            return .saved(url: url)
        } catch {
            return .failed(error: error)
        }
    }

    // MARK: - Untitled naming

    /// Append a new `Untitled-N.swift` document and activate it. The
    /// counter is recovered from the existing documents so it survives
    /// closing and reopening untitled tabs.
    @discardableResult
    func newTab() -> EditorDocument.ID {
        let nextIndex = nextUntitledIndex()
        let document = EditorDocument(
            name: "Untitled-\(nextIndex).swift",
            language: .swift
        )
        return open(document)
    }

    private func nextUntitledIndex() -> Int {
        var maxIndex = 0
        for document in documents {
            let name = document.name
            guard name.hasPrefix("Untitled-") else { continue }
            let suffix = name.dropFirst("Untitled-".count)
            let digits = suffix.prefix { $0.isNumber }
            if let value = Int(digits) {
                maxIndex = max(maxIndex, value)
            }
        }
        return maxIndex + 1
    }

    // MARK: - Sample-catalog reset

    /// Replace the document's text with the canonical sample snippet for
    /// the given language and switch the document's language to match.
    /// Destructive — wipes `isDirty` and clears any prior content.
    func resetToSample(_ language: Language, of id: EditorDocument.ID) {
        update(id) { document in
            document.tab.language = language
            document.tab.name = Self.renamedDocumentName(document.tab.name, for: language)
            document.tab.isDirty = false
            document.text = SampleCodeCatalog.text(for: language)
            document.interactionState = EditorInteractionState()
        }
    }

    // MARK: - Language switch with extension rename

    /// Set the language of a document and rename its file extension to
    /// match the language's primary extension.
    func setLanguageRenaming(_ language: Language, of id: EditorDocument.ID) {
        update(id) { document in
            document.tab.language = language
            document.tab.name = Self.renamedDocumentName(document.tab.name, for: language)
        }
    }

    /// Replace the file extension on `name` with the language's primary
    /// extension. `MyFile.swift` + `.python` → `MyFile.py`; `Untitled`
    /// + `.go` → `Untitled.go`.
    private static func renamedDocumentName(_ name: String, for language: Language) -> String {
        let basename: String
        if let dot = name.lastIndex(of: "."), dot != name.startIndex {
            basename = String(name[..<dot])
        } else {
            basename = name
        }
        let ext = language.fileExtensions.first ?? "txt"
        return "\(basename).\(ext)"
    }
}
