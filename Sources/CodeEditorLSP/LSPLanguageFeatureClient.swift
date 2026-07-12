import Foundation

/// Builds and parses language-feature requests over a JSON-RPC sender.
@MainActor
final class LSPLanguageFeatureClient {
    typealias Request = @Sendable (
        String,
        any Codable & Sendable
    ) async throws -> LSPResponse

    private let request: Request

    init(request: @escaping Request) {
        self.request = request
    }

    func completion(uri: String, position: Position) async throws -> CompletionList {
        let response = try await request(
            LSPLanguageFeatures.Methods.completion,
            LSPLanguageFeatures.createCompletionParams(uri: uri, position: position)
        )
        return try LSPLanguageFeatures.parseCompletionResponse(response)
    }

    func hover(uri: String, position: Position) async throws -> Hover? {
        let response = try await request(
            LSPLanguageFeatures.Methods.hover,
            LSPLanguageFeatures.createHoverParams(uri: uri, position: position)
        )
        return LSPLanguageFeatures.parseHoverResponse(response)
    }

    func definition(uri: String, position: Position) async throws -> [Location] {
        let response = try await request(
            LSPLanguageFeatures.Methods.definition,
            LSPLanguageFeatures.createDefinitionParams(uri: uri, position: position)
        )
        return try LSPLanguageFeatures.parseDefinitionResponse(response)
    }

    func documentSymbols(uri: String) async throws -> [LSPDocumentSymbol] {
        let response = try await request(
            LSPLanguageFeatures.Methods.documentSymbol,
            LSPLanguageFeatures.createDocumentSymbolParams(uri: uri)
        )
        return try LSPLanguageFeatures.parseDocumentSymbolResponse(response)
    }

    func semanticTokens(uri: String) async throws -> SemanticTokens {
        let response = try await request(
            "textDocument/semanticTokens/full",
            SemanticTokensParams(textDocument: TextDocumentIdentifier(uri: uri))
        )
        return try response.decode(as: SemanticTokens.self)
    }

    func semanticTokenDelta(
        uri: String,
        previousResultID: String
    ) async throws -> SemanticTokensDelta {
        let response = try await request(
            "textDocument/semanticTokens/full/delta",
            SemanticTokensDeltaParams(
                textDocument: TextDocumentIdentifier(uri: uri),
                previousResultId: previousResultID
            )
        )
        return try response.decode(as: SemanticTokensDelta.self)
    }

    func semanticTokens(uri: String, range: LSPRange) async throws -> SemanticTokens {
        let response = try await request(
            "textDocument/semanticTokens/range",
            SemanticTokensRangeParams(
                textDocument: TextDocumentIdentifier(uri: uri),
                range: range
            )
        )
        return try response.decode(as: SemanticTokens.self)
    }
}
