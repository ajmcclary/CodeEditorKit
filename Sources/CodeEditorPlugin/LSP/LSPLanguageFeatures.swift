import Foundation

// MARK: - LSP Language Features

/// Provides language feature request building for LSP communication
public enum LSPLanguageFeatures {
    // MARK: - Completion

    /// Creates completion request parameters
    /// - Parameters:
    ///   - uri: Document URI
    ///   - position: Cursor position
    /// - Returns: Completion parameters
    public static func createCompletionParams(
        uri: String,
        position: Position
    ) -> CompletionParams {
        CompletionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: position
        )
    }

    /// Parses completion response
    /// - Parameter response: The LSP response
    /// - Returns: Completion list
    public static func parseCompletionResponse(_ response: LSPResponse) throws -> CompletionList {
        try response.decode(as: CompletionList.self)
    }

    // MARK: - Hover

    /// Creates hover request parameters
    /// - Parameters:
    ///   - uri: Document URI
    ///   - position: Cursor position
    /// - Returns: Hover parameters
    public static func createHoverParams(
        uri: String,
        position: Position
    ) -> HoverParams {
        HoverParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: position
        )
    }

    /// Parses hover response
    /// - Parameter response: The LSP response
    /// - Returns: Hover information if available
    public static func parseHoverResponse(_ response: LSPResponse) -> Hover? {
        try? response.decode(as: Hover.self)
    }

    // MARK: - Definition

    /// Creates definition request parameters
    /// - Parameters:
    ///   - uri: Document URI
    ///   - position: Cursor position
    /// - Returns: Definition parameters
    public static func createDefinitionParams(
        uri: String,
        position: Position
    ) -> DefinitionParams {
        DefinitionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: position
        )
    }

    /// Parses definition response (handles both single Location and array)
    /// - Parameter response: The LSP response
    /// - Returns: Array of locations
    public static func parseDefinitionResponse(_ response: LSPResponse) throws -> [Location] {
        // Handle both single Location and array of Locations
        if let location = try? response.decode(as: Location.self) {
            return [location]
        } else {
            return try response.decode(as: [Location].self)
        }
    }

    // MARK: - Document Symbols

    /// Creates document symbols request parameters
    /// - Parameter uri: Document URI
    /// - Returns: Document symbol parameters
    public static func createDocumentSymbolParams(uri: String) -> DocumentSymbolParams {
        DocumentSymbolParams(
            textDocument: TextDocumentIdentifier(uri: uri)
        )
    }

    /// Parses document symbols response
    /// - Parameter response: The LSP response
    /// - Returns: Array of document symbols
    public static func parseDocumentSymbolResponse(_ response: LSPResponse) throws -> [LSPDocumentSymbol] {
        try response.decode(as: [LSPDocumentSymbol].self)
    }
}

// MARK: - LSP Method Constants

extension LSPLanguageFeatures {
    /// LSP method names for language features
    public enum Methods {
        /// Code completion method
        public static let completion = "textDocument/completion"
        /// Hover information method
        public static let hover = "textDocument/hover"
        /// Go to definition method
        public static let definition = "textDocument/definition"
        /// Document symbols method
        public static let documentSymbol = "textDocument/documentSymbol"
        /// Find references method
        public static let references = "textDocument/references"
        /// Rename symbol method
        public static let rename = "textDocument/rename"
        /// Document formatting method
        public static let formatting = "textDocument/formatting"
        /// Range formatting method
        public static let rangeFormatting = "textDocument/rangeFormatting"
        /// Code action method
        public static let codeAction = "textDocument/codeAction"
        /// Code lens method
        public static let codeLens = "textDocument/codeLens"
        /// Signature help method
        public static let signatureHelp = "textDocument/signatureHelp"
    }
}
