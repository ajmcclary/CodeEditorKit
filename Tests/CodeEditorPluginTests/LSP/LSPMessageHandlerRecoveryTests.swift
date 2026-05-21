@testable import CodeEditorLSP
import Foundation
import XCTest

/// Regression coverage for the message-buffer recovery path. Before this fix,
/// any header parse failure (bad UTF-8 in the header bytes or an unparseable
/// `Content-Length`) called `messageBuffer.removeAll()` and silently dropped
/// every well-formed message already buffered behind it. Recovery now scans
/// for the next `\r\nContent-Length:` framing marker so subsequent messages
/// survive the bad framing on the head.
final class LSPMessageHandlerRecoveryTests: XCTestCase {
    actor MessageInbox {
        private(set) var notifications: [(String, Data)] = []
        private(set) var responses: [(Int, Result<LSPResponse, LSPError>)] = []

        func appendNotification(_ method: String, _ params: Data) {
            notifications.append((method, params))
        }

        func appendResponse(_ id: Int, _ result: Result<LSPResponse, LSPError>) {
            responses.append((id, result))
        }
    }

    /// Wraps the JSON `body` in an LSP frame, optionally with a deliberately
    /// broken `Content-Length` line for malformed-framing tests.
    private func frame(body: String, brokenContentLength: Bool = false) -> Data {
        var header = "Content-Length: "
        if brokenContentLength {
            header += "not-a-number"
        } else {
            header += "\(body.utf8.count)"
        }
        header += "\r\n\r\n"
        return Data(header.utf8) + Data(body.utf8)
    }

    private func makeHandler(inbox: MessageInbox) async -> LSPMessageHandler {
        let handler = LSPMessageHandler()
        await handler.setNotificationCallback { method, params in
            Task { await inbox.appendNotification(method, params) }
        }
        await handler.setResponseCallback { id, result in
            Task { await inbox.appendResponse(id, result) }
        }
        return handler
    }

    func testBackToBackMessagesParseInOrder() async throws {
        let inbox = MessageInbox()
        let handler = await makeHandler(inbox: inbox)

        let first = #"{"jsonrpc":"2.0","method":"window/logMessage","params":{"type":1,"message":"first"}}"#
        let second = #"{"jsonrpc":"2.0","method":"window/logMessage","params":{"type":1,"message":"second"}}"#

        await handler.processIncomingData(frame(body: first) + frame(body: second))

        // Wait for the dispatched-Task notifications to land in the inbox.
        try await Task.sleep(for: .milliseconds(50))

        let notifications = await inbox.notifications
        XCTAssertEqual(notifications.map(\.0), ["window/logMessage", "window/logMessage"])
    }

    func testMalformedContentLengthRecoversSubsequentMessage() async throws {
        let inbox = MessageInbox()
        let handler = await makeHandler(inbox: inbox)

        let goodBody = #"{"jsonrpc":"2.0","method":"window/logMessage","params":{"type":1,"message":"recovered"}}"#
        // First frame's Content-Length is "not-a-number" → header parses as
        // bytes but parseContentLength returns nil. The fix should drop bytes
        // up to the next `\r\nContent-Length:` marker and parse the good
        // message that follows.
        let stream = frame(body: "ignored-bad-body", brokenContentLength: true) + frame(body: goodBody)

        await handler.processIncomingData(stream)

        try await Task.sleep(for: .milliseconds(50))

        let notifications = await inbox.notifications
        XCTAssertEqual(notifications.count, 1, "Subsequent well-formed message must survive bad framing on the head")
        XCTAssertEqual(notifications.first?.0, "window/logMessage")
    }

    func testMalformedHeaderBytesRecoversSubsequentMessage() async throws {
        let inbox = MessageInbox()
        let handler = await makeHandler(inbox: inbox)

        let goodBody = #"{"jsonrpc":"2.0","method":"window/logMessage","params":{"type":1,"message":"recovered"}}"#
        // Use a non-UTF-8 byte sequence in the header position; the handler's
        // `String(data:encoding:.utf8)` decode fails, triggering the same
        // recovery path.
        var bad = Data([0xFF, 0xFE, 0xFD])
        bad.append(Data("\r\n\r\nignored-body".utf8))
        let stream = bad + frame(body: goodBody)

        await handler.processIncomingData(stream)

        try await Task.sleep(for: .milliseconds(50))

        let notifications = await inbox.notifications
        XCTAssertEqual(notifications.count, 1, "Non-UTF-8 header bytes must not nuke pending messages")
        XCTAssertEqual(notifications.first?.0, "window/logMessage")
    }

    func testUnrecoverableBufferIsClearedAsFallback() async throws {
        let inbox = MessageInbox()
        let handler = await makeHandler(inbox: inbox)

        // A bad header with no subsequent `\r\nContent-Length:` anywhere in
        // the buffer — recovery is impossible, fallback is to clear.
        let bad = frame(body: "ignored", brokenContentLength: true)
        await handler.processIncomingData(bad)

        try await Task.sleep(for: .milliseconds(50))

        let notifications = await inbox.notifications
        XCTAssertEqual(notifications.count, 0, "No salvageable message; nothing should be emitted")

        // After the wipe, the handler must be back in a usable state — a
        // fresh good message arriving next still parses.
        let goodBody = #"{"jsonrpc":"2.0","method":"window/logMessage","params":{"type":1,"message":"after"}}"#
        await handler.processIncomingData(frame(body: goodBody))

        try await Task.sleep(for: .milliseconds(50))

        let notificationsAfter = await inbox.notifications
        XCTAssertEqual(notificationsAfter.count, 1)
    }
}
