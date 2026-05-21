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
    var onResponse: (@Sendable (Int, Result<LSPResponse, LSPError>) -> Void)?

    /// Buffer for incomplete messages
    private var messageBuffer = Data()

    /// Logger for debugging
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.lsp", category: "LSPMessageHandler")

    // MARK: - Configuration

    /// Set the notification callback
    func setNotificationCallback(_ callback: @escaping @Sendable (String, Data) -> Void) {
        onNotification = callback
    }

    /// Set the response callback  
    func setResponseCallback(_ callback: @escaping @Sendable (Int, Result<LSPResponse, LSPError>) -> Void) {
        onResponse = callback
    }

    // MARK: - Message Processing

    /// Process incoming data from the LSP server
    /// - Parameter data: Raw data received from server
    func processIncomingData(_ data: Data) {
        messageBuffer.append(data)

        // Process complete messages
        while let message = extractCompleteMessage() {
            processMessage(message)
        }
    }

    // MARK: - Private Methods

    private func extractCompleteMessage() -> Data? {
        // LSP messages have format: "Content-Length: <length>\r\n\r\n<json>"
        // The internal loop is what gives the recovery path a chance to be
        // useful: after `recoverFromMalformedFraming` advances the buffer
        // past a bad header, the next iteration immediately re-attempts the
        // parse on whatever framing now sits at the front of the buffer.
        // Without it, the outer `while` in `processIncomingData` would exit
        // on the bad-header `return nil` and never look at the recovered
        // bytes until more data arrived from the transport.
        while true {
            guard let headerEndRange = messageBuffer.range(of: Data("\r\n\r\n".utf8)) else {
                return nil // Header not complete
            }

            let headerData = messageBuffer.subdata(in: 0..<headerEndRange.lowerBound)
            guard let headerString = String(data: headerData, encoding: .utf8) else {
                logger.error("Failed to decode message header")
                recoverFromMalformedFraming(skipPast: headerEndRange.upperBound)
                continue
            }

            // Parse Content-Length
            guard let contentLength = parseContentLength(from: headerString) else {
                logger.error("Failed to parse Content-Length from header: \(headerString)")
                recoverFromMalformedFraming(skipPast: headerEndRange.upperBound)
                continue
            }

            let messageStart = headerEndRange.upperBound
            let messageEnd = messageStart + contentLength

            // Check if we have the complete message
            guard messageBuffer.count >= messageEnd else {
                return nil // Message not complete
            }

            // Extract the complete message
            let messageData = messageBuffer.subdata(in: messageStart..<messageEnd)

            // Remove processed data from buffer
            messageBuffer.removeSubrange(0..<messageEnd)

            return messageData
        }
    }

    /// Drop bytes up to the next plausible message-framing marker so that
    /// pending well-formed messages later in the buffer survive a parse
    /// failure on the head. Searches for `Content-Length:` starting after
    /// the malformed header's own `\r\n\r\n` (passed as `searchStart`).
    /// LSP frames concatenate body-then-next-header with no separator, so
    /// the marker is the header keyword on its own; the rare case where a
    /// JSON body literally contains the string "Content-Length:" (e.g. a
    /// server logging its own LSP traffic) could cause a false recovery
    /// point — accepted in exchange for not nuking the buffer. When no
    /// marker is found, the buffer is unrecoverable in-protocol and is
    /// cleared (matches the prior unconditional behavior).
    private func recoverFromMalformedFraming(skipPast searchStart: Data.Index) {
        let marker = Data("Content-Length:".utf8)
        let bufferEnd = messageBuffer.endIndex

        guard searchStart < bufferEnd,
              let nextMarker = messageBuffer.range(of: marker, in: searchStart..<bufferEnd) else {
            logger.warning("Cannot locate next Content-Length framing — clearing message buffer")
            messageBuffer.removeAll()
            return
        }

        let droppedBytes = nextMarker.lowerBound
        logger.warning(
            "Recovered message buffer past malformed framing: dropped \(droppedBytes) bytes, resuming at next Content-Length"
        )
        messageBuffer.removeSubrange(0..<nextMarker.lowerBound)
    }

    private func parseContentLength(from header: String) -> Int? {
        let lines = header.components(separatedBy: "\r\n")

        for line in lines where line.hasPrefix("Content-Length:") {
            let parts = line.components(separatedBy: ":")
            if parts.count >= 2 {
                let lengthString = parts[1].trimmingCharacters(in: .whitespaces)
                return Int(lengthString)
            }
        }

        return nil
    }

    private func processMessage(_ data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let messageDict = json as? [String: Any] else {
                logger.error("Invalid LSP message format")
                return
            }

            if let method = messageDict["method"] as? String {
                // This is a notification or request from server
                processServerMessage(method: method, messageDict: messageDict, data: data)
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
        // Extract params if present
        var paramsData = Data()
        if let params = messageDict["params"] {
            do {
                paramsData = try JSONSerialization.data(withJSONObject: params, options: [])
            } catch {
                logger.error("Failed to serialize params: \(error.localizedDescription)")
            }
        }

        // Call notification handler
        onNotification?(method, paramsData)
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

    private func extractRequestId(from id: Any) -> Int? {
        if let intId = id as? Int {
            return intId
        } else if let stringId = id as? String, let intId = Int(stringId) {
            return intId
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
    /// - Throws: LSPError if decoding fails
    public func decode<T: Codable>(as type: T.Type) throws -> T {
        // Parse JSON manually since we can't nest generic structs
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

        // Extract result
        guard let result = dict["result"] else {
            throw LSPError.invalidResponse("No result in response")
        }

        // Encode result back to data and decode as requested type
        let resultData = try JSONSerialization.data(withJSONObject: result, options: [])

        do {
            return try JSONDecoder().decode(type, from: resultData)
        } catch {
            throw LSPError.decodingError("Failed to decode \(type): \(error.localizedDescription)")
        }
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
