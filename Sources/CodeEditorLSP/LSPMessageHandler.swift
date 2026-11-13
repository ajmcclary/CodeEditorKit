// LSP message handling is available on all platforms to support remote LSP connections

import CodeEditorCommon
import Foundation

/// LSP error response structure
struct ResponseError: Codable {
    let code: Int
    let message: String
    let data: String?
}

/// Handles LSP message parsing and protocol communication
actor LSPMessageHandler {
    // MARK: - Properties

    /// Callback for incoming notifications
    var onNotification: (@Sendable (String, Data) -> Void)?

    /// Callback for incoming responses
    var onResponse: (@Sendable (RequestId, Result<LSPResponse, LSPError>) -> Void)?

    /// Callback for server→client requests (`method` and `id`). The owner
    /// must answer every one: servers such as sourcekit-lsp stop replying
    /// to the client until their request is answered.
    var onServerRequest: (@Sendable (RequestId, String, Data) -> Void)?

    /// Callback for an unrecoverable framing violation; the owner must fail
    /// the connection.
    var onStreamFailure: (@Sendable (LSPError) -> Void)?

    /// Buffer for incomplete messages
    private var messageBuffer = Data()

    /// Logger for debugging
    private let logger = CodeEditorLog.lsp(category: "LSPMessageHandler")

    // MARK: - Configuration

    /// Set the notification callback
    func setNotificationCallback(_ callback: @escaping @Sendable (String, Data) -> Void) {
        onNotification = callback
    }

    /// Set the response callback
    func setResponseCallback(_ callback: @escaping @Sendable (RequestId, Result<LSPResponse, LSPError>) -> Void) {
        onResponse = callback
    }

    /// Set the server→client request callback
    func setServerRequestCallback(_ callback: @escaping @Sendable (RequestId, String, Data) -> Void) {
        onServerRequest = callback
    }

    /// Set the unrecoverable-stream-failure callback
    func setStreamFailureCallback(_ callback: @escaping @Sendable (LSPError) -> Void) {
        onStreamFailure = callback
    }

    /// Drop any partial frame left by a previous connection.
    func reset() {
        messageBuffer.removeAll()
    }

    // MARK: - Message Processing

    /// Process incoming data from the LSP server
    /// - Parameter data: Raw data received from server
    func processIncomingData(_ data: Data) {
        messageBuffer.append(data)

        // Process complete messages
        do {
            while let message = try extractCompleteMessage() {
                processMessage(message)
            }
        } catch {
            logger.error("Unrecoverable LSP framing: \(String(describing: error))")
            onStreamFailure?(.invalidResponse("Unrecoverable LSP framing: \(error)"))
        }
    }

    // MARK: - Private Methods

    private func extractCompleteMessage() throws -> Data? {
        // Framing (header scan, Content-Length parse, malformed-framing
        // recovery) is owned by LSPFrameCodec; this actor owns only the
        // accumulation buffer.
        try LSPFrameCodec.extractCompleteMessage(from: &messageBuffer)
    }

    private func processMessage(_ data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let messageDict = json as? [String: Any] else {
                logger.error("Invalid LSP message format")
                return
            }

            if let method = messageDict["method"] as? String {
                if let rawID = messageDict["id"] {
                    // A request from the server: it carries an id and needs a reply.
                    guard let requestID = extractRequestId(from: rawID) else {
                        logger.error("Invalid request ID in server request \(method)")
                        return
                    }
                    onServerRequest?(requestID, method, paramsData(from: messageDict))
                } else {
                    processServerMessage(method: method, messageDict: messageDict, data: data)
                }
            } else if let id = messageDict["id"] {
                // This is a response to our request
                processServerResponse(id: id, messageDict: messageDict, data: data)
            } else {
                logger.error("Unknown LSP message type")
            }
        } catch {
            logger.error("Failed to parse LSP message: \(error.localizedDescription)")
        }
    }

    private func processServerMessage(method: String, messageDict: [String: Any], data _: Data) {
        // Call notification handler
        onNotification?(method, paramsData(from: messageDict))
    }

    /// Re-encodes `params`. `params` may be any JSON value, so fragments
    /// are allowed: without the option a scalar or `null` raises an
    /// Objective-C exception that Swift cannot catch.
    private func paramsData(from messageDict: [String: Any]) -> Data {
        guard let params = messageDict["params"], !(params is NSNull) else { return Data() }
        do {
            return try JSONSerialization.data(withJSONObject: params, options: [.fragmentsAllowed])
        } catch {
            logger.error("Failed to serialize params: \(error.localizedDescription)")
            return Data()
        }
    }

    private func processServerResponse(id: Any, messageDict: [String: Any], data: Data) {
        guard let requestId = extractRequestId(from: id) else {
            logger.error("Invalid request ID in response")
            return
        }

        if let error = messageDict["error"] as? [String: Any] {
            // Error response
            let lspError = parseLSPError(from: error)
            onResponse?(requestId, .failure(lspError))
        } else {
            // Success response
            let response = LSPResponse(data: data, messageDict: messageDict)
            onResponse?(requestId, .success(response))
        }
    }

    private func extractRequestId(from id: Any) -> RequestId? {
        // LSP / JSON-RPC permits numeric or string IDs. Preserve string IDs
        // verbatim (including non-numeric ones like UUIDs) so they route to
        // the correct pending continuation — the previous coercion to `Int`
        // silently dropped responses whose ID didn't parse as a number.
        if let intId = id as? Int {
            return .number(intId)
        }
        if let stringId = id as? String {
            return .string(stringId)
        }
        return nil
    }

    private func parseLSPError(from errorDict: [String: Any]) -> LSPError {
        let code = errorDict["code"] as? Int ?? -1
        let message = errorDict["message"] as? String ?? "Unknown error"
        let data = errorDict["data"]

        return LSPError.serverError(code: code, message: message, data: data as? String)
    }
}

/// LSP response wrapper that provides type-safe decoding
public struct LSPResponse: Sendable {
    private let data: Data

    init(data: Data, messageDict _: [String: Any]) {
        self.data = data
    }

    /// Decode the response result as a specific type
    /// - Parameter type: The type to decode to
    /// - Returns: Decoded value
    /// - Throws: LSPError if decoding fails, including when the result is
    ///   `null` (use ``decodeIfPresent(as:)`` where `null` is a valid answer).
    public func decode<T: Codable>(as type: T.Type) throws -> T {
        guard let value = try decodeIfPresent(as: type) else {
            throw LSPError.decodingError("Failed to decode \(type): result is null")
        }
        return value
    }

    /// Decode the response result, returning nil when the result is `null`
    /// (the normal answer to, for example, a hover over blank space).
    /// - Throws: `LSPError.serverError` for an error response,
    ///   `LSPError.invalidResponse` when there is no `result`, and
    ///   `LSPError.decodingError` when the result does not decode as `T`.
    public func decodeIfPresent<T: Codable>(as type: T.Type) throws -> T? {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = json as? [String: Any] else {
            throw LSPError.invalidResponse("Failed to parse response")
        }

        // Check for error response
        if let errorDict = dict["error"] as? [String: Any] {
            let code = errorDict["code"] as? Int ?? -1
            let message = errorDict["message"] as? String ?? "Unknown error"
            let data = errorDict["data"] as? String
            throw LSPError.serverError(code: code, message: message, data: data)
        }

        guard dict["result"] != nil else {
            throw LSPError.invalidResponse("No result in response")
        }

        // Decode the result straight out of the original bytes; re-serialising
        // it with `JSONSerialization` raised an uncatchable exception for a
        // `null` or scalar result.
        do {
            return try JSONDecoder().decode(ResultEnvelope<T>.self, from: data).result
        } catch {
            throw LSPError.decodingError("Failed to decode \(type): \(error.localizedDescription)")
        }
    }

    /// True when the response's `result` is JSON `null`.
    public var isNullResult: Bool {
        rawResult is NSNull
    }

    /// Get the raw result object
    public var rawResult: Any? {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = json as? [String: Any] else {
            return nil
        }
        return dict["result"]
    }
}

/// The `result` member of a JSON-RPC response; `null` decodes as nil.
private struct ResultEnvelope<T: Decodable>: Decodable {
    let result: T?

    private enum CodingKeys: String, CodingKey {
        case result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        result = try container.decodeIfPresent(T.self, forKey: .result)
    }
}
