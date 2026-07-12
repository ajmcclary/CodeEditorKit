import Foundation

/// Owns document notification construction and per-document diagnostics.
@MainActor
final class LSPDocumentSession {
    private(set) var diagnostics: [String: [LSPDiagnostic]] = [:]

    func openParameters(
        uri: String,
        languageID: String,
        version: Int,
        text: String
    ) -> DidOpenTextDocumentParams {
        DidOpenTextDocumentParams(
            textDocument: TextDocumentItem(
                uri: uri,
                languageId: languageID,
                version: version,
                text: text
            )
        )
    }

    func changeParameters(
        uri: String,
        version: Int,
        changes: [TextDocumentContentChangeEvent]
    ) -> DidChangeTextDocumentParams {
        DidChangeTextDocumentParams(
            textDocument: VersionedTextDocumentIdentifier(uri: uri, version: version),
            contentChanges: changes
        )
    }

    func closeParameters(uri: String) -> DidCloseTextDocumentParams {
        diagnostics.removeValue(forKey: uri)
        return DidCloseTextDocumentParams(
            textDocument: TextDocumentIdentifier(uri: uri)
        )
    }

    func updateDiagnostics(_ values: [LSPDiagnostic], for uri: String) {
        diagnostics[uri] = values
    }

    func removeAll() {
        diagnostics.removeAll()
    }
}
