import CodeEditorPlugin

/// Human-readable digest of the LSP server's advertised capabilities.
/// Built from a `ServerCapabilities` after `initialize` completes; used by
/// `LSPInspectorPanel` to render the capability checklist.
struct ServerCapabilitiesSummary: Equatable {
    let hasHover: Bool
    let hasDefinition: Bool
    let hasDiagnostics: Bool  // diagnostics are pushed via notifications, not a capability flag
    let hasDocumentSymbols: Bool
    let hasCompletion: Bool

    init(_ caps: ServerCapabilities?) {
        self.hasHover = caps?.hoverProvider ?? false
        self.hasDefinition = caps?.definitionProvider ?? false
        // sourcekit-lsp pushes diagnostics by default — there's no capability
        // flag for "publish diagnostics" in the framework's ServerCapabilities
        // shape, so we treat presence of any capability as a proxy.
        self.hasDiagnostics = caps != nil
        self.hasDocumentSymbols = caps?.documentSymbolProvider ?? false
        self.hasCompletion = caps?.completionProvider != nil
    }

    init(
        hasHover: Bool,
        hasDefinition: Bool,
        hasDiagnostics: Bool,
        hasDocumentSymbols: Bool,
        hasCompletion: Bool
    ) {
        self.hasHover = hasHover
        self.hasDefinition = hasDefinition
        self.hasDiagnostics = hasDiagnostics
        self.hasDocumentSymbols = hasDocumentSymbols
        self.hasCompletion = hasCompletion
    }
}
