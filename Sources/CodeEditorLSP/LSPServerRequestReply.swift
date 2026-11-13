import Foundation

/// The reply the client sends to a server→client request.
///
/// The client implements none of the dynamic features these requests ask
/// for, so it acknowledges the ones whose result may be `null`, answers
/// `workspace/configuration` with one `null` per requested item ("no
/// configuration"), answers `workspace/workspaceFolders` with the folders
/// sent in `initialize`, and rejects everything else with JSON-RPC
/// `-32601 Method not found`. What matters is that every request is
/// answered: servers (sourcekit-lsp among them) stop replying to the client
/// while one of their requests is outstanding.
struct LSPServerRequestReply: Encodable {
    enum Outcome {
        /// `"result": null`
        case null
        /// `"result": [null, null, …]`
        case nulls(count: Int)
        /// `"result": [WorkspaceFolder]`
        case folders([WorkspaceFolder])
        /// `"error": {code, message}`
        case error(code: Int, message: String)
    }

    let id: RequestId
    let outcome: Outcome

    /// Requests answered with `"result": null`.
    static let acknowledgedMethods: Set<String> = [
        "client/registerCapability",
        "client/unregisterCapability",
        "window/workDoneProgress/create",
        "window/showMessageRequest",
        "workspace/semanticTokens/refresh",
        "workspace/inlayHint/refresh",
        "workspace/inlineValue/refresh",
        "workspace/codeLens/refresh",
        "workspace/diagnostic/refresh",
        "workspace/foldingRange/refresh"
    ]

    /// JSON-RPC "Method not found".
    static let methodNotFound = -32_601

    /// Upper bound on the `null` entries sent for `workspace/configuration`.
    static let maxConfigurationItems = 1_024

    static func reply(
        to method: String,
        id: RequestId,
        params: Data,
        workspaceFolders: [WorkspaceFolder] = []
    ) -> Self {
        if method == "workspace/configuration" {
            return Self(id: id, outcome: .nulls(count: configurationItemCount(in: params)))
        }
        if method == "workspace/workspaceFolders" {
            return Self(id: id, outcome: .folders(workspaceFolders))
        }
        if acknowledgedMethods.contains(method) {
            return Self(id: id, outcome: .null)
        }
        return Self(id: id, outcome: .error(code: methodNotFound, message: "Unhandled method \(method)"))
    }

    private static func configurationItemCount(in params: Data) -> Int {
        struct ConfigurationParams: Decodable {
            let items: [IgnoredItem]
        }
        struct IgnoredItem: Decodable {
            init(from _: Decoder) {}
        }
        let count = (try? JSONDecoder().decode(ConfigurationParams.self, from: params))?.items.count ?? 0
        return min(count, maxConfigurationItems)
    }

    private enum CodingKeys: String, CodingKey {
        case jsonrpc, id, result, error
    }

    private struct ErrorBody: Encodable {
        let code: Int
        let message: String
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("2.0", forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        switch outcome {
        case .null:
            try container.encodeNil(forKey: .result)

        case .nulls(let count):
            try container.encode([String?](repeating: nil, count: count), forKey: .result)

        case .folders(let folders):
            try container.encode(folders, forKey: .result)

        case let .error(code, message):
            try container.encode(ErrorBody(code: code, message: message), forKey: .error)
        }
    }
}

/// Parameters of the `$/cancelRequest` notification.
struct LSPCancelParams: Codable, Sendable {
    let id: RequestId
}
