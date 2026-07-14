// Content-Length framing is available on all platforms (process + WebSocket transports)

import CodeEditorCommon
import Foundation

/// Content-Length framing codec for the LSP base protocol.
///
/// The single owner of `Content-Length: <n>\r\n\r\n<body>` framing in this
/// package: `ProcessTransport` and `WebSocketTransport` encode outbound
/// frames through `encode(_:)`, and `LSPMessageHandler` drains inbound
/// buffers through `extractCompleteMessage(from:)`, which carries the
/// malformed-framing recovery behavior pinned by
/// `LSPMessageHandlerRecoveryTests`.
enum LSPFrameCodec {
    private static let logger = CodeEditorLog.lsp(category: "LSPFrameCodec")

    /// Wrap a JSON-RPC payload in an LSP base-protocol frame.
    static func encode(_ payload: Data) -> Data {
        var framed = Data("Content-Length: \(payload.count)\r\n\r\n".utf8)
        framed.append(payload)
        return framed
    }

    /// Extract the first complete frame's body from `buffer`, consuming it
    /// (and any malformed prefix it recovers past). Returns nil when no
    /// complete frame is buffered; partial frames are left untouched.
    ///
    /// The internal loop is what gives the recovery path a chance to be
    /// useful: after `recoverFromMalformedFraming` advances the buffer past
    /// a bad header, the next iteration immediately re-attempts the parse
    /// on whatever framing now sits at the front of the buffer.
    static func extractCompleteMessage(from buffer: inout Data) -> Data? {
        while true {
            guard let headerEndRange = buffer.range(of: Data("\r\n\r\n".utf8)) else {
                return nil // Header not complete
            }

            let headerData = buffer.subdata(in: 0..<headerEndRange.lowerBound)
            guard let headerString = String(data: headerData, encoding: .utf8) else {
                logger.error("Failed to decode message header")
                recoverFromMalformedFraming(in: &buffer, skipPast: headerEndRange.upperBound)
                continue
            }

            guard let contentLength = parseContentLength(from: headerString) else {
                logger.error("Failed to parse Content-Length from header: \(headerString)")
                recoverFromMalformedFraming(in: &buffer, skipPast: headerEndRange.upperBound)
                continue
            }

            let messageStart = headerEndRange.upperBound
            let messageEnd = messageStart + contentLength

            guard buffer.count >= messageEnd else {
                return nil // Message not complete
            }

            let messageData = buffer.subdata(in: messageStart..<messageEnd)
            buffer.removeSubrange(0..<messageEnd)
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
    /// cleared.
    private static func recoverFromMalformedFraming(in buffer: inout Data, skipPast searchStart: Data.Index) {
        let marker = Data("Content-Length:".utf8)
        let bufferEnd = buffer.endIndex

        guard searchStart < bufferEnd,
              let nextMarker = buffer.range(of: marker, in: searchStart..<bufferEnd) else {
            logger.warning("Cannot locate next Content-Length framing — clearing message buffer")
            buffer.removeAll()
            return
        }

        let droppedBytes = nextMarker.lowerBound
        logger.warning(
            "Recovered message buffer past malformed framing: dropped \(droppedBytes) bytes, resuming at next Content-Length"
        )
        buffer.removeSubrange(0..<nextMarker.lowerBound)
    }

    private static func parseContentLength(from header: String) -> Int? {
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
}
